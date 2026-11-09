output "vm_id" {
  value = azurerm_windows_virtual_machine.dc01.id
}

output "public_ip" {
  value = azurerm_public_ip.dc01.ip_address
}

output "private_ip" {
  value = azurerm_network_interface.dc01.private_ip_address
}

output "promotion_id" {
  description = "Changes only after the domain controller promotion extension has finished."
  value       = azurerm_virtual_machine_extension.dc01_promote.id
}
