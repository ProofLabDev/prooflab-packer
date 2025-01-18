packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "ubuntu-22-04-nvidia-docker-{{timestamp}}"
  instance_type = "g4dn.xlarge"  // GPU instance type
  region        = "us-west-2"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] // Canonical's AWS account ID
  }

  ssh_username = "ubuntu"

  launch_block_device_mappings {
    device_name = "/dev/sda1"
    volume_size = 50  // Size in GB
    volume_type = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name        = "Ubuntu 22.04 with NVIDIA Docker"
    Environment = "development"
    Builder     = "Packer"
  }
}

build {
  sources = ["source.amazon-ebs.ubuntu"]

  provisioner "shell" {
    inline = [
      "sleep 30",
      "sudo apt-get update",
      "sudo apt-get install -y ca-certificates curl gnupg linux-headers-$(uname -r)",
      
      # Install CUDA toolkit + drivers -- https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#meta-packages
      "wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb",
      "sudo dpkg -i cuda-keyring_1.1-1_all.deb",
      "sudo apt-get update",
      "sudo apt-get install -y cuda-12-6",  # Latest CUDA toolkit
      
      # Add Docker's official GPG key
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "sudo chmod a+r /etc/apt/keyrings/docker.gpg",
      
      # Add Docker repository
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      
      # Install Docker
      "sudo apt-get update",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      
      # Add NVIDIA Container Toolkit repository
      "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg",
      "curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list",
      
      # Install NVIDIA Container Toolkit
      "sudo apt-get update",
      "sudo apt-get install -y nvidia-container-toolkit",
      
      # Configure Docker to use NVIDIA Container Runtime
      "sudo nvidia-ctk runtime configure --runtime=docker",
      "sudo systemctl restart docker",
      
      # Add ubuntu user to docker group
      "sudo usermod -aG docker ubuntu",
      
      # Add CUDA environment variables to .bashrc
      "echo 'export PATH=/usr/local/cuda/bin:$PATH' >> /home/ubuntu/.bashrc",
      "echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> /home/ubuntu/.bashrc",
      
      # Source .bashrc to make variables available immediately
      ". /home/ubuntu/.bashrc",

      # Retart docker
      "sudo systemctl restart docker"
    ]
    execute_command = "bash -c '{{ .Vars }} {{ .Path }}'"
  }

  # Add reboot provisioner
  provisioner "shell" {
    expect_disconnect = true
    inline = ["sudo reboot"]
    execute_command = "bash -c '{{ .Vars }} {{ .Path }}'"
  }

  # Add pause to allow reboot to complete
  provisioner "shell" {
    pause_before = "60s"
    inline = ["echo 'System rebooted and ready'"]
    execute_command = "bash -c '{{ .Vars }} {{ .Path }}'"
  }

  # Test provisioner
  provisioner "shell" {
    inline = [
      # Source bashrc to get CUDA environment
      ". /home/ubuntu/.bashrc",
      
      "echo '### Testing NVIDIA Driver and CUDA Installation ###'",
      "nvidia-smi",
      
      "echo '### Testing Docker Installation ###'",
      "docker --version",
      "docker ps",
      "groups ubuntu | grep docker || echo 'docker group check failed'",
      
      "echo '### Testing NVIDIA Container Toolkit ###'",
      "nvidia-ctk --version",
      "docker info | grep -i nvidia",
    ]
    execute_command = "bash -c '{{ .Vars }} {{ .Path }}'"
  }
} 