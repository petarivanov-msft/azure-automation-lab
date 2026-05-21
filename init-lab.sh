#!/bin/bash
# Azure Automation Scenarios Lab - init script
# Usage: bash <(curl -s https://raw.githubusercontent.com/petarivanov-msft/azure-automation-lab/main/init-lab.sh)
# Note: use bash <(curl ...) not curl | bash - script needs interactive prompts

set -e

CYAN='\e[96m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

register_provider() {
  local ns=$1
  local status=$(az provider show --namespace "$ns" --query "registrationState" -o tsv 2>/dev/null || true)
  status=${status:-NotRegistered}

  if [ "$status" != "Registered" ]; then
    echo -e "${CYAN}Registering provider: ${YELLOW}$ns${CYAN}...${NC}"
    az provider register --namespace "$ns"
    until [ "$(az provider show --namespace "$ns" --query "registrationState" -o tsv)" == "Registered" ]; do
      echo -e "${CYAN}Waiting for ${YELLOW}$ns${CYAN} registration...${NC}"
      sleep 5
    done
    echo -e "${GREEN}Provider ${YELLOW}$ns${GREEN} registered successfully.${NC}"
  else
    echo -e "${GREEN}Provider ${YELLOW}$ns${GREEN} already registered.${NC}"
  fi
}

prompt_input() {

  local prompt_msg=$1
  local var_name=$2
  local current_value="${!var_name}"
  local input
  
  if [ -n "$current_value" ]; then
    echo -en "${CYAN}$prompt_msg ${YELLOW}[$current_value]${CYAN}: ${NC}"
    read -r input </dev/tty
    if [ -n "$input" ]; then
      printf -v "$var_name" '%s' "$input"
    fi
  else
    while [ -z "${!var_name}" ]; do
      echo -en "${CYAN}$prompt_msg: ${NC}"
      read -r input </dev/tty
      printf -v "$var_name" '%s' "$input"
    done
  fi
}

echo -e "${BLUE}========================================${NC}"
echo -e "${CYAN}Azure Automation Scenarios Lab${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Preflight checks
missing=0
for cmd in az terraform git; do
  if ! command -v "$cmd" &>/dev/null; then
    echo -e "${RED}Missing required tool: $cmd${NC}"
    missing=1
  fi
done
if [ "$missing" -eq 1 ]; then
  echo -e "${YELLOW}Install Azure CLI, Terraform >= 1.9.0, and git, then re-run.${NC}"
  exit 1
fi

# Verify az login
if ! az account show &>/dev/null; then
  echo -e "${RED}Not logged in to Azure CLI. Run 'az login' first.${NC}"
  exit 1
fi
echo -e "${GREEN}Azure CLI logged in as: $(az account show --query user.name -o tsv)${NC}"
echo ""

# Clone the repo (or pull latest if already cloned)
if [ ! -d "azure-automation-lab" ]; then
  echo -e "${CYAN}Cloning repository...${NC}"
  git clone https://github.com/petarivanov-msft/azure-automation-lab.git
else
  echo -e "${CYAN}Updating existing repository...${NC}"
  cd azure-automation-lab
  git fetch origin
  git reset --hard origin/main
  cd ..
fi

cd azure-automation-lab

# Set default values
RESOURCE_GROUP="rg-automation-lab"
LOCATION="uksouth"
AUTOMATION_ACCOUNT="auto-lab-$(date +%s)"
VM_ADMIN_USERNAME="azureadmin"

# Register necessary Azure providers
echo -e "${CYAN}Registering Azure providers...${NC}"
for ns in Microsoft.Automation Microsoft.Compute Microsoft.Network; do
  register_provider "$ns"
done

echo ""
echo -e "${CYAN}Configuration:${NC}"
echo ""

# Prompt for deployment parameters
prompt_input "Enter the name for the Azure Resource Group" RESOURCE_GROUP
prompt_input "Enter the Azure region (e.g., eastus, westus2)" LOCATION
prompt_input "Enter the Automation Account name" AUTOMATION_ACCOUNT
prompt_input "Enter VM admin username" VM_ADMIN_USERNAME

