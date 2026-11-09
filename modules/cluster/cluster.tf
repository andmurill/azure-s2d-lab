locals {
  node_list_ps = join(", ", [for n in sort(keys(var.node_names)) : "'${n}'"])
  first_node   = sort(keys(var.node_names))[0]

  cluster_worker_script = <<-EOT
    $ErrorActionPreference = 'Stop'
    Start-Transcript -Path 'C:\cluster-worker.log' -Append | Out-Null
    try {
      $nodes = @(${local.node_list_ps})

      Invoke-Command -ComputerName $nodes -ScriptBlock {
        Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools
      } | Select-Object PSComputerName, Success, RestartNeeded | Format-Table | Out-String | Write-Output

      if (Get-Cluster -ErrorAction SilentlyContinue) {
        Write-Output 'Cluster already exists.'
        foreach ($n in $nodes) {
          if (-not (Get-ClusterNode -Name $n -ErrorAction SilentlyContinue)) {
            Add-ClusterNode -Name $n | Out-Null
            Write-Output ('Added node ' + $n + ' to the cluster.')
          }
        }
      } else {
        New-Cluster -Name ${var.cluster_name} -Node $nodes -NoStorage -ManagementPointNetworkType Distributed | Out-Null
        Write-Output 'Cluster created.'
      }
      Stop-Transcript | Out-Null
      exit 0
    } catch {
      $_ | Out-String | Write-Output
      Stop-Transcript | Out-Null
      exit 1
    }
  EOT

  cluster_script = <<-EOT
    param(
      [string]$AdminUser,
      [string]$AdminPassword,
      [string]$WitnessAccount,
      [string]$WitnessKey
    )
    $ErrorActionPreference = 'Stop'
    $log = 'C:\create-cluster.log'
    function Write-Log($msg) { Add-Content -Path $log -Value ("{0}  {1}" -f (Get-Date -Format s), $msg) }

    Write-Log 'Waiting for the cluster nodes to answer over WinRM'
    foreach ($n in @(${local.node_list_ps})) {
      $ready = $false
      for ($i = 0; $i -lt 40 -and -not $ready; $i++) {
        try {
          Test-WSMan -ComputerName $n -ErrorAction Stop | Out-Null
          $ready = $true
        } catch {
          Start-Sleep -Seconds 15
        }
      }
      if (-not $ready) { throw "Cannot reach $n over WinRM" }
    }
    Write-Log 'All nodes reachable'

    [IO.File]::WriteAllBytes('C:\cluster-worker.ps1', [Convert]::FromBase64String('${base64encode(local.cluster_worker_script)}'))

    Write-Log 'Registering scheduled task to run the worker as the domain admin'
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\cluster-worker.ps1'
    Register-ScheduledTask -TaskName 'CreateCluster' -Action $action -User $AdminUser -Password $AdminPassword -RunLevel Highest -Force | Out-Null
    Start-ScheduledTask -TaskName 'CreateCluster'

    $deadline = (Get-Date).AddMinutes(20)
    do {
      Start-Sleep -Seconds 10
      $state = (Get-ScheduledTask -TaskName 'CreateCluster').State
    } while ($state -eq 'Running' -and (Get-Date) -lt $deadline)

    $result = (Get-ScheduledTaskInfo -TaskName 'CreateCluster').LastTaskResult
    Unregister-ScheduledTask -TaskName 'CreateCluster' -Confirm:$false
    Get-Content 'C:\cluster-worker.log' -ErrorAction SilentlyContinue | Add-Content -Path $log

    if ($state -eq 'Running') { Write-Log 'Task still running after 20 minutes'; throw 'Cluster task timed out' }
    if ($result -ne 0) { Write-Log "Cluster task failed with result $result"; throw "Cluster task failed with result $result" }
    Write-Log 'Cluster task finished OK'

    Set-ClusterQuorum -CloudWitness -AccountName $WitnessAccount -AccessKey $WitnessKey | Out-Null
    Write-Log 'Cloud witness configured'
    (Get-ClusterNode | Format-Table Name, State | Out-String) | Add-Content -Path $log
    (Get-ClusterQuorum | Format-List | Out-String) | Add-Content -Path $log
  EOT
}

resource "azurerm_virtual_machine_run_command" "create_cluster" {
  name               = "create-cluster-${substr(md5(local.cluster_script), 0, 6)}"
  location           = var.location
  virtual_machine_id = azurerm_windows_virtual_machine.node[local.first_node].id

  source {
    script = local.cluster_script
  }

  parameter {
    name  = "AdminUser"
    value = "${var.domain_netbios}\\${var.admin_username}"
  }

  parameter {
    name  = "WitnessAccount"
    value = azurerm_storage_account.witness.name
  }

  protected_parameter {
    name  = "AdminPassword"
    value = var.admin_password
  }

  protected_parameter {
    name  = "WitnessKey"
    value = azurerm_storage_account.witness.primary_access_key
  }

  depends_on = [azurerm_virtual_machine_run_command.wait_for_join]
}
