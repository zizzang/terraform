# resource "azurerm_virtual_wan" "vwan" {
#   name                = upper("${module.naming.virtual_wan.name}")   
#   location            = azurerm_resource_group.network.location 
#   resource_group_name = azurerm_resource_group.network.name     

#   tags                = var.tags
# }

# resource "azurerm_virtual_hub" "vhub" {
#   name                = upper("${module.naming.virtual_wan.name}-hub") 
#   location            = azurerm_resource_group.network.location   
#   resource_group_name = azurerm_resource_group.network.name       
#   virtual_wan_id      = azurerm_virtual_wan.vwan.id               
#   address_prefix      = var.vhub.address_prefix           

# tags = var.tags
# }

# resource "azurerm_virtual_hub_connection" "service" {
#   for_each = {
#     service = azurerm_virtual_network.service
#     bastion     = azurerm_virtual_network.bastion     
#   }
#   name                      = upper("conn-to-${each.value.name}") 
#   virtual_hub_id            = azurerm_virtual_hub.vhub.id         
#   remote_virtual_network_id = each.value.id                       
# }

# resource "azurerm_network_ddos_protection_plan" "service" {
#   name                = upper("${module.naming.network_ddos_protection_plan.name}")
#   location            = azurerm_resource_group.network.location
#   resource_group_name = azurerm_resource_group.network.name

#   tags = var.tags
# }

locals {
  vnets = {
    service = var.vnet_service 
    bastion     = var.vnet_bastion 
  }
}

resource "azurerm_virtual_network" "service" {
  name                = upper("${module.naming.virtual_network.name}-${var.vnet_service.naming}") 
  location            = azurerm_resource_group.network.location                                   
  resource_group_name = azurerm_resource_group.network.name                                       
  address_space       = var.vnet_service.address_space                                            

  # ddos_protection_plan {
  #   enable = true
  #   id     = azurerm_network_ddos_protection_plan.service.id // DDOS 보호 계획 ID
  # }

  tags = var.tags
}

# Bastion Virtual Network
resource "azurerm_virtual_network" "bastion" {
  name                = upper("${module.naming.virtual_network.name}-${var.vnet_bastion.naming}") 
  location            = azurerm_resource_group.network.location                               
  resource_group_name = azurerm_resource_group.network.name                                   
  address_space       = var.vnet_bastion.address_space                                            

  # ddos_protection_plan {
  #   enable = true
  #   id     = azurerm_network_ddos_protection_plan.service.id // DDOS 보호 계획 ID
  # }

  tags = var.tags
}

locals {
  service_subnets = {
    agw_blue = var.subnet_agw_blue 
    agw_green = var.subnet_agw_green 
    aca_blue = var.subnet_aca_blue 
    aca_green = var.subnet_aca_green 
    mysql  = var.subnet_mysql  
    pe     = var.subnet_pe     
  }
  bastion_subnets = {
    bastion = var.subnet_bastion
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

  depends_on = [
    azurerm_virtual_network.service,
    azurerm_virtual_network.bastion,
    azapi_resource.subnet_bastion,
  ]
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

  depends_on = [
    azurerm_virtual_network.service,
    azurerm_virtual_network.bastion,
    azapi_resource.subnet_bastion,
  ]
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

# Subnet 1: agw_blue
resource "azapi_resource" "subnet_service_agw_blue" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-03-01"
  name      = upper(format("%s-%s", module.naming.subnet.name, local.service_subnets["agw_blue"].naming))
  parent_id = azurerm_virtual_network.service.id

  body = {
    properties = {
      addressPrefix = local.service_subnets["agw_blue"].address_prefixes[0]
      networkSecurityGroup = {
        id = azurerm_network_security_group.service["agw_blue"].id
      }
      delegations = [{
        name = "agw-delegation"
        properties = {
          serviceName = "Microsoft.Network/applicationGateways"
        }
      }]
      privateEndpointNetworkPolicies = "Enabled"
    }
  }

  depends_on = [
    azurerm_network_security_group.service
  ]
}

# Subnet 2: agw_green
resource "azapi_resource" "subnet_service_agw_green" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-03-01"
  name      = upper(format("%s-%s", module.naming.subnet.name, local.service_subnets["agw_green"].naming))
  parent_id = azurerm_virtual_network.service.id

  body = {
    properties = {
      addressPrefix = local.service_subnets["agw_green"].address_prefixes[0]
      networkSecurityGroup = {
        id = azurerm_network_security_group.service["agw_green"].id
      }
      delegations = [{
        name = "agw-delegation"
        properties = {
          serviceName = "Microsoft.Network/applicationGateways"
        }
      }]
      privateEndpointNetworkPolicies = "Enabled"
    }
  }

  depends_on = [
    azurerm_network_security_group.service,
    azapi_resource.subnet_service_agw_blue
  ]
}

