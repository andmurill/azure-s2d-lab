variable "location" {
  description = "Azure region for the lab"
  type        = string
  default     = "centralus"
}

variable "prefix" {
  description = "Short prefix used in resource names"
  type        = string
  default     = "s2d"
}

variable "allowed_rdp_cidr" {
  description = "Public IP in CIDR form allowed to RDP to the VMs, e.g. 203.0.113.10/32"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_rdp_cidr, 0))
    error_message = "allowed_rdp_cidr must be a valid CIDR such as 203.0.113.10/32."
  }
}

variable "vnet_address_space" {
  description = "Address space of the virtual network"
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "subnet_prefix" {
  description = "Address prefix of the subnet that holds the VMs"
  type        = string
  default     = "10.10.1.0/24"
}

variable "vm_size" {
  description = "Size of the domain controller VM"
  type        = string
  default     = "Standard_B2ms"
}

variable "node_vm_size" {
  description = "Size of the cluster node VMs. Must support the data disk count and the disk SKU below."
  type        = string
  default     = "Standard_B2ms"
}

variable "admin_username" {
  description = "Local administrator user name for the VMs"
  type        = string
  default     = "labadmin"
}

variable "dc_private_ip" {
  description = "Static private IP of the domain controller"
  type        = string
  default     = "10.10.1.10"
}

variable "shutdown_time" {
  description = "Daily auto-shutdown time in HHmm"
  type        = string
  default     = "2300"
}

variable "shutdown_timezone" {
  description = "Windows time zone ID used for the auto-shutdown schedule"
  type        = string
  default     = "Central America Standard Time"
}

variable "domain_name" {
  description = "DNS name of the Active Directory forest"
  type        = string
  default     = "s2d.local"
}

variable "domain_netbios" {
  description = "NetBIOS name of the domain"
  type        = string
  default     = "S2D"
}

variable "node_names" {
  description = "Cluster node names and their static private IPs"
  type        = map(string)
  default = {
    S2DN1 = "10.10.1.11"
    S2DN2 = "10.10.1.12"
  }
}

variable "cluster_name" {
  description = "Name of the failover cluster"
  type        = string
  default     = "S2D-CLUS"
}

variable "s2d_disk_count" {
  description = "Number of data disks attached to each node for Storage Spaces Direct"
  type        = number
  default     = 4

  validation {
    condition     = var.s2d_disk_count >= 2
    error_message = "Storage Spaces Direct in a guest VM needs at least two data disks per node."
  }
}

variable "s2d_disk_size_gb" {
  description = "Size in GB of each S2D data disk. All disks must be the same size."
  type        = number
  default     = 128
}

variable "s2d_disk_sku" {
  description = "Managed disk SKU for the S2D data disks"
  type        = string
  default     = "Premium_LRS"

  validation {
    condition     = contains(["Premium_LRS", "StandardSSD_LRS"], var.s2d_disk_sku)
    error_message = "Use Premium_LRS (recommended) or StandardSSD_LRS for a cheaper lab."
  }
}

variable "s2d_volume_size_gb" {
  description = "Size in GB of the first cluster shared volume. Leave free pool space for repair."
  type        = number
  default     = 200
}
