# Setup the resource group, key vault, and container registry
provider "azurerm" {
    features {}
}
resource "random_string" "default" {
    length = 4
    special = false
}
data "azurerm_client_config" "current" {}

locals {
    name_prefix = "${var.name}-${random_string.default.result}"
}
resource "azurerm_resource_group" "default" {
  name     = "${local.name_prefix}-rsg"
  location = var.location
}
resource "azurerm_key_vault" "default" {
    name = "${local.name_prefix}-kv"
    location = var.location
    tenant_id = data.azurerm_client_config.current.tenant_id
    sku_name = "standard"
    resource_group_name = azurerm_resource_group.default.name
}
resource "azurerm_key_vault_access_policy" "secret_set" {
  key_vault_id = azurerm_key_vault.default.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "get",
    "set",
    "delete",
  ]
}
resource "azurerm_key_vault_secret" "example" {
    depends_on = [azurerm_key_vault_access_policy.secret_set]
    key_vault_id = azurerm_key_vault.default.id
    name = "test-secret"
    value = "A Secret"
}
resource "azurerm_user_assigned_identity" "default" {
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location

  name = "${var.name}-msi"
}

resource "azurerm_key_vault_access_policy" "secret_get" {
  key_vault_id = azurerm_key_vault.default.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azurerm_user_assigned_identity.default.principal_id

  secret_permissions = [
    "get",
  ]
}

resource "azurerm_app_service_plan" "default" {
  name                = "${local.name_prefix}-svc-plan"
  resource_group_name = azurerm_resource_group.default.name
  location            = var.location
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "default" {
  name                = "${local.name_prefix}-app"
  resource_group_name = azurerm_resource_group.default.name
  location            = var.location
  app_service_plan_id = azurerm_app_service_plan.default.id
  https_only          = true

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.default.id]
  }

  site_config {
    always_on        = true
    linux_fx_version = "DOCKER|${var.docker_image}"
  }

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "WEBSITES_PORT"                       = "8080"
    "KEYVAULT_VAULT_NAME"                 = "${azurerm_key_vault.default.name}"
    "KEYVAULT_SECRET_NAME"                = "${azurerm_key_vault_secret.example.name}"
    "MSI_USER_ASSIGNED_IDENTITY_CLIENTID" = "${azurerm_user_assigned_identity.default.client_id}"
  }
  auth_settings {
    enabled          = false
  }
}

resource "azurerm_container_group" "example" {
  name                = "${local.name_prefix}-container"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  ip_address_type     = "public"
  dns_name_label      = "aci-label"
  os_type             = "Linux"
  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.default.id]
  }

  container {
    name   = "hello-world"
    image  = var.docker_image
    cpu    = "0.5"
    memory = "1.5"
    ports {
      port     = 443
      protocol = "TCP"
    }
    environment_variables = {
        "KEYVAULT_VAULT_NAME"                 = "${azurerm_key_vault.default.name}"
        "KEYVAULT_SECRET_NAME"                = "${azurerm_key_vault_secret.example.name}"
        "MSI_USER_ASSIGNED_IDENTITY_CLIENTID" = "${azurerm_user_assigned_identity.default.client_id}"

    }
  }
}
