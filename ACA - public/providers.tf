# Terraform 공급자 설정
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm" // Azure RM 공급자
      version = "~> 4.0"            // 버전 4.0 이상
    }
    azapi = {
      source  = "Azure/azapi" // Azure API 공급자
      version = "~> 2.0"      // 버전 2.0 이상
    }
    random = {
      source  = "hashicorp/random" // 랜덤 공급자
      version = "3.6.3"            // 버전 3.6.3
    }
    null = {
      source  = "hashicorp/null" // Null 공급자
      version = "3.2.3"          // 버전 3.2.3
    }
  }

  # 백엔드 설정
  # backend "azurerm" {
  #   resource_group_name  = "tfstate"
  #   storage_account_name = "<storage_account_name>"
  #   container_name       = "tfstate"
  #   key                  = "terraform.tfstate"
  # }
}

# Azure API 공급자 설정
provider "azapi" {
  // 설정 옵션
}

# Azure RM 공급자 설정
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false # 리소스 그룹에 리소스가 포함된 경우 삭제 방지 비활성화
    }
  }
  tenant_id           = "" // Entra 테넌트 ID
  subscription_id     = "" // Azure 구독 ID

  storage_use_azuread = true                                   // 스토리지 인증 시 Entra ID 사용 활성화

  resource_providers_to_register = csvdecode(file("Resource_Providers.csv"))[*].Namespace
}

# 랜덤 공급자 설정
provider "random" {
}

# Null 공급자 설정
provider "null" {
}

# Azure 리소스 네이밍 모듈
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.2"
  prefix  = ["${var.naming.prefix}", "${var.naming.env}", "${var.naming.location}"] # ex) prefix-dev-krc
}

