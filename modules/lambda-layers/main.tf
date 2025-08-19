
provider "aws" {
  region = "ap-south-1"
}


resource "aws_lambda_layer_version" "embedding_layer-0" {
  filename            = var.layer_zip_path
  layer_name          = var.layer_name
  compatible_runtimes = ["python3.9", "python3.10", "python3.11"]
  source_code_hash    = filebase64sha256(var.layer_zip_path)

  depends_on = [var.layer_zip_path]
}

resource "aws_lambda_layer_version" "embedding_layer-1" {
  filename            = var.layer_zip_path-1
  layer_name          = var.layer_name-1
  compatible_runtimes = ["python3.9", "python3.10", "python3.11"]
  source_code_hash    = filebase64sha256(var.layer_zip_path-1)

  depends_on = [var.layer_zip_path-1]
}

resource "aws_lambda_layer_version" "embedding_layer-2" {
  filename            = var.layer_zip_path-2
  layer_name          = var.layer_name-2
  compatible_runtimes = ["python3.9", "python3.10", "python3.11"]
  source_code_hash    = filebase64sha256(var.layer_zip_path-2)

  depends_on = [var.layer_zip_path-2]
}
