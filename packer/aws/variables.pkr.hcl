variable "aws_region" {
  type        = string
  description = "AWS region for the build"
  default     = "eu-central-1"
}

variable "aws_instance_type" {
  type        = string
  description = "EC2 instance type for the Packer build"
  default     = "t3.small"
}

variable "aws_source_ami_owner" {
  type        = string
  description = "AWS account ID or canonical ID (e.g. 099720109477 for Canonical) that owns the source AMI"
}

variable "base_ami_name_pattern" {
  type        = string
  description = "Name filter for source AMI. Use golden image pattern (e.g. ubuntu-base-*-prod-*) or Canonical (ubuntu/images/hvm-ssd/ubuntu-*-22.04-amd64-server-*)"
  default     = "ubuntu-base-*-prod-*"
}

variable "base_ami_ubuntu_version" {
  type        = string
  description = "Ubuntu version for name filter when using Canonical AMIs (e.g. 22.04)"
  default     = "22.04"
}

variable "artifact_identifier" {
  type        = string
  description = "Identifier for the AMI (e.g. git SHA, tag, or local)"
  default     = "local"
}

variable "is_release" {
  type        = bool
  description = "True when building from a release tag"
  default     = false
}

variable "vault_otp_ui_image" {
  type        = string
  description = "Docker image for vault-otp-ui (e.g. medneo-docker.jfrog.io/vault-otp-ui:1.0.0)"
  default     = "medneo-docker.jfrog.io/vault-otp-ui:1.0.0"
}

variable "use_golden_image_filter" {
  type        = bool
  description = "When true, use golden image name pattern; when false, use Canonical Ubuntu AMI filter"
  default     = true
}

variable "docker_images_tar_path" {
  type        = string
  description = "Path to tar of pre-pulled Docker images (created by GHA). When empty, images must be pulled at runtime."
  default     = ""
}
