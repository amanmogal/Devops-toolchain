#!/bin/bash

# Exit on any error
set -e

# Default values
ENVIRONMENT="dev"
TEAM_NAMESPACE=""
MULTI_TEAM=false
SKIP_INFRA=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --project-id)
      PROJECT_ID="$2"
      shift 2
      ;;
    --cluster-name)
      CLUSTER_NAME="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --team)
      TEAM_NAMESPACE="$2"
      shift 2
      ;;
    --multi-team)
      MULTI_TEAM=true
      shift
      ;;
    --skip-infrastructure)
      SKIP_INFRA=true
      shift
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

echo "Deploying DevOps Toolchain..."
echo "Environment: $ENVIRONMENT"
if [ -n "$TEAM_NAMESPACE" ]; then
  echo "Team: $TEAM_NAMESPACE"
fi
if [ "$MULTI_TEAM" = true ]; then
  echo "Multi-team mode enabled"
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "gcloud is not installed. Please install Google Cloud SDK first."
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "terraform is not installed. Please install Terraform first."
    exit 1
fi

if [ "$SKIP_INFRA" = false ]; then
  echo "Setting up infrastructure..."
  cd ../infrastructure/terraform

  # Initialize and apply Terraform
  terraform init
  
  # Use specific environment variables if provided
  if [ -n "$ENVIRONMENT" ] && [ -f "environments/${ENVIRONMENT}.tfvars" ]; then
    echo "Using environment-specific configuration: environments/${ENVIRONMENT}.tfvars"
    terraform apply -var-file="environments/${ENVIRONMENT}.tfvars" -auto-approve
  else
    terraform apply -auto-approve
  fi

  # Get cluster credentials if not provided
  if [ -z "$CLUSTER_NAME" ] || [ -z "$REGION" ] || [ -z "$PROJECT_ID" ]; then
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    REGION=$(terraform output -raw region)
    PROJECT_ID=$(terraform output -raw project_id)
  fi

  gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT_ID
  
  cd ../kubernetes
else
  echo "Skipping infrastructure setup..."
  cd ../infrastructure/kubernetes
  
  # Ensure we have cluster credentials if infrastructure was skipped
  if [ -n "$CLUSTER_NAME" ] && [ -n "$REGION" ] && [ -n "$PROJECT_ID" ]; then
    echo "Getting cluster credentials..."
    gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT_ID
  fi
fi

echo "Creating namespaces..."
kubectl apply -f 00-namespaces.yaml

# Create team namespace if specified
if [ -n "$TEAM_NAMESPACE" ]; then
  echo "Creating team namespace: $TEAM_NAMESPACE"
  kubectl create namespace $TEAM_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
  
  # Create team RBAC if multi-team is enabled
  if [ "$MULTI_TEAM" = true ]; then
    echo "Creating RBAC for team $TEAM_NAMESPACE"
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $TEAM_NAMESPACE-sa
  namespace: $TEAM_NAMESPACE
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: $TEAM_NAMESPACE-role
  namespace: $TEAM_NAMESPACE
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $TEAM_NAMESPACE-binding
  namespace: $TEAM_NAMESPACE
subjects:
- kind: ServiceAccount
  name: $TEAM_NAMESPACE-sa
  namespace: $TEAM_NAMESPACE
roleRef:
  kind: Role
  name: $TEAM_NAMESPACE-role
  apiGroup: rbac.authorization.k8s.io
EOF
  fi
fi

# Apply environment-specific overlays if available
if [ -d "overlays/$ENVIRONMENT" ]; then
  echo "Using environment-specific configuration: overlays/$ENVIRONMENT"
  KUSTOMIZE_DIR="overlays/$ENVIRONMENT"
else
  echo "Using base configuration"
  KUSTOMIZE_DIR="base"
fi

echo "Deploying CI/CD service (Jenkins)..."
if [ "$MULTI_TEAM" = true ] && [ -n "$TEAM_NAMESPACE" ]; then
  # Create a kustomization that targets the team namespace
  TMP_DIR=$(mktemp -d)
  cat <<EOF > $TMP_DIR/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: $TEAM_NAMESPACE
resources:
- ../01-cicd-service.yaml
EOF
  kubectl apply -k $TMP_DIR
else
  kubectl apply -f 01-cicd-service.yaml
fi

echo "Deploying Code Quality service (SonarQube)..."
if [ "$MULTI_TEAM" = true ] && [ -n "$TEAM_NAMESPACE" ]; then
  # Create a kustomization that targets the team namespace
  TMP_DIR=$(mktemp -d)
  cat <<EOF > $TMP_DIR/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: $TEAM_NAMESPACE
resources:
- ../02-code-quality-service.yaml
EOF
  kubectl apply -k $TMP_DIR
else
  kubectl apply -f 02-code-quality-service.yaml
fi

