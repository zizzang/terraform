# # Virtual WAN 리소스
# resource "azurerm_virtual_wan" "vwan" {
#   name                = upper("${module.naming.virtual_wan.name}")   
#   location            = azurerm_resource_group.network.location 
#   resource_group_name = azurerm_resource_group.network.name     

#   tags                = var.tags
# }

# # Virtual Hub 리소스
# resource "azurerm_virtual_hub" "vhub" {
#   name                = upper("${module.naming.virtual_wan.name}-hub") 
#   location            = azurerm_resource_group.network.location   
#   resource_group_name = azurerm_resource_group.network.name       
#   virtual_wan_id      = azurerm_virtual_wan.vwan.id               
#   address_prefix      = var.vhub.address_prefix                   

# tags = var.tags
# }

# # Virtual Hub 연결
# resource "azurerm_virtual_hub_connection" "service" {
#   for_each = {
#     service = azurerm_virtual_network.service // Service VNET
#     bastion     = azurerm_virtual_network.bastion     // Bastion VNET
#   }
#   name                      = upper("conn-to-${each.value.name}") 
#   virtual_hub_id            = azurerm_virtual_hub.vhub.id         
#   remote_virtual_network_id = each.value.id                       
# }

# # DDOS Protection Plan, Subscription 당 1개만 생성 가능
# resource "azurerm_network_ddos_protection_plan" "service" {
#   name                = upper("${module.naming.network_ddos_protection_plan.name}")
#   location            = azurerm_resource_group.network.location
#   resource_group_name = azurerm_resource_group.network.name

#   tags = var.tags
# }

locals {
  vnets = {
    service = var.vnet_service // Service VNET 설정
    bastion     = var.vnet_bastion     // Bastion VNET 설정
  }
}

# Service Virtual Network (서비스 리소스 배포)
resource "azurerm_virtual_network" "service" {
  name                = upper("${module.naming.virtual_network.name}-${var.vnet_service.naming}") // VNET 이름
  location            = azurerm_resource_group.network.location                                   // 리소스 위치
  resource_group_name = azurerm_resource_group.network.name                                       // 리소스 그룹 이름
  address_space       = var.vnet_service.address_space                                            // VNET 주소 공간

  # ddos_protection_plan {
  #   enable = true
  #   id     = azurerm_network_ddos_protection_plan.service.id // DDOS 보호 계획 ID
  # }

  tags = var.tags
}

# Bastion Virtual Network
resource "azurerm_virtual_network" "bastion" {
  name                = upper("${module.naming.virtual_network.name}-${var.vnet_bastion.naming}") // VNET 이름
  location            = azurerm_resource_group.network.location                               // 리소스 위치
  resource_group_name = azurerm_resource_group.network.name                                   // 리소스 그룹 이름
  address_space       = var.vnet_bastion.address_space                                            // VNET 주소 공간

  # ddos_protection_plan {
  #   enable = true
  #   id     = azurerm_network_ddos_protection_plan.service.id // DDOS 보호 계획 ID
  # }

  tags = var.tags
}

locals {
  service_subnets = {
    alb_blue    = var.subnet_alb_blue    // Application Gateway for Container Blue 서브넷
    alb_green   = var.subnet_alb_green   // Application Gateway for Container Green 서브넷
    aks_blue    = var.subnet_aks_blue    // AKS Blue 노드 서브넷
    aks_green   = var.subnet_aks_green   // AKS Green 노드 서브넷
    mysql       = var.subnet_mysql       // MySQL 서브넷
    pe          = var.subnet_pe          // Private Endpoint 서브넷
  }
  bastion_subnets = {
    bastion = var.subnet_bastion // Bastion 서브넷
  }
}

