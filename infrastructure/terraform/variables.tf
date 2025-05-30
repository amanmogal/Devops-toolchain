variable "project_id" {
  description = "The project ID to host the cluster in"
  type        = string
  default     = "devops-toolchain-456502"
}

variable "region" {
  description = "The region to host the cluster in"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "devops-toolchain-cluster"
}

variable "network_name" {
  description = "Name of the VPC network"
  type        = string
  default     = "devops-toolchain-vpc"
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
  default     = "devops-toolchain-subnet"
}

variable "gke_num_nodes" {
  description = "Number of nodes per zone in the GKE node pool"
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "environment" {
  description = "Environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "enable_multi_team" {
  description = "Enable multi-team support"
  type        = bool
  default     = false
}

variable "teams" {
  description = "List of teams to configure"
  type        = list(string)
  default     = []
}

variable "enable_ha" {
  description = "Enable high-availability mode"
  type        = bool
  default     = false
}

variable "multi_zone" {
  description = "Enable multi-zone deployment for GKE cluster"
  type        = bool
  default     = false
}

variable "db_tier" {
  description = "The tier for Cloud SQL instances"
  type        = string
  default     = "db-f1-micro"
}

variable "enable_artifact_registry" {
  description = "Enable Artifact Registry for container images"
  type        = bool
  default     = true
}

variable "artifact_registry_name" {
  description = "Name for the Artifact Registry repository"
  type        = string
  default     = "devops-toolchain"
}