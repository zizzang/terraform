# WAF(Web Application Firewall) 정책 - Microsoft 기본 보안 규칙셋을 사용하여 웹 애플리케이션 보호
resource "azurerm_web_application_firewall_policy" "agw" {
  for_each = {
    agw_blue = var.subnet_agw_blue
    agw_green = var.subnet_agw_green
  }

  name                = upper("waf-${module.naming.application_gateway.name}-${replace(each.key, "agw_", "")}")
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location

  custom_rules {
    name      = "TrafficManagerAllow"
    priority  = 1
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RequestHeaders"
        selector      = "Host"
      }

      operator           = "Contains"
      negation_condition = false
      match_values       = [azurerm_traffic_manager_profile.tm.fqdn]
    }

    action = "Allow"
  }

  custom_rules {
    name      = "AllDeny"
    priority  = 100
    rule_type = "MatchRule"

    match_conditions {
      match_variables {
        variable_name = "RemoteAddr"
      }

      operator           = "IPMatch"
      negation_condition = true
      match_values       = ["0.0.0.0"]
    }

    action = "Block"
  }

  # Microsoft 기본 보안 규칙셋 관리
  managed_rules {
    managed_rule_set {
      type    = "Microsoft_DefaultRuleSet" # Microsoft에서 제공하는 기본 보안 규칙셋 사용
      version = "2.1"                      # 규칙셋의 버전 지정 (최신 보안 규칙 적용)
    }
  }

  # 사용자 정의 정책 설정 - 향후 맞춤형 보안 정책 추가 가능
  policy_settings {
    # 사용자 지정 WAF 정책 구성 가능
  }

  tags = var.tags
}

# Application Gateway
resource "azurerm_application_gateway" "agw" {
  for_each = {
    agw_blue = var.subnet_agw_blue # 첫 번째 애플리케이션 게이트웨이
    agw_green = var.subnet_agw_green # 두 번째 애플리케이션 게이트웨이
  }

  name                = upper("${module.naming.application_gateway.name}-${replace(each.key, "agw_", "")}")
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location

  zones        = var.agw.zones # 다중 가용 영역 구성
  enable_http2 = true          # HTTP/2 활성화

  # WAF(Web Application Firewall) v2 SKU 구성
  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
    # capacity = 2
  }

  # AutoScale 구성
  autoscale_configuration {
    min_capacity = var.agw.autoscale_min_capacity
    max_capacity = var.agw.autoscale_max_capacity
  }

  # TLS 정책 추가
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101S"
  }

  # WAF 정책 연결
  force_firewall_policy_association = true
  firewall_policy_id                = azurerm_web_application_firewall_policy.agw[each.key].id

  # 게이트웨이 CIDR 구성 - AGW 서브넷에 IP 할당
  gateway_ip_configuration {
    name      = "gateway-ip-configuration"
    subnet_id = local.subnet_service_map[each.key].id
  }

  # 프론트엔드 구성
  frontend_port {
    name = "${each.value.naming}-feport"
    port = 80
  }

  # 프론트엔드 IP 구성 - 프라이빗 IP 주소 할당
  frontend_ip_configuration {
    name                          = "${each.value.naming}-feip"
    subnet_id                     = local.subnet_service_map[each.key].id
    private_ip_address_allocation = "Static"
    private_ip_address            = cidrhost(local.service_subnets[each.key].address_prefixes[0], 5) # 서브넷 내 5번째 IP 사용, 1~4는 Azure에서 예약된 IP
  }

  # 백엔드 주소 풀 구성
  backend_address_pool {
    name = "${each.value.naming}-beap"
  }

  # 백엔드 HTTP 설정
  backend_http_settings {
    name                  = "${each.value.naming}-be-htst"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  # HTTP 리스너 구성
  http_listener {
    name                           = "${each.value.naming}-httplstn"
    frontend_ip_configuration_name = "${each.value.naming}-feip"
    frontend_port_name             = "${each.value.naming}-feport"
    protocol                       = "Http"
  }

  # 라우팅 규칙
  request_routing_rule {
    name                       = "${each.value.naming}-rqrt"
    priority                   = 9
    rule_type                  = "Basic"
    http_listener_name         = "${each.value.naming}-httplstn"
    backend_address_pool_name  = "${each.value.naming}-beap"
    backend_http_settings_name = "${each.value.naming}-be-htst"
  }

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service,
    azurerm_network_security_rule.agw_inbound_01,
    azurerm_network_security_rule.agw_inbound_02,
    azurerm_network_security_rule.agw_inbound_03
  ]

  tags = var.tags
}

# Azure Monitor 진단 설정 - Application Gateway 로깅 및 모니터링 구성
resource "azurerm_monitor_diagnostic_setting" "azurerm_application_gateway" {
  for_each = {
    agw_blue = var.subnet_agw_blue
    agw_green = var.subnet_agw_green
  }

  # 진단 설정 생성
  name                       = lower("diag-${azurerm_application_gateway.agw[each.key].name}")
  target_resource_id         = azurerm_application_gateway.agw[each.key].id
  storage_account_id         = azurerm_storage_account.log_storage.id # 로그 저장을 위한 스토리지 계정
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id # 로그 저장을 위한 Log Analytics Workspace

  # AGW 액세스 로그 활성화
  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  # AGW 방화벽 로그 활성화
  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  # AGW 성능 로그 활성화
  # enabled_log {
  #   category = "ApplicationGatewayPerformanceLog" 
  # }

  enabled_metric {
    category = "AllMetrics" # 모든 메트릭 데이터
  }
}
