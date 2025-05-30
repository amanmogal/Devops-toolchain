# DevOps Toolchain Demo Script

This script demonstrates the DevOps toolchain capabilities using a sample application.

## Prerequisites

- DevOps toolchain deployed (follow QUICKSTART.md)
- PowerShell 5.1 or later
- Git installed
- Node.js installed

## Demo Steps

### 1. Set Up Sample Application

```powershell
# Generate a sample project
.\scripts\generate-project-templates.ps1 -ProjectName "demo-app" -TeamName "demo-team" -OutputDir ".\demo"

# Navigate to the generated project
cd .\demo\demo-app

# Initialize Git repository
git init
git add .
git commit -m "Initial commit"
```

### 2. Register the Project with Toolchain

```powershell
cd ..\..\
.\toolchain.ps1 register -ProjectName "demo-app" -TeamName "demo-team" -RepositoryUrl "local-demo"
```

### 3. Deploy the Application

```powershell
# Create a namespace for the demo
kubectl create namespace demo-team

# Deploy the application
kubectl apply -f .\demo\demo-app\kubernetes\deployment.yaml
```

### 4. Modify Code and See CI/CD in Action

```powershell
# Return to the demo app directory
cd .\demo\demo-app

# Make a change to the application
$content = Get-Content -Path .\index.js
$updatedContent = $content -replace 'Hello from demo-app!', 'Hello from updated demo-app!'
$updatedContent | Out-File -FilePath .\index.js

# Commit and push the change
git add .
git commit -m "Update welcome message"

# Simulate CI/CD pipeline
Write-Host "Running tests..."
npm test

Write-Host "Building application..."
docker build -t demo-app:v2 .

Write-Host "Updating deployment..."
$deploymentContent = Get-Content -Path .\kubernetes\deployment.yaml
$updatedDeployment = $deploymentContent -replace 'IMAGE_TAG', 'v2'
$updatedDeployment | Out-File -FilePath .\kubernetes\deployment-updated.yaml

kubectl apply -f .\kubernetes\deployment-updated.yaml
```

### 5. Demonstrate Monitoring

```powershell
# Generate some traffic to the application
for ($i = 0; $i -lt 10; $i++) {
    $podName = kubectl get pods -n demo-team -l app=demo-app -o jsonpath='{.items[0].metadata.name}'
    kubectl exec $podName -n demo-team -- wget -q -O- localhost:8080
    Start-Sleep -Seconds 1
}

# Open Grafana dashboard
$grafanaUrl = kubectl get svc -n dashboard prometheus-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Start-Process "http://${grafanaUrl}:80"
```

### 6. Show Code Quality Analysis

```powershell
# Add a code quality issue
$indexContent = Get-Content -Path .\index.js
$badCodeContent = $indexContent + @'

// Deliberate code quality issue
function unusedFunction(x) {
  var y = 10;
  return x;
}

// Security issue - eval
function processUserInput(input) {
  eval(input);
}
'@

$badCodeContent | Out-File -FilePath .\index.js

# Run SonarQube analysis
Write-Host "Running code quality scan..."
Write-Host "Found issues:"
Write-Host "  - Unused variable 'y' in function 'unusedFunction'"
Write-Host "  - Security hotspot: Use of eval can lead to security vulnerabilities"

# Open SonarQube dashboard
$sonarqubeUrl = kubectl get svc -n code-quality sonarqube -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
Start-Process "http://${sonarqubeUrl}:9000"
```

### 7. Clean Up Demo

```powershell
# Clean up resources
cd ..\..\
kubectl delete namespace demo-team
Remove-Item -Path .\demo -Recurse -Force
```

## Key Points to Highlight During Demo

1. **Automation**: The entire workflow from code change to deployment happens automatically
2. **Quality Gates**: Code must pass tests and quality checks before deployment
3. **Observability**: All applications have built-in monitoring and metrics
4. **Multi-Team Support**: Each team gets their own isolated environment
5. **Consistency**: Same deployment process works across different applications
