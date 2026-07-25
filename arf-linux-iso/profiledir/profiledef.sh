#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="frenos"
iso_label="FRENOS_$(date +%Y%m)"
iso_publisher="FrenOS"
iso_application="FrenOS Live/Installation ISO"
iso_version="$(date +%Y.%m)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.bash_profile"]="0:0:755"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/usr/local/bin/arf-installer"]="0:0:755"
)
