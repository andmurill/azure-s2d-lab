# Readiness checks that replace the fixed time_sleep waits.
# Each one polls the real condition instead of waiting a fixed time.

# Makes everything below wait for the domain controller promotion in the other module.
resource "terraform_data" "dc_promoted" {
  input = var.dc_promotion_id
}

locals {
  # 'S2DN1'='10.10.1.11'; 'S2DN2'='10.10.1.12'
  node_map_ps = join("; ", [for k, v in var.node_names : "'${k}'='${v}'"])
}

# Waits until DC01 has finished promotion and its restart: LDAP, AD Web Services
# and DNS all answer, three times in a row. Runs on a node, which does not reboot here.
resource "azurerm_virtual_machine_run_command" "wait_for_dc" {
  name               = "wait-for-dc"
  location           = var.location
  virtual_machine_id = azurerm_windows_virtual_machine.node[local.first_node].id

  source {
    script = <<-EOT
      $ErrorActionPreference = 'Stop'
      $dc = '${var.dc_private_ip}'
      $domain = '${var.domain_name}'
      $ok = 0
      for ($i = 0; $i -lt 120 -and $ok -lt 3; $i++) {
        $up = $false
        try {
          $ldap = (Test-NetConnection -ComputerName $dc -Port 389 -WarningAction SilentlyContinue).TcpTestSucceeded
          $adws = (Test-NetConnection -ComputerName $dc -Port 9389 -WarningAction SilentlyContinue).TcpTestSucceeded
          if ($ldap -and $adws) {
            Resolve-DnsName -Name $domain -Server $dc -ErrorAction Stop | Out-Null
            $up = $true
          }
        } catch { $up = $false }
        if ($up) { $ok++ } else { $ok = 0 }
        if ($ok -lt 3) { Start-Sleep -Seconds 10 }
      }
      if ($ok -lt 3) { throw 'The domain controller did not become ready in time' }
      Write-Output 'Domain controller is ready (LDAP, ADWS and DNS answered 3 times in a row).'
    EOT
  }

  depends_on = [terraform_data.dc_promoted]
}

# Waits until every node is in the domain and has finished the join restart.
# Runs on DC01, which does not reboot here. For each node it reads the real boot time over
# WinRM and compares it with the time the computer account was created (the join). A boot time
# after the join means the join restart is done. Progress goes to C:\wait-for-join.log.
resource "azurerm_virtual_machine_run_command" "wait_for_join" {
  name               = "wait-for-join-${substr(md5(local.node_list_ps), 0, 6)}"
  location           = var.location
  virtual_machine_id = var.dc_vm_id

  source {
    script = <<-EOT
      param(
        [string]$AdminUser,
        [string]$AdminPassword
      )
      $ErrorActionPreference = 'Stop'
      $log = 'C:\wait-for-join.log'
      function Write-Log($msg) { Add-Content -Path $log -Value ("{0}  {1}" -f (Get-Date -Format s), $msg) }
      $nodes = @(${local.node_list_ps})
      $domain = '${var.domain_name}'
      $cred = New-Object System.Management.Automation.PSCredential($AdminUser, (ConvertTo-SecureString $AdminPassword -AsPlainText -Force))
      $deadline = (Get-Date).AddMinutes(25)
      foreach ($n in $nodes) {
        $ready = $false
        $lastNote = ''
        while (-not $ready -and (Get-Date) -lt $deadline) {
          $c = Get-ADComputer -Filter "Name -eq '$n'" -Properties whenCreated -ErrorAction SilentlyContinue
          if (-not $c) {
            $note = 'computer account not found yet'
          } else {
            try {
              $boot = Invoke-Command -ComputerName "$n.$domain" -Credential $cred -ErrorAction Stop -ScriptBlock {
                (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
              }
              if ($boot -gt $c.whenCreated.ToUniversalTime()) {
                $ready = $true
                $note = "booted at $boot UTC, after the join at $($c.whenCreated.ToUniversalTime()) UTC"
              } else {
                $note = "reachable but not restarted since the join (boot $boot UTC, join $($c.whenCreated.ToUniversalTime()) UTC)"
              }
            } catch {
              $note = 'not reachable yet: ' + $_.Exception.Message.Split([char]10)[0]
            }
          }
          if ($note -ne $lastNote) { Write-Log "$n : $note"; $lastNote = $note }
          if (-not $ready) { Start-Sleep -Seconds 10 }
        }
        if (-not $ready) { Write-Log "$n : gave up"; throw "Node $n did not finish joining and restarting in time" }
        Write-Output "$n is joined and back online."
      }
    EOT
  }

  parameter {
    name  = "AdminUser"
    value = "${var.domain_netbios}\\${var.admin_username}"
  }

  protected_parameter {
    name  = "AdminPassword"
    value = var.admin_password
  }

  depends_on = [azurerm_virtual_machine_extension.node_join]
}
