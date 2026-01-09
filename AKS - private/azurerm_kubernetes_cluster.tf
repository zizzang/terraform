# AKS(Azure Kubernetes Service) 클러스터를 위한 사용자 할당 관리 ID
resource "azurerm_user_assigned_identity" "aks" {
  for_each = {
    aks_blue = var.subnet_aks_blue
    aks_green = var.subnet_aks_green
  }
  location            = azurerm_resource_group.aks.location
  name                = upper("${module.naming.user_assigned_identity.name}-AKS-${replace(each.key, "aks_", "")}")
  resource_group_name = azurerm_resource_group.aks.name
}

# 사용자 할당 관리 ID에 Private DNS Zone 권한 부여
resource "azurerm_role_assignment" "aks_private_dns" {
  for_each = {
    aks_blue = var.subnet_aks_blue
    aks_green = var.subnet_aks_green
  }
  scope                = azurerm_private_dns_zone.aks.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks[each.key].principal_id
}

# AKS 클러스터 리소스 
resource "azurerm_kubernetes_cluster" "aks" {
  for_each = {
    aks_blue = var.subnet_aks_blue
    aks_green = var.subnet_aks_green
  }

  name                = upper("${module.naming.kubernetes_cluster.name}-${replace(each.key, "aks_", "")}")
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  node_resource_group = upper("${module.naming.kubernetes_cluster.name}-${replace(each.key, "aks_", "")}-RG-Managed")

  private_cluster_enabled    = true # 프라이빗 클러스터 활성화
  dns_prefix_private_cluster = "${module.naming.kubernetes_cluster.name}-${replace(each.key, "aks_", "")}"
  private_dns_zone_id        = azurerm_private_dns_zone.aks.id

  default_node_pool { # 기본 노드풀 설정
    name                         = var.aks.default_node_pool.name
    node_count                   = var.aks.default_node_pool.node_count
    vm_size                      = var.aks.default_node_pool.vm_size
    vnet_subnet_id               = local.subnet_service_map[each.key].id
    only_critical_addons_enabled = true
    temporary_name_for_rotation  = "temp"
    host_encryption_enabled      = true
    auto_scaling_enabled         = true
    min_count                    = 2
    max_count                    = 5

    upgrade_settings { # 업그레이드 설정
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  monitor_metrics {
    annotations_allowed = null
    labels_allowed      = null
  }

  oms_agent { # Azure Monitor 설정
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.log.id
    msi_auth_for_monitoring_enabled = true
  }

  identity { # 클러스터의 관리 ID 설정 (사용자 할당)
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks[each.key].id]
  }

  network_profile {
    network_plugin      = var.aks.network_profile.network_plugin
    network_data_plane  = var.aks.network_profile.network_data_plane
    network_plugin_mode = var.aks.network_profile.network_plugin_mode
    outbound_type       = "userAssignedNATGateway"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true # Key Vault 비밀 회전 활성화
    # secret_rotation_interval = "2m" 
  }

  sku_tier                  = var.aks.sku_tier
  azure_policy_enabled      = true # Azure Policy 활성화
  oidc_issuer_enabled       = true # OIDC 발급자 활성화
  workload_identity_enabled = true # 워크로드 ID 활성화

  depends_on = [
    azurerm_nat_gateway.aks_nat,
    azurerm_subnet_nat_gateway_association.aks_nat,
    azurerm_role_assignment.aks_private_dns,
  ]
}

# AKS 클러스터의 추가 노드풀 설정
resource "azurerm_kubernetes_cluster_node_pool" "aks" {
  for_each = {
    aks_blue = var.subnet_aks_blue
    aks_green = var.subnet_aks_green
  }
  name                  = var.aks.node_pool.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks[each.key].id
  vm_size               = var.aks.node_pool.vm_size

  temporary_name_for_rotation = "temp"
  host_encryption_enabled     = true # 호스트 암호화 활성화
  auto_scaling_enabled        = true
  min_count                   = var.aks.node_pool.min_count
  max_count                   = var.aks.node_pool.max_count
  vnet_subnet_id              = local.subnet_service_map[each.key].id
}

# AKS 클러스터의 노드 서브넷에 대한 역할 할당
resource "azurerm_role_assignment" "aks_vm_nodepool" {
  for_each = {
    aks_blue = var.subnet_aks_blue
    aks_green = var.subnet_aks_green
  }
  scope                = local.subnet_service_map[each.key].id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks[each.key].principal_id
}

# AKS 클러스터 노드풀의 VMSS를 조회하기 위한 데이터 소스 정의
data "azurerm_resources" "aks_node_pools" {
  depends_on = [
    azurerm_kubernetes_cluster.aks,
    azurerm_kubernetes_cluster_node_pool.aks
  ]

  for_each = { # 각 노드풀 서브넷에 대해 반복 수행
    aks_blue = var.subnet_aks_blue,
    aks_green = var.subnet_aks_green
  }
  resource_group_name = azurerm_kubernetes_cluster.aks[each.key].node_resource_group # 노드 리소스 그룹 이름 지정
  type                = "Microsoft.Compute/virtualMachineScaleSets"                  # VMSS 리소스 타입
}

# 로컬 변수 정의 (VMSS 이름 확인)
locals {
  workload_vmss = {
    for key, value in data.azurerm_resources.aks_node_pools : key => [
      for resource in value.resources :
      resource.name
      if can(regex("workload", resource.name))
    ]
  }
}

# 워크로드 VMSS를 조회하기 위한 데이터 소스 정의 
data "azurerm_virtual_machine_scale_set" "aks_workload_node_pools" {
  for_each = {
    aks_blue = { agw_key = "agw_blue", subnet = var.subnet_aks_blue }
    aks_green = { agw_key = "agw_green", subnet = var.subnet_aks_green }
  }
  name                = local.workload_vmss[each.key][0]                             # 워크로드 VMSS 이름 
  resource_group_name = azurerm_kubernetes_cluster.aks[each.key].node_resource_group # VMSS가 속한 리소스 그룹 이름 
}

# Application Gateway 백엔드에 VMSS 노드 풀 연결
resource "azapi_resource_action" "add_backend_pool_to_vmss_nic" {
  for_each = {
    aks_blue = { agw_key = "agw_blue", subnet = var.subnet_aks_blue }
    aks_green = { agw_key = "agw_green", subnet = var.subnet_aks_green }
  }
  type        = "Microsoft.Compute/virtualMachineScaleSets@2023-03-01"
  resource_id = data.azurerm_virtual_machine_scale_set.aks_workload_node_pools[each.key].id
  method      = "PATCH"

  body = {
    properties = {
      virtualMachineProfile = {
        networkProfile = {
          networkInterfaceConfigurations = [
            {
              name = data.azurerm_virtual_machine_scale_set.aks_workload_node_pools[each.key].name
              properties = {
                primary = true
                ipConfigurations = [
                  {
                    name = data.azurerm_virtual_machine_scale_set.aks_workload_node_pools[each.key].network_interface[0].ip_configuration[0].name
                    properties = {
                      primary = true
                      subnet = {
                        id = local.subnet_service_map[each.key].id
                      }
                      applicationGatewayBackendAddressPools = [
                        {
                          id = [
                            for pool in azurerm_application_gateway.agw[each.value.agw_key].backend_address_pool :
                            pool.id
                          ][0]
                        }
                      ]
                    }
                  }
                ]
              }
            }
          ]
        }
      }
    }
  }

  response_export_values = []
}

# VMSS 인스턴스 업그레이드
resource "azapi_resource_action" "vmss_manual_upgrade" {
  for_each = {
    aks_blue = { agw_key = "agw_blue", subnet = var.subnet_aks_blue }
    aks_green = { agw_key = "agw_green", subnet = var.subnet_aks_green }
  }

  type        = "Microsoft.Compute/virtualMachineScaleSets@2023-03-01"
  resource_id = data.azurerm_virtual_machine_scale_set.aks_workload_node_pools[each.key].id
  action      = "manualUpgrade"
  method      = "POST"

  body = {
    instanceIds = ["*"]
  }

  depends_on = [
    azapi_resource_action.add_backend_pool_to_vmss_nic
  ]

  response_export_values = []
}

# AKS 클러스터를 위한 Private DNS Zone 정의 
resource "azurerm_private_dns_zone" "aks" {
  name                = "privatelink.${azurerm_resource_group.network.location}.azmk8s.io" # DNS Zone 이름 
  resource_group_name = azurerm_resource_group.network.name                                # DNS Zone이 속할 리소스 그룹

  lifecycle {
    ignore_changes = [tags] # 태그 변경 무시 
  }
}

# Private DNS Zone과 가상 네트워크 링크 생성 
resource "azurerm_private_dns_zone_virtual_network_link" "aks" {
  name                  = lower("${azurerm_virtual_network.service.name}-link")  # 링크 이름 지정 
  resource_group_name   = azurerm_private_dns_zone.aks.resource_group_name       # 리소스 그룹 이름 
  private_dns_zone_name = azurerm_private_dns_zone.aks.name                      # Private DNS Zone 이름 
  virtual_network_id    = azurerm_virtual_network.service.id                     # 연결할 가상 네트워크 ID 

  lifecycle {
    ignore_changes = [tags] # 태그 변경 무시 
  }

  depends_on = [
  azurerm_private_dns_zone.aks
  ]
}

# Private DNS Zone과 가상 네트워크 링크 생성 
resource "azurerm_private_dns_zone_virtual_network_link" "aks_bastion" {
  name                  = lower("${azurerm_virtual_network.bastion.name}-link")  # 링크 이름 지정 
  resource_group_name   = azurerm_private_dns_zone.aks.resource_group_name       # 리소스 그룹 이름 
  private_dns_zone_name = azurerm_private_dns_zone.aks.name                      # Private DNS Zone 이름 
  virtual_network_id    = azurerm_virtual_network.bastion.id                     # 연결할 가상 네트워크 ID 

  lifecycle {
    ignore_changes = [tags] # 태그 변경 무시 
  }

  depends_on = [
  azurerm_private_dns_zone.aks
  ]
}

# AKS 클러스터에 대한 모니터링 진단 설정
resource "azurerm_monitor_diagnostic_setting" "aks" {
  for_each                   = azurerm_kubernetes_cluster.aks                                 # 모든 AKS 클러스터에 대해 반복 수행
  name                       = lower("diag-${azurerm_kubernetes_cluster.aks[each.key].name}") # 진단 설정 이름
  target_resource_id         = azurerm_kubernetes_cluster.aks[each.key].id                    # 대상 리소스 ID (AKS 클러스터)
  storage_account_id         = azurerm_storage_account.log_storage.id                         # 스토리지 계정 ID
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id                         # Log Analytics 작업 영역 ID

  // Microsoft.ContainerService/managedClusters에 대해 지원되는 리소스 로그
  // https://learn.microsoft.com/ko-kr/azure/aks/monitor-aks-reference#supported-resource-logs-for-microsoftcontainerservicemanagedclusters

  enabled_log {
    category = "cloud-controller-manager" # 클라우드 컨트롤러 관리자 로그 활성화
  }

  enabled_log {
    category = "cluster-autoscaler" # 클러스터 자동 확장 로그 활성화
  }

  enabled_log {
    category = "csi-azuredisk-controller" # Azure Disk CSI 컨트롤러 로그 활성화
  }

  enabled_log {
    category = "csi-azurefile-controller" # Azure File CSI 컨트롤러 로그 활성화
  }

  enabled_log {
    category = "csi-snapshot-controller" # CSI 스냅샷 컨트롤러 로그 활성화
  }

  enabled_log {
    category = "guard" # Guard 로그 활성화
  }

  enabled_log {
    category = "kube-apiserver" # Kubernetes API 서버 로그 활성화
  }

  enabled_log {
    category = "kube-audit" # Kubernetes 감사 로그 활성화
  }

  enabled_log {
    category = "kube-audit-admin" # Kubernetes 관리자 감사 로그 활성화
  }

  enabled_log {
    category = "kube-controller-manager" # Kubernetes 컨트롤러 관리자 로그 활성화
  }

  enabled_log {
    category = "kube-scheduler" # Kubernetes 스케줄러 로그 활성화
  }

  enabled_log {
    category = "fleet-member-agent" # Fleet 멤버 에이전트 로그 활성화
  }

  enabled_metric {
    category = "AllMetrics" # 모든 메트릭 카테고리 비활성화 (enabled=false)
  }

  depends_on = [
  azurerm_kubernetes_cluster.aks,
  azurerm_storage_account.log_storage,
  azurerm_log_analytics_workspace.log  
  ]
}

# AKS Container Insights 설정
resource "azurerm_monitor_data_collection_rule" "aks_container_insights" {
  for_each            = azurerm_kubernetes_cluster.aks
  name                = upper("DCR-insight-${azurerm_kubernetes_cluster.aks[each.key].name}")
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.log.id
      name                  = azurerm_log_analytics_workspace.log.name
    }
  }

  data_flow {
    streams      = ["Microsoft-ContainerLog", "Microsoft-ContainerLogV2", "Microsoft-KubeEvents", "Microsoft-KubePodInventory", "Microsoft-KubeNodeInventory", "Microsoft-KubePVInventory", "Microsoft-KubeServices", "Microsoft-KubeMonAgentEvents", "Microsoft-InsightsMetrics", "Microsoft-ContainerInventory", "Microsoft-ContainerNodeInventory", "Microsoft-Perf"] # 데이터 스트림
    destinations = ["${azurerm_log_analytics_workspace.log.name}"]                                                                                                                                                                                                                                                                                                       # 데이터 목적지
  }

  data_flow {
    streams      = ["Microsoft-Syslog"]
    destinations = ["${azurerm_log_analytics_workspace.log.name}"]
  }

  data_sources {
    syslog {
      streams        = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "cron", "daemon", "mark", "kern", "local0", "local1", "local2", "local3", "local4", "local5", "local6", "local7", "lpr", "mail", "news", "syslog", "user", "uucp"]
      log_levels     = ["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
      name           = "sysLogsDataSource"
    }

    extension {
      streams        = ["Microsoft-ContainerLog", "Microsoft-ContainerLogV2", "Microsoft-KubeEvents", "Microsoft-KubePodInventory", "Microsoft-KubeNodeInventory", "Microsoft-KubePVInventory", "Microsoft-KubeServices", "Microsoft-KubeMonAgentEvents", "Microsoft-InsightsMetrics", "Microsoft-ContainerInventory", "Microsoft-ContainerNodeInventory", "Microsoft-Perf"] # 데이터 스트림
      extension_name = "ContainerInsights"                                                                                                                                                                                                                                                                                                                                   # 확장 이름
      extension_json = jsonencode({
        "dataCollectionSettings" : {
          "interval" : "1m",
          "namespaceFilteringMode" : "Off",
          "namespaces" : ["kube-system", "gatekeeper-system", "azure-arc"],
          "enableContainerLogV2" : true
        }
      })
      name = "ContainerInsightsExtension"
    }
  }

  description = "DCR for Azure Monitor Container Insights"
}

