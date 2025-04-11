#!/bin/bash

# Exit on any error
set -e

echo "Deploying DevOps Toolchain..."

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

echo "Setting up infrastructure..."
cd ../infrastructure/terraform

# Initialize and apply Terraform
terraform init
terraform apply -auto-approve

# Get cluster credentials
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGION=$(terraform output -raw region)
PROJECT_ID=$(terraform output -raw project_id)

gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION --project $PROJECT_ID

cd ../kubernetes

echo "Creating namespaces..."
kubectl apply -f 00-namespaces.yaml

echo "Deploying CI/CD service (Jenkins)..."
kubectl apply -f 01-cicd-service.yaml

echo "Deploying Code Quality service (SonarQube)..."
kubectl apply -f 02-code-quality-service.yaml

echo "Deploying Dependency Scanner service..."
kubectl apply -f 03-dependency-scanner-service.yaml

echo "Deploying Metrics Collection service (Prometheus & Fluentd)..."
kubectl apply -f 04-metrics-service.yaml

echo "Deploying Dashboard service (Grafana)..."
kubectl apply -f 05-dashboard-service.yaml

echo "Waiting for services to be ready..."
kubectl wait --for=condition=ready pod -l app=jenkins -n cicd --timeout=300s
kubectl wait --for=condition=ready pod -l app=sonarqube -n code-quality --timeout=300s
kubectl wait --for=condition=ready pod -l app=prometheus -n metrics --timeout=300s
kubectl wait --for=condition=ready pod -l app=grafana -n dashboard --timeout=300s

echo "Getting service URLs..."
JENKINS_IP=$(kubectl get svc jenkins -n cicd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
SONARQUBE_IP=$(kubectl get svc sonarqube -n code-quality -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
GRAFANA_IP=$(kubectl get svc grafana -n dashboard -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

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
" 