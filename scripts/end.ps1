<#
 end.ps1 - Experiment 5: shuts everything down so no AWS charges continue.
 Deletes the CloudFormation stack, scales the manual ECS service to 0,
 then proves nothing is still running.
 Run from the project root:  .\scripts\end.ps1
#>
param(
    [string]$Region = "ap-south-1",
    [string]$Stack  = "task-manager-stack"
)
$env:AWS_DEFAULT_REGION = $Region
$env:AWS_PAGER = ""

Write-Host "`n=== 1. Delete the CloudFormation stack ===" -ForegroundColor Cyan
aws cloudformation delete-stack --stack-name $Stack
aws cloudformation wait stack-delete-complete --stack-name $Stack
Write-Host "Stack deleted (or did not exist)."

Write-Host "`n=== 2. Scale the manual ECS service to 0 tasks (ignore errors if it does not exist) ===" -ForegroundColor Cyan
aws ecs update-service --cluster task-manager-cluster --service task-manager-service --desired-count 0 --query "service.desiredCount" --output text

Write-Host "`n=== 3. Verify nothing is running (empty lists mean no charges) ===" -ForegroundColor Cyan
Start-Sleep -Seconds 20
Write-Host "Tasks in task-manager-cluster:"
aws ecs list-tasks --cluster task-manager-cluster --query "taskArns" --output text
Write-Host "Tasks in tm-cf-cluster:"
aws ecs list-tasks --cluster tm-cf-cluster --query "taskArns" --output text

Write-Host "`n=== 4. Stop Jenkins (setup is kept for next time) ===" -ForegroundColor Cyan
docker stop jenkins 2>$null | Out-Null

Write-Host "`nSHUTDOWN COMPLETE. If no task ARNs were listed above, nothing is billing." -ForegroundColor Green