# AKS Container Insights 데이터 수집 규칙 연결
resource "azurerm_monitor_data_collection_rule_association" "aks_container_insights" {
  for_each                = azurerm_kubernetes_cluster.aks
  name                    = "ContainerInsightsExtension"
  target_resource_id      = azurerm_kubernetes_cluster.aks[each.key].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks_container_insights[each.key].id
  description             = "Association of container insights data collection rule. Deleting this association will break the data collection for this AKS Cluster."
}

# 각 AKS 클러스터의 NSG 조회
data "azurerm_resources" "nsgs" {
  for_each = azurerm_kubernetes_cluster.aks

  type                = "Microsoft.Network/networkSecurityGroups"
  resource_group_name = each.value.node_resource_group
}

# 클러스터 키 -> NSG 이름 리스트 매핑
locals {
  aks_nsgs_map = {
    for cluster_key, data_instance in data.azurerm_resources.nsgs :
    cluster_key => [
      for nsg in data_instance.resources : nsg.name
    ]
  }
}

# NSG에 모든 인바운드 트래픽을 거부하는 규칙 정의
resource "azurerm_network_security_rule" "aks_nsg_inbound_deny_all" {
  for_each = {
    for k, v in local.aks_nsgs_map : k => v[0]
  }

  name                        = "Inbound_Deny_All" # 규칙 이름
  priority                    = 4096              # 우선순위(낮을수록 우선 적용됨)
  direction                   = "Inbound"         # 인바운드 트래픽에 적용
  access                      = "Deny"            # 접근 거부
  protocol                    = "*"               # 모든 프로토콜 적용
  source_port_range           = "*"               # 모든 소스 포트에서
  destination_port_range      = "*"               # 모든 목적지 포트로
  source_address_prefix       = "*"               # 모든 소스 IP에서
  destination_address_prefix  = "*"               # 모든 목적지 IP로
  resource_group_name         = azurerm_kubernetes_cluster.aks[each.key].node_resource_group # 리소스 그룹 이름 지정
  network_security_group_name = each.value        # 대상 NSG 이름 지정
  description                 = "외부 인터넷 접근 금지" # 설명

  depends_on = [
    azurerm_kubernetes_cluster.aks # aks 리소스 이후에 생성
  ]
}

