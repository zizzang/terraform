naming = {
  prefix   = "prefix"
  env      = "prd"
  location = "krc"
}

location = "koreacentral"

vhub = {
  address_prefix = "10.0.0.0/24"
}

vnet_service = {
  naming        = "Service"
  address_space = ["10.1.0.0/16", "10.2.0.0/16"]
}

vnet_bastion = {
  naming        = "bastion"
  address_space = ["10.255.0.0/16"]
}

subnet_agw_blue = {
  index            = 0
  naming           = "agw-blue"
  address_prefixes = ["10.1.1.0/24"]
}

subnet_agw_green = {
  index            = 1
  naming           = "agw-green"
  address_prefixes = ["10.1.2.0/24"]
}

subnet_aca_blue = {
  index            = 0
  naming           = "aca-blue"
  address_prefixes = ["10.1.3.0/24"]
}

subnet_aca_green = {
  index            = 1
  naming           = "aca-green"
  address_prefixes = ["10.1.4.0/24"]
}

subnet_mysql = {
  index            = 0
  naming           = "mysql"
  address_prefixes = ["10.1.5.0/24"]
}

subnet_pe = {
  index            = 0
  naming           = "pe"
  address_prefixes = ["10.1.6.0/24"]
}

subnet_bastion = {
  index            = 0
  naming           = "bastion"
  address_prefixes = ["10.255.0.0/24"]
}

agw = {
  zones                  = [1, 2, 3]
  autoscale_min_capacity = 1
  autoscale_max_capacity = 10
}

cosmosdb = {
  sku                = "Standard"
  kind               = "GlobalDocumentDB"
  secondary_location = "koreasouth"
}

keyvault = {
  sku                        = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = true
}

vm = {
  size           = "Standard_D2s_v4"
  admin_username = "azadmin"
}

vm_admin_password = "qwer1234!@#$"

mysql = {
  administratorLogin = "azadmin"
  sku = {
    name = "Standard_D2ds_v4"
    tier = "GeneralPurpose"
  }
}

mysql_administratorLoginPassword = "qwer1234!@#$"

storage = {
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  shared_access_key_enabled = false // 공유 액세스 키 사용 여부 True : Access Key 사용, False : Entra ID 인증 사용
}

bastion_nsg_source = {
    naming  = "Allow-source-IP"       // Source 규칙 이름 식별자
    sources = ["1.1.1.1","2.2.2.2"] // 허용할 소스 주소(CIDR, IP, Tag 등)
}

tags = {
  Managed_by_Terraform = "True"   # 기본 태그
#  Project              = "Project"   # 프로젝트명
}