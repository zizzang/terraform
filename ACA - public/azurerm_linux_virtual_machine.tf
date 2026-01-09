# Public IP (Bastion)
resource "azurerm_public_ip" "vm_bastion" {
  name                = lower("${module.naming.linux_virtual_machine.name}")
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name

  allocation_method = "Static"
  sku               = "Standard"
  sku_tier          = "Regional"

  tags = var.tags
}

# Network Interface (Bastion)
resource "azurerm_network_interface" "vm_bastion" {
  name                = lower("${module.naming.network_interface.name}")
  location            = azurerm_resource_group.vm.location
  resource_group_name = azurerm_resource_group.vm.name

  ip_configuration {
    name                          = "ipConfiguration"
    subnet_id                     = azapi_resource.subnet_bastion.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_bastion.id
  }

  tags = var.tags
}

# Virtual Machine (Bastion)
resource "azurerm_linux_virtual_machine" "vm_bastion" {
  name                            = upper("${module.naming.linux_virtual_machine.name}")
  resource_group_name             = azurerm_resource_group.vm.name
  location                        = azurerm_resource_group.vm.location
  disable_password_authentication = false

  size = var.vm.size

  network_interface_ids = [
    azurerm_network_interface.vm_bastion.id,
  ]

  admin_username             = var.vm.admin_username
  admin_password             = var.vm_admin_password
  encryption_at_host_enabled = true # 호스트에서 암호화
  patch_assessment_mode      = "AutomaticByPlatform"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = "" # 부팅 진단 스토리지 계정 URI, "" 설정 시 Microsoft Managed
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [tags]
  }
}

# VM 상태 확인 (Azure CLI), VM Provisioning 완료 확인 후 Disk Access 설정 업데이트
resource "null_resource" "check_vm_status" {
  depends_on = [azurerm_linux_virtual_machine.vm_bastion]

  provisioner "local-exec" {
    command = <<EOT
      while ($true) {
        $STATUS = az vm show --resource-group ${azurerm_resource_group.vm.name} --name ${azurerm_linux_virtual_machine.vm_bastion.name} --query "provisioningState" -o tsv
        Write-Host "Current State: $STATUS"
        if ($STATUS -eq "Succeeded") {
          Write-Host "VM is Ready!"
          break
        }
        Start-Sleep -Seconds 60
      }
    EOT
    interpreter = ["PowerShell", "-Command"]
  }
}

# VM Disk Access
resource "azurerm_disk_access" "vm_bastion" {
  name                = lower("access-${azurerm_linux_virtual_machine.vm_bastion.name}")
  resource_group_name = azurerm_linux_virtual_machine.vm_bastion.resource_group_name
  location            = azurerm_linux_virtual_machine.vm_bastion.location

  tags = var.tags

  depends_on = [
    azurerm_linux_virtual_machine.vm_bastion,
    null_resource.check_vm_status,
    azurerm_network_interface.vm_bastion
  ]
}

# VM OS Disk 네트워킹 업데이트
resource "azapi_resource_action" "vm_bastion" {
  type        = "Microsoft.Compute/disks@2024-03-02"
  resource_id = azurerm_linux_virtual_machine.vm_bastion.os_disk[0].id
  method      = "PATCH"

  body = {
    location = "${azurerm_resource_group.vm.location}"
    properties = {
      networkAccessPolicy = "AllowPrivate"
      publicNetworkAccess = "Disabled"
      diskAccessId        = "${azurerm_disk_access.vm_bastion.id}"
    }
  }

  depends_on = [
    azurerm_linux_virtual_machine.vm_bastion,
    null_resource.check_vm_status,
    azurerm_disk_access.vm_bastion
  ]
}

# VM OS Disk 네트워킹 업데이트
resource "azapi_resource_action" "vm_bastion_destroy" {
  type        = "Microsoft.Compute/disks@2024-03-02"
  resource_id = azurerm_linux_virtual_machine.vm_bastion.os_disk[0].id
  method      = "PATCH"
  when        = "destroy"

  body = {
    location = "${azurerm_resource_group.vm.location}"
    properties = {
      networkAccessPolicy = "AllowAll"
      publicNetworkAccess = "Enabled"
      diskAccessId        = null
    }
  }

  depends_on = [
    azurerm_linux_virtual_machine.vm_bastion,
    null_resource.check_vm_status,
    azurerm_disk_access.vm_bastion
  ]
}


# Azure Policy for Linux 확장 리소스
resource "azurerm_virtual_machine_extension" "vm_bastion_AzurePolicyforLinux" {
  name                       = "AzurePolicyforLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm_bastion.id
  publisher                  = "Microsoft.GuestConfiguration"
  type                       = "ConfigurationforLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true

  settings = <<SETTINGS
 {
 }
SETTINGS

  tags = var.tags
}

# Guest Attestation 확장 리소스
resource "azurerm_virtual_machine_extension" "vm_bastion_GuestAttestation" {
  name                       = "GuestAttestation"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm_bastion.id
  publisher                  = "Microsoft.Azure.Security.LinuxAttestation"
  type                       = "GuestAttestation"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true

  settings = <<SETTINGS
{
            "AttestationConfig": {
                "MaaSettings": {
                    "maaEndpoint": "",
                    "maaTenantName": "GuestAttestation"
                },
                "AscSettings": {
                    "ascReportingEndpoint": ""
                },
                "useCustomToken": "false",
                "disableAlerts": "false"
            }
        }
SETTINGS

  tags = var.tags
}

# 사용자 할당 관리 ID
resource "azurerm_user_assigned_identity" "vm_bastion" {
  location            = azurerm_resource_group.vm.location
  name                = upper("${module.naming.user_assigned_identity.name}-vm")
  resource_group_name = azurerm_resource_group.vm.name

  tags = var.tags
}

# Azure Monitor Agent 확장
resource "azurerm_virtual_machine_extension" "vm_bastion_AMAExtension" {
  name                       = "AMAExtension"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm_bastion.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true

  settings = <<SETTINGS
{
            "authentication": {
                "managedIdentity": {
                    "identifier-name": "mi_res_id",
                    "identifier-value": "${azurerm_user_assigned_identity.vm_bastion.id}"
                }
            }
        }
SETTINGS

  tags = var.tags
}