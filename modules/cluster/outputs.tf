output "node_names" {
  value = sort(keys(var.node_names))
}

output "witness_account_name" {
  value = azurerm_storage_account.witness.name
}

output "witness_account_key" {
  value     = azurerm_storage_account.witness.primary_access_key
  sensitive = true
}
