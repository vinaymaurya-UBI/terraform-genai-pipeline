output "access_policy_name" {
  description = "Name of the OpenSearch access policy"
  value       = aws_opensearchserverless_access_policy.data_access_policy.name
}
