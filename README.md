# SSHRD_Script
- [Nathan verygenericname's SSHRD_Script](https://github.com/verygenericname/SSHRD_Script) with some extra features
- All these extra features have been tested working on Ubuntu and macOS Sonoma hackintosh. However there are no warranties especially for ARM macOS, please use at your own risk.
## Extra Features
- Reset via ssh, run `--reset-ssh`
- Create 10.0.1-11.2.6 ramdisk and mount /mnt2 on 10.0-11.2.6 devices (for 10.2.1 and lower see Notes)
- Backup and restore activation files (iOS 10.0+)
  - On 10.3+, run `./sshrd.sh --backup-activation` to backup activation files, `./sshrd.sh --restore-activation` to restore them, both commands require booting ramdisk first
  - On 10.0-10.2.1 the commands are `./sshrd.sh --backup-activation-hfs` and `./sshrd.sh --restore-activation-hfs`
  - Activation files will be saved to `Activation_Records/"device serial"`
- Backup and restore activation files (iOS 7-9, partially supported)
  - Run `./sshrd.sh --backup-activation-hfs` or `./sshrd.sh --restore-activation-hfs` after booting ramdisk
  - On 7.0-9.3.5, activation files cannot be directly downloaded, instead they can be moved to /private/var/mobile/Media (the directory that is accessible in normal mode without a jailbreak) to become downloadable
  - The device must be able to go to home screen, passcode locked devices are not supported
  - On iOS 9, activation files can be restored in the same way, place them in /private/var/mobile/Media first
- Backup and restore the entire contents on NAND
  - Run `./sshrd.sh --dump-nand` to backup NAND to disk0.gz, `./sshrd.sh --restore-nand` to restore disk0.gz to /dev/disk0 on device
  - Both commands are supposed to be executed directly after device entered DFU mode
- iOS 7-8 brute force (partially supported)
  - Run `./sshrd.sh --brute-force` to get unlimited passcode attempts on passcode locked and disabled devices, iOS 7-8 only
  - Directly run this command after device entered DFU mode
  - A7 iOS 7 devices will be stuck in recovery loop after booting iOS 12 ramdisk, you may boot an iOS 8 ramdisk using [Legacy iOS Kit](https://github.com/LukeZGD/Legacy-iOS-Kit) to fix this, which is not supported by SSHRD_Script
## Notes
- If there are permission denied, terminated or operation not permitted errors with sshrd.sh, try running sshrd.sh with sudo, especially on macOS
- On 10.2.1 and lower devices, use `/sbin/mount_hfs /dev/disk0s1s1 /mnt1` to mount system partition then load sep `/usr/libexec/seputil --load /mnt1/usr/standalone/firmware/sep-firmware.img4`, and `/sbin/mount_hfs /dev/disk0s1s2 /mnt2` to mount data partition. /mnt2 will be mounted as read/write if device's SEP is compatible with ramdisk version
