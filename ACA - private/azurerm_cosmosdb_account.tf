# Azure Cosmos DB
resource "azurerm_cosmosdb_account" "cosmos" {
  name                = lower(module.naming.cosmosdb_account.name_unique)
  location            = azurerm_resource_group.database.location
  resource_group_name = azurerm_resource_group.database.name
  offer_type          = var.cosmosdb.sku  # SKU
  kind                = var.cosmosdb.kind # DB 종류

  local_authentication_disabled = true    # Entra ID Auth Only
  automatic_failover_enabled    = true    # Failover 활성화
  public_network_access_enabled = false   # Public Network Access Disabled (Private Endpoint 사용)
  minimal_tls_version           = "Tls12" # 최소 TLS 버전 설정

  # 데이터 일관성 정책 설정
  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  # 기본 지역에 대한 지리적 위치 설정
  geo_location {
    location          = azurerm_resource_group.database.location # 기본 지역
    failover_priority = 0                                        # 기본 우선순위 설정
    zone_redundant    = true
  }

  # 보조 지역(Failover 지역)에 대한 지리적 위치 설정
  geo_location {
    location          = var.cosmosdb.secondary_location # 기본 지역
    failover_priority = 1                               # 보조 우선순위 설정
    zone_redundant    = false                           # Korea South 지역에서 지원 안함
  }

  # 백업 정책 설정
  backup {
    type = "Continuous"
    tier = "Continuous30Days"
  }

  tags = var.tags
}

# Cosmos DB Private Endpoint 설정
resource "azurerm_private_endpoint" "cosmos" {
  name                = lower("pe-${azurerm_cosmosdb_account.cosmos.name}")
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  subnet_id           = local.subnet_service_map["pe"].id

  private_service_connection {
    name                           = "psc-cosmos-${azurerm_cosmosdb_account.cosmos.name}"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_cosmosdb_account.cosmos.id
    subresource_names              = ["Sql"]
  }

  tags = var.tags

  depends_on = [
  azurerm_cosmosdb_account.cosmos, # Cosmos DB 계정 생성 후 엔드포인트가 생성되도록 의존성 명시
  azapi_resource.subnet_service_pe
  ]
}

# Cosmos DB Private DNS Zone 설정
resource "azurerm_private_dns_zone" "cosmos" {
  name                = "privatelink.documents.azure.com"
  resource_group_name = azurerm_resource_group.network.name
}

# Cosmos DB Private DNS A 레코드 설정
resource "azurerm_private_dns_a_record" "cosmos" {
  name                = azurerm_cosmosdb_account.cosmos.name
  zone_name           = azurerm_private_dns_zone.cosmos.name
  resource_group_name = azurerm_private_dns_zone.cosmos.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.cosmos.private_service_connection[0].private_ip_address]

  tags = var.tags
}

# Cosmos DB Private DNS Zone과 가상 네트워크의 링크
resource "azurerm_private_dns_zone_virtual_network_link" "cosmos" {
  name                  = lower("${azurerm_virtual_network.service.name}-link")
  resource_group_name   = azurerm_private_dns_zone.cosmos.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.cosmos.name
  virtual_network_id    = azurerm_virtual_network.service.id

  tags = var.tags

  depends_on = [
  azurerm_private_dns_zone.cosmos
  ]
}

# Cosmos DB Private DNS Zone과 가상 네트워크의 링크
resource "azurerm_private_dns_zone_virtual_network_link" "cosmos_bastion" {
  name                  = lower("${azurerm_virtual_network.bastion.name}-link")
  resource_group_name   = azurerm_private_dns_zone.cosmos.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.cosmos.name
  virtual_network_id    = azurerm_virtual_network.bastion.id

  tags = var.tags

  depends_on = [
  azurerm_private_dns_zone.cosmos
  ]
}

# Cosmos DB 진단 설정
resource "azurerm_monitor_diagnostic_setting" "cosmos" {
  name                       = lower("diag-${azurerm_cosmosdb_account.cosmos.name}")
  target_resource_id         = azurerm_cosmosdb_account.cosmos.id
  storage_account_id         = azurerm_storage_account.log_storage.id # 로그 저장 스토리지 계정
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id # 로그 저장 Log Analytics Workspace ID

  # Cosmos DB의 주요 로그 카테고리 활성화
  # Microsoft.ContainerService/managedClusters에 대해 지원되는 리소스 로그
  # https://learn.microsoft.com/ko-kr/azure/cosmos-db/monitor-reference#resource-logs
  enabled_log {
    category = "CassandraRequests"
  }

  enabled_log {
    category = "DataPlaneRequests"
  }

  enabled_log {
    category = "MongoRequests"
  }

  enabled_log {
    category = "QueryRuntimeStatistics"
  }

  enabled_log {
    category = "PartitionKeyStatistics"
  }

  enabled_log {
    category = "PartitionKeyRUConsumption"
  }

  enabled_log {
    category = "ControlPlaneRequests"
  }

  enabled_log {
    category = "GremlinRequests"
  }

  enabled_log {
    category = "TableApiRequests"
  }

  # 메트릭 데이터 설정 
  enabled_metric {
    category = "Requests"
  }

  enabled_metric {
    category = "SLI"
  }
}
