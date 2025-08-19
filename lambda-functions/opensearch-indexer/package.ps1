# PowerShell script to package OpenSearch indexer lambda
# Equivalent of package.sh for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Packaging OpenSearch indexer lambda..." -ForegroundColor Green

# Remove existing zip if it exists
if (Test-Path "opensearch-indexer.zip") {
    Remove-Item "opensearch-indexer.zip" -Force
    Write-Host "Removed existing opensearch-indexer.zip" -ForegroundColor Yellow
}

# Create zip file with lambda function
try {
    Compress-Archive -Path "lambda_function.py" -DestinationPath "opensearch-indexer.zip" -Force
    Write-Host "✓ Created opensearch-indexer.zip successfully" -ForegroundColor Green
} catch {
    Write-Host "Error creating zip file: $_" -ForegroundColor Red
    exit 1
}

Write-Host "✓ OpenSearch indexer lambda packaged successfully!" -ForegroundColor Green
