packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "ubuntu_version" {
  type        = string
  default     = "noble"
  description = "Ubuntu codename version (i.e. 20.04 is focal and 22.04 is jammy)"
}

source "qemu" "ubuntu" {
  cd_files         = ["./cloud-init/*"]
  cd_label         = "cidata"
  disk_compression = true
  disk_image       = true
  disk_size        = "10G"
  headless         = true
  iso_checksum     = "file:https://cloud-images.ubuntu.com/${var.ubuntu_version}/current/SHA256SUMS"
  iso_url          = "https://cloud-images.ubuntu.com/${var.ubuntu_version}/current/${var.ubuntu_version}-server-cloudimg-amd64.img"
  output_directory = "output-${var.ubuntu_version}"
  shutdown_command = "echo 'ubuntu' | sudo -S shutdown -P now"
  ssh_password     = "ubuntu"
  ssh_username     = "ubuntu"
  vm_name          = "ubuntu-${var.ubuntu_version}.img"
  qemuargs = [
    ["-m", "2048M"],
    ["-smp", "2"],
    ["-serial", "mon:stdio"],
  ]
}

build {
  sources = ["source.qemu.ubuntu"]

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    // NOTE: cleanup.sh should always be run last, as this performs post-install cleanup tasks
    scripts = [
      "scripts/install.sh",
      "scripts/cleanup.sh"
    ]
  }

  # from https://github.com/macauyeah/ubuntuPackerImage
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "/usr/bin/apt-get clean",
      "rm -r /etc/netplan/50-cloud-init.yaml /etc/ssh/ssh_host* /etc/sudoers.d/90-cloud-init-users",
      "/usr/bin/truncate --size 0 /etc/machine-id",
      "/usr/bin/gawk -i inplace '/PasswordAuthentication/ { gsub(/yes/, \"no\") }; { print }' /etc/ssh/sshd_config",
      "rm -r /root/.ssh",
      "rm /snap/README",
      "find /usr/share/netplan -name __pycache__ -exec rm -r {} +",
      "rm -f /var/cache/pollinate/seeded /var/cache/motd-news",
      "rm -fr /var/cache/snapd/*",
      "rm -r /var/lib/cloud /var/lib/dbus/machine-id /var/lib/private /var/lib/systemd/timers /var/lib/systemd/timesync /var/lib/systemd/random-seed",
      "rm /var/lib/ubuntu-release-upgrader/release-upgrade-available",
      "rm /var/lib/update-notifier/fsck-at-reboot",
      "find /var/log -type f -exec rm {} +",
      "rm -r /tmp/* /tmp/.*-unix /var/tmp/*",
      "/bin/sync",
      "/sbin/fstrim -v /"
    ]
    remote_folder   = "/tmp"
    valid_exit_codes = [0, 1]
  }
}
