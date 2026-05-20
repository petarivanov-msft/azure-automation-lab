# hybrid_service_url is passed in via var.hybrid_service_url (from automation_account module output)
# No data lookup needed — the AA is created before this module runs.

resource "azurerm_network_interface" "windows" {
  name                = "nic-hw-windows"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_network_interface" "ubuntu" {
  name                = "nic-hw-ubuntu"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_network_interface" "rhel" {
  name                = "nic-hw-rhel"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_windows_virtual_machine" "windows" {
  name                = "vm-hw-windows"
  computer_name       = "hwwindows"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = "Standard_B2s"
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password

  network_interface_ids = [azurerm_network_interface.windows.id]

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  tags = merge(var.tags, {
    OS       = "Windows"
    Platform = "HybridWorker"
  })
}

resource "azurerm_linux_virtual_machine" "ubuntu" {
  name                            = "vm-hw-ubuntu"
  computer_name                   = "hwubuntu"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = "Standard_B2s"
  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.ubuntu.id]

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = merge(var.tags, {
    OS       = "Ubuntu"
    Platform = "HybridWorker"
  })
}

resource "azurerm_linux_virtual_machine" "rhel" {
  name                            = "vm-hw-rhel"
  computer_name                   = "hwrhel"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  size                            = "Standard_B2s"
  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.rhel.id]

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "9-lvm-gen2"
    version   = "latest"
  }

  tags = merge(var.tags, {
    OS       = "RHEL"
    Platform = "HybridWorker"
  })
}

resource "azurerm_automation_hybrid_runbook_worker_group" "windows" {
  name                    = "hybrid-workers-windows"
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
}

resource "azurerm_automation_hybrid_runbook_worker_group" "linux" {
  name                    = "hybrid-workers-linux"
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
}

# Pre-register each VM as a hybrid worker in the AA. The extension (especially
# v1.3+, which auto_upgrade_minor_version pulls in) expects this registration
# to exist before it connects. The worker_id is a random UUID generated once
# and stored in state.
resource "random_uuid" "worker_windows" {}
resource "random_uuid" "worker_ubuntu" {}
resource "random_uuid" "worker_rhel" {}

resource "azurerm_automation_hybrid_runbook_worker" "windows" {
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  worker_group_name       = azurerm_automation_hybrid_runbook_worker_group.windows.name
  vm_resource_id          = azurerm_windows_virtual_machine.windows.id
  worker_id               = random_uuid.worker_windows.result
}

resource "azurerm_automation_hybrid_runbook_worker" "ubuntu" {
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  worker_group_name       = azurerm_automation_hybrid_runbook_worker_group.linux.name
  vm_resource_id          = azurerm_linux_virtual_machine.ubuntu.id
  worker_id               = random_uuid.worker_ubuntu.result
}

resource "azurerm_automation_hybrid_runbook_worker" "rhel" {
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  worker_group_name       = azurerm_automation_hybrid_runbook_worker_group.linux.name
  vm_resource_id          = azurerm_linux_virtual_machine.rhel.id
  worker_id               = random_uuid.worker_rhel.result
}

# Allow RBAC propagation time before extensions attempt registration.
resource "time_sleep" "wait_for_rbac" {
  create_duration = "60s"

  depends_on = [
    azurerm_role_assignment.vm_windows_aa,
    azurerm_role_assignment.vm_ubuntu_aa,
    azurerm_role_assignment.vm_rhel_aa,
    azurerm_automation_hybrid_runbook_worker.windows,
    azurerm_automation_hybrid_runbook_worker.ubuntu,
    azurerm_automation_hybrid_runbook_worker.rhel,
  ]
}

resource "azurerm_virtual_machine_extension" "hybrid_worker_windows" {
  name                       = "HybridWorkerExtension"
  virtual_machine_id         = azurerm_windows_virtual_machine.windows.id
  publisher                  = "Microsoft.Azure.Automation.HybridWorker"
  type                       = "HybridWorkerForWindows"
  type_handler_version       = "1.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    AutomationAccountURL = var.hybrid_service_url
  })

  protected_settings = jsonencode({
    HybridWorkerGroupName = azurerm_automation_hybrid_runbook_worker_group.windows.name
  })

  tags = var.tags

  depends_on = [time_sleep.wait_for_rbac]
}

resource "azurerm_virtual_machine_extension" "hybrid_worker_ubuntu" {
  name                       = "HybridWorkerExtension"
  virtual_machine_id         = azurerm_linux_virtual_machine.ubuntu.id
  publisher                  = "Microsoft.Azure.Automation.HybridWorker"
  type                       = "HybridWorkerForLinux"
  type_handler_version       = "1.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    AutomationAccountURL = var.hybrid_service_url
  })

  protected_settings = jsonencode({
    HybridWorkerGroupName = azurerm_automation_hybrid_runbook_worker_group.linux.name
  })

  tags = var.tags

  depends_on = [time_sleep.wait_for_rbac]
}

