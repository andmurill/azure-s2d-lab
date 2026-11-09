resource "azurerm_availability_set" "nodes" {
  name                         = "avset-${var.prefix}-nodes"
  location                     = azurerm_resource_group.lab.location
  resource_group_name          = azurerm_resource_group.lab.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
  managed                      = true
}

resource "azurerm_network_interface" "node" {
  for_each            = var.node_names
  name                = "nic-${lower(each.key)}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.nodes.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value
  }
}

resource "azurerm_windows_virtual_machine" "node" {
  for_each              = var.node_names
  name                  = each.key
  computer_name         = each.key
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = var.node_vm_size
  availability_set_id   = azurerm_availability_set.nodes.id
  admin_username        = var.admin_username
  admin_password        = random_password.admin.result
  network_interface_ids = [azurerm_network_interface.node[each.key].id]

  os_disk {
    name                 = "osdisk-${lower(each.key)}"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "node" {
  for_each              = var.node_names
  virtual_machine_id    = azurerm_windows_virtual_machine.node[each.key].id
  location              = azurerm_resource_group.lab.location
  enabled               = true
  daily_recurrence_time = var.shutdown_time
  timezone              = var.shutdown_timezone

  notification_settings {
    enabled = false
  }
}

locals {
  # Storage Spaces Direct in a guest VM needs a longer storage I/O timeout.
  # It is set before the domain join so the join restart applies it.
  node_prep_script = <<-EOT
    $ErrorActionPreference = 'Stop'
    $p = 'HKLM:\SYSTEM\CurrentControlSet\Services\spaceport\Parameters'
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    New-ItemProperty -Path $p -Name 'HwTimeout' -PropertyType DWord -Value 30000 -Force | Out-Null
    Write-Output ('HwTimeout = ' + (Get-ItemProperty -Path $p).HwTimeout)
  EOT
}

resource "azurerm_virtual_machine_run_command" "node_prep" {
  for_each           = var.node_names
  name               = "node-prep"
  location           = azurerm_resource_group.lab.location
  virtual_machine_id = azurerm_windows_virtual_machine.node[each.key].id

  source {
    script = local.node_prep_script
  }

  depends_on = [azurerm_virtual_machine_data_disk_attachment.s2d]
}

resource "azurerm_virtual_machine_extension" "node_join" {
  for_each             = var.node_names
  name                 = "join-domain"
  virtual_machine_id   = azurerm_windows_virtual_machine.node[each.key].id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"

  settings = jsonencode({
    Name    = var.domain_name
    User    = "${var.domain_netbios}\\${var.admin_username}"
    Restart = "true"
    Options = "3"
  })

  protected_settings = jsonencode({
    Password = random_password.admin.result
  })

  depends_on = [
    azurerm_virtual_machine_run_command.wait_for_dc,
    azurerm_virtual_machine_run_command.node_prep,
  ]
}
