# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "log" {
  name                = module.naming.log_analytics_workspace.name
  location            = azurerm_resource_group.managed.location
  resource_group_name = azurerm_resource_group.managed.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

# Log 저장 Storage Account
resource "azurerm_storage_account" "log_storage" {
  name                          = lower("${module.naming.storage_account.name_unique}log") # 스토리지 계정 이름
  resource_group_name           = azurerm_resource_group.storage.name                      # 리소스 그룹 이름
  location                      = azurerm_resource_group.storage.location                  # 리소스 위치
  account_tier                  = "Standard"                                               # 계정 티어
  account_replication_type      = "LRS"                                                    # 복제 유형
  public_network_access_enabled = false                                                    # 공용 네트워크 접근 비활성화

  https_traffic_only_enabled = true
  shared_access_key_enabled  = false
  allowed_copy_scope         = "PrivateLink"
  min_tls_version            = "TLS1_2"

  blob_properties {
    delete_retention_policy {
      days    = 7          # 삭제된 Blob 보관 기간 (1~365일)
    }
  }

  tags = merge(
    var.tags,
    {
      SEC_ASSETS_PII    = "Y",
      SEC_ASSETS_PUBLIC = "Y"
    }
  )
}

# Storage Account - Blob에 대한 Private Endpoint 설정
resource "azurerm_private_endpoint" "log_storage" {
  name                = lower("pe-${azurerm_storage_account.log_storage.name}")
  location            = azurerm_resource_group.storage.location
  resource_group_name = azurerm_resource_group.storage.name
  subnet_id           = local.subnet_service_map["pe"].id

  private_service_connection {
    name                           = "psc-blob-${azurerm_storage_account.log_storage.name}"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.log_storage.id
    subresource_names              = ["blob"]
  }

  tags = var.tags
}

# Private DNS Zone 리소스
resource "azurerm_private_dns_zone" "storage" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.network.name

  tags = var.tags
}

# Private DNS Zone A 레코드 설정
resource "azurerm_private_dns_a_record" "log_storage" {
  name                = azurerm_storage_account.log_storage.name                                                # A 레코드 이름
  zone_name           = azurerm_private_dns_zone.storage.name                                                   # DNS Zone 이름
  resource_group_name = azurerm_private_dns_zone.storage.resource_group_name                                    # 리소스 그룹 이름
  ttl                 = 300                                                                                     # TTL 설정 (초 단위)
  records             = [azurerm_private_endpoint.log_storage.private_service_connection[0].private_ip_address] # Private IP 주소
}

# Storage Account에 대한 Private DNS Zone과 가상 네트워크의 링크 설정
resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  name                  = lower("${azurerm_virtual_network.service.name}-link")
  resource_group_name   = azurerm_private_dns_zone.storage.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.storage.name
  virtual_network_id    = azurerm_virtual_network.service.id

  tags = var.tags

  depends_on = [
  azurerm_private_dns_zone.storage
  ]
}

# Storage Account에 대한 Private DNS Zone과 가상 네트워크의 링크 설정
resource "azurerm_private_dns_zone_virtual_network_link" "storage_bastion" {
  name                  = lower("${azurerm_virtual_network.bastion.name}-link")
  resource_group_name   = azurerm_private_dns_zone.storage.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.storage.name
  virtual_network_id    = azurerm_virtual_network.bastion.id

  tags = var.tags

  depends_on = [
  azurerm_private_dns_zone.storage
  ]
}

# Storage 계정에 대한 수명 주기 관리 정책(Lifecycle Policy) 설정
# - 모든 블록 블랍(blockBlob)에 대해 수정 후 365일이 지나면 자동 삭제
# - 컨테이너나 prefix 제한 없이 전체 blob에 적용
resource "azapi_resource" "storage_lifecycle_policy" {
  type      = "Microsoft.Storage/storageAccounts/managementPolicies@2021-02-01" # 스토리지 계정 관리 정책 리소스 타입 및 API 버전
  name      = "default"                                                        # 관리 정책 리소스 이름(항상 "default" 여야 함)
  parent_id = azurerm_storage_account.log_storage.id                            # 정책을 적용할 대상 스토리지 계정 ID

  body = {
    properties = {
      policy = {
        rules = [                                                               # 정책 규칙 정의 시작
          {
            name    = "storage_lifecycle_policy"                                # 규칙 이름
            enabled = true                                                      # 규칙 활성화 여부
            type    = "Lifecycle"                                               # 규칙 유형(Lifecycle)
            definition = {
              actions = {                                                       # 규칙이 수행할 동작 정의
                baseBlob = {                                                    # 블랍 데이터에 대한 정책
                  delete = {                                                    # 삭제 동작 정의
                    daysAfterModificationGreaterThan = 365                      # 마지막 수정 후 365일이 지나면 삭제
                  }
                }
              }
              filters = {                                                       # 정책 필터 정의
                blobTypes = ["blockBlob"]                                       # blockBlob 타입만 대상 (모든 컨테이너/경로에 적용)
              }
            }
          }
        ]
      }
    }
  }
}