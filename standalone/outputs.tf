# Outputs

output "f5vm01_mgmt_name" {
  description = "f5vm01 management device name"
  value       = module.bigip.name
}
output "f5vm01_mgmt_public_ip" {
  description = "f5vm01 management public IP address"
  value       = module.bigip.mgmtPublicIP
}
output "f5vm01_mgmt_pip_url" {
  description = "f5vm01 management public URL"
  value       = "https://${module.bigip.mgmtPublicIP}"
}
output "f5vm01_mgmt_private_ip" {
  description = "f5vm01 management private IP address"
  value       = google_compute_address.mgt.address
}
output "f5vm01_ext_private_ip" {
  description = "f5vm01 external primary IP address (self IP)"
  value       = google_compute_address.ext.address
}
output "f5vm01_int_private_ip" {
  description = "f5vm01 internal primary IP address (self IP)"
  value       = google_compute_address.int.address
}
output "tls_public_key" {
  value     = [trimspace(tls_private_key.ed25519.public_key_openssh)]
  sensitive = true
}