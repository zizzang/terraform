# Azure 클라이언트 구성 데이터 소스
data "azurerm_client_config" "current" {
  // 현재 인증된 Azure 클라이언트의 구성 정보를 가져옵니다.
}

# 현재 구독 정보 데이터 소스
data "azurerm_subscription" "current" {
  // 현재 사용 중인 Azure 구독 정보를 가져옵니다.
}

# AKS 리소스 그룹
resource "azurerm_resource_group" "aks" {
  name     = upper("${module.naming.resource_group.name}-aks")
  location = var.location

  tags = var.tags
}

# Database 리소스 그룹
resource "azurerm_resource_group" "database" {
  name     = upper("${module.naming.resource_group.name}-database")
  location = var.location

  tags = var.tags
}

# Storage 리소스 그룹
resource "azurerm_resource_group" "storage" {
  name     = upper("${module.naming.resource_group.name}-storage")
  location = var.location

  tags = var.tags
}

# Network 리소스 그룹
resource "azurerm_resource_group" "network" {
  name     = upper("${module.naming.resource_group.name}-network")
  location = var.location

  tags = var.tags
}

# VM 리소스 그룹
resource "azurerm_resource_group" "vm" {
  name     = upper("${module.naming.resource_group.name}-vm")
  location = var.location

  tags = var.tags
}

# Managed 리소스 그룹 (Log Analytics, Managed ID 등)
resource "azurerm_resource_group" "managed" {
  name     = upper("${module.naming.resource_group.name}-managed")
  location = var.location

  tags = var.tags
}

# # Azure Activity Log 진단 설정
# resource "azurerm_monitor_diagnostic_setting" "activity_log" {
#   name                       = lower("activity-log-${var.naming.prefix}-${data.azurerm_subscription.current.display_name}")
#   target_resource_id         = data.azurerm_subscription.current.id
#   storage_account_id         = azurerm_storage_account.log_storage.id
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id

#   enabled_log {
#     category = "Administrative"
#   }

#   enabled_log {
#     category = "Security"
#   }

#   enabled_log {
#     category = "Policy"
#   }

#   enabled_log {
#     category = "ServiceHealth"
#   }

#   enabled_log {
#     category = "Alert"
#   }

#   enabled_log {
#     category = "Recommendation"
#   }

#   enabled_log {
#     category = "Autoscale"
#   }

#   enabled_log {
#     category = "ResourceHealth"
#   }
# }
