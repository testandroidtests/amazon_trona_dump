#!/system/bin/sh
if ! applypatch -c EMMC:/dev/block/platform/bootdevice/by-name/recovery:15450112:8f8c1a86e59b2a4f2247c4abb832bd4a6c9d50a8; then
  applypatch  EMMC:/dev/block/platform/bootdevice/by-name/boot:9822208:45c70ad5d20c6ef794da8c921a0e6212bcd66a8a EMMC:/dev/block/platform/bootdevice/by-name/recovery 8933ec975632ee7490a174f5a03855bf39b387bb 15448064 45c70ad5d20c6ef794da8c921a0e6212bcd66a8a:/system/recovery-from-boot.p && installed=1 && log -t recovery "Installing new recovery image: succeeded" || log -t recovery "Installing new recovery image: failed"
  [ -n "$installed" ] && dd if=/system/recovery-sig of=/dev/block/platform/bootdevice/by-name/recovery bs=1 seek=15448064 && sync && log -t recovery "Install new recovery signature: succeeded" || log -t recovery "Installing new recovery signature: failed"
else
  log -t recovery "Recovery image already installed"
fi
