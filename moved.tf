# Moves the existing resources into the modules, so a refactor of a live lab plans no changes.

moved {
  from = azurerm_resource_group.lab
  to   = module.network.azurerm_resource_group.lab
}

moved {
  from = azurerm_virtual_network.lab
  to   = module.network.azurerm_virtual_network.lab
}

moved {
  from = azurerm_subnet.nodes
  to   = module.network.azurerm_subnet.nodes
}

moved {
  from = azurerm_network_security_group.nodes
  to   = module.network.azurerm_network_security_group.nodes
}

moved {
  from = azurerm_subnet_network_security_group_association.nodes
  to   = module.network.azurerm_subnet_network_security_group_association.nodes
}

moved {
  from = azurerm_public_ip.dc01
  to   = module.domain_controller.azurerm_public_ip.dc01
}

moved {
  from = azurerm_network_interface.dc01
  to   = module.domain_controller.azurerm_network_interface.dc01
}

moved {
  from = azurerm_windows_virtual_machine.dc01
  to   = module.domain_controller.azurerm_windows_virtual_machine.dc01
}

moved {
  from = azurerm_dev_test_global_vm_shutdown_schedule.dc01
  to   = module.domain_controller.azurerm_dev_test_global_vm_shutdown_schedule.dc01
}

moved {
  from = azurerm_virtual_machine_extension.dc01_promote
  to   = module.domain_controller.azurerm_virtual_machine_extension.dc01_promote
}

moved {
  from = random_string.witness
  to   = module.cluster.random_string.witness
}

moved {
  from = azurerm_storage_account.witness
  to   = module.cluster.azurerm_storage_account.witness
}

moved {
  from = azurerm_availability_set.nodes
  to   = module.cluster.azurerm_availability_set.nodes
}

moved {
  from = azurerm_network_interface.node
  to   = module.cluster.azurerm_network_interface.node
}

moved {
  from = azurerm_windows_virtual_machine.node
  to   = module.cluster.azurerm_windows_virtual_machine.node
}

moved {
  from = azurerm_dev_test_global_vm_shutdown_schedule.node
  to   = module.cluster.azurerm_dev_test_global_vm_shutdown_schedule.node
}

moved {
  from = azurerm_virtual_machine_run_command.node_prep
  to   = module.cluster.azurerm_virtual_machine_run_command.node_prep
}

moved {
  from = azurerm_virtual_machine_extension.node_join
  to   = module.cluster.azurerm_virtual_machine_extension.node_join
}

moved {
  from = azurerm_managed_disk.s2d
  to   = module.cluster.azurerm_managed_disk.s2d
}

moved {
  from = azurerm_virtual_machine_data_disk_attachment.s2d
  to   = module.cluster.azurerm_virtual_machine_data_disk_attachment.s2d
}

moved {
  from = azurerm_virtual_machine_run_command.wait_for_dc
  to   = module.cluster.azurerm_virtual_machine_run_command.wait_for_dc
}

moved {
  from = azurerm_virtual_machine_run_command.wait_for_join
  to   = module.cluster.azurerm_virtual_machine_run_command.wait_for_join
}

moved {
  from = azurerm_virtual_machine_run_command.create_cluster
  to   = module.cluster.azurerm_virtual_machine_run_command.create_cluster
}

moved {
  from = azurerm_virtual_machine_run_command.enable_s2d
  to   = module.cluster.azurerm_virtual_machine_run_command.enable_s2d
}
