variable "template-to-derive" {
  type        = string
  description = "the name of the template to derive from"
  default     = "ubuntu-20.04-with-basic-tools"
}

variable "template-to-derive-version" {
  type        = string
  description = "the version of the template to derive from"
  default     = "1.2.0"
}

variable "vsphere_username" {
  type        = string
  description = "username to interact with vSphere"
  default     = ""
}

variable "vsphere_password" {
  type        = string
  description = "password of the vSphere user"
  default     = ""
}

variable "vSphere-cluster" {
  type        = string
  description = "map of clusters to use for the image provisioning"
  default     = "B01 Prod"
}

variable "vSphere-server" {
  type        = string
  description = "map of the urls of the vSphere api servers"
  default     = "b01-vc-01.hosting.alltimetech.co.uk"
}

variable "vSphere-datastore" {
  type        = string
  description = "map of datastores to use"
  default     = "B01-SAN-01-VOL-01"
}

variable "vm_network" {
  type        = string
  description = "map of networks to be used to spawn a vm to build the golden image template"
  default     = "B01-CORP-STAGING"
}

variable "resource_pool" {
  type        = string
  description = "map of resource pools to be used for the golden image template creation"
  default     = "Medneo/development resource pool"
}

variable "packer_user" {
  type        = string
  description = "user for the basic image provisioning"
  default     = "packer"
}


variable "vmware-host" {
  type        = string
  description = "map of the actual hosts to use for provisioning"
  default     = "b01-esxi-01.hosting.alltimetech.co.uk"
}

variable "is_release" {
  type        = bool
  description = "switch deciding if a given packer build is a potential production build or not"
  default     = false
}

variable "artifact_identifier" {
  type        = string
  description = "identifier for the artifacts created by the build"
  default     = "local"
}

variable "deployment_artifact_path" {
    type        = string
    description = "path to the folder at which the source project artifacts are located"
    default     = "deployment-artifacts"
}

variable "git_clone_token" {
    type        = string
    description = "github api token to enable cloning of private repos"
    default     = ""
}