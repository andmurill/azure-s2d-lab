variable "prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_address_space" {
  type = list(string)
}

variable "subnet_prefix" {
  type = string
}

variable "dc_private_ip" {
  description = "Static IP of the domain controller, used as the VNet DNS server."
  type        = string
}

variable "allowed_rdp_cidr" {
  type = string
}
