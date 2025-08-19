
provider "aws" {
  region = "ap-south-1"
}


resource "aws_opensearchserverless_security_policy" "encryption_policy" {
  name = "${var.collection_name}-encryption"
  type = "encryption"
  policy = jsonencode({
    Rules = [
      {
        Resource = [
          "collection/${var.collection_name}"
        ]
        ResourceType = "collection"
      }
    ]
    AWSOwnedKey = true
  })
}




resource "aws_opensearchserverless_security_policy" "network_policy" {
  name        = "${var.collection_name}-network"
  type        = "network"
  description = "Network policy for ${var.collection_name}"
  policy = jsonencode([
    {
      Rules = [
        {
          Resource = [
            "collection/${var.collection_name}"
          ]
          ResourceType = "collection"
        },
        {
          Resource = [
            "collection/${var.collection_name}"
          ]
          ResourceType = "dashboard"
        }
      ]
      AllowFromPublic = true
    }
  ])
}



resource "aws_opensearchserverless_collection" "embedding_collection" {
  name = var.collection_name
  type = "VECTORSEARCH"

  tags = var.tags
}
