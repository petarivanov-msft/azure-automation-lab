terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowRDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.allowed_source_ip
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_public_ip" "pip" {
  name                = "${var.prefix}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
  tags                = var.tags
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }

  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "nsg_nic" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "random_password" "vm_password" {
  length  = 16
  special = true
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = "${var.prefix}-vm"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.vm_password.result

  network_interface_ids = [azurerm_network_interface.nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_automation_account" "automation" {
  name                = "${var.prefix}-automation"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Terraform doesn't expose automationHybridServiceUrl directly, so we fetch it via REST
data "external" "automation_hybrid_url" {
  program = ["bash", "-c", <<-EOT
    set -e
    result=$(az rest --method get --url "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.Automation/automationAccounts/${azurerm_automation_account.automation.name}?api-version=2023-11-01" 2>/dev/null || echo '{}')
    url=$(echo "$result" | jq -r '.properties.automationHybridServiceUrl // "placeholder"')
    echo "{\"url\":\"$url\"}"
  EOT
  ]

  depends_on = [azurerm_automation_account.automation]
}

resource "random_uuid" "worker_id" {}

resource "azurerm_automation_hybrid_runbook_worker_group" "worker_group" {
  name                    = "${var.prefix}-worker-group"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation.name
}

# VM must be registered before the extension is installed — otherwise machineId association fails
resource "azurerm_automation_hybrid_runbook_worker" "worker" {
  automation_account_name = azurerm_automation_account.automation.name
  resource_group_name     = azurerm_resource_group.rg.name
  worker_group_name       = azurerm_automation_hybrid_runbook_worker_group.worker_group.name
  vm_resource_id          = azurerm_windows_virtual_machine.vm.id
  worker_id               = random_uuid.worker_id.result
}

resource "azurerm_virtual_machine_extension" "hybrid_worker" {
  name                       = "HybridWorkerExtension"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.Automation.HybridWorker"
  type                       = "HybridWorkerForWindows"
  type_handler_version       = "1.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    AutomationAccountURL = data.external.automation_hybrid_url.result.url
  })

  protected_settings = jsonencode({
    HybridWorkerGroupName = azurerm_automation_hybrid_runbook_worker_group.worker_group.name
  })

  depends_on = [
    azurerm_automation_hybrid_runbook_worker.worker,
    data.external.automation_hybrid_url
  ]

  tags = var.tags
}

data "azurerm_subscription" "current" {}

resource "azurerm_role_assignment" "automation_contributor" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_automation_account.automation.identity[0].principal_id
  depends_on           = [azurerm_automation_account.automation]
}

resource "azurerm_role_assignment" "vm_contributor" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_windows_virtual_machine.vm.identity[0].principal_id
  depends_on           = [azurerm_windows_virtual_machine.vm]
}

resource "azurerm_virtual_machine_extension" "powershell_modules" {
  name                       = "InstallPowerShellModules"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force; Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; Install-Module -Name Az.Accounts -Force -AllowClobber; Install-Module -Name Az.Compute -Force -AllowClobber; Write-Host 'PowerShell modules installed successfully'\""
  })

  depends_on = [azurerm_virtual_machine_extension.hybrid_worker]

  tags = var.tags
}

resource "azurerm_automation_module" "az_accounts" {
  name                    = "Az.Accounts"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Accounts"
  }
}

resource "azurerm_automation_module" "az_compute" {
  name                    = "Az.Compute"
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation.name

  module_link {
    uri = "https://www.powershellgallery.com/api/v2/package/Az.Compute"
  }

  depends_on = [azurerm_automation_module.az_accounts]
}

