terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.90"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  token     = var.yandex_token
  cloud_id  = var.yandex_cloud_id
  folder_id = var.yandex_folder_id
  zone      = var.yandex_zone
}

variable "yandex_token" { description = "Yandex Cloud OAuth token" }
variable "yandex_cloud_id" { description = "Yandex Cloud ID" }
variable "yandex_folder_id" { description = "Yandex Cloud Folder ID" }
variable "yandex_zone" {
  description = "Зона"
  default = "ru-central1-a"
}

resource "yandex_vpc_network" "network" {
  name = "bookstore-network20"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "bookstore-subnet20"
  zone           = var.yandex_zone
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.1.0/24"]
}

data "yandex_compute_image" "ubuntu" {
  family      = "ubuntu-2404-lts-oslogin"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "${path.module}/id_rsa"
}

resource "local_file" "public_key" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = "${path.module}/id_rsa.pub"
}

resource "yandex_compute_instance" "vm" {
  name        = "bookstore-vm20"
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = <<EOF
  #cloud-config
  packages:
    - docker.io
  runcmd:
    - systemctl enable docker
    - systemctl start docker
    - docker run -d -p 80:8080 jmix/jmix-bookstore
  EOF
  }
}

output "ssh_connection_string" {
  value = "ssh -i id_rsa ipiris@${yandex_compute_instance.vm.network_interface.0.nat_ip_address}"
}

output "web_app_url" {
  value = "http://${yandex_compute_instance.vm.network_interface.0.nat_ip_address}"
}