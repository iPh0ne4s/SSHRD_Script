#!/usr/bin/env sh
set -e
oscheck=$(uname)

version="$1"

major=$(echo "$version" | cut -d. -f1)
minor=$(echo "$version" | cut -d. -f2)
patch=$(echo "$version" | cut -d. -f3)

color_R=$(tput setaf 9)
color_G=$(tput setaf 10)
color_B=$(tput setaf 12)
color_Y=$(tput setaf 208)
color_N=$(tput sgr0)

echo_code() {
    echo "${color_B}${1}${color_N}"
}

echo_text() {
    echo "${color_G}${1}${color_N}"
}

echo_warn() {
    echo "${color_Y}${1}${color_N}"
}

echo_error() {
    echo "${color_R}${1}${color_N}"
}

ERR_HANDLER () {
    [ $? -eq 0 ] && exit
    echo_error "[-] An error occurred"
    killall iproxy > /dev/null 2>&1 | true
    if [ "$oscheck" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 | true
    fi
}

trap ERR_HANDLER EXIT

if [ -z "$1" ]; then
    echo_text "[*] Basic usage:"
    echo_code "    ./sshrd.sh <ramdisk version>"
    echo_code "    ./sshrd.sh boot"
    echo_code "    ./sshrd.sh ssh"
    echo_text "[*] See README.md for more information"
    exit
fi

if [ ! -e sshtars/ssh.tar ] && [ "$oscheck" = 'Linux' ]; then
    gzip -d -k sshtars/ssh.tar.gz
    gzip -d -k sshtars/t2ssh.tar.gz
    gzip -d -k sshtars/atvssh.tar.gz
    gzip -d -k sshtars/iram.tar.gz
fi

chmod +x "$oscheck"/*

if [ "$1" = 'clean' ]; then
    rm -rf sshramdisk work 12rd sshtars/*.tar
    echo_text "[*] Removed current SSH ramdisk"
    exit
elif [ "$1" = 'dump-blobs' ]; then
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 | true
        sudo killall usbmuxd > /dev/null 2>&1 | true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    "$oscheck"/iproxy 2222 22 > /dev/null 2>&1 &
    version=$("$oscheck"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "sw_vers -productVersion")
    version=${version%%.*}
    if [ "$version" -ge 16 ]; then
        device=rdisk2
    else
        device=rdisk1
    fi
    "$oscheck"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "cat /dev/$device" | dd of=dump.raw bs=256 count=$((0x4000))
    "$oscheck"/img4tool --convert -s "$(date '+%Y-%m-%d_%H-%M-%S')".shsh2 dump.raw
    killall iproxy > /dev/null 2>&1 | true
    if [ "$oscheck" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 | true
    fi
    rm -f dump.raw
    echo_text "[*] Onboard blobs should be dumped to "$(date '+%Y-%m-%d_%H-%M-%S')".shsh2"
    echo_text "[*] If your device is on 16.0+, it is recommended to use Legacy iOS Kit to dump fully useful blobs, go here for more details: https://github.com/LukeZGD/Legacy-iOS-Kit/wiki/Saving-onboard-SHSH-blobs-of-current-iOS-version"
    exit
elif [ "$1" = 'reboot' ]; then
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 | true
        sudo killall usbmuxd > /dev/null 2>&1 | true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    "$oscheck"/iproxy 2222 22 > /dev/null 2>&1 &
    "$oscheck"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot"
    killall iproxy > /dev/null 2>&1 | true
    if [ "$oscheck" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 | true
    fi
    echo_text "[*] Device should now reboot"
    exit
elif [ "$1" = 'ssh' ]; then
    echo_text "[*] For accessing data, note the following:"
    echo_code "    Host: sftp://127.0.0.1   User: root   Password: alpine   Port: 2222"
    echo_text "[*] Mount filesystems:"
    echo_code "10.3 and above: /usr/bin/mount_filesystems"
    echo_code "10.0-10.2.1: mount_hfs /dev/disk0s1s1 /mnt1 && /usr/libexec/seputil --load /mnt1/usr/standalone/firmware/sep-firmware.img4 && mount_hfs /dev/disk0s1s2 /mnt2"
    echo_code "7.0-9.3.5: mount_hfs /dev/disk0s1s1 /mnt1 && mount_hfs /dev/disk0s1s2 /mnt2"
    echo_text "[*] Rename system snapshot (when first time modifying /mnt1 on 11.3+):"
    echo_code '    /usr/bin/snaputil -n "$(/usr/bin/snaputil -l /mnt1)" orig-fs /mnt1'
    echo_text "[*] Erase device without updating (9.0+):"
    echo_code "    /usr/sbin/nvram oblit-inprogress=5"
    echo_text "[*] Reboot:"
    echo_code "    /sbin/reboot"
    echo_text "[*] Remove Setup.app (up to 13.2.3 or 12.4.4; on 10.0+ the device must be erased afterwards, on 11.3+ also rename system snapshot):"
    echo_code "    rm -rf /mnt1/Applications/Setup.app"
    killall iproxy > /dev/null 2>&1 | true
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 | true
        sudo killall usbmuxd > /dev/null 2>&1 | true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    if [ -e sshramdisk/device_port_44 ]; then
        echo_text "[*] If stuck here, unplug and replug device, run ./sshrd.sh ssh again"
        "$oscheck"/iproxy 2222 44 > /dev/null 2>&1 &
    else
        "$oscheck"/iproxy 2222 22 > /dev/null 2>&1 &
    fi
    "$oscheck"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost || true
    killall iproxy > /dev/null 2>&1 | true
    if [ "$oscheck" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 | true
    fi
    exit
elif [ "$1" = '--backup-activation' ]; then
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 | true
        sudo killall usbmuxd > /dev/null 2>&1 | true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    "$oscheck"/iproxy 2222 22 > /dev/null 2>&1 &
    serial_number=$("$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/ioreg -l | grep IOPlatformSerialNumber | sed 's/.*IOPlatformSerialNumber\" = \"\(.*\)\"/\1/' | cut -d '\"' -f4")
    mkdir -p activation_records/$serial_number
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/mount_filesystems || true"
    "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no "root@127.0.0.1:/mnt2/containers/Data/System/*/Library/activation_records/activation_record.plist" activation_records/$serial_number || "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no "root@127.0.0.1:/mnt2/containers/Data/System/*/Library/activation_records/pod_record.plist" activation_records/$serial_number || true
    "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist activation_records/$serial_number || true
    "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv activation_records/$serial_number || true
    if [ -s activation_records/$serial_number/*_record.plist ] && [ -s activation_records/$serial_number/com.apple.commcenter.device_specific_nobackup.plist ] && [ -s activation_records/$serial_number/IC-Info.sisv ]; then
    echo_text "[*] Activation files saved to activation_records/$serial_number"
    elif [ -s activation_records/$serial_number/*_record.plist ] && [ -s activation_records/$serial_number/com.apple.commcenter.device_specific_nobackup.plist ] && [ ! -s activation_records/$serial_number/IC-Info.sisv ]; then
    echo_error "[-] ERROR: Failed to save IC-Info.sisv, delete current /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv, reboot to lock screen, enter DFU mode, boot SSH ramdisk and try again"
    else
    echo_error "[-] ERROR: Failed to save activation files, select a ramdisk version that is identical or close enough to device version and try again"
    fi
    killall iproxy > /dev/null 2>&1 | true
    if [ "$oscheck" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 | true
    fi
    exit
elif [ "$1" = '--restore-activation' ]; then
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 | true
        sudo killall usbmuxd > /dev/null 2>&1 | true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    "$oscheck"/iproxy 2222 22 > /dev/null 2>&1 &
    serial_number=$("$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/ioreg -l | grep IOPlatformSerialNumber | sed 's/.*IOPlatformSerialNumber\" = \"\(.*\)\"/\1/' | cut -d '\"' -f4")
    if [ ! -s activation_records/$serial_number/*_record.plist ]; then
        echo_error "[-] ERROR: Activation files not found"
        killall iproxy > /dev/null 2>&1 | true
        if [ "$oscheck" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 | true
        fi
        exit
    fi
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/mount_filesystems || true"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "rm -rf /mnt2/mobile/Media/Downloads/Activation /mnt2/mobile/Media/Activation"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mkdir -p /mnt2/mobile/Media/Downloads/Activation"
    "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no activation_records/$serial_number/activation_record.plist root@127.0.0.1:/mnt2/mobile/Media/Downloads/Activation || "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no activation_records/$serial_number/pod_record.plist root@127.0.0.1:/mnt2/mobile/Media/Downloads/Activation
    "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no activation_records/$serial_number/com.apple.commcenter.device_specific_nobackup.plist root@127.0.0.1:/mnt2/mobile/Media/Downloads/Activation
    "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no activation_records/$serial_number/IC-Info.sisv root@127.0.0.1:/mnt2/mobile/Media/Downloads/Activation
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/Downloads/Activation /mnt2/mobile/Media"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown -R mobile:mobile /mnt2/mobile/Media/Activation"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod -R 755 /mnt2/mobile/Media/Activation"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "cd /mnt2/containers/Data/System/*/Library/internal; mkdir -p ../activation_records"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/Activation/*_record.plist /mnt2/containers/Data/System/*/Library/activation_records"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 666 /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:nobody /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/Activation/com.apple.commcenter.device_specific_nobackup.plist /mnt2/wireless/Library/Preferences"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 600 /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown _wireless:_wireless /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mkdir -p /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/Activation/IC-Info.sisv /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 664 /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:mobile /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "rm -rf /mnt2/mobile/Media/Activation"
    echo_text "[*] Activation files restored to device"
    killall iproxy > /dev/null 2>&1 | true
    if [ "$oscheck" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 | true
    fi
    exit
elif [ "$1" = '--backup-activation-hfs' ]; then
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 | true
        sudo killall usbmuxd > /dev/null 2>&1 | true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    "$oscheck"/iproxy 2222 22 > /dev/null 2>&1 &
    serial_number=$("$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/ioreg -l | grep IOPlatformSerialNumber | sed 's/.*IOPlatformSerialNumber\" = \"\(.*\)\"/\1/' | cut -d '\"' -f4")
    mkdir -p activation_records/$serial_number
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s1 /mnt1 || true"
    "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt1/System/Library/CoreServices/SystemVersion.plist . || true
    if [ ! -s SystemVersion.plist ]; then
        echo_error "[-] ERROR: Failed to mount filesystems as HFS+, probably iOS 10.3+, run ./sshrd.sh --backup-activation"
        killall iproxy > /dev/null 2>&1 | true
        if [ "$oscheck" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 | true
        fi
        exit
    fi
    device_version=$(grep -A1 '<key>ProductVersion</key>' SystemVersion.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
    device_major=$(echo "$device_version" | cut -d. -f1)
    device_minor=$(echo "$device_version" | cut -d. -f2)
    echo_text "[*] Device Version: "$device_version""; sleep 3
    rm -f SystemVersion.plist
    if [ "$device_major" -eq 10 ] && [ "$device_minor" -lt 3 ]; then
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/libexec/seputil --load /mnt1/usr/standalone/firmware/sep-firmware.img4 || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 || true"
        "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no "root@127.0.0.1:/mnt2/containers/Data/System/*/Library/activation_records/activation_record.plist" activation_records/$serial_number || "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no "root@127.0.0.1:/mnt2/containers/Data/System/*/Library/activation_records/pod_record.plist" activation_records/$serial_number || true
        "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist activation_records/$serial_number || true
        "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv activation_records/$serial_number || true
        if [ -s activation_records/$serial_number/*_record.plist ] && [ -s activation_records/$serial_number/com.apple.commcenter.device_specific_nobackup.plist ] && [ -s activation_records/$serial_number/IC-Info.sisv ]; then
        echo_text "[*] Activation files saved to activation_records/$serial_number"
        elif [ -s activation_records/$serial_number/*_record.plist ] && [ -s activation_records/$serial_number/com.apple.commcenter.device_specific_nobackup.plist ] && [ ! -s activation_records/$serial_number/IC-Info.sisv ]; then
        echo_error "[-] ERROR: Failed to save IC-Info.sisv, delete current /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv, reboot to lock screen, enter DFU mode, boot SSH ramdisk and try again"
        else
        echo_error "[-] ERROR: Failed to save activation files, select a ramdisk version that is identical or close enough to device version and try again"
        fi
        killall iproxy > /dev/null 2>&1 | true
        if [ "$oscheck" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 | true
        fi
        exit
    elif [ "$device_major" -eq 9 ] && [ "$device_minor" -eq 3 ]; then
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist /mnt2/mobile/Media || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist /mnt2/mobile/Media || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv /mnt2/mobile/Media || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 777 /mnt2/mobile/Media/*_record.plist /mnt2/mobile/Media/com.apple.commcenter.device_specific_nobackup.plist /mnt2/mobile/Media/IC-Info.sisv || true"
        echo_text "[*] Activation files moved to /private/var/mobile/Media on device, and can be accessed at normal mode without a jailbreak"
        echo_text "[*] If failing to move IC-Info.sisv, delete current /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv, reboot and try again"
        killall iproxy > /dev/null 2>&1 | true
        if [ "$oscheck" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 | true
        fi
        exit
    elif [ "$device_major" -eq 9 ] && [ "$device_minor" -lt 3 ] || [ "$device_major" -eq 8 ]; then
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv /mnt2/mobile/Library/mad/activation_records/*_record.plist /mnt2/mobile/Media || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist /mnt2/mobile/Media || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv /mnt2/mobile/Media || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 777 /mnt2/mobile/Media/*_record.plist /mnt2/mobile/Media/com.apple.commcenter.device_specific_nobackup.plist /mnt2/mobile/Media/IC-Info.sisv || true"
        echo_text "[*] Activation files moved to /private/var/mobile/Media on device, and can be accessed at normal mode without a jailbreak"
        echo_text "[*] If failing to move IC-Info.sisv, delete current /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv, reboot and try again"
        killall iproxy > /dev/null 2>&1 | true
        if [ "$oscheck" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 | true
        fi
        exit
    elif [ "$device_major" -eq 7 ]; then
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv /mnt2/root/Library/Lockdown/activation_records/*_record.plist /mnt2/mobile/Media || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist /mnt2/mobile/Media || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv /mnt2/mobile/Media || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 777 /mnt2/mobile/Media/*_record.plist /mnt2/mobile/Media/com.apple.commcenter.device_specific_nobackup.plist /mnt2/mobile/Media/IC-Info.sisv || true"
        echo_text "[*] Activation files moved to /private/var/mobile/Media on device, and can be accessed at normal mode without a jailbreak"
        echo_text "[*] If failing to move IC-Info.sisv, delete current /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv, reboot and try again"
        killall iproxy > /dev/null 2>&1 | true
        if [ "$oscheck" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 | true
        fi
        exit
    fi
elif [ "$1" = '--restore-activation-hfs' ]; then
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 | true
        sudo killall usbmuxd > /dev/null 2>&1 | true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    "$oscheck"/iproxy 2222 22 > /dev/null 2>&1 &
    serial_number=$("$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/ioreg -l | grep IOPlatformSerialNumber | sed 's/.*IOPlatformSerialNumber\" = \"\(.*\)\"/\1/' | cut -d '\"' -f4")
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s1 /mnt1 || true"
    "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt1/System/Library/CoreServices/SystemVersion.plist . || true
    if [ ! -s SystemVersion.plist ]; then
        echo_error "[-] ERROR: Failed to mount filesystems as HFS+, probably iOS 10.3+, run ./sshrd.sh --restore-activation"
        killall iproxy > /dev/null 2>&1 | true
        if [ "$oscheck" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 | true
        fi
        exit
    fi
    device_version=$(grep -A1 '<key>ProductVersion</key>' SystemVersion.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
    device_major=$(echo "$device_version" | cut -d. -f1)
    device_minor=$(echo "$device_version" | cut -d. -f2)
    echo_text "[*] Device Version: "$device_version""; sleep 3
    rm -f SystemVersion.plist
    if [ "$device_major" -eq 10 ] && [ "$device_minor" -lt 3 ]; then
        if [ ! -s activation_records/$serial_number/*_record.plist ]; then
            echo_error "[-] ERROR: Activation files not found"
            killall iproxy > /dev/null 2>&1 | true
            if [ "$oscheck" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 | true
            fi
            exit
        fi
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/libexec/seputil --load /mnt1/usr/standalone/firmware/sep-firmware.img4 || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "rm -rf /mnt2/mobile/Media/Downloads/Activation /mnt2/mobile/Media/Activation"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mkdir -p /mnt2/mobile/Media/Downloads/Activation"
        "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no activation_records/$serial_number/activation_record.plist root@127.0.0.1:/mnt2/mobile/Media/Downloads/Activation || "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no activation_records/$serial_number/pod_record.plist root@127.0.0.1:/mnt2/mobile/Media/Downloads/Activation
        "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no activation_records/$serial_number/com.apple.commcenter.device_specific_nobackup.plist root@127.0.0.1:/mnt2/mobile/Media/Downloads/Activation
        "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no activation_records/$serial_number/IC-Info.sisv root@127.0.0.1:/mnt2/mobile/Media/Downloads/Activation
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/Downloads/Activation /mnt2/mobile/Media"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown -R mobile:mobile /mnt2/mobile/Media/Activation"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod -R 755 /mnt2/mobile/Media/Activation"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "cd /mnt2/containers/Data/System/*/Library/internal; mkdir -p ../activation_records"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/Activation/*_record.plist /mnt2/containers/Data/System/*/Library/activation_records"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 666 /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:nobody /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/Activation/com.apple.commcenter.device_specific_nobackup.plist /mnt2/wireless/Library/Preferences"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 600 /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown _wireless:_wireless /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mkdir -p /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/Activation/IC-Info.sisv /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 664 /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:mobile /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "rm -rf /mnt2/mobile/Media/Activation"
        echo_text "[*] Activation files restored to device"
        killall iproxy > /dev/null 2>&1 | true
        if [ "$oscheck" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 | true
        fi
        exit
# Currently not working, on 9.3.x activation files won't be recognized
    elif [ "$device_major" -eq 9 ] && [ "$device_minor" -eq 3 ]; then
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "cd /mnt2/containers/Data/System/*/Library/internal; mkdir -p ../activation_records"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/*_record.plist /mnt2/containers/Data/System/*/Library/activation_records"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 666 /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:nobody /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/com.apple.commcenter.device_specific_nobackup.plist /mnt2/wireless/Library/Preferences"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 600 /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown _wireless:_wireless /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mkdir -p /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/IC-Info.sisv /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 664 /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:mobile /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
        echo_text "[*] Activation files restored to device"
        killall iproxy > /dev/null 2>&1 | true
        if [ "$oscheck" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 | true
        fi
        exit
    elif ([ "$device_major" -eq 8 ] && [ "$device_minor" -ge 3 ]) || ([ "$device_major" -eq 9 ] && [ "$device_minor" -lt 3 ]); then
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 || true"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mkdir -p /mnt2/mobile/Library/mad/activation_records"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/*_record.plist /mnt2/mobile/Library/mad/activation_records"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 666 /mnt2/mobile/Library/mad/activation_records/*_record.plist"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:nobody /mnt2/mobile/Library/mad/activation_records/*_record.plist"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/com.apple.commcenter.device_specific_nobackup.plist /mnt2/wireless/Library/Preferences"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 600 /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown _wireless:_wireless /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mkdir -p /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/IC-Info.sisv /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 664 /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
        "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:mobile /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
        echo_text "[*] Activation files restored to device"
        killall iproxy > /dev/null 2>&1 | true
        if [ "$oscheck" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 | true
        fi
        exit
    elif [ "$device_major" -eq 8 ] && [ "$device_minor" -lt 3 ] || [ "$device_major" -eq 7 ]; then
        echo_error "[-] ERROR: Restoring activation files via ramdisk is not supported on 64-bit iOS 7.0-8.2, which will cause bootloop"
        killall iproxy > /dev/null 2>&1 | true
        if [ "$oscheck" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 | true
        fi
        exit
    fi
elif [ "$1" = '--dump-nand' ]; then
    if [ -s disk0.gz ]; then
        echo_error "[-] ERROR: Please rename current disk0.gz first"
        exit
    fi
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 | true
        sudo killall usbmuxd > /dev/null 2>&1 | true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    echo_text "[*] Dumping /dev/disk0, this will take a long time"
    "$oscheck"/iproxy 2222 22 > /dev/null 2>&1 &
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "dd if=/dev/disk0 bs=64k | gzip -1 -" | dd of=disk0.gz bs=64k
    echo_text "[*] Done!"
    killall iproxy > /dev/null 2>&1 | true
    if [ "$oscheck" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 | true
    fi
    exit
elif [ "$1" = '--restore-nand' ]; then
    if [ ! -s disk0.gz ]; then
        echo_error "[-] ERROR: disk0.gz not found"
        exit
    fi
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 | true
        sudo killall usbmuxd > /dev/null 2>&1 | true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    echo_text "[*] Restoring /dev/disk0, this will take a long time"
    "$oscheck"/iproxy 2222 22 > /dev/null 2>&1 &
    dd if=disk0.gz bs=64k | "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "gzip -d | dd of=/dev/disk0 bs=64k"
    echo_text "[*] Done!"
    killall iproxy > /dev/null 2>&1 | true
    if [ "$oscheck" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 | true
    fi
    exit
elif [ "$1" = '--dump-disk0s1s1' ]; then
    if [ -s disk0s1s1.gz ]; then
        echo_error "[-] ERROR: Please rename current disk0s1s1.gz first"
        exit
    fi
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 | true
        sudo killall usbmuxd > /dev/null 2>&1 | true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    echo_text "[*] Dumping /dev/disk0s1s1, this will take several minutes"
    "$oscheck"/iproxy 2222 22 > /dev/null 2>&1 &
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "dd if=/dev/disk0s1s1 bs=64k | gzip -1 -" | dd of=disk0s1s1.gz bs=64k
    echo_text "[*] Done!"
    killall iproxy > /dev/null 2>&1 | true
    if [ "$oscheck" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 | true
    fi
    exit
elif [ "$1" = '--restore-disk0s1s1' ]; then
    if [ ! -s disk0s1s1.gz ]; then
        echo_error "[-] ERROR: disk0s1s1.gz not found"
        exit
    fi
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 | true
        sudo killall usbmuxd > /dev/null 2>&1 | true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    echo_text "[*] Restoring /dev/disk0s1s1, this will take several minutes"
    "$oscheck"/iproxy 2222 22 > /dev/null 2>&1 &
    dd if=disk0s1s1.gz bs=64k | "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "gzip -d | dd of=/dev/disk0s1s1 bs=64k"
    echo_text "[*] Done!"
    killall iproxy > /dev/null 2>&1 | true
    if [ "$oscheck" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 | true
    fi
    exit
elif [ "$1" = '--brute-force' ]; then
    echo_warn "[!] WARNING: Only compatible with iOS 7-8"; sleep 3
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 | true
        sudo killall usbmuxd > /dev/null 2>&1 | true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    "$oscheck"/iproxy 2222 22 > /dev/null 2>&1 &
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s1 /mnt1 && /sbin/mount_hfs /dev/disk0s1s2 /mnt2"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "cp -f /com.apple.springboard.plist /mnt1"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Library/Preferences/com.apple.springboard.plist /mnt2/mobile/Library/Preferences/com.apple.springboard.plist.bak"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "ln -s /com.apple.springboard.plist /mnt2/mobile/Library/Preferences/com.apple.springboard.plist"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "rm -rf /mnt2/mobile/Library/SpringBoard/LockoutStateJournal.plist"
    echo_text "[*] Now the device should get unlimited passcode attempts"
    killall iproxy > /dev/null 2>&1 | true
    if [ "$oscheck" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 | true
    fi
    exit
elif [ "$1" = '--install-trollstore' ]; then
    echo_warn "[!] WARNING: Only compatible with iOS 14.0-16.6.1, 16.7 RC, 17.0"; sleep 3
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 | true
        sudo killall usbmuxd > /dev/null 2>&1 | true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    "$oscheck"/iproxy 2222 22 > /dev/null 2>&1 &
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/mount_filesystems || true"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/trollstoreinstaller Tips"
    killall iproxy > /dev/null 2>&1 | true
    if [ "$oscheck" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 | true
    fi
    exit
elif [ "$1" = '--exit-recovery' ]; then
    "$oscheck"/irecovery -n
    exit
elif [ "$1" = 'reset' ]; then
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 | true
        sudo killall usbmuxd > /dev/null 2>&1 | true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    "$oscheck"/iproxy 2222 22 > /dev/null 2>&1 &
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/nvram oblit-inprogress=5"
    echo_text "[*] Device should show a progress bar and erase all data after rebooting"
    echo_text "[*] If running this command by mistake, SSH into device, run /usr/sbin/nvram -c"
    killall iproxy > /dev/null 2>&1 | true
    if [ "$oscheck" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 | true
    fi
    exit
else
    if [ "$oscheck" = 'Darwin' ]; then
        check_cmd="ioreg -p IOUSB"
        check_str="Apple Mobile Device (DFU Mode)"
    else
        check_cmd="lsusb"
        check_str="Apple, Inc. Mobile Device (DFU Mode)"
    fi

    if ! $check_cmd 2>/dev/null | grep -q "$check_str"; then
        echo_text "[*] Waiting for device in DFU mode"
        
        until $check_cmd 2>/dev/null | grep -q "$check_str"; do
            sleep 1
        done
    fi
fi

echo_text "[*] Getting device info and pwning... this may take a second"
check=$("$oscheck"/irecovery -q | grep CPID | sed 's/CPID: //')
replace=$("$oscheck"/irecovery -q | grep MODEL | sed 's/MODEL: //')
deviceid=$("$oscheck"/irecovery -q | grep PRODUCT | sed 's/PRODUCT: //')

ipswurl=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$oscheck"/jq '.firmwares | .[] | select(.version=="'$1'")' | "$oscheck"/jq -s '.[0] | .url' --raw-output)

if [ "$1" = 'boot' ]; then
    if [ ! -e sshramdisk/iBSS.img4 ] || [ ! -e sshramdisk/iBEC.img4 ] || [ ! -e sshramdisk/kernelcache.img4 ] || [ ! -e sshramdisk/devicetree.img4 ] || [ ! -e sshramdisk/ramdisk.img4 ]; then
        echo_error "[-] ERROR: Please create an SSH ramdisk first!"
        exit
    fi

    major=$(cat sshramdisk/version.txt | awk -F. '{print $1}')
    minor=$(cat sshramdisk/version.txt | awk -F. '{print $2}')
    patch=$(cat sshramdisk/version.txt | awk -F. '{print $3}')
    major=${major:-0}
    minor=${minor:-0}
    patch=${patch:-0}
    
    if [ "$check" = '0x8960' ] && [ "$oscheck" = 'Linux' ]; then
        device_pwnd="$("$oscheck"/irecovery -q | grep "PWND" | cut -c 7-)"
        if [ -z "$device_pwnd" ]; then
            echo_error "[-] ERROR: Please use ipwnder_lite to enter pwnDFU mode first!"
            exit
        else
            echo_text "[*] Pwned: "$device_pwnd""
        fi
    else
        "$oscheck"/gaster pwn > /dev/null
    fi
    "$oscheck"/gaster reset > /dev/null
    "$oscheck"/irecovery -f sshramdisk/iBSS.img4
    sleep 5
    "$oscheck"/irecovery -f sshramdisk/iBEC.img4

    if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
        "$oscheck"/irecovery -c go
    fi
    sleep 2
    "$oscheck"/irecovery -f sshramdisk/logo.img4
    "$oscheck"/irecovery -c "setpicture 0x1"
    "$oscheck"/irecovery -f sshramdisk/ramdisk.img4
    "$oscheck"/irecovery -c ramdisk
    if [ "$major" -ge 16 ]; then
        "$oscheck"/irecovery -f sshramdisk/sep-firmware.img4
        "$oscheck"/irecovery -c firmware
    fi
    "$oscheck"/irecovery -f sshramdisk/devicetree.img4
    "$oscheck"/irecovery -c devicetree
    if [ "$major" -ge 12 ]; then
        "$oscheck"/irecovery -f sshramdisk/trustcache.img4
        "$oscheck"/irecovery -c firmware
    fi
    "$oscheck"/irecovery -f sshramdisk/kernelcache.img4
    "$oscheck"/irecovery -c bootx

    echo_text "[*] Device should now show text on screen, run ./sshrd.sh ssh to SSH into device"
    exit
fi

if [ "$check" = '0x8960' ] && [ "$oscheck" = 'Linux' ]; then
    echo_warn "[!] WARNING: Linux and A7 device detected, the device must be placed into pwnDFU using ipwnder_lite, otherwise the boot process will fail"; sleep 5
else
    "$oscheck"/gaster pwn > /dev/null
fi
rm -rf sshramdisk work 12rd; mkdir work sshramdisk
"$oscheck"/img4tool -e -s other/shsh/"${check}".shsh -m work/IM4M
cd work

../"$oscheck"/pzb -g BuildManifest.plist "$ipswurl"
../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"

if [ "$major" -ge 16 ]; then
    ../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/sep-firmware[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
fi

if [ "$oscheck" = 'Darwin' ]; then
    if [ "$major" -lt 12 ]; then
    :
    else
    ../"$oscheck"/pzb -g Firmware/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache "$ipswurl"
    fi
else
    if [ "$major" -lt 12 ]; then
    :
    else
    ../"$oscheck"/pzb -g Firmware/"$(../Linux/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')".trustcache "$ipswurl"
    fi
fi

../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"

if [ "$oscheck" = 'Darwin' ]; then
    ../"$oscheck"/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
else
    ../"$oscheck"/pzb -g "$(../Linux/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" "$ipswurl"
fi
cd ..

# Use local ivkey file as a workaround for A7 pwndfu issue on Linux, avoiding `gaster decrypt` command
devicetree_ivkey="$(sed -n "s/^"${replace}"_"${version}"_DeviceTree=\"\([^\"]*\)\"$/\1/p" other/ivkey)"
ibec_ivkey="$(sed -n "s/^"${replace}"_"${version}"_iBEC=\"\([^\"]*\)\"$/\1/p" other/ivkey)"
ibss_ivkey="$(sed -n "s/^"${replace}"_"${version}"_iBSS=\"\([^\"]*\)\"$/\1/p" other/ivkey)"
kernelcache_ivkey="$(sed -n "s/^"${replace}"_"${version}"_Kernelcache=\"\([^\"]*\)\"$/\1/p" other/ivkey)"
restoreramdisk_ivkey="$(sed -n "s/^"${replace}"_"${version}"_RestoreRamdisk=\"\([^\"]*\)\"$/\1/p" other/ivkey)"

if [ "$major" -ge 18 ]; then    # iBSS and iBEC have been unencrypted since iOS 18
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/iBSS[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" -o work/iBSS.dec
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/iBEC[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" -o work/iBEC.dec
elif [ "$check" = '0x8960' ]; then
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/iBSS[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" -o work/iBSS.dec -k "$ibss_ivkey"
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/iBEC[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" -o work/iBEC.dec -k "$ibec_ivkey"
else
    "$oscheck"/gaster decrypt work/"$(awk "/""${replace}""/{x=1}x&&/iBSS[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" work/iBSS.dec
    "$oscheck"/gaster decrypt work/"$(awk "/""${replace}""/{x=1}x&&/iBEC[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" work/iBEC.dec
fi
if ([ "$major" -eq 10 ] && [ "$minor" -lt 3 ] || [ "$major" -lt 10 ]) || ([ "$major" -le 12 ] && ([ "$deviceid" = 'iPad6,3' ] || [ "$deviceid" = 'iPad6,4' ] || [ "$deviceid" = 'iPad6,7' ] || [ "$deviceid" = 'iPad6,8' ] || [ "$deviceid" = 'iPad6,11' ] || [ "$deviceid" = 'iPad6,12' ])); then
    "$oscheck"/kairos work/iBSS.dec work/iBSS.patched
    "$oscheck"/img4 -i work/iBSS.patched -o sshramdisk/iBSS.img4 -M work/IM4M -A -T ibss
    "$oscheck"/kairos work/iBEC.dec work/iBEC.patched -b "rd=md0 debug=0x2014e -v wdt=-1 `if [ -z "$2" ]; then :; else echo "$2=$3"; fi` `if [ "$check" = '0x8960' ] || [ "$check" = '0x7000' ] || [ "$check" = '0x7001' ]; then echo "nand-enable-reformat=1 -restore"; fi` `if [ "$major" -lt 10 ]; then echo "amfi=0xff cs_enforcement_disable=1"; fi`" -n
    "$oscheck"/img4 -i work/iBEC.patched -o sshramdisk/iBEC.img4 -M work/IM4M -A -T ibec
else
    "$oscheck"/iBoot64Patcher work/iBSS.dec work/iBSS.patched
    "$oscheck"/img4 -i work/iBSS.patched -o sshramdisk/iBSS.img4 -M work/IM4M -A -T ibss
    "$oscheck"/iBoot64Patcher work/iBEC.dec work/iBEC.patched -b "rd=md0 debug=0x2014e -v wdt=-1 `if [ -z "$2" ]; then :; else echo "$2=$3"; fi` `if [ "$check" = '0x8960' ] || [ "$check" = '0x7000' ] || [ "$check" = '0x7001' ]; then echo "nand-enable-reformat=1 -restore"; fi`"
    "$oscheck"/img4 -i work/iBEC.patched -o sshramdisk/iBEC.img4 -M work/IM4M -A -T ibec
fi   

if [ "$major" -lt 10 ]; then
    if [ "$check" = '0x8960' ]; then
        :
    else
        kbag=$("$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -b | head -n 1)
        iv=$("$oscheck"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ',' -f 1 | cut -d ' ' -f 2)
        key=$("$oscheck"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ' ' -f 4)
        kernelcache_ivkey="$iv$key"
    fi
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o work/kernelcache.im4p -k "$kernelcache_ivkey" -D
    "$oscheck"/img4 -i work/kernelcache.im4p -o sshramdisk/kernelcache.img4 -M work/IM4M -T rkrn
else
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o work/kcache.raw
    "$oscheck"/KPlooshFinder work/kcache.raw work/kcache.patched
    "$oscheck"/kerneldiff work/kcache.raw work/kcache.patched work/kc.bpatch
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o sshramdisk/kernelcache.img4 -M work/IM4M -T rkrn -P work/kc.bpatch `if [ "$oscheck" = 'Linux' ]; then echo "-J"; fi`
fi 

if [ "$major" -eq 10 ] && [ "$minor" -lt 3 ]; then
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/DeviceTree[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash[.].*[.]production[/]//')" -o sshramdisk/devicetree.img4 -M work/IM4M -T rdtr
elif [ "$major" -lt 10 ]; then
    if [ "$check" = '0x8960' ]; then
        :
    else
        kbag=$("$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/DeviceTree[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash[.].*[.]production[/]//')" -b | head -n 1)
        iv=$("$oscheck"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ',' -f 1 | cut -d ' ' -f 2)
        key=$("$oscheck"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ' ' -f 4)
        devicetree_ivkey="$iv$key"
    fi
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/DeviceTree[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash[.].*[.]production[/]//')" -o work/dtree.raw -k "$devicetree_ivkey"
    "$oscheck"/img4 -i work/dtree.raw -o sshramdisk/devicetree.img4 -A -M work/IM4M -T rdtr
else
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/DeviceTree[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]//')" -o sshramdisk/devicetree.img4 -M work/IM4M -T rdtr
fi   

if [ "$major" -ge 16 ]; then
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/sep-firmware[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]//')" -o sshramdisk/sep-firmware.img4 -M work/IM4M -T sepi
fi

if [ "$oscheck" = 'Darwin' ]; then
    if [ "$major" -ge 12 ]; then
        "$oscheck"/img4 -i work/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache -o sshramdisk/trustcache.img4 -M work/IM4M -T rtsc
    fi
    if [ "$major" -lt 10 ]; then
        if [ "$check" = '0x8960' ]; then
            :
        else
            kbag=$("$oscheck"/img4 -i work/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -b | head -n 1)
            iv=$("$oscheck"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ',' -f 1 | cut -d ' ' -f 2)
            key=$("$oscheck"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ' ' -f 4)
            restoreramdisk_ivkey="$iv$key"
        fi
        "$oscheck"/img4 -i work/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -o work/ramdisk.dmg -k "$restoreramdisk_ivkey"
    else
        "$oscheck"/img4 -i work/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -o work/ramdisk.dmg
    fi
else
    if [ "$major" -ge 12 ]; then
        "$oscheck"/img4 -i work/"$(Linux/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')".trustcache -o sshramdisk/trustcache.img4 -M work/IM4M -T rtsc
    fi
    if [ "$major" -lt 10 ]; then
        if [ "$check" = '0x8960' ]; then
            :
        else
            kbag=$("$oscheck"/img4 -i work/"$(Linux/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" -b | head -n 1)
            iv=$("$oscheck"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ',' -f 1 | cut -d ' ' -f 2)
            key=$("$oscheck"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ' ' -f 4)
            restoreramdisk_ivkey="$iv$key"
        fi
        "$oscheck"/img4 -i work/"$(Linux/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" -o work/ramdisk.dmg -k "$restoreramdisk_ivkey"
    else
        "$oscheck"/img4 -i work/"$(Linux/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" -o work/ramdisk.dmg
    fi
fi

if [ "$oscheck" = 'Darwin' ]; then
    if [ "$major" -eq 16 ] && [ "$minor" -ge 1 ] || [ "$major" -gt 16 ]; then
    :
    elif [ "$major" -eq 11 ] && [ "$minor" -lt 3 ] || [ "$major" -eq 10 ] || [ "$major" -eq 9 ]; then
        hdiutil resize -size 110MB work/ramdisk.dmg
    elif [ "$major" -eq 7 ] || [ "$major" -eq 8 ]; then
        hdiutil resize -size 50MB work/ramdisk.dmg
    else
        hdiutil resize -size 210MB work/ramdisk.dmg
    fi
    hdiutil attach -mountpoint /tmp/SSHRD work/ramdisk.dmg -owners off
    
    if [ "$major" -eq 16 ] && [ "$minor" -ge 1 ] || [ "$major" -gt 16 ]; then
        hdiutil create -size 210m -imagekey diskimage-class=CRawDiskImage -format UDZO -fs HFS+ -layout NONE -srcfolder /tmp/SSHRD -copyuid root work/ramdisk1.dmg
        hdiutil detach -force /tmp/SSHRD
        hdiutil attach -mountpoint /tmp/SSHRD work/ramdisk1.dmg -owners off
    else
    :
    fi
    
    if [ "$replace" = 'j42dap' ]; then
        "$oscheck"/gtar -x --no-overwrite-dir -f sshtars/atvssh.tar.gz -C /tmp/SSHRD/
    elif [ "$check" = '0x8012' ]; then
        "$oscheck"/gtar -x --no-overwrite-dir -f sshtars/t2ssh.tar.gz -C /tmp/SSHRD/
        echo_warn "[!] WARNING: T2 MIGHT HANG AND DO NOTHING WHEN BOOTING THE RAMDISK!"
    else
        if [ "$major" -lt 12 ]; then
            mkdir 12rd
            ipswurl12=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$oscheck"/jq '.firmwares | .[] | select(.version=="'12.0'")' | "$oscheck"/jq -s '.[0] | .url' --raw-output)
            cd 12rd
            ../"$oscheck"/pzb -g BuildManifest.plist "$ipswurl12"
            ../"$oscheck"/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl12"
            ../"$oscheck"/img4 -i "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -o ramdisk.dmg
            hdiutil attach -mountpoint /tmp/12rd ramdisk.dmg -owners off
            cp /tmp/12rd/usr/lib/libiconv.2.dylib /tmp/12rd/usr/lib/libcharset.1.dylib /tmp/SSHRD/usr/lib/
            hdiutil detach -force /tmp/12rd
            cd ..
            rm -rf 12rd
        else
        :
        fi
        if [ "$major" -eq 7 ] || [ "$major" -eq 8 ]; then
            "$oscheck"/gtar -x --no-overwrite-dir -f sshtars/iram.tar.gz -C /tmp/SSHRD/
            touch sshramdisk/device_port_44
        else
            "$oscheck"/gtar -x --no-overwrite-dir -f sshtars/ssh.tar.gz -C /tmp/SSHRD/
        fi
        tar -xvf other/sbplist.tar -C /tmp/SSHRD/
    fi
    hdiutil detach -force /tmp/SSHRD
    if [ "$major" -eq 16 ] && [ "$minor" -ge 1 ] || [ "$major" -gt 16 ]; then
        hdiutil resize -sectors min work/ramdisk1.dmg
    else
        hdiutil resize -sectors min work/ramdisk.dmg
    fi
else
    if [ "$major" -eq 16 ] && [ "$minor" -ge 1 ] || [ "$major" -gt 16 ]; then
        echo_error "[-] ERROR: Creating 16.1+ ramdisk is only supported on macOS, this is due to ramdisks switching to APFS over HFS+, and another dmg library has to be used"
        exit
    elif [ "$major" -eq 11 ] && [ "$minor" -lt 3 ] || [ "$major" -eq 10 ] || [ "$major" -eq 9 ]; then
        "$oscheck"/hfsplus work/ramdisk.dmg grow 110000000 > /dev/null
    elif [ "$major" -eq 7 ] || [ "$major" -eq 8 ]; then
        "$oscheck"/hfsplus work/ramdisk.dmg grow 50000000 > /dev/null
    else
        "$oscheck"/hfsplus work/ramdisk.dmg grow 210000000 > /dev/null
    fi

    if [ "$replace" = 'j42dap' ]; then
        "$oscheck"/hfsplus work/ramdisk.dmg untar sshtars/atvssh.tar > /dev/null
    elif [ "$check" = '0x8012' ]; then
        "$oscheck"/hfsplus work/ramdisk.dmg untar sshtars/t2ssh.tar > /dev/null
        echo_warn "[!] WARNING: T2 MIGHT HANG AND DO NOTHING WHEN BOOTING THE RAMDISK!"
    else
        if [ "$major" -lt 12 ]; then
            mkdir 12rd
            ipswurl12=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$oscheck"/jq '.firmwares | .[] | select(.version=="'12.0'")' | "$oscheck"/jq -s '.[0] | .url' --raw-output)
            cd 12rd
            ../"$oscheck"/pzb -g BuildManifest.plist "$ipswurl12"
            ../"$oscheck"/pzb -g "$(../Linux/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" "$ipswurl12"
            ../"$oscheck"/img4 -i "$(../Linux/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" -o ramdisk.dmg
            ../"$oscheck"/hfsplus ramdisk.dmg extract usr/lib/libcharset.1.dylib libcharset.1.dylib
            ../"$oscheck"/hfsplus ramdisk.dmg extract usr/lib/libiconv.2.dylib libiconv.2.dylib
            ../"$oscheck"/hfsplus ../work/ramdisk.dmg add libiconv.2.dylib usr/lib/libiconv.2.dylib
            ../"$oscheck"/hfsplus ../work/ramdisk.dmg add libcharset.1.dylib usr/lib/libcharset.1.dylib
            cd ..
            rm -rf 12rd
        else
        :
        fi
        if [ "$major" -eq 7 ] || [ "$major" -eq 8 ]; then
            "$oscheck"/hfsplus work/ramdisk.dmg untar sshtars/iram.tar > /dev/null
            touch sshramdisk/device_port_44
        else
            "$oscheck"/hfsplus work/ramdisk.dmg untar sshtars/ssh.tar > /dev/null
        fi
        "$oscheck"/hfsplus work/ramdisk.dmg untar other/sbplist.tar > /dev/null
    fi
fi
if [ "$oscheck" = 'Darwin' ]; then
    if [ "$major" -eq 16 ] && [ "$minor" -ge 1 ] || [ "$major" -gt 16 ]; then
        "$oscheck"/img4 -i work/ramdisk1.dmg -o sshramdisk/ramdisk.img4 -M work/IM4M -A -T rdsk
    else
        "$oscheck"/img4 -i work/ramdisk.dmg -o sshramdisk/ramdisk.img4 -M work/IM4M -A -T rdsk
    fi
else
    "$oscheck"/img4 -i work/ramdisk.dmg -o sshramdisk/ramdisk.img4 -M work/IM4M -A -T rdsk
fi
"$oscheck"/img4 -i other/bootlogo.im4p -o sshramdisk/logo.img4 -M work/IM4M -A -T rlgo
rm -rf work 12rd
echo_text "[*] Finished! Please use ./sshrd.sh boot to boot your device"
echo $1 > sshramdisk/version.txt
