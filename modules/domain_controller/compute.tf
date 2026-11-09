resource "azurerm_public_ip" "dc01" {
  name                = "pip-dc01"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "dc01" {
  name                = "nic-dc01"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.dc_private_ip
    public_ip_address_id          = azurerm_public_ip.dc01.id
  }
}

resource "azurerm_windows_virtual_machine" "dc01" {
  name                  = "DC01"
  computer_name         = "DC01"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.dc01.id]

  os_disk {
    name                 = "osdisk-dc01"
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

resource "azurerm_dev_test_global_vm_shutdown_schedule" "dc01" {
  virtual_machine_id    = azurerm_windows_virtual_machine.dc01.id
  location              = var.location
  enabled               = true
  daily_recurrence_time = var.shutdown_time
  timezone              = var.shutdown_timezone

  notification_settings {
    enabled = false
  }
}
