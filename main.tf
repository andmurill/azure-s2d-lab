resource "random_password" "admin" {
  length      = 20
  special     = false
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
}

module "network" {
  source = "./modules/network"

  prefix             = var.prefix
  location           = var.location
  vnet_address_space = var.vnet_address_space
  subnet_prefix      = var.subnet_prefix
  dc_private_ip      = var.dc_private_ip
  allowed_rdp_cidr   = var.allowed_rdp_cidr
}

module "domain_controller" {
  source = "./modules/domain_controller"

  resource_group_name = module.network.resource_group_name
  location            = module.network.location
  subnet_id           = module.network.subnet_id
  dc_private_ip       = var.dc_private_ip
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.admin.result
  shutdown_time       = var.shutdown_time
  shutdown_timezone   = var.shutdown_timezone
  domain_name         = var.domain_name
  domain_netbios      = var.domain_netbios
}

module "cluster" {
  source = "./modules/cluster"

  prefix              = var.prefix
  resource_group_name = module.network.resource_group_name
  location            = module.network.location
  subnet_id           = module.network.subnet_id
  node_names          = var.node_names
  node_vm_size        = var.node_vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.admin.result
  domain_name         = var.domain_name
  domain_netbios      = var.domain_netbios
  dc_private_ip       = var.dc_private_ip
  dc_vm_id            = module.domain_controller.vm_id
  dc_promotion_id     = module.domain_controller.promotion_id
  cluster_name        = var.cluster_name
  shutdown_time       = var.shutdown_time
  shutdown_timezone   = var.shutdown_timezone
  s2d_disk_count      = var.s2d_disk_count
  s2d_disk_size_gb    = var.s2d_disk_size_gb
  s2d_disk_sku        = var.s2d_disk_sku
  s2d_volume_size_gb  = var.s2d_volume_size_gb
  s2d_extra_volumes   = var.s2d_extra_volumes
}