resource "azurerm_automation_runbook" "test_hybrid_worker" {
  name                    = "Test-HybridWorker-ManagedIdentity"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  automation_account_name = azurerm_automation_account.automation.name
  log_verbose             = true
  log_progress            = true
  description             = "Test runbook that uses managed identity to connect to Azure and list VMs"
  runbook_type            = "PowerShell"

  content = <<-EOT
    <#
    .SYNOPSIS
        Test runbook for Hybrid Worker using Managed Identity
    #>
    
    Write-Output "Connecting to Azure using Managed Identity..."
    try {
        Connect-AzAccount -Identity -ErrorAction Stop
        Write-Output "Successfully connected to Azure!"
        
        $context = Get-AzContext
        Write-Output "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
        Write-Output "Tenant: $($context.Tenant.Id)"
        
    } catch {
        Write-Error "Failed to connect to Azure: $_"
        throw
    }
    
    Write-Output "`n--- Listing all VMs in the subscription ---"
    try {
        $vms = Get-AzVM
        Write-Output "Found $($vms.Count) VM(s) in the subscription:"
        
        foreach ($vm in $vms) {
            Write-Output "`nVM Name: $($vm.Name)"
            Write-Output "  Resource Group: $($vm.ResourceGroupName)"
            Write-Output "  Location: $($vm.Location)"
            Write-Output "  VM Size: $($vm.HardwareProfile.VmSize)"
            Write-Output "  OS Type: $($vm.StorageProfile.OsDisk.OsType)"
            Write-Output "  Provisioning State: $($vm.ProvisioningState)"
        }
    } catch {
        Write-Error "Failed to list VMs: $_"
    }
    
    Write-Output "`n--- Getting details about the Hybrid Worker VM ---"
    try {
        $currentVM = Get-AzVM -ResourceGroupName "${azurerm_resource_group.rg.name}" -Name "${var.prefix}-vm" -Status
        Write-Output "VM Name: $($currentVM.Name)"
        Write-Output "Power State: $($currentVM.PowerState)"
        Write-Output "VM Agent Status: $($currentVM.VMAgent.Statuses[0].DisplayStatus)"
        
        Write-Output "`nInstalled Extensions:"
        foreach ($ext in $currentVM.Extensions) {
            Write-Output "  - $($ext.Name) (Type: $($ext.Type))"
        }
        
    } catch {
        Write-Error "Failed to get current VM details: $_"
    }
    
    Write-Output "`n--- Runbook execution completed successfully ---"
  EOT

  depends_on = [
    azurerm_automation_module.az_compute,
    azurerm_automation_hybrid_runbook_worker.worker
  ]

  tags = var.tags
}

resource "null_resource" "publish_runbook" {
  provisioner "local-exec" {
    command     = <<-EOT
      #!/bin/bash
      set -e
      runbook=$(az automation runbook show \
        --automation-account-name ${azurerm_automation_account.automation.name} \
        --resource-group ${azurerm_resource_group.rg.name} \
        --name ${azurerm_automation_runbook.test_hybrid_worker.name} 2>/dev/null || echo '{}')
      
      state=$(echo "$runbook" | jq -r '.state // ""')
      
      if [ "$state" != "Published" ]; then
        echo "Publishing runbook..."
        az automation runbook publish \
          --automation-account-name ${azurerm_automation_account.automation.name} \
          --resource-group ${azurerm_resource_group.rg.name} \
          --name ${azurerm_automation_runbook.test_hybrid_worker.name}
      else
        echo "Runbook is already published"
      fi
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [azurerm_automation_runbook.test_hybrid_worker]

  triggers = {
    runbook_content = sha256(azurerm_automation_runbook.test_hybrid_worker.content)
  }
}

resource "null_resource" "run_test_runbook" {
  count = var.run_test_runbook ? 1 : 0

  provisioner "local-exec" {
    command     = <<-EOT
      #!/bin/bash
      set -e
      echo "Starting test runbook on hybrid worker..."
      
      job=$(az automation runbook start \
        --automation-account-name ${azurerm_automation_account.automation.name} \
        --resource-group ${azurerm_resource_group.rg.name} \
        --name ${azurerm_automation_runbook.test_hybrid_worker.name} \
        --run-on ${azurerm_automation_hybrid_runbook_worker_group.worker_group.name})
      
      jobName=$(echo "$job" | jq -r '.name')
      echo "Job started: $jobName"
      
      maxWait=120
      waited=0
      status="Running"
      
      while [[ "$status" != "Completed" && "$status" != "Failed" && "$status" != "Stopped" && "$status" != "Suspended" && $waited -lt $maxWait ]]; do
        sleep 5
        waited=$((waited + 5))
        
        jobStatus=$(az automation job show \
          --automation-account-name ${azurerm_automation_account.automation.name} \
          --resource-group ${azurerm_resource_group.rg.name} \
          --name "$jobName")
        
        status=$(echo "$jobStatus" | jq -r '.status')
        echo -n "."
      done
      
      echo ""
      echo "Job Status: $status"
      
      if [ "$status" == "Completed" ]; then
        echo ""
        echo "========== RUNBOOK OUTPUT =========="
        
        subscriptionId=$(az account show --query id -o tsv)
        outputUrl="/subscriptions/$subscriptionId/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.Automation/automationAccounts/${azurerm_automation_account.automation.name}/jobs/$jobName/output?api-version=2023-11-01"
        
        output=$(az rest --method get --url "$outputUrl")
        echo "$output"
        
        echo ""
        echo "========== END OUTPUT =========="
      else
        echo "Job did not complete successfully. Status: $status"
      fi
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    null_resource.publish_runbook,
    azurerm_virtual_machine_extension.hybrid_worker,
    azurerm_virtual_machine_extension.powershell_modules
  ]

  triggers = {
    always_run = timestamp()
  }
}
