/*Inbound Deny All*/
resource "azurerm_network_security_rule" "service_inbound_deny_all" {
  for_each                    = azurerm_network_security_group.service
  name                        = "Inbound_Deny_All"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name
  description                 = "외부 인터넷 접근 금지"

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service,
  ]
}

resource "azurerm_network_security_rule" "bastion_inbound_deny_all" {
  name                        = "Inbound_Deny_All"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.bastion.name
  description                 = "외부 인터넷 접근 금지"

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.bastion,
  ]
}

resource "azurerm_network_security_rule" "Service_vNet_inbound" {
  for_each = {
    agw_blue = var.subnet_agw_blue
    agw_green = var.subnet_agw_green
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
    mysql = var.subnet_mysql
    pe = var.subnet_pe
  }
  name                        = "Inbound_Allow_Virtual_Network"
  priority                    = 4094
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}

resource "azurerm_network_security_rule" "Service_vNet_LB_inbound" {
  for_each = {
    agw_blue = var.subnet_agw_blue
    agw_green = var.subnet_agw_green
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
    mysql = var.subnet_mysql
    pe = var.subnet_pe
  }
  name                        = "Inbound_Allow_LoadBalancer"
  priority                    = 4095
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}


/* Application Gateway 필수 규칙
참고 문서(https://learn.microsoft.com/ko-kr/azure/application-gateway/configuration-infrastructure) */
resource "azurerm_network_security_rule" "agw_inbound_01" {
  for_each = {
    agw_blue = var.subnet_agw_blue
    agw_green = var.subnet_agw_green
  }
  name                        = "Inbound_Allow_Application_Gateway_Subnet"
  priority                    = 4091
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80","443"]
  source_address_prefix       = "*"
  destination_address_prefix  = each.value.address_prefixes[0]
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}

resource "azurerm_network_security_rule" "agw_inbound_02" {
  for_each = {
    agw_blue = var.subnet_agw_blue
    agw_green = var.subnet_agw_green
  }
  name                        = "Inbound_Allow_Application_Gateway_AzureLoadBalancer"
  priority                    = 4092
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}


resource "azurerm_network_security_rule" "agw_inbound_03" {
  for_each = {
    agw_blue = var.subnet_agw_blue
    agw_green = var.subnet_agw_green
  }
  name                        = "Inbound_Allow_Application_Gateway_GatewayManager"
  priority                    = 4093
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}

resource "azurerm_network_security_rule" "agw_outbound_01" {
  for_each = {
    agw_blue = var.subnet_agw_blue
    agw_green = var.subnet_agw_green
  }
  name                        = "Outbound_Allow_Application_Gateway_Internet"
  priority                    = 4096
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Internet"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}


/* VM */
resource "azurerm_network_security_rule" "vm_inbound_01" {
  name                        = "Inbound_Allow_SSH"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = [22]
  source_address_prefixes     = var.bastion_nsg_source.sources
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.bastion.name
  description                 = "Bastion에서의 SSH 접근 허용"

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.bastion
  ]
}

resource "azurerm_network_security_rule" "vm_inbound_02" {
  name                        = "Inbound_Allow_Virtual_Network"
  priority                    = 4094
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.bastion.name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.bastion
  ]
}

resource "azurerm_network_security_rule" "vm_inbound_03" {
  name                        = "Inbound_Allow_LoadBalancer"
  priority                    = 4095
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.bastion.name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.bastion
  ]
}


/* Container Apps 필수 규칙
https://learn.microsoft.com/ko-kr/azure/container-apps/firewall-integration?tabs=workload-profiles
*/
resource "azurerm_network_security_rule" "aca_inbound_01" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                        = "Inbound_Allow_ContainerApps"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = [80, 443, 31080, 31443]
  source_address_prefix       = "*"
  destination_address_prefix  = each.value.address_prefixes[0]
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}

resource "azurerm_network_security_rule" "aca_inbound_02" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                        = "Inbound_Allow_ContainerApps_AzureLoadBalancer"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "30000-32767"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = each.value.address_prefixes[0]
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}

resource "azurerm_network_security_rule" "aca_outbound_01" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                        = "Outbound_Allow_MCR_443"
  priority                    = 1000
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = each.value.address_prefixes[0]
  destination_address_prefix  = "MicrosoftContainerRegistry"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}

resource "azurerm_network_security_rule" "aca_outbound_02" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                        = "Outbound_Allow_AFD"
  priority                    = 1001
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = each.value.address_prefixes[0]
  destination_address_prefix  = "AzureFrontDoor.FirstParty"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}

resource "azurerm_network_security_rule" "aca_outbound_03" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                        = "Outbound_Allow_Subnet"
  priority                    = 1003
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = each.value.address_prefixes[0]
  destination_address_prefix  = each.value.address_prefixes[0]
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}

resource "azurerm_network_security_rule" "aca_outbound_04" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                        = "Outbound_Allow_AAD"
  priority                    = 1004
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = each.value.address_prefixes[0]
  destination_address_prefix  = "AzureActiveDirectory"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}

resource "azurerm_network_security_rule" "aca_outbound_05" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                        = "Outbound_Allow_Monitor"
  priority                    = 1005
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = each.value.address_prefixes[0]
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}

resource "azurerm_network_security_rule" "aca_outbound_06" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                        = "Outbound_Allow_DNS"
  priority                    = 1006
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "53"
  source_address_prefix       = each.value.address_prefixes[0]
  destination_address_prefix  = "168.63.129.16"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}

resource "azurerm_network_security_rule" "aca_outbound_07" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                         = "Outbound_Allow_ACR"
  priority                     = 1007
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Udp"
  source_port_range            = "*"
  destination_port_range       = "53"
  source_address_prefix        = each.value.address_prefixes[0]
  destination_address_prefixes = ["${azurerm_private_endpoint.acr.custom_dns_configs[0].ip_addresses[0]}", "${azurerm_private_endpoint.acr.custom_dns_configs[1].ip_addresses[0]}"]
  resource_group_name          = azurerm_resource_group.network.name
  network_security_group_name  = azurerm_network_security_group.service[each.key].name

  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}

resource "azurerm_network_security_rule" "aca_outbound_08" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                        = "Outbound_Allow_Storage"
  priority                    = 1008
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = each.value.address_prefixes[0]
  destination_address_prefix  = "Storage.${azurerm_resource_group.network.location}"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.service[each.key].name
  depends_on = [
    azapi_resource.subnet_bastion,
    azurerm_network_security_group.service
  ]
}
