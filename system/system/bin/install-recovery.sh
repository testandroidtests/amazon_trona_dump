#!/system/bin/sh
if ! applypatch -c EMMC:/dev/block/platform/bootdevice/by-name/recovery:15462400:09899e30b02bb1534dd831d2375f5213c415fdc3; then
  applypatch  EMMC:/dev/block/platform/bootdevice/by-name/boot:9818112:10716c276b7cca9c30809d20d7d4f16947eefe01 EMMC:/dev/block/platform/bootdevice/by-name/recovery cbbacd705884b2e437c54aeb8592b3cf7435e1e6 15460352 10716c276b7cca9c30809d20d7d4f16947eefe01:/system/recovery-from-boot.p && installed=1 && log -t recovery "Installing new recovery image: succeeded" || log -t recovery "Installing new recovery image: failed"
  [ -n "$installed" ] && dd if=/system/recovery-sig of=/dev/block/platform/bootdevice/by-name/recovery bs=1 seek=15460352 && sync && log -t recovery "Install new recovery signature: succeeded" || log -t recovery "Installing new recovery signature: failed"
else
  log -t recovery "Recovery image already installed"
fi