# Subnet 3: aca_blue
resource "azapi_resource" "subnet_service_aca_blue" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-03-01"
  name      = upper(format("%s-%s", module.naming.subnet.name, local.service_subnets["aca_blue"].naming))
  parent_id = azurerm_virtual_network.service.id

  body = {
    properties = {
      addressPrefix = local.service_subnets["aca_blue"].address_prefixes[0]
      networkSecurityGroup = {
        id = azurerm_network_security_group.service["aca_blue"].id
      }
      delegations = [{
        name = "aca-delegation"
        properties = {
          serviceName = "Microsoft.App/environments"
        }
      }]
      privateEndpointNetworkPolicies = "Enabled"
    }
  }

  depends_on = [
    azurerm_network_security_group.service,
    azapi_resource.subnet_service_agw_green
  ]
}

# Subnet 4: aca_green
resource "azapi_resource" "subnet_service_aca_green" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-03-01"
  name      = upper(format("%s-%s", module.naming.subnet.name, local.service_subnets["aca_green"].naming))
  parent_id = azurerm_virtual_network.service.id

  body = {
    properties = {
      addressPrefix = local.service_subnets["aca_green"].address_prefixes[0]
      networkSecurityGroup = {
        id = azurerm_network_security_group.service["aca_green"].id
      }
      delegations = [{
        name = "aca-delegation"
        properties = {
          serviceName = "Microsoft.App/environments"
        }
      }]
      privateEndpointNetworkPolicies = "Enabled"
    }
  }

  depends_on = [
    azurerm_network_security_group.service,
    azapi_resource.subnet_service_aca_blue
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
    azapi_resource.subnet_service_aca_green
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
  name      = upper(format("%s-%s", module.naming.subnet.name, var.subnet_bastion.naming)) 
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
    agw_blue   = azapi_resource.subnet_service_agw_blue
    agw_green  = azapi_resource.subnet_service_agw_green
    aca_blue   = azapi_resource.subnet_service_aca_blue
    aca_green  = azapi_resource.subnet_service_aca_green
    mysql      = azapi_resource.subnet_service_mysql
    pe         = azapi_resource.subnet_service_pe
  }
}

data "azurerm_network_watcher" "service" {
  name                = "NetworkWatcher_${azurerm_virtual_network.service.location}"
  resource_group_name = "NetworkWatcherRG"

  depends_on = [
    azapi_resource.subnet_bastion
  ]
}

resource "azurerm_network_watcher_flow_log" "service" {
  network_watcher_name = data.azurerm_network_watcher.service.name
  resource_group_name  = "NetworkWatcherRG"
  name                 = "flow-${azurerm_virtual_network.service.name}"

  target_resource_id = azurerm_virtual_network.service.id
  storage_account_id = azurerm_storage_account.log_storage.id 
  enabled            = true

  retention_policy {
    enabled = true
    days    = 365  
  }

  traffic_analytics {
    enabled               = true                                             
    workspace_id          = azurerm_log_analytics_workspace.log.workspace_id 
    workspace_region      = azurerm_log_analytics_workspace.log.location
    workspace_resource_id = azurerm_log_analytics_workspace.log.id
  }
}

resource "azurerm_network_watcher_flow_log" "bastion" {
  network_watcher_name = data.azurerm_network_watcher.service.name
  resource_group_name  = "NetworkWatcherRG"
  name                 = "flow-${azurerm_virtual_network.bastion.name}"

  target_resource_id = azurerm_virtual_network.bastion.id
  storage_account_id = azurerm_storage_account.log_storage.id 
  enabled            = true

  retention_policy {
    enabled = true 
    days    = 365 
  }

  traffic_analytics {
    enabled               = true                                             
    workspace_id          = azurerm_log_analytics_workspace.log.workspace_id 
    workspace_region      = azurerm_log_analytics_workspace.log.location
    workspace_resource_id = azurerm_log_analytics_workspace.log.id
  }
}

resource "azurerm_network_watcher_flow_log" "subnet_service" {
  for_each             = local.subnet_service_map
  network_watcher_name = data.azurerm_network_watcher.service.name
  resource_group_name  = "NetworkWatcherRG"
  name                 = "flow-${each.value.name}"

  target_resource_id = each.value.id
  storage_account_id = azurerm_storage_account.log_storage.id 
  enabled            = true

  retention_policy {
    enabled = true 
    days    = 365  
  }

  traffic_analytics {
    enabled               = true                                            
    workspace_id          = azurerm_log_analytics_workspace.log.workspace_id 
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
