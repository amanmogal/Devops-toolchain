# DevOps Toolchain Quick Start Guide

This guide provides instructions for deploying the DevOps toolchain in minutes.

## Prerequisites

Before you begin, ensure you have:

1. Windows with PowerShell
2. Google Cloud SDK installed
3. kubectl installed
4. Terraform installed
5. A Google Cloud Platform account with sufficient permissions

## Option 1: Single-Team Deployment (Quickest)

Run these commands in PowerShell:

```powershell
# Clone the repository if you haven't already
git clone https://github.com/your-org/devops-toolchain.git
cd "Devops toolchain"

# Log in to Google Cloud
gcloud auth login
gcloud config set project your-project-id

# Deploy the toolchain
.\toolchain.ps1 deploy -Environment dev
```

## Option 2: Multi-Team Deployment

For organizations with multiple teams:

```powershell
# Deploy the base toolchain
.\toolchain.ps1 deploy -Environment dev -MultiTeam

# Register your first project
.\toolchain.ps1 register -ProjectName "project-a" -RepositoryUrl "https://github.com/org/repo-a" -TeamName "team-a"

# Register a second project
.\toolchain.ps1 register -ProjectName "project-b" -RepositoryUrl "https://github.com/org/repo-b" -TeamName "team-b"
```

## Option 3: Dedicated Instances per Team

For complete isolation between teams:

```powershell
# Create config for Team A's project
$configContent = @"
{
  "name": "project-a",
  "repository": "https://github.com/org/repo-a",
  "team": "team-a",
  "environment": "dev"
}
"@
$configPath = "configs/projects/project-a/config.json"
New-Item -Path "configs/projects/project-a" -ItemType Directory -Force
$configContent | Out-File -FilePath $configPath

# Deploy dedicated instance
.\toolchain.ps1 create-instance -ConfigFile $configPath
```

## Accessing the Toolchain

After deployment completes, you'll see URLs and credentials for:
- Jenkins CI/CD system
- SonarQube code quality platform
- Grafana dashboards

## Next Steps

1. Set up your first project by following the project onboarding template in `docs/templates/project-onboarding.md`
2. Configure repository integration with the CI/CD system
3. Create custom dashboards for your applications

For detailed documentation, refer to the [Deployment Guide](DEPLOYMENT_GUIDE.md).
