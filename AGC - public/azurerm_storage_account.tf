# Storage Account
resource "azurerm_storage_account" "storage" {
  name                          = lower("${module.naming.storage_account.name_unique}")
  resource_group_name           = azurerm_resource_group.storage.name
  location                      = azurerm_resource_group.storage.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = true

  https_traffic_only_enabled      = true
  shared_access_key_enabled       = false # 공유 액세스 키 비활성화
  allowed_copy_scope              = "PrivateLink"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  blob_properties {
    delete_retention_policy {
      days    = 7          # 삭제된 Blob 보관 기간 (1~365일)
    }
  }

  tags = merge(
    var.tags,
    {
      SEC_ASSETS_PII    = "Y",
      SEC_ASSETS_PUBLIC = "Y"
    }
  )
}

# Storage Account - Blob에 대한 Private Endpoint 설정
resource "azurerm_private_endpoint" "storage" {
  name                = lower("pe-${azurerm_storage_account.storage.name}")
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  subnet_id           = local.subnet_service_map["pe"].id

  private_service_connection {
    name                           = "psc-blob-${azurerm_storage_account.storage.name}"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.storage.id
    subresource_names              = ["blob"]
  }

  tags = var.tags
}

# Private DNS Zone A 레코드 설정
resource "azurerm_private_dns_a_record" "storage" {
  name                = azurerm_storage_account.storage.name
  zone_name           = azurerm_private_dns_zone.storage.name
  resource_group_name = azurerm_private_dns_zone.storage.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.storage.private_service_connection[0].private_ip_address]
}

# Storage Account Blob 진단 설정
resource "azurerm_monitor_diagnostic_setting" "storage_blob" {
  name               = lower("diag-${azurerm_storage_account.storage.name}")
  target_resource_id = "${azurerm_storage_account.storage.id}/blobServices/default/"
  storage_account_id = azurerm_storage_account.log_storage.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Capacity"
  }

  enabled_metric {
    category = "Transaction"
  }
}

# Storage Account - File 진단 설정
resource "azurerm_monitor_diagnostic_setting" "storage_file" {
  name                       = lower("diag-${azurerm_storage_account.storage.name}")
  target_resource_id         = "${azurerm_storage_account.storage.id}/fileServices/default/"
  storage_account_id         = azurerm_storage_account.log_storage.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Capacity"
  }

  enabled_metric {
    category = "Transaction"
  }
}

# Storage Account - Queue 진단 설정
resource "azurerm_monitor_diagnostic_setting" "storage_queue" {
  name                       = lower("diag-${azurerm_storage_account.storage.name}")
  target_resource_id         = "${azurerm_storage_account.storage.id}/queueServices/default/"
  storage_account_id         = azurerm_storage_account.log_storage.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Capacity"
  }

  enabled_metric {
    category = "Transaction"
  }
}

# Storage Account - Table 진단 설정
resource "azurerm_monitor_diagnostic_setting" "storage_table" {
  name                       = lower("diag-${azurerm_storage_account.storage.name}")
  target_resource_id         = "${azurerm_storage_account.storage.id}/tableServices/default/"
  storage_account_id         = azurerm_storage_account.log_storage.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  enabled_metric {
    category = "Capacity"
  }

  enabled_metric {
    category = "Transaction"
  }
}
