terraform {
  required_version = ">= 0.12.8, <= 0.12.9"
}

provider "google" {
  version = "2.15"
  project = var.project
  region  = var.region
}

resource "google_compute_project_metadata_item" "ssh-keys" {
  key   = "ssh-keys"
  value = join("\n", var.ssh_keys)
}

resource "google_compute_instance" "app" {
  name         = "reddit-app${count.index}"
  count        = var.instance_count
  machine_type = "g1-small"
  zone         = var.zone
  tags         = ["reddit-app"]
  // metadata = {
  //   block-project-ssh-keys = false
  // }

  boot_disk {
    initialize_params {
      image = var.disk_image
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  provisioner "file" {
    source      = "files/puma.service"
    destination = "/tmp/puma.service"
  }

  provisioner "remote-exec" {
    script = "files/deploy.sh"
  }

  connection {
    type        = "ssh"
    host        = self.network_interface[0].access_config[0].nat_ip
    user        = "appuser"
    agent       = false
    private_key = file(var.private_key_path)
  }
}

resource "google_compute_firewall" "firewall_puma" {
  name    = "allow-puma-default"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["9292"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["reddit-app"]
}