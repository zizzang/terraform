resource "azurerm_application_load_balancer" "alb" {
  for_each = {
    alb_blue = var.subnet_alb_blue
    alb_green = var.subnet_alb_green
  }
  name                = upper("${replace("${module.naming.lb.name}", "lb", "alb")}-${replace(each.key, "alb_", "")}")
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_application_load_balancer_subnet_association" "aks" {
  for_each = {
    alb_blue = var.subnet_alb_blue
    alb_green = var.subnet_alb_green
  }
  name                         = "conn-${azurerm_application_load_balancer.alb[each.key].name}"
  application_load_balancer_id = azurerm_application_load_balancer.alb[each.key].id
  subnet_id                    = local.subnet_service_map[each.key].id
}
