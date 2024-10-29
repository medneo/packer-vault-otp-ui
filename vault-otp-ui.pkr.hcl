source "vsphere-clone" "vault-otp-ui-vm" {

  convert_to_template = true
  template            = "${local.released_template_folder}/${var.template-to-derive}_${var.template-to-derive-version}"
  vm_name             = "vault_otp_ui_${var.artifact_identifier}"

  username              = local.vsphere_username
  password              = local.vsphere_password
  cluster               = var.vSphere-cluster
  vcenter_server        = var.vSphere-server
  host                  = var.vmware-host
  datastore             = var.vSphere-datastore
  folder                = local.template_directory
  resource_pool         = var.resource_pool


  ssh_username          = var.packer_user

  ssh_password          = local.packer_pwd

  network               = var.vm_network

  notes                 = <<NOTES
This is a VMWare template based on ubuntu 20.04, which will provide the
vault otp ui defined here https://github.com/medneo/vault-otp-ui
NOTES

  insecure_connection = true

}

build {
    name = "vault-otp-ui-vm"
    sources = [
        "source.vsphere-clone.vault-otp-ui-vm"
    ]
    provisioner "ansible-local" {
        playbook_file = "./ansible/prepare-steps.yml"
    }
    provisioner "file" {
        source          = var.deployment_artifact_path_tls
        destination     = "/var/srv/deployment"
    }
    provisioner "file" {
        source          = var.deployment_artifact_path_vault_otp_ui
        destination     = "/var/srv/deployment"
    }
    provisioner "ansible-local" {
        playbook_file   = "./ansible/install-check-mk-role.yml"
        extra_arguments = [
            "--extra-vars",
            "git_clone_token=${local.git_clone_token}"
        ]
    }

    provisioner "ansible-local" {
        playbook_file   = "./ansible/install-check-mk-agent.yml"
    }
}