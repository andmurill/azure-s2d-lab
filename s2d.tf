locals {
  # PowerShell arguments for each extra volume
  s2d_volume_args = {
    for name, v in var.s2d_extra_volumes : name => (
      v.tier_template != ""
      ? "-StorageTierFriendlyNames '${v.tier_template}' -StorageTierSizes ${v.size_gb}GB"
      : (v.copies > 0 ? "-Size ${v.size_gb}GB -NumberOfDataCopies ${v.copies}" : "-Size ${v.size_gb}GB")
    )
  }

  # One guarded New-Volume block per extra volume
  s2d_extra_volumes_ps = join("\n", [
    for name, args in local.s2d_volume_args : join("\n", [
      "if (Get-VirtualDisk -FriendlyName '${name}' -ErrorAction SilentlyContinue) {",
      "  Write-Output '${name} already exists - nothing to do.'",
      "} else {",
      "  New-Volume -StoragePoolFriendlyName 'S2D*' -FriendlyName '${name}' -FileSystem CSVFS_ReFS ${args} | Out-Null",
      "  Write-Output '${name} created.'",
      "}",
    ])
  ])

  s2d_worker_script = <<-EOT
    $ErrorActionPreference = 'Stop'
    Start-Transcript -Path 'C:\s2d-worker.log' -Append | Out-Null
    try {
      $nodes = @(${local.node_list_ps})

      Write-Output '--- Validation: Storage Spaces Direct, Inventory, Network, System Configuration'
      try {
        Test-Cluster -Node $nodes -Include 'Storage Spaces Direct', 'Inventory', 'Network', 'System Configuration' | Out-Null
        Write-Output 'Validation finished. The report path is printed above.'
      } catch {
        Write-Output ('Validation did not complete: ' + $_.Exception.Message)
      }

      Write-Output '--- Enable Storage Spaces Direct'
      $pool = Get-StoragePool -ErrorAction SilentlyContinue | Where-Object { -not $_.IsPrimordial -and $_.FriendlyName -like 'S2D*' }
      if ($pool) {
        Write-Output 'S2D pool already exists - skipping Enable-ClusterS2D.'
      } else {
        Enable-ClusterS2D -Confirm:$false -Verbose
      }

      Write-Output '--- Disable automatic drive replacement (required for S2D in guest VMs)'
      $set = $false
      for ($i = 0; $i -lt 10 -and -not $set; $i++) {
        try {
          Get-StorageSubSystem Clus* | Set-StorageHealthSetting -Name 'System.Storage.PhysicalDisk.AutoReplace.Enabled' -Value 'False'
          $v = Get-StorageSubSystem Clus* | Get-StorageHealthSetting -Name 'System.Storage.PhysicalDisk.AutoReplace.Enabled'
          Write-Output ('AutoReplace.Enabled = ' + $v.Value)
          $set = $true
        } catch {
          Write-Output ('Health Service not ready yet: ' + $_.Exception.Message + ' - retrying in 30 seconds')
          Start-Sleep -Seconds 30
        }
      }
      if (-not $set) { throw 'Could not disable automatic drive replacement' }

      Write-Output '--- Create the first volume'
      if (Get-VirtualDisk -FriendlyName 'Volume1' -ErrorAction SilentlyContinue) {
        Write-Output 'Volume1 already exists - nothing to do.'
      } else {
        New-Volume -StoragePoolFriendlyName 'S2D*' -FriendlyName 'Volume1' -FileSystem CSVFS_ReFS -Size ${var.s2d_volume_size_gb}GB | Out-Null
        Write-Output 'Volume1 created.'
      }

      Write-Output '--- Create the extra volumes (if any)'
      ${local.s2d_extra_volumes_ps}

      Write-Output '--- Failover test: move the core cluster group to every node and back'
      foreach ($n in ($nodes + $nodes[0])) {
        if ((Get-ClusterGroup -Name 'Cluster Group').OwnerNode.Name -ne $n) {
          Move-ClusterGroup -Name 'Cluster Group' -Node $n | Out-Null
        }
        Write-Output ('Core cluster group owner: ' + (Get-ClusterGroup -Name 'Cluster Group').OwnerNode.Name)
      }

      Write-Output '--- State'
      Get-StoragePool | Format-Table FriendlyName, IsPrimordial, Size, AllocatedSize, HealthStatus | Out-String | Write-Output
      Get-PhysicalDisk | Sort-Object DeviceId | Format-Table DeviceId, FriendlyName, MediaType, Size, HealthStatus, Usage | Out-String | Write-Output
      Get-VirtualDisk | Format-Table FriendlyName, ResiliencySettingName, NumberOfDataCopies, FaultDomainAwareness, Size, FootprintOnPool, HealthStatus | Out-String | Write-Output
      Get-StorageTier | Format-Table FriendlyName, MediaType, ResiliencySettingName | Out-String | Write-Output
      Get-ClusterSharedVolume | Format-Table Name, State | Out-String | Write-Output

      Stop-Transcript | Out-Null
      exit 0
    } catch {
      $_ | Out-String | Write-Output
      Stop-Transcript | Out-Null
      exit 1
    }
  EOT

  s2d_script = <<-EOT
    param(
      [string]$AdminUser,
      [string]$AdminPassword
    )
    $ErrorActionPreference = 'Stop'
    $log = 'C:\enable-s2d.log'
    function Write-Log($msg) { Add-Content -Path $log -Value ("{0}  {1}" -f (Get-Date -Format s), $msg) }

    [IO.File]::WriteAllBytes('C:\s2d-worker.ps1', [Convert]::FromBase64String('${base64encode(local.s2d_worker_script)}'))

    Write-Log 'Registering scheduled task to run the S2D worker as the domain admin'
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\s2d-worker.ps1'
    Register-ScheduledTask -TaskName 'EnableS2D' -Action $action -User $AdminUser -Password $AdminPassword -RunLevel Highest -Force | Out-Null
    Start-ScheduledTask -TaskName 'EnableS2D'

    $deadline = (Get-Date).AddMinutes(40)
    do {
      Start-Sleep -Seconds 15
      $state = (Get-ScheduledTask -TaskName 'EnableS2D').State
    } while ($state -eq 'Running' -and (Get-Date) -lt $deadline)

    $result = (Get-ScheduledTaskInfo -TaskName 'EnableS2D').LastTaskResult
    Unregister-ScheduledTask -TaskName 'EnableS2D' -Confirm:$false
    Get-Content 'C:\s2d-worker.log' -ErrorAction SilentlyContinue | Add-Content -Path $log

    if ($state -eq 'Running') { Write-Log 'Task still running after 40 minutes'; throw 'S2D task timed out' }
    if ($result -ne 0) { Write-Log "S2D task failed with result $result"; throw "S2D task failed with result $result" }
    Write-Log 'S2D task finished OK'
  EOT
}

resource "azurerm_virtual_machine_run_command" "enable_s2d" {
  # The name carries a hash of the script so a changed script always runs as a new command.
  name               = "enable-s2d-${substr(md5(local.s2d_script), 0, 6)}"
  location           = azurerm_resource_group.lab.location
  virtual_machine_id = azurerm_windows_virtual_machine.node[local.first_node].id

  source {
    script = local.s2d_script
  }

  parameter {
    name  = "AdminUser"
    value = "${var.domain_netbios}\\${var.admin_username}"
  }

  protected_parameter {
    name  = "AdminPassword"
    value = random_password.admin.result
  }

  # The guest worker allows up to 40 minutes, so Terraform must wait longer than its 30-minute default.
  timeouts {
    create = "45m"
  }

  depends_on = [
    azurerm_virtual_machine_run_command.create_cluster,
    azurerm_virtual_machine_data_disk_attachment.s2d,
  ]
}
