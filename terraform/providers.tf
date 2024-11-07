
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.69.0"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.64.0"
    }
    unifi = {
      source  = "paultyng/unifi"
      version = "0.41.0"
    }
  }

  backend "s3" {
    bucket = var.minio_bucket
    key    = "cluster_creator.tfstate"
    region = "default"

    access_key = var.minio_access_key
    secret_key = var.minio_secret_key

    endpoints = {
      s3 = var.minio_endpoint
    }

    use_path_style              = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }
}

provider "aws" {
  region = "default"

  access_key = var.minio_access_key
  secret_key = var.minio_secret_key

  endpoints {
    s3 = var.minio_endpoint
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true
}

provider "unifi" {
  username = var.unifi_username
  password = var.unifi_password
  api_url  = var.unifi_api_url
  allow_insecure = true
}

provider "proxmox" {
  endpoint = "https://${var.proxmox_host}:8006/api2/json"
  api_token = var.proxmox_api_token
  ssh {
    username = var.proxmox_username
    agent = true
  }
  insecure = true
}