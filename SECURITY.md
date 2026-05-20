# Security Policy

## Reporting a Vulnerability

Please report security vulnerabilities through GitHub's private vulnerability reporting:

1. Go to the [Security tab](https://github.com/petarivanov-msft/azure-hybrid-worker-lab/security)
2. Click "Report a vulnerability"
3. Include description, steps to reproduce, and potential impact

## Security Considerations

This is a lab/demo environment. Before using in production:

- Restrict NSG rules to specific IP addresses (set `allowed_source_ip` variable)
- Review and narrow RBAC role assignments
- Enable Azure Disk Encryption
- Configure a remote Terraform state backend
- Never commit `terraform.tfvars` files containing passwords
