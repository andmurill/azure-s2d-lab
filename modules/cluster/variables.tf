variable "prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "node_names" {
  description = "Cluster nodes and their static IPs."
  type        = map(string)
}

variable "node_vm_size" {
  type = string
}

variable "admin_username" {
  type = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "domain_name" {
  type = string
}

variable "domain_netbios" {
  type = string
}

variable "dc_private_ip" {
  type = string
}

variable "dc_vm_id" {
  description = "ID of DC01. The join check runs on it."
  type        = string
}

variable "dc_promotion_id" {
  description = "Output of the domain controller module. Nothing in this module starts before it exists."
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "shutdown_time" {
  type = string
}

variable "shutdown_timezone" {
  type = string
}

variable "s2d_disk_count" {
  type = number
}

variable "s2d_disk_size_gb" {
  type = number
}

variable "s2d_disk_sku" {
  type = string
}

variable "s2d_volume_size_gb" {
  type = number
}

variable "s2d_extra_volumes" {
  type = map(object({
    size_gb       = number
    copies        = optional(number, 0)
    tier_template = optional(string, "")
  }))
  default = {}
}
