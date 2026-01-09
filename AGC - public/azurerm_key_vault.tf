# Azure Key Vault
resource "azurerm_key_vault" "kv" {
  name                        = upper("${module.naming.key_vault.name_unique}")
  location                    = azurerm_resource_group.managed.location
  resource_group_name         = azurerm_resource_group.managed.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = var.keyvault.soft_delete_retention_days
  purge_protection_enabled    = var.keyvault.purge_protection_enabled

  sku_name                      = var.keyvault.sku
  public_network_access_enabled = false # Public Network Access Disabled (Private Endpoint 사용)

  tags = var.tags
}

# Key Vault Private Endpoint 설정
resource "azurerm_private_endpoint" "kv" {
  name                = lower("pe-${azurerm_key_vault.kv.name}")
  location            = azurerm_key_vault.kv.location
  resource_group_name = azurerm_resource_group.network.name
  subnet_id           = local.subnet_service_map["pe"].id

  private_service_connection {
    name                           = "psc-${azurerm_key_vault.kv.name}"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
  }

  tags = var.tags
}

# Key Vault Private DNS Zone 설정
resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.network.name

  tags = var.tags
}

# Key Vault Private DNS A 레코드 설정
resource "azurerm_private_dns_a_record" "kv" {
  name                = lower(azurerm_key_vault.kv.name)
  zone_name           = azurerm_private_dns_zone.kv.name
  resource_group_name = azurerm_private_dns_zone.kv.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.kv.private_service_connection[0].private_ip_address]
}

# Key Vault Private DNS Zone과 가상 네트워크 링크 설정
resource "azurerm_private_dns_zone_virtual_network_link" "kv" {
  name                  = lower("${azurerm_virtual_network.service.name}-link")
  resource_group_name   = azurerm_private_dns_zone.kv.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.service.id

  tags = var.tags

  depends_on = [
  azurerm_private_dns_zone.kv
  ]
}

# Key Vault Private DNS Zone과 가상 네트워크 링크 설정
resource "azurerm_private_dns_zone_virtual_network_link" "kv_bastion" {
  name                  = lower("${azurerm_virtual_network.bastion.name}-link")
  resource_group_name   = azurerm_private_dns_zone.kv.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.bastion.id

  tags = var.tags

  depends_on = [
  azurerm_private_dns_zone.kv
  ]
}

# Key Vault 진단 설정 리소스 정의  
resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = lower("diag-${azurerm_key_vault.kv.name}")        # 진단 설정 이름을 'diag-' 접두어와 Key Vault 계정명을 소문자로 지정합니다.
  target_resource_id         = azurerm_key_vault.kv.id                          # 진단 설정의 대상 리소스 ID는 Key Vault 계정의 ID입니다.
  storage_account_id         = azurerm_storage_account.log_storage.id # 로그 저장 스토리지 계정 # Key Vault 로그가 저장될 스토리지 계정 ID입니다.
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id # 로그 저장 Log Analytics Workspace ID  # Key Vault 로그가 저장될 Log Analytics Workspace ID입니다.

  enabled_log {
    category = "AuditEvent"                                                            # Key Vault의 감사 이벤트(AuditEvent) 로그를 활성화
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"                                          # Key Vault 관련 Azure Policy 평가 상세 로그를 활성화                           
  }

  enabled_metric {
    category = "AllMetrics"                                                            # 모든 Key Vault 메트릭 데이터를 수집       
  }

  depends_on = [
  azurerm_private_dns_zone.kv, # Private DNS Zone이 먼저 생성되어야 함을 명시
  ]
}