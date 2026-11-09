output "resource_group_name" {
  value = module.network.resource_group_name
}

output "subnet_id" {
  value = module.network.subnet_id
}

output "dc01_public_ip" {
  value = module.domain_controller.public_ip
}

output "dc01_private_ip" {
  value = module.domain_controller.private_ip
}

output "admin_username" {
  value = var.admin_username
}

output "admin_password" {
  value     = random_password.admin.result
  sensitive = true
}

output "witness_account_name" {
  value = module.cluster.witness_account_name
}

output "witness_account_key" {
  value     = module.cluster.witness_account_key
  sensitive = true
}

output "node_names" {
  value = module.cluster.node_names
}

output "s2d_disk_count_per_node" {
  value = var.s2d_disk_count
}
