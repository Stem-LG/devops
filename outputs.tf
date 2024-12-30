output "web_server_internal_ip" {
  value = virtualbox_vm.web_server.network_adapter.0.ipv4_address
}

output "db_server_internal_ip" {
  value = virtualbox_vm.db_server.network_adapter.0.ipv4_address
}