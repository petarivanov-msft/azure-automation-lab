#!/bin/bash
# Destroy all lab resources.
# Run from the terraform directory or repo root.

set -e

CYAN='\e[96m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}Azure Automation Lab - Cleanup${NC}"
echo ""

if [ ! -f "terraform.tfvars" ] && [ ! -f "../terraform/terraform.tfvars" ]; then
  echo -e "${RED}Error: terraform.tfvars not found.${NC}"
  echo -e "${YELLOW}Run from the terraform directory or repo root.${NC}"
  exit 1
fi

if [ -f "terraform.tfvars" ]; then
  TERRAFORM_DIR="."
else
  TERRAFORM_DIR="../terraform"
  cd "$TERRAFORM_DIR"
fi

echo -e "${YELLOW}WARNING: This will destroy all lab resources.${NC}"
echo ""

if [ -f "terraform.tfstate" ]; then
  echo -e "${CYAN}Resources in state:${NC}"
  terraform show -json | jq -r '.values.root_module.resources[].address' 2>/dev/null || echo "  (run terraform plan to see)"
  echo ""
fi

read -rp "$(echo -e "${RED}Destroy everything? (yes/no): ${NC}")" confirm

if [ "$confirm" == "yes" ]; then
  echo ""
  echo -e "${CYAN}Destroying...${NC}"
  terraform destroy -auto-approve
  echo ""
  echo -e "${GREEN}Done. All resources removed.${NC}"
  echo ""
else
  echo -e "${YELLOW}Cancelled.${NC}"
fi