echo -e "${CYAN}Generating secure password for VMs...${NC}"
# Generate a password that meets Azure complexity requirements:
# 12+ chars, uppercase, lowercase, digit, special character.
VM_ADMIN_PASSWORD="$(openssl rand -base64 12)$(openssl rand -hex 2)!Aa"
export TF_VAR_vm_admin_password="$VM_ADMIN_PASSWORD"
# Persist password early so it survives script interruptions.
# The file is written inside terraform/ (gitignored) for easy re-export.

echo ""
echo -e "${CYAN}Network access:${NC}"
echo -e "  Lock RDP/WinRM/SSH to a specific source IP/CIDR (recommended)."
echo -e "  Examples: ${YELLOW}203.0.113.4/32${NC} or ${YELLOW}203.0.113.0/24${NC}"
echo -e "  Type ${YELLOW}*${NC} to open to the public internet (lab-only)."
ALLOWED_SOURCE_IP=""
ACK_OPEN_NSG="false"
while [ -z "$ALLOWED_SOURCE_IP" ]; do
  prompt_input "allowed_source_ip" ALLOWED_SOURCE_IP
  if [ "$ALLOWED_SOURCE_IP" == "*" ]; then
    echo -en "${YELLOW}'*' opens RDP/WinRM/SSH to the world. Type 'YES' to confirm: ${NC}"
    read -r confirm_open </dev/tty
    if [ "$confirm_open" != "YES" ]; then
      ALLOWED_SOURCE_IP=""
    else
      ACK_OPEN_NSG="true"
    fi
  fi
done

# Scenario selection
echo ""
echo -e "${CYAN}Scenarios:${NC}"
echo ""
echo -e "  ${YELLOW}1${NC}) Runbooks (PowerShell 5.1, PowerShell 7.4, Python 3.10)"
echo -e "  ${YELLOW}2${NC}) Hybrid Workers (Windows, Ubuntu, RHEL VMs)"
echo -e "  ${YELLOW}3${NC}) Graph API Automation (requires elevated permissions)"
echo ""
echo -e "  ${GREEN}a${NC}) Deploy ALL scenarios"
echo -e "  ${RED}n${NC}) Deploy NONE (core Automation Account only)"
echo ""
echo -e "${CYAN}Enter choice (comma-separated for multiple, e.g., 1,2 or 'a' for all):${NC}"
echo -en "${CYAN}Selection [a]: ${NC}"
read -r scenario_choice </dev/tty
scenario_choice=${scenario_choice:-a}

# Initialize all to false
ENABLE_RUNBOOKS="false"
ENABLE_HYBRID_WORKERS="false"
ENABLE_GRAPH_API="false"

# Parse selection
if [ "$scenario_choice" == "a" ] || [ "$scenario_choice" == "A" ]; then
  ENABLE_RUNBOOKS="true"
  ENABLE_HYBRID_WORKERS="true"
  ENABLE_GRAPH_API="true"
  echo -e "${GREEN}All scenarios selected.${NC}"
elif [ "$scenario_choice" != "n" ] && [ "$scenario_choice" != "N" ]; then
  # Parse comma-separated values
  IFS=',' read -ra SCENARIOS <<< "$scenario_choice"
  for scenario in "${SCENARIOS[@]}"; do
    scenario=$(echo "$scenario" | tr -d ' ')  # Remove whitespace
    case $scenario in
      1) ENABLE_RUNBOOKS="true" ;;
      2) ENABLE_HYBRID_WORKERS="true" ;;
      3) ENABLE_GRAPH_API="true" ;;
      *) echo -e "${RED}Unknown scenario: $scenario (ignored)${NC}" ;;
    esac
  done
fi

# Show selected scenarios
echo ""
echo -e "${CYAN}Scenarios to deploy:${NC}"
echo -e "  Runbooks (PS5.1/PS7.4/Python):  $([ "$ENABLE_RUNBOOKS" == "true" ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}")"
echo -e "  Hybrid Workers (3 VMs):         $([ "$ENABLE_HYBRID_WORKERS" == "true" ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}")"
echo -e "  Graph API:                      $([ "$ENABLE_GRAPH_API" == "true" ] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}")"

