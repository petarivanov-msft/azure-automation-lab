data "azurerm_automation_account" "main" {
  name                = var.automation_account_name
  resource_group_name = var.resource_group_name
}

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
    AutomationAccountURL = data.azurerm_automation_account.main.hybrid_service_url
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
    AutomationAccountURL = data.azurerm_automation_account.main.hybrid_service_url
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
    AutomationAccountURL = data.azurerm_automation_account.main.hybrid_service_url
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

resource "null_resource" "publish_test_runbook" {
  provisioner "local-exec" {
    interpreter = ["pwsh", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Continue'
      $runbook = az automation runbook show `
        --automation-account-name '${var.automation_account_name}' `
        --resource-group '${var.resource_group_name}' `
        --name 'Test-HybridWorker-ManagedIdentity' 2>$null | ConvertFrom-Json
      
      if ($runbook.state -ne 'Published') {
        az automation runbook publish `
          --automation-account-name '${var.automation_account_name}' `
          --resource-group '${var.resource_group_name}' `
          --name 'Test-HybridWorker-ManagedIdentity'
        Write-Host "Runbook published"
      }
    EOT
  }

  depends_on = [azurerm_automation_runbook.test_hybrid_worker]

  triggers = {
    runbook_content = sha256(file("${path.module}/runbooks/Test-HybridWorker-ManagedIdentity.ps1"))
  }
}

resource "null_resource" "run_test_windows" {
  count = var.run_test_runbook ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["pwsh", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Continue'
      Write-Host "Running test on Windows hybrid worker..."
      Start-Sleep -Seconds 30

      $job = az automation runbook start `
        --automation-account-name '${var.automation_account_name}' `
        --resource-group '${var.resource_group_name}' `
        --name 'Test-HybridWorker-ManagedIdentity' `
        --run-on '${azurerm_automation_hybrid_runbook_worker_group.windows.name}' 2>$null | ConvertFrom-Json

      if ($job) {
        $jobName = $job.name
        $maxWait = 180
        $waited = 0
        $status = "Running"

        while ($status -notin @('Completed', 'Failed', 'Stopped', 'Suspended') -and $waited -lt $maxWait) {
          Start-Sleep -Seconds 10
          $waited += 10
          $status = (az automation job show --automation-account-name '${var.automation_account_name}' --resource-group '${var.resource_group_name}' --name $jobName 2>$null | ConvertFrom-Json).status
          Write-Host "  $status ($waited s)"
        }

        Write-Host "Windows hybrid worker test: $status"
      } else {
        Write-Host "Could not start job - worker may still be initializing"
      }
    EOT
  }

  depends_on = [
    null_resource.publish_test_runbook,
    azurerm_virtual_machine_extension.hybrid_worker_windows,
    azurerm_virtual_machine_extension.windows_powershell_modules
  ]

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "run_test_ubuntu" {
  count = var.run_test_runbook ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["pwsh", "-Command"]
    command     = <<-EOT
      $ErrorActionPreference = 'Continue'
      Write-Host "Running test on Ubuntu hybrid worker..."
      Start-Sleep -Seconds 60

      $job = az automation runbook start `
        --automation-account-name '${var.automation_account_name}' `
        --resource-group '${var.resource_group_name}' `
        --name 'Test-HybridWorker-ManagedIdentity' `
        --run-on '${azurerm_automation_hybrid_runbook_worker_group.linux.name}' 2>$null | ConvertFrom-Json

      if ($job) {
        $jobName = $job.name
        $maxWait = 180
        $waited = 0
        $status = "Running"

        while ($status -notin @('Completed', 'Failed', 'Stopped', 'Suspended') -and $waited -lt $maxWait) {
          Start-Sleep -Seconds 10
          $waited += 10
          $status = (az automation job show --automation-account-name '${var.automation_account_name}' --resource-group '${var.resource_group_name}' --name $jobName 2>$null | ConvertFrom-Json).status
          Write-Host "  $status ($waited s)"
        }

        Write-Host "Ubuntu hybrid worker test: $status"
      } else {
        Write-Host "Could not start job - worker may still be initializing"
      }
    EOT
  }

  depends_on = [
    null_resource.publish_test_runbook,
    null_resource.run_test_windows,
    azurerm_virtual_machine_extension.hybrid_worker_ubuntu,
    azurerm_virtual_machine_extension.ubuntu_powershell_setup
  ]

  triggers = {
    always_run = timestamp()
  }
}

resource "null_resource" "test_summary" {
  count = var.run_test_runbook ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["pwsh", "-Command"]
    command     = <<-EOT
      Write-Host ""
      Write-Host "Hybrid worker tests complete."
      Write-Host "Automation Account : ${var.automation_account_name}"
      Write-Host "Worker groups      : ${azurerm_automation_hybrid_runbook_worker_group.windows.name}, ${azurerm_automation_hybrid_runbook_worker_group.linux.name}"
      Write-Host ""
      Write-Host "To run the test manually:"
      Write-Host "  az automation runbook start --automation-account-name '${var.automation_account_name}' --resource-group '${var.resource_group_name}' --name 'Test-HybridWorker-ManagedIdentity' --run-on '<worker-group>'"
    EOT
  }

  depends_on = [
    null_resource.run_test_windows,
    null_resource.run_test_ubuntu
  ]

  triggers = {
    always_run = timestamp()
  }
}
