# PRA Lab Deploy

## Projektstruktur

- `infra/terraform/modules/common_infra` – gemeinsam genutztes Terraform-Modul (RG, NSG, Regeln)
- `infra/terraform/templates/windows_vms_with_public_ip` – Terraform-Template für Windows-VMs
- `infra/terraform/templates/linux_vms_with_public_ip` – Terraform-Template für Linux-VMs
- `automation/scripts/pra_api` – PowerShell-Skripte für PRA-API (Manifest, Validierung, Cleanup)
- `automation/scripts/extensions_linux` – Linux-Extensions (Client/Jumpoint Installation)
- `automation/scripts/extensions_windows` – Windows-Extensions (Client/Jumpoint Installation)
- `pipelines` – Azure DevOps Deploy/Destroy/Test-Pipelines
