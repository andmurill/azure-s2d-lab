locals {
  # One entry per node and disk, e.g. "S2DN1-disk0" => { node = "S2DN1", lun = 0 }
  s2d_disks = {
    for pair in setproduct(keys(var.node_names), range(var.s2d_disk_count)) :
    "${pair[0]}-disk${pair[1]}" => {
      node = pair[0]
      lun  = pair[1]
    }
  }
}

resource "azurerm_managed_disk" "s2d" {
  for_each             = local.s2d_disks
  name                 = "disk-${lower(each.key)}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = var.s2d_disk_sku
  create_option        = "Empty"
  disk_size_gb         = var.s2d_disk_size_gb
}

resource "azurerm_virtual_machine_data_disk_attachment" "s2d" {
  for_each           = local.s2d_disks
  managed_disk_id    = azurerm_managed_disk.s2d[each.key].id
  virtual_machine_id = azurerm_windows_virtual_machine.node[each.value.node].id
  lun                = each.value.lun
  caching            = "None"
}
