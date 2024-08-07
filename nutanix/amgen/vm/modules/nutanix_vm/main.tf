terraform {
  required_providers {
    nutanix = {
      source = "nutanix/nutanix"
      version = "1.2.0"
    }
    cloudinit = {
      source = "hashicorp/cloudinit"
      version = "2.3.4"
    }
  }
}

provider "nutanix" {
  username     = var.username 
  password     = var.password 
  endpoint     = var.nutanix_endpoint
  port         = var.nutanix_port
  insecure     = true
  wait_timeout = 10
}

resource "nutanix_virtual_machine" "vm" {
  lifecycle {
    ignore_changes = all 
  }
  for_each             = setunion(var.masters, var.workers)
  name                 = "${var.vm_name}-${each.key}"
  description          = var.vm_description 
  cluster_uuid         = var.cluster_uuid
  num_vcpus_per_socket = var.vcpus_per_socket
  num_sockets          = var.num_sockets
  memory_size_mib      = var.memory_in_mb
 
  guest_customization_cloud_init_user_data = base64encode(templatefile("./cloud-init_user-data.tpl", {
    hostname       = "${var.vm_name}-${each.key}"
    ssh_public_key = var.ssh_public_key
  }))

  # This parent_reference is what actually tells the provider to clone the specified VM
  parent_reference = {
    kind = "vm"
    name = var.template_name
    uuid = var.template_uuid
  }


  disk_list {

    data_source_reference = {
      kind = "vm"
      name = var.template_name
      uuid = var.template_uuid 
    }

  }

  serial_port_list {
    index = 0
    is_connected = "true"
  }

  nic_list {
    subnet_name = var.subnet_name
    subnet_uuid = var.subnet_uuid
  }
}

#data "nutanix_virtual_machine" "vm" {
# for_each = var.masters
# vm_id = nutanix_virtual_machine.vm[each.key].id
#}
#output "master_ips" {
#value = [
#for i in tolist(var.masters) : {
#hostname = nutanix_virtual_machine.vm[i].name
#privateip = nutanix_virtual_machine.vm[i].nic_list[0].ip_endpoint_list[0].ip 
#}
#]
#}
data "nutanix_virtual_machine" "master_vms" {
 for_each = var.masters
 vm_id = nutanix_virtual_machine.vm[each.key].id
}

data "nutanix_virtual_machine" "worker_vms" {
 for_each = var.workers
 vm_id = nutanix_virtual_machine.vm[each.key].id
}

output "worker_ips" {
value = [
for i in data.nutanix_virtual_machine.worker_vms : {
hostname = i.name
privateip = i.nic_list[0].ip_endpoint_list[0].ip
}
]
}

output "master_ips" {
value = [
for i in data.nutanix_virtual_machine.master_vms : {
hostname = i.name
privateip = i.nic_list[0].ip_endpoint_list[0].ip
}
]
}
