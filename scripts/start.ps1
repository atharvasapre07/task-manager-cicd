<#
 start.ps1 - Experiment 5: entire pipeline, from source code to a running app on AWS.
 Stages: 1 Test -> 2 Build -> 3 Push -> 4 Deploy -> 5 Verify
 Run from the project root:  .\scripts\start.ps1
 Prerequisites: docker login done once, aws configure done once.
#>
param(
    [string]$DockerUser = "atharvasapre03",
    [string]$Repo       = "task-manager",
    [string]$Region     = "ap-south-1",
    [string]$Stack      = "task-manager-stack"
)
$ErrorActionPreference = "Stop"
$env:AWS_DEFAULT_REGION = $Region
$env:AWS_PAGER = ""

function Check($what) {
    if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: $what" -ForegroundColor Red; exit 1 }
}
function Stage($n, $text) { Write-Host "`n=== STAGE $n : $text ===" -ForegroundColor Cyan }

$sw = [Diagnostics.Stopwatch]::StartNew()

# Start Jenkins too (ignored if it is already running or does not exist)
try { docker start jenkins 2>$null | Out-Null } catch { }

# Use the project's venv if there is one, so pytest and Flask are available
$py = "python"
if (Test-Path ".\venv\Scripts\python.exe") { $py = ".\venv\Scripts\python.exe" }

# Tag the image with the git commit, or a timestamp if this is not a git repository
$tag = (git rev-parse --short HEAD 2>$null)
if (-not $tag) { $tag = Get-Date -Format "yyyyMMddHHmm" }
$image = "$DockerUser/$Repo"
Write-Host "Image tag for this run: $tag"

Stage 1 "Test (pytest)"
& $py -m pytest -q
Check "unit tests - nothing was built or deployed"

Stage 2 "Build (docker build)"
docker build --build-arg GIT_COMMIT=$tag -t "${image}:$tag" -t "${image}:latest" .
Check "docker build"

Stage 3 "Push to Docker Hub"
docker push "${image}:$tag"
Check "docker push (run docker login first)"
docker push "${image}:latest"
Check "docker push latest"

Stage 4 "Deploy to Amazon ECS Fargate (CloudFormation)"
# Network of the account's default VPC in ap-south-1 (same values used in Experiment 6)
$vpc     = "vpc-0406582b2e56c52a4"
$subnets = "subnet-07c10a35d10d1e0d6,subnet-0bc48509aa5748d61,subnet-0fde631a8c8feae01"
Write-Host "VPC: $vpc"
Write-Host "Subnets: $subnets"

# A stack left in ROLLBACK_COMPLETE by a failed first attempt cannot be updated: remove it first
try { $status = aws cloudformation describe-stacks --stack-name $Stack --query "Stacks[0].StackStatus" --output text 2>$null } catch { $status = "" }
if ($status -eq "ROLLBACK_COMPLETE") {
    Write-Host "Previous attempt failed (ROLLBACK_COMPLETE) - deleting it first..." -ForegroundColor Yellow
    aws cloudformation delete-stack --stack-name $Stack
    aws cloudformation wait stack-delete-complete --stack-name $Stack
}

aws cloudformation deploy `
    --template-file infra/infra.yaml `
    --stack-name $Stack `
    --capabilities CAPABILITY_IAM `
    --no-fail-on-empty-changeset `
    --parameter-overrides "VpcId=$vpc" "SubnetIds=$subnets" "ImageUrl=docker.io/${image}:$tag" "DesiredCount=1"
Check "cloudformation deploy"
aws ecs wait services-stable --cluster tm-cf-cluster --services tm-cf-service
Check "waiting for the service to become stable"

Stage 5 "Verify"
$task = aws ecs list-tasks --cluster tm-cf-cluster --service-name tm-cf-service --query "taskArns[0]" --output text
$eni  = aws ecs describe-tasks --cluster tm-cf-cluster --tasks $task --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text
$ip   = aws ec2 describe-network-interfaces --network-interface-ids $eni --query "NetworkInterfaces[0].Association.PublicIp" --output text
Check "find public IP"
Start-Sleep -Seconds 10
try {
    $h = Invoke-RestMethod "http://${ip}:8080/health" -TimeoutSec 15
    Write-Host "Health check: $($h.status)" -ForegroundColor Green
} catch { Write-Host "Health check not ready yet - open the URL in a minute." -ForegroundColor Yellow }

$sw.Stop()
Write-Host "`nDONE in $([int]$sw.Elapsed.TotalSeconds) seconds. Commit/tag: $tag"
Write-Host "App URL: http://${ip}:8080" -ForegroundColor Green
Write-Host "Remember to run .\scripts\end.ps1 when you finish to stop AWS charges."
