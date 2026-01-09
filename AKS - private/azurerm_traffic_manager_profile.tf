# 랜덤 ID 생성 - Traffic Manager 프로필의 relative name에 사용
resource "random_id" "server" {
  keepers = {
    azi_id = 1
  }
  byte_length = 8
}

# Traffic Manager 프로필
resource "azurerm_traffic_manager_profile" "tm" {
  name                   = upper("${module.naming.traffic_manager_profile.name}")
  resource_group_name    = azurerm_resource_group.network.name
  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = random_id.server.hex
    ttl           = 60
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
  }

  tags = var.tags
}

# Traffic Manager 외부 엔드포인트
resource "azurerm_traffic_manager_external_endpoint" "tm" {
  for_each             = azurerm_application_gateway.agw
  name                 = each.value.name
  profile_id           = azurerm_traffic_manager_profile.tm.id
  always_serve_enabled = false
  weight               = each.key == "agw_blue" ? 1000 : 1
  target               = each.value.frontend_ip_configuration[0].private_ip_address
}
