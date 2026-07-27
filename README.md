# SSHRD_Script
- An unofficial, enhanced version of [Nathan verygenericname's SSHRD_Script](https://github.com/verygenericname/SSHRD_Script)
- This script has been tested working on Ubuntu 24.04 and macOS Sonoma hackintosh. However there are no warranties especially for ARM macOS, please use at your own risk
- Linux or macOS required. Virtual machine and windows are not and will never be supported even if some features are available on them. It is recommended to use USB-A cable and Intel PC
- A7-A11 devices only. For 32-bit devices, use [Legacy iOS Kit](https://github.com/LukeZGD/Legacy-iOS-Kit)
## Basic Usage: create ramdisk, boot ramdisk, SSH into device
0. Clone this repository:   
`git clone https://github.com/iPh0ne4s/SSHRD_Script --recursive`   
cd into SSHRD_Script directory. Run `chmod +x sshrd.sh` if running the script for the first time
1. Enter DFU mode, run `./sshrd.sh <ramdisk version>` to create ramdisk
  - For iOS 7-9 devices, run `./sshrd.sh 10.0.1`
    - A7 iOS 7 devices will be stuck in a black screen recovery mode after loading a higher version ramdisk, boot 8.0 ramdisk to fix this. It is the only case that iOS 8 ramdisk should be used
  - For iOS 10+ devices, use device version as ramdisk version, e.g., run `./sshrd.sh 11.2.2` for iOS 11.2.2 iPhone 6s, or the closest one if target ipsw doesn't exist, e.g., `./sshrd.sh 11.1` for iOS 11.0.1 iPhone X
    - Use 14.6 ramdisk on iOS 15 devices if iOS 15 ramdisk crashes
    - A wrong ramdisk version might cause bootloop, and this always happens on 16.4+ devices, check device version first
  - It is common to see "an error occurred" or device rebooting, just repeat the process, re-enter DFU if necessary
2. Run `./sshrd.sh boot` to boot ramdisk, if unable to connect to device, unplug and replug the cable
3. Run `./sshrd.sh ssh` to SSH into device, if the terminal says "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!", run `rm -f ~/.ssh/known_hosts` and try again
  - GUI tools such as [FileZilla](https://filezilla-project.org/) can be used to access device
## Other Commands
### In this part, unless otherwise specified, all the commands should be executed after booting ramdisk, i.e., after creating ramdisk and running `./sshrd.sh boot`, before `./sshrd.sh ssh`
- Reboot device: `./sshrd.sh reboot`
- Erase device without updating on iOS 9+: `./sshrd.sh reset`
- Dump onboard blobs: `./sshrd.sh dump-blobs`
- Remove temporary files: `./sshrd.sh clean` (run this one when no device)
- Exit recovery mode: `./sshrd.sh --exit-recovery` (run this one in recovery mode)
- Backup and restore activation files (iOS 10+)
  - Run `./sshrd.sh --backup-activation` to backup activation files, `./sshrd.sh --restore-activation` to restore them
- Backup and restore activation files (iOS 7-9, requires open menu)
  - Commands are `./sshrd.sh --backup-activation-hfs` and `./sshrd.sh --restore-activation-hfs`
  - On 7.0-9.3.5, activation files cannot be downloaded using scp or sftp command, instead they can be moved to /private/var/mobile/Media (the directory that is accessible in normal mode without a jailbreak) to become downloadable, therefore passcode locked devices are not supported
  - On 8.3+, activation files can be restored in the same way, place them in /private/var/mobile/Media first. On 7.0-8.2, however, moving them back will cause bootloop
- Backup and restore the entire contents on NAND (dangerous, might cause bootloop)
  - Run `./sshrd.sh --dump-nand` to backup NAND to a .gz file, `./sshrd.sh --restore-nand` to restore the .gz file to /dev/disk0 on device. Do not mount any partition before running these commands
  - On 7.0-10.2.1, there are also a few more options: `./sshrd.sh --dump-disk0s1s1`, `./sshrd.sh --restore-disk0s1s1`, `./sshrd.sh --dump-disk0s1s2`, `./sshrd.sh --restore-disk0s1s2`
- Install TrollStore on 14.0-16.6.1, 16.7 RC, 17.0: `./sshrd.sh --install-trollstore`
- Un-disable and get unlimited passcode attempts on iOS 7-8: `./sshrd.sh --brute-force`
## Notes & Known Issues
- "kex_exchange_identification: read: Connection reset by peer" and "Connection reset by 127.0.0.1 port 2222" indicate an SSH connection issue, if this occurs, try the following solutions: unplug and replug device, change cable, re-enter ramdisk mode, reboot PC
- On Linux, A7 devices must be manually placed into pwnDFU using [ipwnder_lite](https://github.com/LukeZGD/ipwnder_lite). [Usage](https://github.com/LukeZGD/Legacy-iOS-Kit/wiki/Pwning-Using-Another-iOS-Device)
- If there are permission denied, terminated or operation not permitted errors with sshrd.sh, try running sshrd.sh with sudo, especially on macOS
- Even if mounting /mnt2 as read/write, some files like photos still won't be downloadable, that's due to userdata encryption and there's actually nothing wrong
- Devices downgraded with turdus merula might not be able to mount /mnt2
- iOS 15 ramdisk will crash when saving activation files for unknown reason, use 14.6 ramdisk instead
- iOS 7-9 ramdisk is unusable except early iOS 8 versions, and iOS 8 ramdisk is only for exiting black screen recovery mode caused by a higher version ramdisk on A7 iOS 7 devices
- iOS 16+ ramdisk is partially broken
  - iBoot64Patcher fails at patching iBSS/iBEC on iPads
  - Mounting /mnt2 will possibly fail
  - 16.1+ ramdisk.img4 cannot be created on Linux (requires `hdiutil`)