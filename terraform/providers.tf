terraform {
  required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = ">= 5.69.0"
#     }
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.64.0"
    }
    unifi = {
      source  = "paultyng/unifi"
      version = "0.41.0"
    }
  }

#   backend "s3" {
#     bucket     = local.minio_bucket
#     key        = "cluster_creator.tfstate"
#     region     = "default"
#     access_key = local.minio_access_key
#     secret_key = local.minio_secret_key
# 
#     endpoints = {
#       s3 = local.minio_endpoint
#     }
# 
#     use_path_style              = true
#     skip_credentials_validation = true
#     skip_metadata_api_check     = true
#     skip_region_validation      = true
#     skip_requesting_account_id  = true
#   }
}

# provider "aws" {
#   region     = "default"
#   access_key = local.minio_access_key
#   secret_key = local.minio_secret_key
# 
#   endpoints {
#     s3 = local.minio_endpoint
#   }
# 
#   skip_credentials_validation = true
#   skip_metadata_api_check     = true
#   skip_region_validation      = true
#   skip_requesting_account_id  = true
#   s3_use_path_style           = true
# }

# provider "unifi" {
#   username       = local.unifi_username
#   password       = local.unifi_password
#   api_url        = local.unifi_api_url
#   allow_insecure = true
# }

provider "proxmox" {
  endpoint   = "https://${local.proxmox_host}:8006/api2/json"
  api_token  = local.proxmox_api_token
  ssh {
    username = local.proxmox_username
    agent    = true
  }
  insecure   = true
}
