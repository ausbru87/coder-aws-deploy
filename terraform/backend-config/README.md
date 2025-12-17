# Terraform Backend Configuration

This directory contains backend configuration files for Terraform remote state storage in S3.

## Quick Setup

### 1. Create AWS Resources (One-Time Setup)

```bash
# Create S3 bucket for state storage
aws s3 mb s3://your-org-coder-terraform-state --region us-east-1

# Enable versioning (required for state recovery)
aws s3api put-bucket-versioning \
  --bucket your-org-coder-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket your-org-coder-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket your-org-coder-terraform-state \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name coder-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. Create Your Backend Config File

```bash
# For production deployment
cp prod.hcl.example prod.hcl
vim prod.hcl  # Update bucket name and other values

# For development deployment
cp dev.hcl.example dev.hcl
vim dev.hcl  # Update bucket name and other values
```

### 3. Initialize Terraform with Backend

```bash
# From terraform/ directory
terraform init -backend-config=backend-config/prod.hcl
```

## File Structure

- `prod.hcl.example` - Template for production environment backend config
- `dev.hcl.example` - Template for development environment backend config
- `prod.hcl` - Your actual production config (gitignored)
- `dev.hcl` - Your actual development config (gitignored)

## Important Notes

- **Never commit actual `.hcl` files** - Only `.hcl.example` templates should be in git
- The S3 bucket name must be **globally unique** across all AWS accounts
- The bucket and DynamoDB table **must exist before** running `terraform init`
- You can use the same bucket for multiple environments by using different `key` paths
- State locking prevents concurrent modifications to infrastructure

## Bucket Naming Convention

Recommended format: `<org-name>-<project>-terraform-state`

Examples:
- `acme-coder-terraform-state`
- `mycompany-dev-coder-terraform-state`

## Multiple Environments

To manage multiple environments with the same bucket:

```hcl
# prod.hcl
key = "coder/prod/terraform.tfstate"

# dev.hcl
key = "coder/dev/terraform.tfstate"

# staging.hcl
key = "coder/staging/terraform.tfstate"
```

## Troubleshooting

### Error: "bucket does not exist"
- Solution: Create the S3 bucket first (see step 1 above)

### Error: "table does not exist"
- Solution: Create the DynamoDB table first (see step 1 above)

### Error: "access denied"
- Solution: Ensure your AWS credentials have permissions for S3 and DynamoDB

## Security Best Practices

1. **Enable bucket versioning** - Allows state recovery
2. **Enable encryption** - Protects sensitive data in state
3. **Enable state locking** - Prevents concurrent modifications
4. **Block public access** - Prevents accidental exposure
5. **Use IAM policies** - Restrict access to authorized users only
6. **Enable CloudTrail** - Audit all state modifications

## See Also

- [Quick Start Guide](../../docs/getting-started/quickstart.md#step-04-create-terraform-backend)
- [Day 0 Deployment Guide](../../docs/operations/day0-deployment.md#step-23-configure-backend)
- [Terraform S3 Backend Documentation](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
