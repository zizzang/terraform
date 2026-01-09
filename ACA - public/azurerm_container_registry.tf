# Azure Container Registry (ACR)
resource "azurerm_container_registry" "acr" {
  name                          = module.naming.container_registry.name_unique
  resource_group_name           = azurerm_resource_group.aca.name
  location                      = azurerm_resource_group.aca.location
  sku                           = "Premium" # 프리미엄 SKU - Private Endpoint 사용시 필요
  admin_enabled                 = false     # 관리자 계정 비활성화
  public_network_access_enabled = false     # Public Network Access Disable, Private Endpoint 연결 필요

  georeplications {
    location                  = "koreasouth"# 복제할 Azure 지역 지정
    regional_endpoint_enabled = true        # 이 지역에서 지역 엔드포인트 활성화 여부
    zone_redundancy_enabled   = false       # 이 지역에서 영역 중복성 사용 여부
  }

  tags = var.tags
}

# Private Endpoint (ACR)
resource "azurerm_private_endpoint" "acr" {
  name                = lower("pe-${azurerm_container_registry.acr.name}")
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  subnet_id           = local.subnet_service_map["pe"].id

  private_service_connection {
    name                           = "psc-${azurerm_container_registry.acr.name}"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
  }

  tags = var.tags
}

# Private DNS Zone (ACR)
resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.network.name

  tags = var.tags
}

# Private DNS A 레코드 - Private Endpoint의 IP 주소 매핑
resource "azurerm_private_dns_a_record" "acr" {
  name                = azurerm_container_registry.acr.name                                             # ACR 이름과 동일한 A 레코드 이름
  zone_name           = azurerm_private_dns_zone.acr.name                                               # 앞서 생성한 Private DNS Zone 이름
  resource_group_name = azurerm_private_dns_zone.acr.resource_group_name                                # Private DNS Zone과 동일한 리소스 그룹
  ttl                 = 300                                                                             # DNS 레코드 캐시 시간 (5분)
  records             = [azurerm_private_endpoint.acr.private_service_connection[0].private_ip_address] # Private Endpoint의 개인 IP 주소를 레코드로 사용

  depends_on = [azurerm_private_endpoint.acr]
}

# Private DNS Zone과 가상 네트워크 링크 설정
resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = lower("${azurerm_virtual_network.service.name}-link")
  resource_group_name   = azurerm_private_dns_zone.acr.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.service.id

  tags = var.tags

  depends_on = [
  azurerm_private_dns_zone.acr
  ]
}

# Private DNS Zone과 가상 네트워크 링크 설정
resource "azurerm_private_dns_zone_virtual_network_link" "acr_bastion" {
  name                  = lower("${azurerm_virtual_network.bastion.name}-link")
  resource_group_name   = azurerm_private_dns_zone.acr.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.bastion.id

  tags = var.tags

  depends_on = [
  azurerm_private_dns_zone.acr
  ]
}
