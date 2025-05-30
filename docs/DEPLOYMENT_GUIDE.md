# DevOps Toolchain Deployment Guide

This guide provides instructions for deploying our DevOps toolchain in a real-world environment to support multiple teams and projects.

## Deployment Options

### Option 1: Centralized Deployment (Shared Service)

A single deployment that serves multiple teams and projects.

#### Prerequisites:

- Access to Google Cloud Platform with Organization or Folder Admin permissions
- Terraform installed
- kubectl installed
- gcloud CLI installed
- PowerShell (for Windows environments)

#### Deployment Steps:

1. **Clone the repository:**

```powershell
git clone https://github.com/your-org/devops-toolchain.git
cd "Devops toolchain"
```

2. **Configure GCP authentication:**

```powershell
gcloud auth application-default login
gcloud config set project your-project-id
```

3. **Create a configuration file:**

```powershell
Copy-Item "infrastructure/terraform/terraform.tfvars.example" -Destination "infrastructure/terraform/terraform.tfvars"
```

4. **Edit the configuration:**

```powershell
notepad "infrastructure/terraform/terraform.tfvars"
```

5. **Deploy the infrastructure:**

```powershell
cd "infrastructure/terraform"
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

6. **Deploy Kubernetes components:**

```powershell
cd "../.."
./scripts/deploy-services.sh
```

7. **Create team namespaces:**

```powershell
kubectl create namespace team-a
kubectl create namespace team-b
# Repeat for each team
```

8. **Configure RBAC for team access:**

```powershell
kubectl apply -f infrastructure/kubernetes/security/team-rbac.yaml
```

### Option 2: Per-Project Deployment

Deploy a separate instance for each project with customizations.

#### Deployment Steps:

1. **Create project configuration:**

```powershell
./scripts/create-project-config.ps1 -ProjectName "project-a" -TeamName "team-a" -Environment "production"
```

2. **Deploy dedicated instance:**

```powershell
./scripts/deploy-project-instance.ps1 -ConfigFile "configs/project-a.json"
```

## Onboarding New Projects

1. **Create project in source control:**
   - Create a new Git repository
   - Add CI configuration (.github/workflows)

2. **Register project with toolchain:**

```powershell
./scripts/register-project.ps1 -ProjectName "new-project" -RepositoryUrl "https://github.com/org/repo"
```

3. **Set up pipelines:**
   - Copy pipeline templates from templates directory
   - Customize as needed for the project

4. **Configure monitoring:**
   - Create project-specific Grafana dashboards
   - Set up alerts for project metrics

## Maintenance Procedures

### Updating Components

```powershell
./scripts/update-components.ps1 -Component "prometheus" -Version "v2.40.0"
```

### Backing Up Data

```powershell
./scripts/backup-toolchain-data.ps1 -Components "jenkins,sonarqube" -Destination "gs://backups"
```

### Scaling Resources

Adjust the infrastructure resources in `terraform.tfvars` and run:

```powershell
cd "infrastructure/terraform"
terraform apply
```

## Best Practices

1. **Security**:
   - Regularly rotate service account credentials
   - Implement network policies for pod isolation
   - Enable audit logging

2. **Performance**:
   - Monitor resource usage and scale appropriately
   - Use autoscaling for CI/CD agents
   - Configure resource limits for all workloads

3. **Reliability**:
   - Implement regular backups
   - Set up monitoring alerts
   - Document recovery procedures

## Troubleshooting

### Common Issues

1. **Pipeline failures**:
   - Check logs in Jenkins/GitHub Actions
   - Verify resource limits are sufficient
   - Check for expired credentials

2. **Monitoring issues**:
   - Verify Prometheus targets are scraped
   - Check connectivity between components
   - Validate configuration changes

For additional support, contact the DevOps team or file an issue in our support repository.
