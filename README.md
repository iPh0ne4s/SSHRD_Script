# SSHRD_Script
- An unofficial, modified version of [Nathan verygenericname's SSHRD_Script](https://github.com/verygenericname/SSHRD_Script)
- All the extra features have been tested working on Ubuntu 24.04 and macOS Sonoma hackintosh. However there are no warranties especially for ARM macOS, please use at your own risk
- Linux or macOS required, virtual machine and windows are not and will never be supported. It is recommended to use USB-A cable and Intel PC
## Usage
0. Clone this repository:   
`git clone https://github.com/iPh0ne4s/SSHRD_Script --recursive`   
cd into SSHRD_Script directory. Run `chmod +x sshrd.sh` if running the script for the first time
1. Run `./sshrd.sh <ramdisk version>` to create ramdisk
  - To backup and restore activation files (or modify files in /mnt2) on iOS 10.0+, select a ramdisk version that is identical or close enough to device's version, e.g., run `./sshrd.sh 11.2.2` for iOS 11.2.2 iPhone 6s, `./sshrd.sh 10.0.1` for iOS 10.0 iPhone 7, `./sshrd.sh 11.1` for iOS 11.0.1 iPhone X. In other cases, simply run `./sshrd.sh 12.0`
  - It is normal to see "an error occurred", just try again
2. Run `./sshrd.sh boot` to boot ramdisk
  - If unable to connect to device, unplug and replug the cable
3. Run `./sshrd.sh ssh` to SSH into device, if the terminal says "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!", run `rm -rf ~/.ssh` and try again. Here are some other commands:
  - Reboot device: `./sshrd.sh reboot`
  - Erase device: `./sshrd.sh reset`
    - Run this one before `./sshrd.sh boot`
  - Dump onboard blobs: `./sshrd.sh dump-blobs`
  - Remove temporary files: `./sshrd.sh clean`
  - For extra commands see below
## Extra Features
### In this part, all the commands starting with ./sshrd.sh are designed to be executed after booting ramdisk, i.e., after creating ramdisk and running `./sshrd.sh boot`, before `./sshrd.sh ssh`
- Create 10.0.1-11.2.6 ramdisk and mount /mnt2 on 10.0-11.2.6 devices
- Backup and restore activation files (iOS 10.0+)
  - On 10.3+, run `./sshrd.sh --backup-activation` to backup activation files, `./sshrd.sh --restore-activation` to restore them
  - On 10.0-10.2.1, commands are `./sshrd.sh --backup-activation-hfs` and `./sshrd.sh --restore-activation-hfs`
- Backup and restore activation files (iOS 7-9, partially supported)
  - Commands are `./sshrd.sh --backup-activation-hfs` and `./sshrd.sh --restore-activation-hfs`
  - On 7.0-9.3.5, activation files cannot be downloaded using scp or sftp command, instead they can be moved to /private/var/mobile/Media (the directory that is accessible in normal mode without a jailbreak) to become downloadable, therefore open menu devices only, passcode locked devices are not supported
  - On 8.3+, activation files can be restored in the same way, place them in /private/var/mobile/Media first
- Backup and restore the entire contents on NAND (dangerous, might cause bootloop)
  - Run `./sshrd.sh --dump-nand` to backup NAND to disk0.gz, `./sshrd.sh --restore-nand` to restore disk0.gz to /dev/disk0 on device
  - Or run `./sshrd.sh --dump-disk0s1s1` and `./sshrd.sh --restore-disk0s1s1` to backup and restore system partition
- iOS 7-8 brute force (partially supported)
  - Run `./sshrd.sh --brute-force` to get unlimited passcode attempts on passcode locked and disabled devices, iOS 7-8 only
  - A7 iOS 7 devices will be stuck in recovery loop after booting iOS 12 ramdisk, you may boot an iOS 8 ramdisk using [Legacy iOS Kit](https://github.com/LukeZGD/Legacy-iOS-Kit) to fix this, which is not supported by SSHRD_Script
## Notes
- If there are permission denied, terminated or operation not permitted errors with sshrd.sh, try running sshrd.sh with sudo, especially on macOS
- On 10.2.1 and lower devices, run `/sbin/mount_hfs /dev/disk0s1s1 /mnt1 && /usr/libexec/seputil --load /mnt1/usr/standalone/firmware/sep-firmware.img4 && /sbin/mount_hfs /dev/disk0s1s2 /mnt2` to mount filesystems. /mnt2 will be mounted as read/write only if device's SEP is compatible with ramdisk version, currently supports 10.0-10.2.1
- Even if mounting /mnt2 as read/write, some files like photos still won't be downloadable, that's due to userdata encryption and there's actually nothing wrong