# VNet 피어링 - Service VNET에서 Bastion VNET으로
resource "azurerm_virtual_network_peering" "service_to_bastion" {
  name                      = "peer-service-to-bastion"
  resource_group_name       = azurerm_resource_group.network.name
  virtual_network_name      = azurerm_virtual_network.service.name
  remote_virtual_network_id = azurerm_virtual_network.bastion.id
 
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
 
# VNet 피어링 - Bastion VNET에서 Service VNET으로
resource "azurerm_virtual_network_peering" "bastion_to_service" {
  name                      = "peer-bastion-to-service"
  resource_group_name       = azurerm_resource_group.network.name
  virtual_network_name      = azurerm_virtual_network.bastion.name
  remote_virtual_network_id = azurerm_virtual_network.service.id
 
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_network_security_group" "service" {
  for_each            = local.service_subnets
  name                = upper("NSG-${module.naming.subnet.name}-${each.value.naming}")
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  tags = var.tags
}

resource "azurerm_network_security_group" "bastion" {
  name                = upper("NSG-${module.naming.subnet.name}-${var.subnet_bastion.naming}")
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  tags = var.tags
}

# Subnet 1: alb_blue
resource "azapi_resource" "subnet_service_alb_blue" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-03-01"
  name      = upper(format("%s-%s", module.naming.subnet.name, local.service_subnets["alb_blue"].naming))
  parent_id = azurerm_virtual_network.service.id

  body = {
    properties = {
      addressPrefix = local.service_subnets["alb_blue"].address_prefixes[0]
      networkSecurityGroup = {
        id = azurerm_network_security_group.service["alb_blue"].id
      }
      delegations = [{
        name = "alb-delegation"
        properties = {
          serviceName = "Microsoft.ServiceNetworking/trafficControllers"
        }
      }]
      privateEndpointNetworkPolicies = "Enabled"
    }
  }

  depends_on = [
    azurerm_network_security_group.service
  ]
}

# Subnet 2: alb_green
resource "azapi_resource" "subnet_service_alb_green" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-03-01"
  name      = upper(format("%s-%s", module.naming.subnet.name, local.service_subnets["alb_green"].naming))
  parent_id = azurerm_virtual_network.service.id

  body = {
    properties = {
      addressPrefix = local.service_subnets["alb_green"].address_prefixes[0]
      networkSecurityGroup = {
        id = azurerm_network_security_group.service["alb_green"].id
      }
      delegations = [{
        name = "alb-delegation"
        properties = {
          serviceName = "Microsoft.ServiceNetworking/trafficControllers"
        }
      }]
      privateEndpointNetworkPolicies = "Enabled"
    }
  }

  depends_on = [
    azurerm_network_security_group.service,
    azapi_resource.subnet_service_alb_blue
  ]
}

# Subnet 3: aks_blue
resource "azapi_resource" "subnet_service_aks_blue" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-03-01"
  name      = upper(format("%s-%s", module.naming.subnet.name, local.service_subnets["aks_blue"].naming))
  parent_id = azurerm_virtual_network.service.id

  body = {
    properties = {
      addressPrefix = local.service_subnets["aks_blue"].address_prefixes[0]
      networkSecurityGroup = {
        id = azurerm_network_security_group.service["aks_blue"].id
      }
      privateEndpointNetworkPolicies = "Enabled"
    }
  }

  depends_on = [
    azurerm_network_security_group.service,
    azapi_resource.subnet_service_alb_green
  ]
}

# Subnet 4: aks_green
resource "azapi_resource" "subnet_service_aks_green" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-03-01"
  name      = upper(format("%s-%s", module.naming.subnet.name, local.service_subnets["aks_green"].naming))
  parent_id = azurerm_virtual_network.service.id

  body = {
    properties = {
      addressPrefix = local.service_subnets["aks_green"].address_prefixes[0]
      networkSecurityGroup = {
        id = azurerm_network_security_group.service["aks_green"].id
      }
      privateEndpointNetworkPolicies = "Enabled"
    }
  }

  depends_on = [
    azurerm_network_security_group.service,
    azapi_resource.subnet_service_aks_blue
  ]
}

# Subnet 5: mysql
resource "azapi_resource" "subnet_service_mysql" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-03-01"
  name      = upper(format("%s-%s", module.naming.subnet.name, local.service_subnets["mysql"].naming))
  parent_id = azurerm_virtual_network.service.id

  body = {
    properties = {
      addressPrefix = local.service_subnets["mysql"].address_prefixes[0]
      networkSecurityGroup = {
        id = azurerm_network_security_group.service["mysql"].id
      }
      delegations = [{
        name = "mysql-delegation"
        properties = {
          serviceName = "Microsoft.DBforMySQL/flexibleServers"
        }
      }]
      privateEndpointNetworkPolicies = "Enabled"
    }
  }

  depends_on = [
    azurerm_network_security_group.service,
    azapi_resource.subnet_service_aks_green
  ]
}

# Subnet 6: pe
resource "azapi_resource" "subnet_service_pe" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-03-01"
  name      = upper(format("%s-%s", module.naming.subnet.name, local.service_subnets["pe"].naming))
  parent_id = azurerm_virtual_network.service.id

  body = {
    properties = {
      addressPrefix = local.service_subnets["pe"].address_prefixes[0]
      networkSecurityGroup = {
        id = azurerm_network_security_group.service["pe"].id
      }
      privateEndpointNetworkPolicies = "Enabled"
    }
  }

  depends_on = [
    azurerm_network_security_group.service,
    azapi_resource.subnet_service_mysql
  ]
}

