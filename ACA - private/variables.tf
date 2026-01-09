# 네이밍 관련 변수 정의
variable "naming" {
  type = object({
    prefix   = string // prefix
    env      = string // 환경 구분자 (예: dev, prod)
    location = string // 위치 구분자
  })
  default = {
    prefix   = "prefix" // prefix
    env      = "prd" // 기본값: 운영 환경
    location = "krc" // 기본값: 한국 중부
  }
}

# Azure 리소스 위치 변수
variable "location" {
  type        = string
  default     = "koreacentral" // 기본값: 한국 중부 리전
  description = "Location"
}

# 가상 허브 설정 변수
variable "vhub" {
  type = object({ address_prefix = string // 가상 허브의 주소 범위
  })
  default = {
    address_prefix = "10.0.0.0/24" // 기본 주소 범위
  }
}

# VNET 기본 설정 변수
variable "vnet_service" {
  type = object({
    naming        = string       // VNET 이름 식별자
    address_space = list(string) // VNET 주소 공간 목록
  })
  default = {
    naming        = "Service"                      // 기본 VNET 이름
    address_space = ["10.1.0.0/16", "10.2.0.0/16"] // 기본 주소 범위
  }
}

# Bastion VNET 설정 변수
variable "vnet_bastion" {
  type = object({
    naming        = string       // Bastion VNET 이름 식별자
    address_space = list(string) // Bastion VNET 주소 공간
  })
  default = {
    naming        = "bastion"             // Bastion VNET 이름
    address_space = ["10.255.0.0/16"] // Bastion 주소 범위
  }
}

# Application Gateway Blue 서브넷 설정
variable "subnet_agw_blue" {
  type = object({
    index            = number       // 서브넷 인덱스
    naming           = string       // 서브넷 이름 식별자
    address_prefixes = list(string) // 서브넷 주소 범위
  })
  default = {
    index            = 0
    naming           = "agw-blue"
    address_prefixes = ["10.1.1.0/24"]
  }
}

# Application Gateway Green 서브넷 설정
variable "subnet_agw_green" {
  type = object({
    index            = number
    naming           = string
    address_prefixes = list(string)
  })
  default = {
    index            = 1
    naming           = "agw-green"
    address_prefixes = ["10.1.2.0/24"]
  }
}

# Container App Environment Blue 서브넷 설정
variable "subnet_aca_blue" {
  type = object({
    index            = number
    naming           = string
    address_prefixes = list(string)
  })
  default = {
    index            = 0
    naming           = "aca-blue"
    address_prefixes = ["10.1.3.0/24"]
  }
}

# Container App Environment Green 서브넷 설정
variable "subnet_aca_green" {
  type = object({
    index            = number
    naming           = string
    address_prefixes = list(string)
  })
  default = {
    index            = 1
    naming           = "aca-green"
    address_prefixes = ["10.1.4.0/24"]
  }
}

# MySQL 서브넷 설정
variable "subnet_mysql" {
  type = object({
    index            = number
    naming           = string
    address_prefixes = list(string)
  })
  default = {
    index            = 0
    naming           = "mysql"
    address_prefixes = ["10.1.5.0/24"]
  }
}

# Private Endpoint 서브넷 설정
variable "subnet_pe" {
  type = object({
    index            = number
    naming           = string
    address_prefixes = list(string)
  })
  default = {
    index            = 0
    naming           = "pe"
    address_prefixes = ["10.1.6.0/24"]
  }
}

# Bastion 서브넷 설정
variable "subnet_bastion" {
  type = object({
    index            = number
    naming           = string
    address_prefixes = list(string)
  })
  default = {
    index            = 0
    naming           = "bastion"
    address_prefixes = ["10.255.0.0/24"]
  }
}

# Application Gateway
variable "agw" {
  type = object({
    zones                  = list(number) // 가용 영역 설정
    autoscale_min_capacity = number       // 최소 인스턴스 수
    autoscale_max_capacity = number       // 최대 인스턴스 수
  })
  default = {
    zones                  = [1, 2, 3] // 기본값: 가용 영역 1, 2, 3 설정
    autoscale_min_capacity = 1         // 기본값: 최소 1개 인스턴스
    autoscale_max_capacity = 10        // 기본값: 최대 10개 인스턴스
  }
}

# Cosmos DB
variable "cosmosdb" {
  type = object({
    sku                = string // SKU 설정
    kind               = string // DB 종류 설정
    secondary_location = string // 장애 조치 지역 설정
  })
  default = {
    sku                = "Standard"         // 기본값: 표준 SKU
    kind               = "GlobalDocumentDB" // 기본값: DocumentDB
    secondary_location = "koreasouth"       // 기본값: 한국 남부 지역
  }
}

# Key Vault
variable "keyvault" {
  type = object({
    sku                        = string // Key Vault SKU 설정
    soft_delete_retention_days = number // 소프트 삭제 보존 기간 설정
    purge_protection_enabled   = bool   // 제거 보호 활성화 설정
  })
  default = {
    sku                        = "standard" // 기본값: 표준 SKU
    soft_delete_retention_days = 7          // 기본값: 7일
    purge_protection_enabled   = true       // 기본값: 제거 보호 활성화
  }
}

# Virtual Machine
variable "vm" {
  type = object({
    admin_username = string // VM 관리자 사용자 이름
    size           = string // VM 크기
  })
  default = {
    admin_username = "azadmin"         // 기본값: azadmin
    size           = "Standard_D2s_v4" // 기본값: Standard_D2s_v4
  }
}

# VM 관리자 사용자 패스워드
variable "vm_admin_password" {
  type      = string
  default   = "qwer1234!@#$"
  sensitive = true
}

# MySQL 서버 설정
variable "mysql" {
  type = object({
    administratorLogin = string // 관리자 로그인 이름
    sku = object({
      name = string // SKU 이름
      tier = string // SKU 계층
    })
  })
  default = {
    administratorLogin = "azadmin" // 기본값: azadmin
    sku = {
      name = "Standard_D2ds_v4" // 기본값: Standard_D2ds_v4
      tier = "GeneralPurpose"   // 기본값: GeneralPurpose
    }
  }
}

variable "mysql_administratorLoginPassword" {
  type      = string
  default   = "qwer1234!@#$"
  sensitive = true
}

# Storage Account
variable "storage" {
  type = object({
    account_tier              = string // 스토리지 계정 티어, 변경 시 강제로 새 리소스로 재생성됨
    account_replication_type  = string // 스토리지 계정 복제 유형, 변경 시 강제로 새 리소스로 재생성됨
    shared_access_key_enabled = bool   // 공유 액세스 키 사용 여부 True : Access Key 사용, False : Entra ID 인증 사용
  })
  default = {
    account_tier              = "Standard" // 기본값: Standard
    account_replication_type  = "LRS"      // 기본값: LRS
    shared_access_key_enabled = false      // 기본값: false
  }
}

#Bastion VM NSG Allow Source IP
variable "bastion_nsg_source" {
  type = object({
    naming  = string       // Source 규칙 이름 식별자
    sources = list(string) // 허용할 소스 주소(CIDR, IP, Tag 등)
  })
  default = {
    naming  = "Allow-source-IP"
    sources = ["*"] // 기본: 모든 인터넷 트래픽 허용
  }
}

# Tags
variable "tags" {
  type = map(string)
  default = {
    Managed_by_Terraform = "True"
  }
}