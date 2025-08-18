import json
import boto3
import os
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth

def lambda_handler(event, context):
    try:
        embeddings_data = event['body']['embeddings_data']
        csv_filename = event['body']['csv_filename']
        
        opensearch_endpoint = os.environ['OPENSEARCH_ENDPOINT']
        region = os.environ['AWS_REGION']
        
        credentials = boto3.Session().get_credentials()
        awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, region, 'aoss', session_token=credentials.token)
        
        client = OpenSearch(
            hosts=[{'host': opensearch_endpoint.replace('https://', ''), 'port': 443}],
            http_auth=awsauth,
            use_ssl=True,
            verify_certs=True,
            connection_class=RequestsHttpConnection
        )
        
        index_name = csv_filename.lower().replace('_', '-')
        
        if not client.indices.exists(index_name):
            mapping = {
                "mappings": {
                    "properties": {
                        "text": {"type": "text"},
                        "embedding": {
                            "type": "knn_vector",
                            "dimension": 1536,
                            "method": {
                                "name": "hnsw",
                                "space_type": "cosinesimil",
                                "engine": "nmslib"
                            }
                        },
                        "metadata": {"type": "object"}
                    }
                },
                "settings": {
                    "index": {
                        "knn": True
                    }
                }
            }
            client.indices.create(index_name, body=mapping)
        
        indexed_count = 0
        for record in embeddings_data:
            doc = {
                'text': record['text'],
                'embedding': record['embedding'],
                'metadata': record['metadata']
            }
            
            response = client.index(
                index=index_name,
                id=record['id'],
                body=doc
            )
            
            if response['result'] in ['created', 'updated']:
                indexed_count += 1
        
        return {
            'statusCode': 200,
            'body': {
                'message': f'Successfully indexed {indexed_count} records to {index_name}',
                'index_name': index_name,
                'indexed_count': indexed_count
            }
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': {'error': str(e)}
        }
