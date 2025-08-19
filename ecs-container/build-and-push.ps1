# PowerShell script to build and push container image
# Equivalent of build-and-push.sh for Windows

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Set default values
$AWS_REGION = if ($env:AWS_REGION) { $env:AWS_REGION } else { "ap-south-1" }
$ECR_REPOSITORY_NAME = "embedding-pipeline-trigger"
$IMAGE_TAG = if ($env:IMAGE_TAG) { $env:IMAGE_TAG } else { "latest" }

# Colors for output
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    $ColorMap = @{ "Red" = "Red"; "Green" = "Green"; "Yellow" = "Yellow"; "Blue" = "Blue"; "White" = "White" }
    Write-Host $Message -ForegroundColor $ColorMap[$Color]
}

# Check if Docker is running
Write-ColorOutput "Checking Docker availability..." "Yellow"
try {
    $null = docker --version 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Docker command not found" }
    
    $null = docker ps 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Docker daemon not running" }
    
    Write-ColorOutput "✓ Docker is running and accessible" "Green"
} catch {
    Write-ColorOutput "Error: Docker is not available or not running." "Red"
    Write-ColorOutput "Please ensure Docker Desktop is installed and running on Windows." "Yellow"
    Write-ColorOutput "Steps to fix:" "Yellow"
    Write-ColorOutput "1. Install Docker Desktop for Windows if not installed" "White"
    Write-ColorOutput "2. Start Docker Desktop application" "White"
    Write-ColorOutput "3. Wait for Docker to fully start (check system tray)" "White"
    Write-ColorOutput "4. Run 'docker ps' to verify it's working" "White"
    # exit 1
}

Write-ColorOutput "Building and pushing container image..." "Green"

# Get AWS Account ID
try {
    $AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
    if ($LASTEXITCODE -ne 0) { throw "Failed to get AWS account ID" }
} catch {
    Write-ColorOutput "Error: Failed to get AWS account ID. Check AWS credentials." "Red"
    # exit 1
}

Write-ColorOutput "AWS Account: $AWS_ACCOUNT_ID" "Yellow"
Write-ColorOutput "Region: $AWS_REGION" "Yellow"
Write-ColorOutput "Repository: $ECR_REPOSITORY_NAME" "Yellow"
Write-ColorOutput "Tag: $IMAGE_TAG" "Yellow"
Write-Host

# Create ECR repository if it doesn't exist
Write-ColorOutput "Creating ECR repository if needed..." "Yellow"

# Check if repository exists
$repoExists = $false
try {
    $null = aws ecr describe-repositories --repository-names $ECR_REPOSITORY_NAME --region $AWS_REGION --output text 2>$null
    if ($LASTEXITCODE -eq 0) {
        $repoExists = $true
        Write-ColorOutput "✓ ECR repository already exists" "Green"
    }
} catch {
    # Repository doesn't exist, we'll create it
}

# Create repository if it doesn't exist
if (-not $repoExists) {
    try {
        $createResult = aws ecr create-repository --repository-name $ECR_REPOSITORY_NAME --region $AWS_REGION --output json
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✓ Created ECR repository successfully" "Green"
        } else {
            throw "Failed to create ECR repository"
        }
    } catch {
        Write-ColorOutput "Error creating ECR repository: $_" "Red"
        Write-ColorOutput "Please check your AWS permissions for ECR operations." "Yellow"
        exit 1
    }
}

# Verify repository exists before proceeding
Write-ColorOutput "Verifying ECR repository..." "Yellow"
try {
    $repoInfo = aws ecr describe-repositories --repository-names $ECR_REPOSITORY_NAME --region $AWS_REGION --output json
    if ($LASTEXITCODE -ne 0) {
        throw "Repository verification failed"
    }
    Write-ColorOutput "✓ ECR repository verified and ready" "Green"
} catch {
    Write-ColorOutput "Error: ECR repository not available: $_" "Red"
    exit 1
}

# Get ECR login token
Write-ColorOutput "Logging into ECR..." "Yellow"
try {
    $loginCommand = aws ecr get-login-password --region $AWS_REGION
    if ($LASTEXITCODE -ne 0) { throw "Failed to get ECR login password" }
    
    $loginCommand | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
    if ($LASTEXITCODE -ne 0) { throw "Failed to login to ECR" }
    
    Write-ColorOutput "✓ Successfully logged into ECR" "Green"
} catch {
    Write-ColorOutput "Error logging into ECR: $_" "Red"
    # exit 1
}

# Build image
Write-ColorOutput "Building Docker image..." "Yellow"
try {
    docker build -t "${ECR_REPOSITORY_NAME}:${IMAGE_TAG}" .
    if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }
    Write-ColorOutput "✓ Docker image built successfully" "Green"
} catch {
    Write-ColorOutput "Error building Docker image: $_" "Red"
    # exit 1
}

# Tag image for ECR
$ECR_URI = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY_NAME}:${IMAGE_TAG}"
Write-ColorOutput "Tagging image for ECR..." "Yellow"
try {
    docker tag "${ECR_REPOSITORY_NAME}:${IMAGE_TAG}" "$ECR_URI"
    if ($LASTEXITCODE -ne 0) { throw "Docker tag failed" }
    Write-ColorOutput "✓ Image tagged for ECR" "Green"
} catch {
    Write-ColorOutput "Error tagging image: $_" "Red"
    # exit 1
}

# Push image
Write-ColorOutput "Pushing image to ECR..." "Yellow"
try {
    docker push "$ECR_URI"
    if ($LASTEXITCODE -ne 0) { throw "Docker push failed" }
    Write-ColorOutput "✓ Image pushed successfully!" "Green"
} catch {
    Write-ColorOutput "Error pushing image: $_" "Red"
    # exit 1
}

Write-Host
Write-ColorOutput "Image pushed successfully!" "Green"
Write-ColorOutput "Image URI: $ECR_URI" "Blue"
