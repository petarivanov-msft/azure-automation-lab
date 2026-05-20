# hybrid_service_url is passed in via var.hybrid_service_url (from automation_account module output)
# No data lookup needed — the AA is created before this module runs.

resource "random_uuid" "worker_id_windows" {}
resource "random_uuid" "worker_id_ubuntu" {}
resource "random_uuid" "worker_id_rhel" {}

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

resource "azurerm_automation_hybrid_runbook_worker" "windows" {
  automation_account_name = var.automation_account_name
  resource_group_name     = var.resource_group_name
  worker_group_name       = azurerm_automation_hybrid_runbook_worker_group.windows.name
  vm_resource_id          = azurerm_windows_virtual_machine.windows.id
  worker_id               = random_uuid.worker_id_windows.result
}

resource "azurerm_automation_hybrid_runbook_worker" "ubuntu" {
  automation_account_name = var.automation_account_name
  resource_group_name     = var.resource_group_name
  worker_group_name       = azurerm_automation_hybrid_runbook_worker_group.linux.name
  vm_resource_id          = azurerm_linux_virtual_machine.ubuntu.id
  worker_id               = random_uuid.worker_id_ubuntu.result
}

resource "azurerm_automation_hybrid_runbook_worker" "rhel" {
  automation_account_name = var.automation_account_name
  resource_group_name     = var.resource_group_name
  worker_group_name       = azurerm_automation_hybrid_runbook_worker_group.linux.name
  vm_resource_id          = azurerm_linux_virtual_machine.rhel.id
  worker_id               = random_uuid.worker_id_rhel.result
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

  depends_on = [azurerm_automation_hybrid_runbook_worker.windows]

  tags = var.tags
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

  depends_on = [azurerm_automation_hybrid_runbook_worker.ubuntu]

  tags = var.tags
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

  depends_on = [azurerm_automation_hybrid_runbook_worker.rhel]

  tags = var.tags
}

# Automation account MI needs Contributor to manage resources via runbooks
resource "azurerm_role_assignment" "automation_contributor" {
  scope                            = var.resource_group_id
  role_definition_name             = "Contributor"
  principal_id                     = var.automation_identity_principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "vm_windows_contributor" {
  scope                            = var.resource_group_id
  role_definition_name             = "Contributor"
  principal_id                     = azurerm_windows_virtual_machine.windows.identity[0].principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "vm_ubuntu_contributor" {
  scope                            = var.resource_group_id
  role_definition_name             = "Contributor"
  principal_id                     = azurerm_linux_virtual_machine.ubuntu.identity[0].principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "vm_rhel_contributor" {
  scope                            = var.resource_group_id
  role_definition_name             = "Contributor"
  principal_id                     = azurerm_linux_virtual_machine.rhel.identity[0].principal_id
  skip_service_principal_aad_check = true
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
}

# Publish the test runbook on content changes (bash - no PowerShell dependency)
resource "null_resource" "publish_test_runbook" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      state=$(az automation runbook show \
        --automation-account-name '${var.automation_account_name}' \
        --resource-group '${var.resource_group_name}' \
        --name 'Test-HybridWorker-ManagedIdentity' \
        --query state -o tsv 2>/dev/null || echo "")

      if [ "$state" != "Published" ]; then
        echo "Publishing Test-HybridWorker-ManagedIdentity..."
        az automation runbook publish \
          --automation-account-name '${var.automation_account_name}' \
          --resource-group '${var.resource_group_name}' \
          --name 'Test-HybridWorker-ManagedIdentity'
        echo "Runbook published."
      else
        echo "Runbook already published."
      fi
    EOT
  }

  depends_on = [azurerm_automation_runbook.test_hybrid_worker]

  triggers = {
    runbook_content = sha256(file("${path.module}/runbooks/Test-HybridWorker-ManagedIdentity.ps1"))
  }
}

# Deployment summary (bash, no PowerShell, no WinGet feedback predictor crashes)
resource "null_resource" "deployment_summary" {
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      echo ""
      echo "=== Hybrid Worker Deployment Complete ==="
      echo "Automation Account : ${var.automation_account_name}"
      echo "Resource Group     : ${var.resource_group_name}"
      echo "Worker groups      : ${azurerm_automation_hybrid_runbook_worker_group.windows.name}, ${azurerm_automation_hybrid_runbook_worker_group.linux.name}"
      echo ""
      echo "To run the connectivity test manually:"
      echo "  az automation runbook start \\"
      echo "    --automation-account-name '${var.automation_account_name}' \\"
      echo "    --resource-group '${var.resource_group_name}' \\"
      echo "    --name 'Test-HybridWorker-ManagedIdentity' \\"
      echo "    --run-on '${azurerm_automation_hybrid_runbook_worker_group.windows.name}'"
      echo ""
      echo "Note: Hybrid workers may take 5-10 minutes after VM extension installation"
      echo "to fully register with the Automation Account before runbooks can execute."
    EOT
  }

  depends_on = [
    null_resource.publish_test_runbook,
    azurerm_virtual_machine_extension.hybrid_worker_windows,
    azurerm_virtual_machine_extension.hybrid_worker_ubuntu,
    azurerm_virtual_machine_extension.hybrid_worker_rhel,
  ]

  triggers = {
    always_run = timestamp()
  }
}
