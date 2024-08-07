terraform {
  required_version = ">=1.5.7"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
    cloudinit = {
      source = "hashicorp/cloudinit"
      version = "2.3.4"
    }
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "2.8.1"
    }
  }
}

variable "vm_hostname_prefix" {
  default = "surya1"
}

variable "master_vm_count" {
  description = "number of master VMs to create"
  type = number
  default = 3
  validation {
    condition = var.master_vm_count >= 1
    error_message = "Must be 1 or more."
  }
}

variable "worker_vm_count" {
  description = "number of worker VMs to create"
  type = number
  default = 3
  validation {
    condition = var.worker_vm_count >= 1
    error_message = "Must be 1 or more."
  }
}

variable "master_vm_cpu" {
  description = "number of CPUs per master VM"
  type = number
  default = 4
}

variable "master_vm_memory" {
  description = "amount of memory [GiB] per master VM"
  type = number
  default = 16
}

variable "worker_vm_cpu" {
  description = "number of CPUs per worker VM"
  type = number
  default = 8
}

variable "worker_vm_memory" {
  description = "amount of memory [GiB] per worker VM"
  type = number
  default = 64
}

variable "vm_disk_os_size" {
  description = "minimum size of the OS disk [GiB]"
  type = number
  default = 50
}

variable "vm_disk_data_size" {
  description = "size of the DATA disk [GiB]"
  type = number
  default = 30
}

variable "vsphere_user" {
  default = "cloudadmin@vmc.local"
}

variable "vsphere_password" {
  default = "password"
  sensitive = true
}

variable "vsphere_server" {
  default = "vcenter.sddc-3-232-94-253.vmwarevmc.com"
}

variable "vsphere_datacenter" {
  default = "SDDC-Datacenter"
}

variable "vsphere_compute_cluster" {
  default = "Cluster-1"
}

variable "vsphere_network" {
  default = "sddc-rafay-k8s"
}

variable "vsphere_datastore" {
  default = "WorkloadDatastore"
}

variable "vsphere_folder" {
  default = "Cluster-3"
}

variable "vsphere_ubuntu_template" {
  default = "ubuntu-2204-kube-v1.29.0"
}

variable "vm_prefix" {
  default = "surya1"
}

provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "datacenter" {
  name = var.vsphere_datacenter
}

data "vsphere_compute_cluster" "compute_cluster" {
  name           = var.vsphere_compute_cluster
  datacenter_id  = data.vsphere_datacenter.datacenter.id
}

data "vsphere_datastore" "datastore" {
  name          = var.vsphere_datastore
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_network" "network" {
  name          = var.vsphere_network
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "vsphere_virtual_machine" "ubuntu_template" {
  name          = var.vsphere_ubuntu_template
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

data "cloudinit_config" "master" {
  count         = var.master_vm_count
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      hostname: ${var.vm_prefix}-master-${count.index}
      users:
        - name: ubuntu
          passwd: '$6$rounds=4096$23GLKxe5CyPc1$fL5FgZCbCgw30ZHwqDt8hoO07m6isstJlxUIwvHBcSLVGzjdiR1Z1zA2yKGtR6EIv5LHflJuedbaiLUqU5Wfj0'
          sudo: ALL=(ALL) NOPASSWD:ALL
          lock_passwd: false
          shell: /bin/bash
          ssh-authorized-keys:
            - ${file("id_ssh.pub")}
      EOF
  }
}

data "cloudinit_config" "worker" {
  count         = var.worker_vm_count
  gzip          = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      hostname: ${var.vm_prefix}-worker-${count.index}
      users:
        - name: ubuntu
          passwd: '$6$rounds=4096$23GLKxe5CyPc1$fL5FgZCbCgw30ZHwqDt8hoO07m6isstJlxUIwvHBcSLVGzjdiR1Z1zA2yKGtR6EIv5LHflJuedbaiLUqU5Wfj0'
          sudo: ALL=(ALL) NOPASSWD:ALL
          lock_passwd: false
          shell: /bin/bash
          ssh-authorized-keys:
            - ${file("id_ssh.pub")}
      EOF
  }
}

resource "vsphere_folder" "folder" {
  path          = var.vsphere_folder
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.datacenter.id
}

