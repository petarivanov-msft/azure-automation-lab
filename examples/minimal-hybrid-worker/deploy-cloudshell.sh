#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Azure Hybrid Worker Lab - Cloud Shell Deployment${NC}"
echo ""

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo "Terraform not found, installing..."
    wget -q https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
    unzip -q terraform_1.6.0_linux_amd64.zip
    sudo mv terraform /usr/local/bin/
    rm terraform_1.6.0_linux_amd64.zip
fi

terraform version
az account show --query "{Name:name, SubscriptionId:id}" --output table

read -p "$(echo -e ${YELLOW}Correct subscription? [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Set subscription with: az account set --subscription YOUR_SUBSCRIPTION_ID"
    exit 1
fi

echo -e "\n${GREEN}Initializing Terraform...${NC}"
terraform init

read -p "$(echo -e ${YELLOW}Show plan first? [y/N]: ${NC})" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    terraform plan
    read -p "$(echo -e ${YELLOW}Continue? [y/N]: ${NC})" -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
fi

echo -e "\n${GREEN}Deploying... (~7-10 minutes)${NC}"
start_time=$(date +%s)
terraform apply -auto-approve
end_time=$(date +%s)

duration=$((end_time - start_time))
echo -e "\n${GREEN}Done in $((duration / 60))m $((duration % 60))s${NC}\n"

terraform output

echo -e "\n${RED}Remember to run 'terraform destroy -auto-approve' when done to avoid charges!${NC}"
