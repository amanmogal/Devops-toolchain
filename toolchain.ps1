# DevOps Toolchain Deployment for Windows
# 
# This script helps deploy the DevOps toolchain in Windows environments
#
param (
    [Parameter(Mandatory=$false)]
    [ValidateSet("deploy", "register", "create-instance", "help")]
    [string]$Command = "help",
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectId,
    
    [Parameter(Mandatory=$false)]
    [string]$ClusterName,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-central1",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$TeamName,
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectName,
    
    [Parameter(Mandatory=$false)]
    [string]$RepositoryUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$MultiTeam,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipInfrastructure
)

function Show-Help {
    Write-Host @"
DevOps Toolchain Deployment for Windows

Usage:
  .\toolchain.ps1 [command] [options]

Commands:
  deploy           Deploy the DevOps toolchain
  register         Register a new project with the toolchain
  create-instance  Create a dedicated toolchain instance for a project
  help             Show this help message

Options for 'deploy':
  -ProjectId           GCP project ID
  -ClusterName         GKE cluster name
  -Region              GCP region (default: us-central1)
  -Environment         Deployment environment (default: dev)
  -TeamName            Team namespace
  -MultiTeam           Enable multi-team support
  -SkipInfrastructure  Skip infrastructure setup

Options for 'register':
  -ProjectName         Name of the project to register
  -RepositoryUrl       Git repository URL
  -TeamName            Team name (default: default)
  -Environment         Target environment (default: dev)

Options for 'create-instance':
  -ConfigFile          Path to project configuration file
  -Region              GCP region (default: us-central1)

Examples:
  # Deploy the toolchain in dev environment
  .\toolchain.ps1 deploy -Environment dev

  # Register a new project
  .\toolchain.ps1 register -ProjectName my-app -RepositoryUrl https://github.com/org/repo -TeamName team-a

  # Create a dedicated toolchain instance
  .\toolchain.ps1 create-instance -ConfigFile configs/projects/my-app/config.json
"@
}

function Check-Prerequisites {
    $missing = @()
    
    if (-not (Get-Command "gcloud" -ErrorAction SilentlyContinue)) {
        $missing += "Google Cloud SDK"
    }
    
    if (-not (Get-Command "kubectl" -ErrorAction SilentlyContinue)) {
        $missing += "kubectl"
    }
    
    if (-not (Get-Command "terraform" -ErrorAction SilentlyContinue)) {
        $missing += "Terraform"
    }
    
    if ($missing.Count -gt 0) {
        Write-Host "Missing prerequisites: $($missing -join ', ')" -ForegroundColor Red
        Write-Host "Please install the required tools and try again." -ForegroundColor Red
        exit 1
    }
}

function Create-DeploymentScripts {
    if (-not (Test-Path -Path "scripts/deployment")) {
        Write-Host "Creating deployment scripts..." -ForegroundColor Yellow
        & ./scripts/create-deployment-scripts.ps1
    }
}

# Main script execution
Check-Prerequisites

switch ($Command) {
    "deploy" {
        Write-Host "Deploying DevOps Toolchain..." -ForegroundColor Green
        $params = @{}
        if ($ProjectId) { $params.Add("ProjectId", $ProjectId) }
        if ($ClusterName) { $params.Add("ClusterName", $ClusterName) }
        if ($Region) { $params.Add("Region", $Region) }
        if ($Environment) { $params.Add("Environment", $Environment) }
        if ($TeamName) { $params.Add("TeamNamespace", $TeamName) }
        if ($MultiTeam) { $params.Add("MultiTeam", $true) }
        if ($SkipInfrastructure) { $params.Add("SkipInfrastructure", $true) }
        
        & ./scripts/deploy-services.ps1 @params
    }
    "register" {
        Create-DeploymentScripts
        
        if (-not $ProjectName -or -not $RepositoryUrl) {
            Write-Host "Error: ProjectName and RepositoryUrl are required for the register command." -ForegroundColor Red
            Show-Help
            exit 1
        }
        
        Write-Host "Registering project $ProjectName..." -ForegroundColor Green
        $params = @{
            ProjectName = $ProjectName
            RepositoryUrl = $RepositoryUrl
        }
        
        if ($TeamName) { $params.Add("TeamName", $TeamName) }
        if ($Environment) { $params.Add("Environment", $Environment) }
        
        & ./scripts/deployment/register-project.ps1 @params
    }
    "create-instance" {
        Create-DeploymentScripts
        
        if (-not $ConfigFile) {
            Write-Host "Error: ConfigFile is required for the create-instance command." -ForegroundColor Red
            Show-Help
            exit 1
        }
        
        Write-Host "Creating toolchain instance using $ConfigFile..." -ForegroundColor Green
        $params = @{
            ConfigFile = $ConfigFile
        }
        
        if ($Region) { $params.Add("Region", $Region) }
        
        & ./scripts/deployment/deploy-project-instance.ps1 @params
    }
    "help" {
        Show-Help
    }
    default {
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Show-Help
        exit 1
    }
}