resource "vsphere_virtual_machine" "master" {
  # https://github.com/hashicorp/terraform-provider-vsphere/issues/1902
  # ignoring these fields due to the above issue and its causing the vm to restart
  lifecycle {
    ignore_changes = [
      ept_rvi_mode,
      hv_mode
    ]
  }
  count                = var.master_vm_count
  folder               = vsphere_folder.folder.path
  name                 = "${var.vm_prefix}-master-${count.index}"
  guest_id             = data.vsphere_virtual_machine.ubuntu_template.guest_id
  firmware             = data.vsphere_virtual_machine.ubuntu_template.firmware
  num_cpus             = var.master_vm_cpu
  num_cores_per_socket = var.master_vm_cpu
  memory               = var.master_vm_memory * 1024
  nested_hv_enabled    = true
  vvtd_enabled         = true
  enable_disk_uuid     = true
  resource_pool_id     = data.vsphere_compute_cluster.compute_cluster.resource_pool_id
  datastore_id         = data.vsphere_datastore.datastore.id
  scsi_type            = data.vsphere_virtual_machine.ubuntu_template.scsi_type
  disk {
    unit_number      = 0
    label            = "os"
    size             = max(data.vsphere_virtual_machine.ubuntu_template.disks.0.size, var.vm_disk_os_size)
    eagerly_scrub    = data.vsphere_virtual_machine.ubuntu_template.disks.0.eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.ubuntu_template.disks.0.thin_provisioned
  }
  disk {
    unit_number      = 1
    label            = "data"
    size             = var.vm_disk_data_size
    eagerly_scrub    = data.vsphere_virtual_machine.ubuntu_template.disks.0.eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.ubuntu_template.disks.0.thin_provisioned
  }
  network_interface {
    network_id  = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.ubuntu_template.network_interface_types.0
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.ubuntu_template.id
  }
  extra_config = {
    "guestinfo.userdata"           = data.cloudinit_config.master[count.index].rendered
    "guestinfo.userdata.encoding"  = "gzip+base64"
  }
}

resource "vsphere_virtual_machine" "worker" {
  # https://github.com/hashicorp/terraform-provider-vsphere/issues/1902
  # ignoring these fields due to the above issue and its causing the vm to restart
  lifecycle {
    ignore_changes = [
      ept_rvi_mode,
      hv_mode
    ]
  }
  count                = var.worker_vm_count
  folder               = vsphere_folder.folder.path
  name                 = "${var.vm_prefix}-worker-${count.index}"
  guest_id             = data.vsphere_virtual_machine.ubuntu_template.guest_id
  firmware             = data.vsphere_virtual_machine.ubuntu_template.firmware
  num_cpus             = var.worker_vm_cpu
  num_cores_per_socket = var.worker_vm_cpu
  memory               = var.worker_vm_memory * 1024
  nested_hv_enabled    = true
  vvtd_enabled         = true
  enable_disk_uuid     = true
  resource_pool_id     = data.vsphere_compute_cluster.compute_cluster.resource_pool_id
  datastore_id         = data.vsphere_datastore.datastore.id
  scsi_type            = data.vsphere_virtual_machine.ubuntu_template.scsi_type
  disk {
    unit_number      = 0
    label            = "os"
    size             = max(data.vsphere_virtual_machine.ubuntu_template.disks.0.size, var.vm_disk_os_size)
    eagerly_scrub    = data.vsphere_virtual_machine.ubuntu_template.disks.0.eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.ubuntu_template.disks.0.thin_provisioned
  }
  disk {
    unit_number      = 1
    label            = "data"
    size             = var.vm_disk_data_size
    eagerly_scrub    = data.vsphere_virtual_machine.ubuntu_template.disks.0.eagerly_scrub
    thin_provisioned = data.vsphere_virtual_machine.ubuntu_template.disks.0.thin_provisioned
  }
  network_interface {
    network_id  = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.ubuntu_template.network_interface_types.0
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.ubuntu_template.id
  }
  extra_config = {
    "guestinfo.userdata"           = data.cloudinit_config.worker[count.index].rendered
    "guestinfo.userdata.encoding"  = "gzip+base64"
  }
}

output "master_ips" {
  value = [
    for i in vsphere_virtual_machine.master : {
      hostname  = i.name
      privateip = i.default_ip_address
    }
  ]
}

output "worker_ips" {
  value = [
    for i in vsphere_virtual_machine.worker : {
      hostname  = i.name
      privateip = i.default_ip_address
    }
  ]
}
