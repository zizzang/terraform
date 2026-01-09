# ACA 용 사용자 할당 관리 ID
resource "azurerm_user_assigned_identity" "aca" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                = upper("${module.naming.user_assigned_identity.name}-aca-${replace(each.key, "aca_", "")}")
  location            = azurerm_resource_group.aca.location
  resource_group_name = azurerm_resource_group.aca.name
}

# Container App Environment
resource "azurerm_container_app_environment" "aca" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                = upper("${module.naming.container_app_environment.name}-${replace(each.key, "aca_", "")}")
  location            = azurerm_resource_group.aca.location
  resource_group_name = azurerm_resource_group.aca.name

  infrastructure_resource_group_name = upper("${module.naming.container_app_environment.name}-${replace(each.key, "aca_", "")}-RG") // 인프라 리소스 그룹 이름
  infrastructure_subnet_id           = local.subnet_service_map[each.key].id
  internal_load_balancer_enabled     = true
  zone_redundancy_enabled            = true

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  workload_profile {
    name                  = "D4"
    workload_profile_type = "D4"
    minimum_count         = 1
    maximum_count         = 5
  }
}

# Container App Environment에 대한 Private DNS 영역 생성
resource "azurerm_private_dns_zone" "aca" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                = azurerm_container_app_environment.aca[each.key].default_domain
  resource_group_name = azurerm_resource_group.network.name
}

# Private DNS 영역에 대한 Virtual Network 링크 생성
resource "azurerm_private_dns_zone_virtual_network_link" "aca" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                  = lower("${azurerm_virtual_network.service.name}-link") // 링크 이름
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.aca[each.key].name
  virtual_network_id    = azurerm_virtual_network.service.id

  depends_on = [
    azurerm_container_app_environment.aca,
  azurerm_private_dns_zone.aca]
}

resource "azurerm_private_dns_zone_virtual_network_link" "aca_bastion" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                  = lower("${azurerm_virtual_network.bastion.name}-link") // 링크 이름
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.aca[each.key].name
  virtual_network_id    = azurerm_virtual_network.bastion.id

  depends_on = [
    azurerm_container_app_environment.aca,
    azurerm_private_dns_zone.aca]
}


# Private DNS 영역에 CAE 리소스 A 레코드 추가
# 참고 문서 (https://learn.microsoft.com/ko-kr/azure/container-apps/waf-app-gateway?tabs=default-domain)
resource "azurerm_private_dns_a_record" "aca" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                = "*"
  resource_group_name = azurerm_resource_group.network.name
  zone_name           = azurerm_private_dns_zone.aca[each.key].name
  ttl                 = 3600
  records             = [azurerm_container_app_environment.aca[each.key].static_ip_address]

  depends_on = [
    azurerm_private_dns_zone.aca,
    azurerm_private_dns_zone_virtual_network_link.aca,
  ]
}

resource "azurerm_container_app" "aca" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                         = lower("${module.naming.container_app.name}-${replace(each.key, "aca_", "")}")
  container_app_environment_id = azurerm_container_app_environment.aca[each.key].id
  resource_group_name          = azurerm_resource_group.aca.name
  revision_mode                = "Single"

  template {
    container {
      name   = "nginx"           // 컨테이너 이름
      image  = "docker.io/nginx" // 컨테이너 이미지
      cpu    = 0.25
      memory = "0.5Gi"
    }
    min_replicas = 1
    max_replicas = 5

    # Custom Scale Rule 설정 (https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_app#custom_scale_rule-2)
    # CPU 스케일링 설정 (https://keda.sh/docs/2.17/scalers/cpu/)
    custom_scale_rule {
      name             = "cpu-custom-scale-rule" // 사용자 정의 스케일링 규칙 이름
      custom_rule_type = "cpu"                   // 스케일링 규칙 유형
      metadata = {
        type : "Utilization"
        value : "80"
      }
    }
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.aca[each.key].id
    ]
  }

  # Ingress 설정 - ACA에 대한 외부 트래픽 수신
  ingress {
    allow_insecure_connections = true # HTTP 연결 허용 여부 (true : HTTP/HTTPS 모두 허용, false : HTTPS Only)
    external_enabled           = true # CAE 외부 연결 허용 여부 (true : Limited to VNET, false : Limited to Container Apps Environment) )
    target_port                = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
    transport = "auto"
  }
}

# ACA 에 대한 ACR Pull 권한 부여
resource "azurerm_role_assignment" "acr" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  principal_id         = azurerm_user_assigned_identity.aca[each.key].principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}
