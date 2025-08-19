# PowerShell script to build lambda layer
# Equivalent of build_layer.sh for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Write-Host "Building lambda layer..." -ForegroundColor Green

# Create python directory
if (Test-Path "python") {
    Remove-Item -Path "python" -Recurse -Force
}
New-Item -ItemType Directory -Name "python" -Force | Out-Null

# Install requirements
Write-Host "Installing requirements..." -ForegroundColor Yellow
pip install -r requirements.txt -t python/

# Create zip file
Write-Host "Creating zip file..." -ForegroundColor Yellow
if (Test-Path "embedding-layer.zip") {
    Remove-Item "embedding-layer.zip" -Force
}

# Use PowerShell's Compress-Archive or 7zip if available
try {
    Compress-Archive -Path "python/*" -DestinationPath "boto3-pandas-numpy-layer.zip" -Force
    Write-Host "✓ Created boto3-pandas-numpy-layer.zip successfully" -ForegroundColor Green
} catch {
    Write-Host "Error creating zip file: $_" -ForegroundColor Red
    exit 1
}

# Clean up
Remove-Item -Path "python" -Recurse -Force

Write-Host "✓ Lambda layer build completed!" -ForegroundColor Green
