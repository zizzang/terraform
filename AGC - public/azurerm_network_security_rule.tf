/*Inbound Deny All*/
resource "azurerm_network_security_rule" "service_inbound_deny_all" {
  for_each                    = { for k, v in azurerm_network_security_group.service : k => v if !can(regex("alb", k)) } # alb 제외
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
    aks_blue = var.subnet_aks_blue
    aks_green = var.subnet_aks_green
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
    aks_blue = var.subnet_aks_blue
    aks_green = var.subnet_aks_green
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
