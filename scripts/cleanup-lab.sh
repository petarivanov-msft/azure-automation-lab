#!/bin/bash
# Destroy all lab resources.
# Run from the terraform directory, repo root, or scripts/ directory.

set -e

CYAN='\e[96m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}Azure Automation Lab - Cleanup${NC}"
echo ""

# Locate the terraform directory from common invocation points
if [ -f "terraform.tfstate" ] || [ -f "main.tf" ]; then
  TERRAFORM_DIR="."
elif [ -d "terraform" ] && [ -f "terraform/main.tf" ]; then
  TERRAFORM_DIR="terraform"
elif [ -d "../terraform" ] && [ -f "../terraform/main.tf" ]; then
  TERRAFORM_DIR="../terraform"
else
  echo -e "${RED}Error: cannot locate the terraform/ directory.${NC}"
  echo -e "${YELLOW}Run from the repo root, terraform/ directory, or scripts/ directory.${NC}"
  exit 1
fi

cd "$TERRAFORM_DIR"

echo -e "${YELLOW}WARNING: This will destroy all lab resources.${NC}"
echo ""

if [ -f "terraform.tfstate" ]; then
  echo -e "${CYAN}Resources in state:${NC}"
  terraform state list 2>/dev/null || echo "  (run terraform plan to see)"
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
