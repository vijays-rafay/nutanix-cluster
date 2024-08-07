variable "subnet_name" {
  type = string
}

variable "subnet_uuid" {
  type = string
}

variable "username" {
  type = string
}

variable "password" {
  type = string
}

variable "nutanix_endpoint" {
  type = string
}

variable "nutanix_port" {
  type = number
}

variable "vm_name" {
  type = string
}

variable "vm_description" {
  type = string
}

variable "cluster_uuid" {
  type = string
}

variable "num_sockets" {
  type = number 
}

variable "vcpus_per_socket" {
  type = number 
}

variable "memory_in_mb" {
  type = number 
}

variable "template_uuid" {
  type = string
}

variable "template_name" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "masters" {
  type = set(string)
}

variable "workers" {
  type = set(string)
}
