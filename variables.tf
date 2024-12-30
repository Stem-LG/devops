variable "ubuntu_image" {
  type    = string
  default = "/home/unknown/Downloads/bionic-server-cloudimg-amd64-vagrant.box"
}

variable "web_server_name" {
  type    = string
  default = "web-server"
}

variable "db_server_name" {
  type    = string
  default = "db-server"
}