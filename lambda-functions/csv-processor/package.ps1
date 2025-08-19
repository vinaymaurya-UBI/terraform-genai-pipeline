# PowerShell script to package CSV processor lambda
# Equivalent of package.sh for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Packaging CSV processor lambda..." -ForegroundColor Green

# Remove existing zip if it exists
if (Test-Path "csv-processor.zip") {
    Remove-Item "csv-processor.zip" -Force
    Write-Host "Removed existing csv-processor.zip" -ForegroundColor Yellow
}

# Create zip file with lambda function
try {
    Compress-Archive -Path "lambda_function.py" -DestinationPath "csv-processor.zip" -Force
    Write-Host "✓ Created csv-processor.zip successfully" -ForegroundColor Green
} catch {
    Write-Host "Error creating zip file: $_" -ForegroundColor Red
    exit 1
}

Write-Host "✓ CSV processor lambda packaged successfully!" -ForegroundColor Green
