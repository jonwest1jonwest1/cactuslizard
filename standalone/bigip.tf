# BIG-IP

############################ Public IPs ############################

# Create Public IPs - VIP
resource "google_compute_address" "vip1" {
  name = format("%s-vip1-%s", var.projectPrefix, random_id.buildSuffix.hex)
}

# Forwarding rule for Public IP
resource "google_compute_forwarding_rule" "vip1" {
  name       = format("%s-forwarding-rule-%s", var.projectPrefix, random_id.buildSuffix.hex)
  target     = google_compute_target_instance.f5vm01.id
  ip_address = google_compute_address.vip1.address
  port_range = "1-65535"
}

resource "google_compute_target_instance" "f5vm01" {
  name     = format("%s-ti-%s", var.projectPrefix, random_id.buildSuffix.hex)
  instance = module.bigip.bigip_instance_ids
  zone     = var.gcp_zone_1
}

############################ Private IPs ############################

# Reserve IPs on external subnet for BIG-IP 1 nic0
resource "google_compute_address" "ext" {
  name         = format("%s-bigip-ext-%s", var.projectPrefix, random_id.buildSuffix.hex)
  subnetwork   = var.extSubnet
  address_type = "INTERNAL"
  region       = replace(var.gcp_zone_1, "/-[a-z]$/", "")
}

# Reserve VIP on external subnet for BIG-IP 1 nic0
resource "google_compute_address" "vip" {
  name         = format("%s-bigip-ext-vip-%s", var.projectPrefix, random_id.buildSuffix.hex)
  subnetwork   = var.extSubnet
  address_type = "INTERNAL"
  region       = replace(var.gcp_zone_1, "/-[a-z]$/", "")
}

# Reserve IPs on management subnet for BIG-IP 1 nic1
resource "google_compute_address" "mgt" {
  name         = format("%s-bigip-mgt-%s", var.projectPrefix, random_id.buildSuffix.hex)
  subnetwork   = var.mgmtSubnet
  address_type = "INTERNAL"
  region       = replace(var.gcp_zone_1, "/-[a-z]$/", "")
}

# Reserve IPs on internal subnet for BIG-IP 1 nic2
resource "google_compute_address" "int" {
  name         = format("%s-bigip-int-%s", var.projectPrefix, random_id.buildSuffix.hex)
  subnetwork   = var.intSubnet
  address_type = "INTERNAL"
  region       = replace(var.gcp_zone_1, "/-[a-z]$/", "")
}

############################ Generate SSH Key ############################

resource "tls_private_key" "ed25519" {
  algorithm = "ED25519"
}

# Public key loaded from a terraform-generated private key, using the PEM (RFC 1421) format
data "tls_public_key" "private_key_pem" {
  private_key_pem = tls_private_key.ed25519.private_key_pem
}

############################ Onboard Scripts ############################

# Setup Onboarding scripts
locals {
  f5_onboard1 = templatefile("${path.module}/f5_onboard.tmpl", {
    regKey                            = var.license1
    f5_username                       = var.f5_username
    f5_password                       = var.f5_password
    gcp_secret_manager_authentication = var.gcp_secret_manager_authentication
    ssh_keypair                       = tls_private_key.ed25519.public_key_openssh
    svc_acct                          = var.svc_acct
    telemetry_secret                  = var.telemetry_secret
    telemetry_privateKeyId            = var.telemetry_privateKeyId
    gcp_project_id                    = var.gcp_project_id
    INIT_URL                          = var.INIT_URL
    DO_URL                            = var.DO_URL
    AS3_URL                           = var.AS3_URL
    TS_URL                            = var.TS_URL
    FAST_URL                          = var.FAST_URL
    DO_VER                            = split("/", var.DO_URL)[7]
    AS3_VER                           = split("/", var.AS3_URL)[7]
    TS_VER                            = split("/", var.TS_URL)[7]
    FAST_VER                          = split("/", var.FAST_URL)[7]
    dns_server                        = var.dns_server
    dns_suffix                        = var.dns_suffix
    ntp_server                        = var.ntp_server
    timezone                          = var.timezone
    bigIqLicenseType                  = var.bigIqLicenseType
    bigIqHost                         = var.bigIqHost
    bigIqPassword                     = var.bigIqPassword
    bigIqUsername                     = var.bigIqUsername
    bigIqLicensePool                  = var.bigIqLicensePool
    bigIqSkuKeyword1                  = var.bigIqSkuKeyword1
    bigIqSkuKeyword2                  = var.bigIqSkuKeyword2
    bigIqUnitOfMeasure                = var.bigIqUnitOfMeasure
    bigIqHypervisor                   = var.bigIqHypervisor
    NIC_COUNT                         = true
    public_vip                        = google_compute_address.vip1.address
  })

}

############################ Compute ############################

module "bigip" {
  source              = "./terraform-gcp-bigip-module"
  prefix              = var.projectPrefix
  vm_name             = format("%s-bigip1-%s", var.projectPrefix, random_id.buildSuffix.hex)
  project_id          = var.gcp_project_id
  machine_type        = var.machine_type
  image               = var.image_name
  f5_username         = var.f5_username
  f5_ssh_publickey    = tls_private_key.ed25519.public_key_openssh
  service_account     = var.svc_acct
  mgmt_subnet_ids     = [{ "subnet_id" = var.mgmtSubnet, "public_ip" = true, "private_ip_primary" = google_compute_address.mgt.address }]
  external_subnet_ids = [{ "subnet_id" = var.extSubnet, "public_ip" = true, "private_ip_primary" = google_compute_address.ext.address, "private_ip_secondary" = google_compute_address.vip.address }]
  internal_subnet_ids = [{ "subnet_id" = var.intSubnet, "public_ip" = false, "private_ip_primary" = google_compute_address.int.address, "private_ip_secondary" = "" }]
  zone                = var.gcp_zone_1
  custom_user_data    = local.f5_onboard1
  sleep_time          = "30s"
}

