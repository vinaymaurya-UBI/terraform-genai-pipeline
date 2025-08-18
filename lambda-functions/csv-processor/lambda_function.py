import json
import boto3
import pandas as pd
from io import StringIO
import numpy as np

s3_client = boto3.client('s3')
bedrock_client = boto3.client('bedrock-runtime')

def lambda_handler(event, context):
    try:
        s3_bucket = event['s3_bucket']
        csv_file_path = event['csv_file_path']
        columns_to_embed = event['columns_to_embed']
        
        csv_obj = s3_client.get_object(Bucket=s3_bucket, Key=csv_file_path)
        csv_content = csv_obj['Body'].read().decode('utf-8')
        df = pd.read_csv(StringIO(csv_content))
        
        embeddings_data = []
        
        for index, row in df.iterrows():
            text_to_embed = ' '.join([str(row[col]) for col in columns_to_embed if col in df.columns])
            
            metadata = {}
            for col in df.columns:
                if col not in columns_to_embed:
                    metadata[col] = str(row[col])
            
            embedding_vector = generate_embedding(text_to_embed)
            
            embeddings_data.append({
                'id': f"{csv_file_path.split('/')[-1].split('.')[0]}_{index}",
                'text': text_to_embed,
                'embedding': embedding_vector,
                'metadata': metadata
            })
        
        return {
            'statusCode': 200,
            'body': {
                'embeddings_data': embeddings_data,
                'csv_filename': csv_file_path.split('/')[-1].split('.')[0],
                'total_records': len(embeddings_data)
            }
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': {'error': str(e)}
        }

def generate_embedding(text):
    try:
        response = bedrock_client.invoke_model(
            modelId='amazon.titan-embed-text-v1',
            body=json.dumps({
                'inputText': text
            }),
            contentType='application/json'
        )
        
        response_body = json.loads(response['body'].read())
        return response_body['embedding']
        
    except Exception as e:
        raise Exception(f"Bedrock embedding failed: {str(e)}")