resource "azapi_resource" "subnet_bastion" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-03-01"
  name      = upper(format("%s-%s", module.naming.subnet.name, var.subnet_bastion.naming)) # ← 자식 리소스 이름만
  parent_id = azurerm_virtual_network.bastion.id

  body = {
    properties = {
      addressPrefix = var.subnet_bastion.address_prefixes[0]
      networkSecurityGroup = {
        id = azurerm_network_security_group.bastion.id
      }
    }
  }

  depends_on = [
    azurerm_network_security_group.bastion,
    azapi_resource.subnet_service_mysql
  ]
}

locals {
  subnet_service_map = {
    alb_blue   = azapi_resource.subnet_service_alb_blue
    alb_green  = azapi_resource.subnet_service_alb_green
    aks_blue   = azapi_resource.subnet_service_aks_blue
    aks_green  = azapi_resource.subnet_service_aks_green
    mysql      = azapi_resource.subnet_service_mysql
    pe         = azapi_resource.subnet_service_pe
  }
}

# Network Watcher 리소스 데이터 소스
data "azurerm_network_watcher" "service" {
  name                = "NetworkWatcher_${azurerm_virtual_network.service.location}"
  resource_group_name = "NetworkWatcherRG"

  depends_on = [
    azapi_resource.subnet_bastion,
  ]
}

# Service VNET Flow Log 리소스
resource "azurerm_network_watcher_flow_log" "service" {
  network_watcher_name = data.azurerm_network_watcher.service.name
  resource_group_name  = "NetworkWatcherRG"
  name                 = "flow-${azurerm_virtual_network.service.name}"

  target_resource_id = azurerm_virtual_network.service.id
  storage_account_id = azurerm_storage_account.log_storage.id // 로그 저장스토리지 계정 ID
  enabled            = true

  retention_policy {
    enabled = true # 보존 정책 활성화
    days    = 365  # 보존 기간 (일)
  }

  traffic_analytics {
    enabled               = true                                             # 트래픽 분석 활성화
    workspace_id          = azurerm_log_analytics_workspace.log.workspace_id # Log Analytics Workspace 
    workspace_region      = azurerm_log_analytics_workspace.log.location
    workspace_resource_id = azurerm_log_analytics_workspace.log.id
  }
}

# Bastion VNET Flow Log 리소스
resource "azurerm_network_watcher_flow_log" "bastion" {
  network_watcher_name = data.azurerm_network_watcher.service.name
  resource_group_name  = "NetworkWatcherRG"
  name                 = "flow-${azurerm_virtual_network.bastion.name}"

  target_resource_id = azurerm_virtual_network.bastion.id
  storage_account_id = azurerm_storage_account.log_storage.id # 로그 저장스토리지 계정 ID
  enabled            = true

  retention_policy {
    enabled = true # 보존 정책 활성화
    days    = 365  # 보존 기간 (일)
  }

  traffic_analytics {
    enabled               = true                                             # 트래픽 분석 활성화
    workspace_id          = azurerm_log_analytics_workspace.log.workspace_id # Log Analytics Workspace
    workspace_region      = azurerm_log_analytics_workspace.log.location
    workspace_resource_id = azurerm_log_analytics_workspace.log.id
  }
}

# Service Subnet Flow Log 리소스 정의
resource "azurerm_network_watcher_flow_log" "subnet_service" {
  for_each             = local.subnet_service_map
  network_watcher_name = data.azurerm_network_watcher.service.name
  resource_group_name  = "NetworkWatcherRG"
  name                 = "flow-${each.value.name}"

  target_resource_id = each.value.id
  storage_account_id = azurerm_storage_account.log_storage.id # 로그 저장스토리지 계정 ID
  enabled            = true

  retention_policy {
    enabled = true # 보존 정책 활성화
    days    = 365  #  보존 기간 (일)
  }

  traffic_analytics {
    enabled               = true                                             # 트래픽 분석 활성화
    workspace_id          = azurerm_log_analytics_workspace.log.workspace_id # Log Analytics Workspace
    workspace_region      = azurerm_log_analytics_workspace.log.location
    workspace_resource_id = azurerm_log_analytics_workspace.log.id
  }

  depends_on = [
    azurerm_virtual_network.service,
    azurerm_virtual_network.bastion,
    azapi_resource.subnet_bastion,
    azurerm_storage_account.log_storage,
    azurerm_log_analytics_workspace.log
  ]
}