if [ "$ENABLE_HYBRID_WORKERS" == "true" ]; then
  echo ""
  echo -e "${YELLOW}Note: Hybrid Workers will create 3 VMs:${NC}"
  echo -e "  - Windows Server 2022 (Hybrid Worker)"
  echo -e "  - Ubuntu 22.04 LTS (Hybrid Worker)"
  echo -e "  - RHEL 9 (Hybrid Worker)"
fi

# Create terraform.tfvars file
echo ""
echo -e "${CYAN}Creating terraform.tfvars...${NC}"
cd terraform

cat > terraform.tfvars <<EOF
resource_group_name     = "$RESOURCE_GROUP"
location                = "$LOCATION"
automation_account_name = "$AUTOMATION_ACCOUNT"
vm_admin_username       = "$VM_ADMIN_USERNAME"
# vm_admin_password is supplied via the TF_VAR_vm_admin_password env var
# exported by init-lab.sh; do not write it here.

# Network access
allowed_source_ip    = "$ALLOWED_SOURCE_IP"
acknowledge_open_nsg = $ACK_OPEN_NSG

# Scenario toggles
enable_runbooks        = $ENABLE_RUNBOOKS
enable_hybrid_workers  = $ENABLE_HYBRID_WORKERS
enable_graph_api       = $ENABLE_GRAPH_API
EOF

echo -e "${GREEN}Done.${NC}"
echo ""

# Save password to a gitignored file right away so it survives Ctrl+C.
PASSWORD_FILE="$(pwd)/.vm_admin.password"
printf '%s' "$VM_ADMIN_PASSWORD" > "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE" 2>/dev/null || true

if [ -d ".terraform" ]; then
  echo -e "${CYAN}Re-using existing Terraform cache (.terraform/). Pass --upgrade to refresh providers.${NC}"
fi

INIT_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --upgrade) INIT_ARGS+=("-upgrade") ;;
  esac
done

# Initialize Terraform
echo -e "${CYAN}Initializing Terraform...${NC}"
terraform init "${INIT_ARGS[@]}"

# Run Terraform plan
echo ""
echo -e "${CYAN}Generating deployment plan...${NC}"
terraform plan -out=tfplan

# Apply Terraform
echo ""
echo -en "${YELLOW}Deploy the lab environment? (yes/no): ${NC}"
read -r confirm </dev/tty
if [[ "$confirm" == "yes" || "$confirm" == "y" || "$confirm" == "Y" ]]; then
  echo -e "${CYAN}Deploying...${NC}"
  echo -e "${YELLOW}This will take approximately 15-25 minutes...${NC}"
  terraform apply tfplan
  
  echo ""
  echo -e "${GREEN}Deployment complete.${NC}"
  echo ""
  ACTUAL_RG=$(terraform output -raw resource_group_name 2>/dev/null || echo "$RESOURCE_GROUP")
  echo -e "${CYAN}Resource Group:${NC} $ACTUAL_RG"
  echo -e "${CYAN}Location:${NC} $LOCATION"
  echo -e "${CYAN}Automation Account:${NC} $AUTOMATION_ACCOUNT"
  echo ""
  echo -e "VM credentials: username=$VM_ADMIN_USERNAME"
  echo -e "VM password saved to: ${YELLOW}$PASSWORD_FILE${NC} (gitignored, chmod 600)"
  echo -e "Re-export with: ${YELLOW}export TF_VAR_vm_admin_password=\$(cat $PASSWORD_FILE)${NC}"
  echo ""
  echo -e "${CYAN}Outputs:${NC} terraform output"
  echo ""
  echo -e "${YELLOW}Cleanup when done:${NC}"
  echo -e "  cd $(pwd)"
  echo -e "  terraform destroy -auto-approve"
  echo ""
else
  echo -e "${YELLOW}Deployment cancelled.${NC}"
  rm -f tfplan
fi
