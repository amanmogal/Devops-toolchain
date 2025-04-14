terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# GKE cluster
resource "google_container_cluster" "primary" {
  name     = "devops-toolchain-cluster"
  project  = var.project_id
  location = var.region

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  networking_mode = "VPC_NATIVE"

  # Update IP allocation policy
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-devops-toolchain-cluster-pods-cbbdf5fe"
    services_secondary_range_name = "gke-devops-toolchain-cluster-services-cbbdf5fe"
  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block = "10.0.0.0/28"
  }

  # Remove default node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Maintenance policy
  maintenance_policy {
    recurring_window {
      start_time = "2023-01-01T18:30:00Z"
      end_time   = "2023-01-01T18:30:00Z"
      recurrence = "FREQ=DAILY"
    }
  }

  # Security configuration
  enable_shielded_nodes = true
  
  # Binary authorization
  binary_authorization {
    evaluation_mode = "DISABLED"
  }

  # Network policy
  network_policy {
    enabled = false
  }

  # HTTP load balancing
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = true
    }
    gcp_filestore_csi_driver_config {
      enabled = false
    }
  }

  # Logging and monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
  
  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
      "APISERVER",
      "SCHEDULER",
      "CONTROLLER_MANAGER"
    ]
    managed_prometheus {
      enabled = true
    }
  }

  # Node pool defaults
  node_config {
    shielded_instance_config {
      enable_secure_boot = true
    }
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  # Vertical Pod Autoscaling
  vertical_pod_autoscaling {
    enabled = false
  }
}

# Default node pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "default-pool"
  project    = var.project_id
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 2

  node_config {
    machine_type = "e2-standard-4"
    disk_size_gb = 100
    disk_type    = "pd-standard"

    service_account = "devops-sa@devops-toolchain-456502.iam.gserviceaccount.com"
    
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# VPC
resource "google_compute_network" "vpc" {
  name                    = "devops-toolchain-vp"
  project                 = var.project_id
  auto_create_subnetworks = false
  mtu                     = 1460
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name                     = "devops-toolchain-subne"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.0.0.0/20"
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "gke-devops-toolchain-cluster-pods-cbbdf5fe"
    ip_cidr_range = "10.8.0.0/14"
  }

  secondary_ip_range {
    range_name    = "gke-devops-toolchain-cluster-services-cbbdf5fe"
    ip_cidr_range = "34.118.224.0/20"
  }
}

# Cloud SQL instance for services that need persistent storage
resource "google_sql_database_instance" "main" {
  name             = "devops-toolchain-db"
  database_version = "POSTGRES_13"
  region           = var.region

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "gke-cluster"
        value = "10.10.0.0/16"
      }
    }
  }

  deletion_protection = false
}

# Cloud Storage bucket for artifacts
resource "google_storage_bucket" "artifacts" {
  name          = "${var.project_id}-artifacts"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true
}

# Artifact Registry repository for container images
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = "devops-toolchain"
  format        = "docker"
}

# Tools node pool
resource "google_container_node_pool" "tools_pool" {
  name       = "tools-pool"
  project    = var.project_id
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    machine_type = "e2-standard-2"
    disk_size_gb = 100
    disk_type    = "pd-standard"

    service_account = "devops-sa@devops-toolchain-456502.iam.gserviceaccount.com"
    
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

# Add this service account configuration to your main.tf
resource "google_service_account" "gke_nodes_sa" {
  project      = var.project_id
  account_id   = "devops-sa"  # Changed to match your existing SA
  display_name = "DevOps Service Account for GKE Nodes"
}

# Add required IAM bindings for the service account
resource "google_project_iam_member" "gke_nodes_sa_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes_sa.email}"
}

resource "google_project_iam_member" "gke_nodes_sa_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes_sa.email}"
}

resource "google_project_iam_member" "gke_nodes_sa_artifacts" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes_sa.email}"
} 