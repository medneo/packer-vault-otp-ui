locals {
    released_template_folder  = "Production Resources/Templates"
    template_directory        = var.is_release ? "Production Resources/Templates" : "Development Resources/Templates"
}

local "vsphere_username" {
  expression = var.vsphere_username == "" ? vault("/secret/data/jenkins/terraform.tfvars","DC01_VSPHERE_CREDENTIALS_USR") : var.vsphere_username
  sensitive = true
}

local "vsphere_password" {
  expression = var.vsphere_password == "" ? vault("/secret/data/jenkins/terraform.tfvars","DC01_VSPHERE_CREDENTIALS_PWD") : var.vsphere_password
  sensitive = true
}

local "packer_pwd" {
  expression = vault("/secret/data/jenkins/terraform.tfvars","PACKER_CENTOS_PASSWORD")
  sensitive  = true
}

local "git_clone_token" {
    expression  = var.git_clone_token == "" ? vault("/secret/data/jenkins/terraform.tfvars","JENKINS_GITHUB_TOKEN") : var.git_clone_token
    sensitive   = true
}