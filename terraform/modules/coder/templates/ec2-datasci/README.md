# EC2-based Data Science Workspace Template

This template creates an EC2-based workspace for data science and machine learning workloads with optional GPU support.

## Features

- **Base OS**: Ubuntu 22.04 LTS (CUDA), Amazon Linux 2023 (CUDA)
- **GPU Options**: g4dn (T4), g5 (A10G), p3 (V100), p4d (A100)
- **Pre-installed**: Jupyter Lab, Python, PyTorch, TensorFlow, CUDA
- **Auto-start/Auto-stop**: Configured for 0700/1800 ET
- **High-performance Storage**: gp3 EBS with 3000 IOPS

## T-Shirt Sizes

| Size | vCPU | RAM | Storage | GPU Options | Use Case |
|------|------|-----|---------|-------------|----------|
| Data Sci Standard | 8 | 32GB | 500GB | None, T4, A10G, V100 | Data analysis, light ML |
| Data Sci Large | 16 | 64GB | 1TB | None, T4, A10G, V100, A100 | ML training |
| Data Sci XLarge | 32 | 64GB | 2TB | 4x T4, 4x A10G, 8x V100, 8x A100 | Large-scale ML |

## GPU Instance Types

| GPU Type | Instance Family | GPU Model | Use Case |
|----------|-----------------|-----------|----------|
| g4dn | g4dn.xlarge - g4dn.12xlarge | NVIDIA T4 | Inference, light training |
| g5 | g5.xlarge - g5.12xlarge | NVIDIA A10G | Balanced training |
| p3 | p3.2xlarge - p3.16xlarge | NVIDIA V100 | High-performance training |
| p4d | p4d.24xlarge | NVIDIA A100 | Enterprise ML, 8x A100 |

## Requirements Covered

- **11.4**: Initial templates include ec2-datasci
- **11.8**: GPU instance types and ML tooling
- **14.7a**: GPU nodes not pre-warmed, provisioning up to 5 min

## Usage

1. Push this template to Coder:
   ```bash
   coder templates push ec2-datasci --directory ./templates/ec2-datasci
   ```

2. Configure auto-start/auto-stop schedule in Coder admin settings

3. Users can create workspaces from this template via the Coder UI

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `vpc_id` | VPC ID for the workspace | Required |
| `subnet_id` | Subnet ID for the workspace | Required |
| `instance_profile_name` | IAM instance profile name | Required |
| `default_region` | Default AWS region | `us-east-1` |

## Pre-installed Software

The Deep Learning AMI includes:
- Python 3.10+ with pip and conda
- Jupyter Lab
- PyTorch (latest stable)
- TensorFlow (latest stable)
- CUDA Toolkit and cuDNN
- NumPy, Pandas, Scikit-learn
- Matplotlib, Seaborn
- Git

## GPU Provisioning Note

**Important**: GPU instances are not pre-warmed to optimize costs. Provisioning time may be up to 5 minutes depending on GPU availability in the selected region. This is expected behavior per Requirement 14.7a.

## Security

- Security group allows only outbound HTTPS/HTTP and DNS
- EBS volumes are encrypted at rest
- IAM instance profile provides least-privilege access
- Workspace is isolated in private subnet
