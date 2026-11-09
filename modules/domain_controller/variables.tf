variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "dc_private_ip" {
  type = string
}

variable "vm_size" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "shutdown_time" {
  type = string
}

variable "shutdown_timezone" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "domain_netbios" {
  type = string
}
