#terraform {
#  required_providers {
#    nutanix = {
#      source = "nutanix/nutanix"
#      version = "1.2.0"
#    }
#    cloudinit = {
#      source = "hashicorp/cloudinit"
#      version = "2.3.4"
#    }
#  }
#}

#provider "nutanix" {
#  username     = var.username 
#  password     = var.password 
#  endpoint     = var.nutanix_endpoint
#  port         = var.nutanix_port
#  insecure     = true
#  wait_timeout = 10
#}

module "nutainx_vm" {
  username     = var.username
  password     = var.password
  nutanix_endpoint     = var.nutanix_endpoint
  nutanix_port         = var.nutanix_port
  source = "./modules/nutanix_vm"
  masters = var.masters
  workers = var.workers 
  vm_name = var.vm_prefix
  vm_description = var.vm_description
  cluster_uuid = var.cluster_uuid 
  vcpus_per_socket = var.vcpus_per_socket
  num_sockets   = var.num_sockets
  memory_in_mb  = var.memory_in_mb
  template_name = var.template_name
  template_uuid = var.template_uuid
  subnet_name = var.subnet_name
  subnet_uuid = var.subnet_uuid
  ssh_public_key = var.ssh_public_key
}

output "master_ips" {
value = module.nutainx_vm.master_ips
}

output "worker_ips" {
value = module.nutainx_vm.worker_ips
}
