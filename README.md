# azure-s2d-lab

Terraform lab that builds a Windows Server 2022 failover cluster on Azure and enables **Storage Spaces Direct (S2D)** on it, with a Cluster Shared Volume. It extends my [azure-wsfc-lab](https://github.com/andmurill/azure-wsfc-lab) and follows the lab flow in the S2D deep dive, adapted for Azure VMs.

## What it builds

| Piece | Detail |
|---|---|
| Network | VNet and subnet, NSG allowing RDP only from my IP, VNet DNS pointing at DC01 |
| DC01 | Windows Server 2022, promoted to a new forest (`s2d.local`) by Terraform |
| Nodes | `S2DN1`, `S2DN2`, in an **availability set**, joined to the domain |
| Data disks | Managed disks per node (default 4 x 128 GB Premium SSD), no host caching |
| Cluster | `S2D-CLUS` with a distributed network name and a cloud witness |
| S2D | Validation, health setting, `Enable-ClusterS2D`, `Volume1` as a CSV, failover test |

## How it differs from the Hyper-V lab

| Deep dive (Hyper-V on one host) | This lab (Azure) |
|---|---|
| Virtual switches, NAT, DHCP, DNS forwarders | Azure VNet provides them |
| SMB1 and SMB2 private networks | One NIC per node (Azure has physical redundancy) |
| Hyper-V role, Data Center Bridging | Not installed: storage only, no nested VMs |
| 8 dynamic VHDX per node | Managed disks created by Terraform with `for_each` and `setproduct` |
| Host checkpoints | Not supported for S2D disks: rebuild with Terraform instead |
| Manual DC, domain join, cluster, S2D | Fully automated |

## Guest S2D requirements applied

- Availability set for the nodes (cannot be added to a VM after it exists)
- At least two data disks per node, Premium SSD, flat layout with no cache devices
- Automatic drive replacement disabled in the Health Service
- `HwTimeout` raised to 30 seconds (set before the domain-join restart)
- Cloud witness (a disk witness is not supported with S2D)
- Validation with `Storage Spaces Direct`, `Inventory`, `Network`, `System Configuration`
- Failover test: core cluster group moved to every node and back

## Run it

```powershell
$env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
terraform init
terraform plan -out main.tfplan
terraform apply main.tfplan
```

Logs on the first node: `C:\create-cluster.log`, `C:\enable-s2d.log`, `C:\s2d-worker.log`.

## Verified result

Checked from inside the cluster after `terraform apply`:

| Check | Result |
|---|---|
| Cluster nodes | `S2DN1` and `S2DN2` both Up |
| Storage pool | `S2D on S2D-CLUS`, about 1,016 GiB (8 x 128 GB data disks), Healthy |
| Volumes | `Volume1` (200 GB, two-way mirror) and the automatic `ClusterPerformanceHistory`, both Healthy |
| Cluster shared volume | `Cluster Virtual Disk (Volume1)` Online |
| Failover test | Core cluster group moved S2DN1, S2DN2, back to S2DN1 |
| Drive auto-replace | `AutoReplace.Enabled = false` |

Azure reports the data disks with media type `HDD`.

## Problems found while building it

| Problem | Cause | Fix |
|---|---|---|
| S2D step failed on `Set-StorageHealthSetting` | The Health Service only exists after `Enable-ClusterS2D` | Enable S2D first, then set the health setting, with a retry loop |
| Re-apply failed: run command "already exists" | A failed run command is created in Azure but never recorded in Terraform state | Delete the orphan with `az vm run-command delete`, then apply again |

## Cost

Run `terraform destroy` when finished. The VMs auto-shut down at 23:00 but the disks keep billing.
