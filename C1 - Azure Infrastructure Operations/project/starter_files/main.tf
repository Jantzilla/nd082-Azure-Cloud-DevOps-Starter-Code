provider "azurerm" {
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
  features {}
}

data "azurerm_image" "image" {
  name                =  "ubuntuImage" 
  resource_group_name = "packer-rg"
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}


resource "azurerm_public_ip" "pip" {
  count               = var.instance_count
  name                = "${var.prefix}-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Dynamic"
  tags                = var.tags
}

resource "azurerm_network_interface" "main" {
  count               = var.instance_count
  name                = "${var.prefix}-nic${count.index}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }

  tags                            = var.tags
}

resource "azurerm_availability_set" "avset" {
  name                         = "${var.prefix}avset"
  location                     = azurerm_resource_group.main.location
  resource_group_name          = azurerm_resource_group.main.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
  tags                         = var.tags
}

resource "azurerm_network_security_group" "webserver" {
  name                = "tls_webserver"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
    security_rule {
    access                     = "Allow"
    direction                  = "Inbound"
    name                       = "vms"
    priority                   = 100
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_range     = "*"
    destination_address_prefix = azurerm_subnet.internal.address_prefixes[0]
  }
  security_rule {
    access                     = "Deny"
    direction                  = "Inbound"
    name                       = "tls"
    priority                   = 101
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "443"
    destination_address_prefix = azurerm_subnet.internal.address_prefixes[0]
  }

  tags                         = var.tags
}

resource "azurerm_lb" "example" {
  name                = "${var.prefix}-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.pip[0].id
  }

  tags                   = var.tags
}

resource "azurerm_lb_backend_address_pool" "example" {
  loadbalancer_id     = azurerm_lb.example.id
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_rule" "example" {
  resource_group_name            = azurerm_resource_group.main.name
  loadbalancer_id                = azurerm_lb.example.id
  name                           = "HTTPSAccess"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = azurerm_lb.example.frontend_ip_configuration[0].name
}

resource "azurerm_network_interface_backend_address_pool_association" "example" {
  count                   = var.instance_count
  backend_address_pool_id = azurerm_lb_backend_address_pool.example.id
  ip_configuration_name   = "primary"
  network_interface_id    = element(azurerm_network_interface.main.*.id, count.index)
}

resource "azurerm_linux_virtual_machine" "main" {
  count                           = var.instance_count
  name                            = "${var.prefix}-vm${count.index}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  source_image_id                 = data.azurerm_image.image.id
  size                            = "Standard_D2s_v3"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rd1234!"
  availability_set_id             = azurerm_availability_set.avset.id
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.main[count.index].id,
  ]

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "18.04-LTS"
#     version   = "latest"
#   }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  tags                   = var.tags
}