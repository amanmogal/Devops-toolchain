# Project Onboarding Template

## Project Registration Information

- Project Name: [NAME]
- Team Name: [TEAM]
- Environment: [ENV]
- Repository URL: [REPO_URL]

## Step 1: Register the Project

Run the following command to register your project with the DevOps toolchain:

```powershell
.\toolchain.ps1 register -ProjectName "[NAME]" -RepositoryUrl "[REPO_URL]" -TeamName "[TEAM]" -Environment "[ENV]"
```

## Step 2: Configure Your Repository

Add the following files to your repository:

### 1. CI/CD Pipeline Configuration

Create a file at `.github/workflows/ci-cd.yml` with the following content:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
    
    - name: Install Dependencies
      run: npm ci
    
    - name: Run Tests
      run: npm test
    
    - name: Build
      run: npm run build
    
    - name: SonarQube Analysis
      uses: SonarSource/sonarqube-scan-action@master
      env:
        SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
      with:
        args: >
          -Dsonar.projectKey=[NAME]
          -Dsonar.projectName=[NAME]
    
    - name: Build & Push Docker Image
      if: github.event_name != 'pull_request'
      uses: google-github-actions/setup-gcloud@v0
      with:
        project_id: ${{ secrets.GCP_PROJECT_ID }}
        service_account_key: ${{ secrets.GCP_SA_KEY }}
    
    - name: Configure Docker
      run: gcloud auth configure-docker
    
    - name: Build and Push
      run: |
        docker build -t [IMAGE_REPO]/[NAME]:${{ github.sha }} .
        docker push [IMAGE_REPO]/[NAME]:${{ github.sha }}
```

### 2. Kubernetes Deployment Manifest

Create a file at `kubernetes/deployment.yaml` with:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: [NAME]
spec:
  replicas: 2
  selector:
    matchLabels:
      app: [NAME]
  template:
    metadata:
      labels:
        app: [NAME]
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      containers:
      - name: [NAME]
        image: [IMAGE_REPO]/[NAME]:[TAG]
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: [NAME]
spec:
  selector:
    app: [NAME]
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
```

### 3. SonarQube Properties

Create a file at `sonar-project.properties` with:

```properties
sonar.projectKey=[NAME]
sonar.projectName=[NAME]

sonar.sources=src
sonar.tests=test
sonar.javascript.lcov.reportPaths=coverage/lcov.info
```

## Step 3: Configure GitHub Secrets

Add the following secrets to your GitHub repository:

- `SONAR_TOKEN`: SonarQube authentication token
- `SONAR_HOST_URL`: URL to the SonarQube server
- `GCP_PROJECT_ID`: Google Cloud project ID
- `GCP_SA_KEY`: Service account key with push permissions to Artifact Registry

## Step 4: First Deployment

After pushing the configuration to your repository, your first pipeline will run automatically. Once the pipeline completes, deploy your application:

```powershell
kubectl apply -f kubernetes/deployment.yaml -n [TEAM]
```

## Step 5: Set Up Monitoring

Create a Grafana dashboard for your application by importing the template dashboard from the DevOps toolchain.
