resource "aws_lambda_layer_version" "embedding_layer" {
  filename            = var.layer_zip_path
  layer_name          = var.layer_name
  compatible_runtimes = ["python3.9", "python3.10", "python3.11"]
  source_code_hash    = filebase64sha256(var.layer_zip_path)

  depends_on = [var.layer_zip_path]
}
