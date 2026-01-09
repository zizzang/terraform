# MySQL Flexible Server (azurerm provider에서 databasePort 설정 지원되지 않음)
resource "azapi_resource" "mysql" {
  type      = "Microsoft.DBforMySQL/flexibleServers@2024-06-01-preview"
  name      = lower("${module.naming.mysql_server.name_unique}")
  parent_id = azurerm_resource_group.database.id
  # identity = {
  #   type = "UserAssigned"
  #   userAssignedIdentities = {

  #   }
  # }
  location = azurerm_resource_group.database.location # 리소스 위치
  body = {
    properties = {
      administratorLogin         = var.mysql.administratorLogin         # 관리자 로그인 이름
      administratorLoginPassword = var.mysql_administratorLoginPassword # 관리자 로그인 암호
      availabilityZone           = "1"                                  # 가용성 영역
      backup = {                                                        # 백업 설정
        backupIntervalHours = 24                                        # 백업 간격 (시간 단위)
        backupRetentionDays = 7                                         # 백업 보존 기간 (일 단위)
        geoRedundantBackup  = "Disabled"                                # 지리적 중복 백업 비활성화
      }
      # createMode   = "string"
      databasePort = 25001 # 데이터베이스 포트
      # dataEncryption = {
      #   geoBackupKeyURI                 = "string"
      #   geoBackupUserAssignedIdentityId = "string"
      #   primaryKeyURI                   = "string"
      #   primaryUserAssignedIdentityId   = "string"
      #   type                            = "string"
      # }
      highAvailability = {                        # 고가용성 설정
        mode                    = "ZoneRedundant" # 영역 중복 모드
        standbyAvailabilityZone = "3"             # 대기 가용성 영역
      }
      # importSourceProperties = {
      #   dataDirPath = "string"
      #   sasToken    = "string"
      #   storageType = "string"
      #   storageUrl  = "string"
      # }
      # maintenancePolicy = {
      #   patchStrategy = "string"
      # }
      maintenanceWindow = { # Maintenance 설정
        customWindow = "Disabled"
        dayOfWeek    = 0
        startHour    = 0
        startMinute  = 0
      }
      network = {                                                           # 네트워크 설정
        delegatedSubnetResourceId = "${local.subnet_service_map["mysql"].id}" # 서브넷 리소스 ID
        privateDnsZoneResourceId  = azurerm_private_dns_zone.mysql.id       # Private DNS Zone 리소스 ID
        publicNetworkAccess       = "Disabled"                              # 공용 네트워크 접근 비활성화
      }
      replicationRole = "None" # 복제 역할
      # restorePointInTime     = "string"
      # sourceServerResourceId = "string"
      # storage = {                            
      #   autoGrow          = "Enabled"        
      #   autoIoScaling     = "Enabled"        
      #   iops              = 684              
      #   logOnDisk         = "Enabled"        
      #   storageRedundancy = "ZoneRedundancy" 
      #   storageSizeGB     = 128              
      # }
      version = "8.0.21" # MySQL 버전
    }
    sku = {                     # SKU 설정
      name = var.mysql.sku.name # SKU 이름
      tier = var.mysql.sku.tier # SKU 티어
    }
  }

  tags = var.tags

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_private_dns_zone.mysql,
    azurerm_private_dns_zone_virtual_network_link.mysql
  ]

  lifecycle {
    ignore_changes = [
      tags,
      body.properties.backup,
      body.properties.highAvailability.state,
      body.properties.storage.storageSku,
      body.properties.replicaCapacity,
      body.properties.state,
      body.properties.fullVersion,
      body.properties.fullyQualifiedDomainName
    ]
  }
}

# MySQL 서버 구성 설정을 위한 로컬 변수
locals {
  mysql_configurations = {
    # TLS 설정
    tls = {
      name  = "require_secure_transport"
      value = "ON"
    }
    # Audit 로그 설정
    audit_log = {
      name  = "audit_log_enabled"
      value = "ON"
    }
    # 서버 로그 설정
    server_log = {
      name  = "error_server_log_file"
      value = "ON"
    }
    # Error 로그 설정
    log_output = {
      name  = "log_output"
      value = "FILE"
    }
    # Slow 쿼리 로그 설정
    slow_query = {
      name  = "slow_query_log"
      value = "ON"
    }
  }
}

# MySQL 서버 구성 설정 리소스
resource "azurerm_mysql_flexible_server_configuration" "mysql" {
  for_each = local.mysql_configurations

  name                = each.value.name
  resource_group_name = azurerm_resource_group.database.name
  server_name         = azapi_resource.mysql.name
  value               = each.value.value
}

# MySQL 서버에 대한 Private DNS Zone 리소스
resource "azurerm_private_dns_zone" "mysql" {
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.network.name

  tags = var.tags
}

# MySQL 서버 Private DNS Zone과 가상 네트워크의 링크 리소스
resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = lower("${azurerm_virtual_network.service.name}-link")
  resource_group_name   = azurerm_private_dns_zone.mysql.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = azurerm_virtual_network.service.id

  tags = var.tags

  depends_on = [
  azurerm_private_dns_zone.mysql
  ]
}

# MySQL 서버 Private DNS Zone과 가상 네트워크의 링크 리소스
resource "azurerm_private_dns_zone_virtual_network_link" "mysql_bastion" {
  name                  = lower("${azurerm_virtual_network.bastion.name}-link")
  resource_group_name   = azurerm_private_dns_zone.mysql.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = azurerm_virtual_network.bastion.id

  tags = var.tags

  depends_on = [
  azurerm_private_dns_zone.mysql
  ]
}


# MySQL 서버 진단 설정
resource "azurerm_monitor_diagnostic_setting" "mysql" {
  name                       = lower("diag-${azapi_resource.mysql.name}")
  target_resource_id         = azapi_resource.mysql.id
  storage_account_id         = azurerm_storage_account.log_storage.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id

  enabled_log {
    category = "MySqlSlowLogs" # Slow 쿼리 로그 활성화
  }

  enabled_log {
    category = "MySqlAuditLogs" # 감사 로그 활성화
  }

  enabled_metric {
    category = "AllMetrics" # 모든 메트릭 활성화
  }
}