resource "azurerm_virtual_machine_extension" "hybrid_worker_rhel" {
  name                       = "HybridWorkerExtension"
  virtual_machine_id         = azurerm_linux_virtual_machine.rhel.id
  publisher                  = "Microsoft.Azure.Automation.HybridWorker"
  type                       = "HybridWorkerForLinux"
  type_handler_version       = "1.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    AutomationAccountURL = var.hybrid_service_url
  })

  protected_settings = jsonencode({
    HybridWorkerGroupName = azurerm_automation_hybrid_runbook_worker_group.linux.name
  })

  tags = var.tags

  depends_on = [time_sleep.wait_for_rbac]
}

# Give the hybrid worker extension time to register the VM with the AA before
# downstream consumers (e.g. invoking the test runbook) try to use it. Replaces
# the manual "wait 5-10 minutes" note in the README.
resource "time_sleep" "wait_for_worker_registration" {
  create_duration = "180s"

  depends_on = [
    azurerm_virtual_machine_extension.hybrid_worker_windows,
    azurerm_virtual_machine_extension.hybrid_worker_ubuntu,
    azurerm_virtual_machine_extension.hybrid_worker_rhel,
  ]
}

# Automation account MI needs Contributor to manage resources via runbooks.
resource "azurerm_role_assignment" "automation_contributor" {
  scope                            = var.resource_group_id
  role_definition_name             = "Contributor"
  principal_id                     = var.automation_identity_principal_id
  skip_service_principal_aad_check = true
}

# The HybridWorker v2 extension uses the VM's system-assigned MI to call the
# Automation Account JRDS endpoint and register itself as a worker. The MI
# needs hybridRunbookWorkers/read+write on the AA — "Automation Contributor"
# is the narrowest built-in role that grants this.
resource "azurerm_role_assignment" "vm_windows_aa" {
  scope                = var.automation_account_id
  role_definition_name = "Automation Contributor"
  principal_id         = azurerm_windows_virtual_machine.windows.identity[0].principal_id
}

resource "azurerm_role_assignment" "vm_ubuntu_aa" {
  scope                = var.automation_account_id
  role_definition_name = "Automation Contributor"
  principal_id         = azurerm_linux_virtual_machine.ubuntu.identity[0].principal_id
}

resource "azurerm_role_assignment" "vm_rhel_aa" {
  scope                = var.automation_account_id
  role_definition_name = "Automation Contributor"
  principal_id         = azurerm_linux_virtual_machine.rhel.identity[0].principal_id
}

resource "azurerm_virtual_machine_extension" "windows_powershell_modules" {
  name                       = "InstallPowerShellModules"
  virtual_machine_id         = azurerm_windows_virtual_machine.windows.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force; Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; Install-Module -Name Az.Accounts -Force -AllowClobber; Install-Module -Name Az.Compute -Force -AllowClobber; Install-Module -Name Az.Resources -Force -AllowClobber; Write-Host 'PowerShell Az modules installed successfully'\""
  })

  depends_on = [azurerm_virtual_machine_extension.hybrid_worker_windows]

  tags = var.tags
}

resource "azurerm_virtual_machine_extension" "ubuntu_powershell_setup" {
  name                       = "InstallPowerShellAndModules"
  virtual_machine_id         = azurerm_linux_virtual_machine.ubuntu.id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = "apt-get update && apt-get install -y wget apt-transport-https software-properties-common && . /etc/os-release && wget -q https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb && dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb && apt-get update && apt-get install -y powershell && pwsh -Command 'Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; Install-Module -Name Az.Accounts -Force -AllowClobber -Scope AllUsers; Install-Module -Name Az.Compute -Force -AllowClobber -Scope AllUsers; Install-Module -Name Az.Resources -Force -AllowClobber -Scope AllUsers' && echo 'PowerShell and Az modules installed successfully'"
  })

  depends_on = [azurerm_virtual_machine_extension.hybrid_worker_ubuntu]

  tags = var.tags
}

resource "azurerm_virtual_machine_extension" "rhel_powershell_setup" {
  name                       = "InstallPowerShellAndModules"
  virtual_machine_id         = azurerm_linux_virtual_machine.rhel.id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = "curl https://packages.microsoft.com/config/rhel/9/prod.repo | tee /etc/yum.repos.d/microsoft.repo && dnf install -y powershell && pwsh -Command 'Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; Install-Module -Name Az.Accounts -Force -AllowClobber -Scope AllUsers; Install-Module -Name Az.Compute -Force -AllowClobber -Scope AllUsers; Install-Module -Name Az.Resources -Force -AllowClobber -Scope AllUsers' && echo 'PowerShell and Az modules installed successfully'"
  })

  depends_on = [azurerm_virtual_machine_extension.hybrid_worker_rhel]

  tags = var.tags
}

resource "azurerm_automation_runbook" "test_hybrid_worker" {
  name                    = "Test-HybridWorker-ManagedIdentity"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = var.automation_account_name
  log_verbose             = true
  log_progress            = true
  description             = "Validates hybrid worker connectivity using managed identity"
  runbook_type            = "PowerShell"

  content = file("${path.module}/runbooks/Test-HybridWorker-ManagedIdentity.ps1")
  tags    = var.tags

  depends_on = [time_sleep.wait_for_worker_registration]
}
