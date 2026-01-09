# AKS 클러스터에 대한 Prometheus Monitor Workspace
resource "azurerm_monitor_workspace" "aks" {
  name                = upper("mw-${module.naming.kubernetes_cluster.name}")
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location

  tags = var.tags
}

# Azure Managed Grafana
resource "azurerm_dashboard_grafana" "aks" {
  name                              = upper("gf-${module.naming.kubernetes_cluster.name}")
  resource_group_name               = azurerm_resource_group.aks.name
  location                          = azurerm_resource_group.aks.location
  grafana_major_version             = 11
  api_key_enabled                   = true
  deterministic_outbound_ip_enabled = true
  public_network_access_enabled     = false # Public Network Access Disabled

  azure_monitor_workspace_integrations { # Azure Monitor Workspace 연결
    resource_id = azurerm_monitor_workspace.aks.id
  }

  identity {
    type = "SystemAssigned" # 시스템 할당 ID
  }

  tags = var.tags
}

# AKS 클러스터의 Prometheus 데이터 수집을 위한 DCE
resource "azurerm_monitor_data_collection_endpoint" "aks" {
  for_each                      = azurerm_kubernetes_cluster.aks
  name                          = upper("DCE-${azurerm_kubernetes_cluster.aks[each.key].name}")
  resource_group_name           = azurerm_resource_group.aks.name
  location                      = azurerm_resource_group.aks.location
  kind                          = "Linux"
  public_network_access_enabled = true
  description                   = "AKS Cluster Prometheus"

  tags = var.tags
}

# AKS 클러스터의 Prometheus 데이터 수집을 위한 DCR
resource "azurerm_monitor_data_collection_rule" "aks" {
  for_each            = azurerm_kubernetes_cluster.aks
  name                = upper("DCR-${azurerm_kubernetes_cluster.aks[each.key].name}")
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  kind                = "Linux"

  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.aks[each.key].id

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.aks.id
      name               = "MonitoringAccount1"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }

  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
    }
  }

  description = "DCR for Azure Monitor Metrics Profile (Managed Prometheus)"

  tags = var.tags
}

# AKS 클러스터와 Prometheus 데이터 수집을 위한 DCR 연결
resource "azurerm_monitor_data_collection_rule_association" "aks_dcra" {
  for_each                = azurerm_kubernetes_cluster.aks
  name                    = upper("dcra-prom-${azurerm_kubernetes_cluster.aks[each.key].name}")
  target_resource_id      = azurerm_kubernetes_cluster.aks[each.key].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.aks[each.key].id
}

# AKS 클러스터와 Prometheus 데이터 수집을 위한 DCE 연결
resource "azurerm_monitor_data_collection_rule_association" "aks_dcea" {
  for_each                    = azurerm_kubernetes_cluster.aks
  target_resource_id          = azurerm_kubernetes_cluster.aks[each.key].id
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.aks[each.key].id
}

# Grafana 에 대한 역할 할당
resource "azurerm_role_assignment" "aks_monitor" {
  scope              = azurerm_monitor_workspace.aks.id
  role_definition_id = "/subscriptions/${split("/", azurerm_monitor_workspace.aks.id)[2]}/providers/Microsoft.Authorization/roleDefinitions/b0d8363b-8ddd-447d-831f-62ca05bff136" # Monitoring Data Reader
  principal_id       = azurerm_dashboard_grafana.aks.identity.0.principal_id
}