# 서비스 서브넷별(VNet) 내부 통신 허용 규칙 정의
resource "azurerm_network_security_rule" "aks_nsg_vNet_inbound" {
  for_each = { for k, v in local.aks_nsgs_map : k => v[0] }
  name                        = "Inbound_Allow_Virtual_Network" # 규칙 이름
  priority                    = 4094 # 우선순위
  direction                   = "Inbound" # 인바운드 트래픽
  access                      = "Allow" # 허용
  protocol                    = "*" # 모든 프로토콜
  source_port_range           = "*" # 모든 소스 포트
  destination_port_range      = "*" # 모든 목적지 포트
  source_address_prefix       = "VirtualNetwork" # 소스는 동일 가상 네트워크
  destination_address_prefix  = "VirtualNetwork" # 목적지도 동일 가상 네트워크
  resource_group_name         = azurerm_kubernetes_cluster.aks[each.key].node_resource_group # 리소스 그룹 이름 지정
  network_security_group_name = each.value # 대상 NSG 이름 지정

  depends_on = [
    azurerm_kubernetes_cluster.aks # aks 리소스 이후에 생성
  ]
}

# 서비스 서브넷별 로드밸런서에서 오는 트래픽 허용 규칙 정의
resource "azurerm_network_security_rule" "aks_nsg_vNet_LB_inbound" {
  for_each = { for k, v in local.aks_nsgs_map : k => v[0] }
  name                        = "Inbound_Allow_LoadBalancer" # 규칙 이름
  priority                    = 4095 # 우선순위
  direction                   = "Inbound" # 인바운드 트래픽
  access                      = "Allow" # 허용
  protocol                    = "*" # 모든 프로토콜
  source_port_range           = "*" # 모든 소스 포트
  destination_port_range      = "*" # 모든 목적지 포트
  source_address_prefix       = "AzureLoadBalancer" # 소스는 Azure 로드밸런서
  destination_address_prefix  = "*" # 모든 목적지 IP
  resource_group_name         = azurerm_kubernetes_cluster.aks[each.key].node_resource_group # 리소스 그룹 이름 지정
  network_security_group_name = each.value # 대상 NSG 이름 지정

  depends_on = [
    azurerm_kubernetes_cluster.aks # aks 리소스 이후에 생성
  ]
}