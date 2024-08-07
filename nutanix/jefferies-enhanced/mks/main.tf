terraform {
  required_version = ">=1.5.7"
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
  default = "cluster-name"
}

variable "cluster_project" {
  description = "Name of the project"
  type        = string
  default = "project-name"
}

variable "cluster_blueprint_name" {
  description = "Name of the blueprint"
  type        = string
  default = "minimal"
}

variable "cluster_blueprint_version" {
  description = "Version of the blueprint"
  type        = string
  default = "latest"
}

variable "cluster_dedicated_masters" {
  description = "Enable dedicated masters"
  type        = bool
  default = false
}

variable "cluster_ha" {
  description = "Enable high availability"
  type        = bool
  default = false
}

variable "cluster_kubernetes_version" {
  description = "Version of Kubernetes"
  type        = string
  default = "v1.29.0"
}

variable "cluster_location" {
  description = "Location of the cluster"
  type        = string
  default = "sanjose-us"
}

variable "master_ips" {
  description = "IP addresses of the master nodes"
  type       = list(object({
    hostname = string
    privateip = string
  }))
}

variable "worker_ips" {
  description = "IP addresses of the worker nodes"
  type       = list(object({
    hostname = string
    privateip = string
  }))
}
variable "cluster_labels" {
  description = "Labels for the cluster"
  type        = map
  default = {
    env = "development"
    email = "suryakant@rafay.co"
  }
}

locals {
  rafay_spec = {
    apiVersion = "infra.k8smgmt.io/v3"
    kind       = "Cluster"
    metadata   = {
      name    = var.cluster_name
      project = var.cluster_project
      labels  = var.cluster_labels
    }
    spec = {
      type       = "mks"
      blueprint  = {
        name    = var.cluster_blueprint_name
        version = var.cluster_blueprint_version
      }
      config     = {
        autoApproveNodes     = true
        dedicatedMastersEnabled = var.cluster_dedicated_masters
        highAvailability     = var.cluster_ha
        kubernetesVersion    = var.cluster_kubernetes_version
        location             = var.cluster_location
        network              = {
          cni           = {
            name    = "Calico"
            version = "3.26.1"
          }
          podSubnet    = "10.244.0.0/16"
          serviceSubnet = "10.96.0.0/12"
        }
        nodes = concat(
          [ 
            for i in var.master_ips : {
              hostname        = i.hostname
              privateip       = i.privateip
              operatingSystem = "Ubuntu22.04"
              arch            = "amd64"
              roles           = ["Master"]
              ssh             = {
                username      = "ubuntu"
                ipAddress     = i.privateip
                port          = "22"
                privateKeyPath = "id_ssh"
              }
            }
          ],
          [
            for i in var.worker_ips : {
              hostname        = i.hostname
              privateip       = i.privateip
              operatingSystem = "Ubuntu22.04"
              arch            = "amd64"
              roles           = ["Worker"]
              ssh             = {
                username      = "ubuntu"
                ipAddress     = i.privateip
                port          = "22"
                privateKeyPath = "id_ssh"
              }
            }
          ]
        )
      }
    }
  }
}

resource "random_id" "rafay_spec_file_suffix" {
  byte_length = 4
}

resource "local_file" "rafay_spec" {
  content         = jsonencode(local.rafay_spec)
  filename        = "rafay-spec-${random_id.rafay_spec_file_suffix.hex}.json"
  file_permission = "0600"
}

resource "terraform_data" "rctl_apply" {
  triggers_replace = [
    local_file.rafay_spec.content,
    local_file.rafay_spec.filename
  ]

  # Run rctl apply when the YAML file changes or is created
  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = "./apply.sh"
    environment = {
      "FILE_NAME" = local_file.rafay_spec.filename
      "PROJECT_NAME" = var.cluster_project
    }
  }
}

resource "terraform_data" "rctl_delete" {
  input = {
    kind    = lower(local.rafay_spec.kind)
    name    = local.rafay_spec.metadata.name
    project = local.rafay_spec.metadata.project
  }

  # Run rctl delete when `terraform destroy` is called
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/sh", "-c"]
    command     = "./delete.sh"
    environment = {
      "KIND"    = self.input.kind
      "NAME"    = self.input.name
      "PROJECT" = self.input.project
    }
  }
}
