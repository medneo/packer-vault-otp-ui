packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1.2"
    }
  }
}

source "amazon-ebs" "vault-otp-ui" {
  ami_name = "vault-otp-ui-${var.artifact_identifier}"

  source_ami_filter {
    filters = merge(
      {
        name                = var.use_golden_image_filter ? var.base_ami_name_pattern : "ubuntu/images/hvm-ssd/ubuntu-*-${var.base_ami_ubuntu_version}-amd64-server-*"
        root-device-type    = "ebs"
        virtualization-type = "hvm"
      },
      var.use_golden_image_filter ? { "tag:OS" = "ubuntu", "tag:Environment" = "prod" } : {}
    )
    owners      = [var.aws_source_ami_owner]
    most_recent = true
  }

  instance_type = var.aws_instance_type
  region        = var.aws_region

  ssh_username = "ubuntu"
  ssh_timeout  = "10m"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 12
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name        = "vault-otp-ui-${var.artifact_identifier}"
    Application = "vault-otp-ui"
    BuildDate   = timestamp()
  }
}

build {
  name = "vault-otp-ui-aws"

  sources = ["source.amazon-ebs.vault-otp-ui"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update -qq",
      "sudo apt-get install -y -qq ca-certificates curl gnupg",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "sudo chmod a+r /etc/apt/keyrings/docker.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update -qq",
      "sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo usermod -aG docker ubuntu"
    ]
  }

  provisioner "file" {
    source      = var.docker_images_tar_path != "" ? var.docker_images_tar_path : "/dev/null"
    destination = "/tmp/docker-images.tar"
  }

  provisioner "shell" {
    script           = "${path.root}/../../scripts/install-app.sh"
    environment_vars = ["DOCKER_IMAGES_TAR_PATH=/tmp/docker-images.tar"]
  }

  provisioner "file" {
    source      = "${path.root}/../../docker-compose-vault-otp-ui.yml"
    destination = "/tmp/docker-compose-vault-otp-ui.yml"
  }

  provisioner "file" {
    source      = "${path.root}/../../nginx-healthz.conf"
    destination = "/tmp/nginx-healthz.conf"
  }

  provisioner "file" {
    source      = "${path.root}/../../docker-compose-tls-override.yml"
    destination = "/tmp/docker-compose-tls-override.yml"
  }

  provisioner "file" {
    source      = "${path.root}/../../Caddyfile.tls"
    destination = "/tmp/Caddyfile.tls"
  }

  provisioner "shell" {
    inline = [
      "sudo mkdir -p /opt/vault-otp-ui",
      "sudo cp /tmp/docker-compose-vault-otp-ui.yml /opt/vault-otp-ui/docker-compose.yml",
      "sudo cp /tmp/nginx-healthz.conf /opt/vault-otp-ui/nginx-healthz.conf",
      "sudo cp /tmp/docker-compose-tls-override.yml /opt/vault-otp-ui/docker-compose-tls-override.yml",
      "sudo cp /tmp/Caddyfile.tls /opt/vault-otp-ui/Caddyfile.tls",
      "echo 'LOG_GROUP=ec2/docker' | sudo tee /opt/vault-otp-ui/.env",
      "echo 'AWS_REGION=eu-central-1' | sudo tee -a /opt/vault-otp-ui/.env",
      "sudo chown -R ubuntu:ubuntu /opt/vault-otp-ui"
    ]
  }

  provisioner "file" {
    source      = "${path.root}/../systemd/vault-otp-ui.service"
    destination = "/tmp/vault-otp-ui.service"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/vault-otp-ui.service /etc/systemd/system/vault-otp-ui.service",
      "sudo systemctl enable vault-otp-ui.service"
    ]
  }
}