echo "Deploying Dependency Scanner service..."
if [ "$MULTI_TEAM" = true ] && [ -n "$TEAM_NAMESPACE" ]; then
  # Create a kustomization that targets the team namespace
  TMP_DIR=$(mktemp -d)
  cat <<EOF > $TMP_DIR/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: $TEAM_NAMESPACE
resources:
- ../03-dependency-scanner-service.yaml
EOF
  kubectl apply -k $TMP_DIR
else
  kubectl apply -f 03-dependency-scanner-service.yaml
fi

echo "Deploying Metrics Collection service (Prometheus & Fluentd)..."
kubectl apply -f 04-metrics-service.yaml

echo "Deploying Dashboard service (Grafana)..."
kubectl apply -f 05-dashboard-service.yaml

echo "Waiting for services to be ready..."
NAMESPACE="${TEAM_NAMESPACE:-cicd}"
CODE_QUALITY_NS="${TEAM_NAMESPACE:-code-quality}"
METRICS_NS="${TEAM_NAMESPACE:-metrics}"
DASHBOARD_NS="${TEAM_NAMESPACE:-dashboard}"

kubectl wait --for=condition=ready pod -l app=jenkins -n $NAMESPACE --timeout=300s || echo "Jenkins pods not ready yet"
kubectl wait --for=condition=ready pod -l app=sonarqube -n $CODE_QUALITY_NS --timeout=300s || echo "SonarQube pods not ready yet"
kubectl wait --for=condition=ready pod -l app=prometheus -n $METRICS_NS --timeout=300s || echo "Prometheus pods not ready yet"
kubectl wait --for=condition=ready pod -l app=grafana -n $DASHBOARD_NS --timeout=300s || echo "Grafana pods not ready yet"

echo "Getting service URLs..."
JENKINS_IP=$(kubectl get svc jenkins -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
SONARQUBE_IP=$(kubectl get svc sonarqube -n $CODE_QUALITY_NS -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
GRAFANA_IP=$(kubectl get svc grafana -n $DASHBOARD_NS -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

# Generate config file for future reference
CONFIG_DIR="../configs"
mkdir -p $CONFIG_DIR

cat <<EOF > $CONFIG_DIR/toolchain-deployment-${ENVIRONMENT}.json
{
  "environment": "$ENVIRONMENT",
  "team": "${TEAM_NAMESPACE:-shared}",
  "projectId": "$PROJECT_ID",
  "clusterName": "$CLUSTER_NAME",
  "region": "$REGION",
  "multiTeam": $MULTI_TEAM,
  "services": {
    "jenkins": {
      "namespace": "$NAMESPACE",
      "ip": "$JENKINS_IP",
      "port": 8080
    },
    "sonarqube": {
      "namespace": "$CODE_QUALITY_NS",
      "ip": "$SONARQUBE_IP",
      "port": 9000
    },
    "grafana": {
      "namespace": "$DASHBOARD_NS",
      "ip": "$GRAFANA_IP",
      "port": 80
    }
  },
  "deployedAt": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

echo "
DevOps Toolchain has been deployed successfully!

Access your services at:
Jenkins: http://$JENKINS_IP:8080
SonarQube: http://$SONARQUBE_IP:9000
Grafana: http://$GRAFANA_IP:80

Initial credentials:
- Jenkins: Check pod logs for initial admin password
- SonarQube: admin/admin
- Grafana: admin/admin123

Please change these passwords immediately after first login.

For multi-team usage:
1. Register new projects using: ./scripts/deployment/register-project.ps1
2. Create team-specific deployments with: ./scripts/deployment/deploy-project-instance.ps1

Configuration saved to: $CONFIG_DIR/toolchain-deployment-${ENVIRONMENT}.json
"

# Create PowerShell version of this script for Windows users
cat <<EOF > ../scripts/deploy-services.ps1
# PowerShell version of deploy-services.sh
param (
    [string]\$ProjectId,
    [string]\$ClusterName,
    [string]\$Region,
    [string]\$Environment = "dev",
    [string]\$TeamNamespace,
    [switch]\$MultiTeam,
    [switch]\$SkipInfrastructure
)

Write-Host "Deploying DevOps Toolchain using PowerShell..."

# Build bash command with parameters
\$bashArgs = "./deploy-services.sh"

if (\$ProjectId) { \$bashArgs += " --project-id \$ProjectId" }
if (\$ClusterName) { \$bashArgs += " --cluster-name \$ClusterName" }
if (\$Region) { \$bashArgs += " --region \$Region" }
if (\$Environment) { \$bashArgs += " --environment \$Environment" }
if (\$TeamNamespace) { \$bashArgs += " --team \$TeamNamespace" }
if (\$MultiTeam) { \$bashArgs += " --multi-team" }
if (\$SkipInfrastructure) { \$bashArgs += " --skip-infrastructure" }

# Execute the bash script using WSL
wsl bash -c "cd \$(wsl wslpath -u '\$PWD') && \$bashArgs"

Write-Host "Deployment complete!"
EOF

echo "Created PowerShell wrapper script: ../scripts/deploy-services.ps1" 