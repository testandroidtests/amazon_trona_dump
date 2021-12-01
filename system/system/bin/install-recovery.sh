#!/system/bin/sh
if ! applypatch -c EMMC:/dev/block/platform/bootdevice/by-name/recovery:15456256:3811fab6555c36d926b0906765cba03e269ec379; then
  applypatch  EMMC:/dev/block/platform/bootdevice/by-name/boot:9830400:dee9cb8c2f9c3152705bb97dce24b851d4142f09 EMMC:/dev/block/platform/bootdevice/by-name/recovery 0bc933a95209fcf0caad9debca29d27d878b7e64 15454208 dee9cb8c2f9c3152705bb97dce24b851d4142f09:/system/recovery-from-boot.p && installed=1 && log -t recovery "Installing new recovery image: succeeded" || log -t recovery "Installing new recovery image: failed"
  [ -n "$installed" ] && dd if=/system/recovery-sig of=/dev/block/platform/bootdevice/by-name/recovery bs=1 seek=15454208 && sync && log -t recovery "Install new recovery signature: succeeded" || log -t recovery "Installing new recovery signature: failed"
else
  log -t recovery "Recovery image already installed"
fi
