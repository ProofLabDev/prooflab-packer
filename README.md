# Ubuntu 22.04 NVIDIA Docker AMI Builder

This Packer configuration builds an Amazon Machine Image (AMI) based on Ubuntu 22.04 with NVIDIA drivers, CUDA toolkit, NVIDIA Container Toolkit, and Docker pre-installed.

## Prerequisites

- [Packer](https://www.packer.io/downloads) installed
- AWS credentials configured
- AWS CLI installed (optional)

## Features

- Ubuntu 22.04 LTS base
- NVIDIA Driver (535)
- CUDA Toolkit 12.3
- Docker CE
- NVIDIA Container Toolkit
- Configured for GPU workloads

## Usage

1. Initialize Packer plugins:

    ```bash
    packer init ubuntu-nvidia-docker.pkr.hcl
    ```

2. Build the AMI:

    ```bash
    packer build ubuntu-nvidia-docker.pkr.hcl
    ```

## Configuration

The build uses a `g4dn.xlarge` instance type by default, which includes an NVIDIA GPU. You can modify the `instance_type` in the configuration file if needed.

## Verification

After launching an instance with this AMI, you can verify the setup:

```bash
# Check NVIDIA driver
nvidia-smi

# Check CUDA version
nvcc --version

# Test Docker with NVIDIA GPU
docker run --rm --gpus all nvidia/cuda:12.3.0-base-ubuntu22.04 nvidia-smi
```

## Security

- The AMI is built with the latest security updates as of build time
- Docker is configured to use NVIDIA runtime by default
- The `ubuntu` user is added to the `docker` group for non-root Docker access

## License

MIT
