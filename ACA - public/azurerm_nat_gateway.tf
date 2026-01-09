# NAT Gateway용 Public IP
resource "azurerm_public_ip" "aca_nat" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                = upper("${module.naming.nat_gateway.name}-${replace(each.key, "aca_", "")}")
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# NAT Gateway 리소스
resource "azurerm_nat_gateway" "aca_nat" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  name                = upper("${module.naming.nat_gateway.name}-${replace(each.key, "aca_", "")}")
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  sku_name            = "Standard"

  tags = var.tags
}

# NAT Gateway와 Public IP 연결
resource "azurerm_nat_gateway_public_ip_association" "aca_nat" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }
  nat_gateway_id       = azurerm_nat_gateway.aca_nat[each.key].id # NAT Gateway ID
  public_ip_address_id = azurerm_public_ip.aca_nat[each.key].id   # Public IP ID
}

# NAT Gateway와 서브넷 연결 리소스
resource "azurerm_subnet_nat_gateway_association" "aca_nat" {
  for_each = {
    aca_blue = var.subnet_aca_blue
    aca_green = var.subnet_aca_green
  }

  subnet_id      = local.subnet_service_map[each.key].id      # 연결할 서브넷 ID
  nat_gateway_id = azurerm_nat_gateway.aca_nat[each.key].id # 연결할 NAT Gateway ID
}
