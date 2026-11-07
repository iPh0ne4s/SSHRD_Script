#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
if [ "$(uname)" = 'Darwin' ]; then
    /usr/bin/xattr -cr "$(uname)"
fi
chmod -R 777 "$(uname)" saved > /dev/null 2>&1 || true

color_R=$(tput setaf 9)
color_G=$(tput setaf 10)
color_B=$(tput setaf 12)
color_Y=$(tput setaf 208)
color_N=$(tput sgr0)

echo_code() {
    echo "${color_B}    ${1}${color_N}"
}
echo_text() {
    echo "${color_G}[*] ${1}${color_N}"
}
echo_warn() {
    echo "${color_Y}[WARNING] ${1}${color_N}"
}
echo_input() {
    echo "${color_Y}[Input] ${1}${color_N}"
}
echo_error() {
    echo "${color_R}[ERROR] ${1}${color_N}"
}

pause() {
    echo_input "Press Enter/Return to continue (or press Ctrl+C to cancel)"
    read
}

ERR_HANDLER () {
    [ $? -eq 0 ] && exit
    echo_error "An error occurred"
    killall iproxy > /dev/null 2>&1 || true
    if [ "$(uname)" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 || true
    fi
}
trap ERR_HANDLER EXIT

backup_activation() {
    if [ "$(uname)" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
        sudo killall usbmuxd > /dev/null 2>&1 || true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
    if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -e /mnt2/tmp"; then
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/mount_filesystems || true"
    fi
    ramdisk_version=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/sw_vers -productVersion")
    ramdisk_major_version=${ramdisk_version%%.*}
    if [ "$ramdisk_major_version" -ge 15 ]; then
        serial_number=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/mnt1/usr/sbin/ioreg -l | grep IOPlatformSerialNumber | sed 's/.*IOPlatformSerialNumber\" = \"\(.*\)\"/\1/' | cut -d '\"' -f4")
    else
        serial_number=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/ioreg -l | grep IOPlatformSerialNumber | sed 's/.*IOPlatformSerialNumber\" = \"\(.*\)\"/\1/' | cut -d '\"' -f4")
    fi
    if [ -s saved/activation_records/$serial_number/*_record.plist ] || [ -s saved/activation_records/$serial_number/com.apple.commcenter.device_specific_nobackup.plist ] || [ -s saved/activation_records/$serial_number/IC-Info.sisv ]; then
        echo_warn "Activation files exist, proceeding will overwrite previous files"; pause
    fi
    mkdir -p saved/activation_records/$serial_number
    if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist"; then
        "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no "root@127.0.0.1:/mnt2/containers/Data/System/*/Library/activation_records/*_record.plist" saved/activation_records/$serial_number > /dev/null 2>&1 || true    # Generally activation_record.plist, sometimes pod_record.plist
    else
        echo_error "activation_record.plist not found on device"
    fi
    if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"; then
        "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist saved/activation_records/$serial_number || true
    else
        echo_error "com.apple.commcenter.device_specific_nobackup.plist not found on device"
    fi
    if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"; then
        "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv saved/activation_records/$serial_number || true
        if [ ! -s saved/activation_records/$serial_number/IC-Info.sisv ]; then
            echo_error "IC-Info.sisv is currently undownloadable, delete /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv, reboot to lock screen, this will generate a downloadable IC-Info.sisv, boot SSH ramdisk and try again"
        fi
    else
        echo_error "IC-Info.sisv not found on device"
    fi
    if [ -s saved/activation_records/$serial_number/*_record.plist ] && [ -s saved/activation_records/$serial_number/com.apple.commcenter.device_specific_nobackup.plist ] && [ -s saved/activation_records/$serial_number/IC-Info.sisv ]; then
        echo_text "Activation files saved to saved/activation_records/$serial_number"
    else
        echo_error "Failed to save one or more activation files, if caused by undownloadable IC-Info.sisv, follow the instruction above, otherwise make sure device is activated properly"
    fi
    
    # Obtain previous phone number from com.apple.commcenter.plist, requires plistutil installed on Linux
    if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/wireless/Library/Preferences/com.apple.commcenter.plist"; then
        "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt2/wireless/Library/Preferences/com.apple.commcenter.plist . > /dev/null 2>&1 || true
        if [ "$(uname)" = 'Darwin' ]; then
            /usr/bin/plutil -convert xml1 com.apple.commcenter.plist > /dev/null 2>&1 || true
        else
            plistutil -i com.apple.commcenter.plist -o com.apple.commcenter.plist > /dev/null 2>&1 || true
        fi
        cdma_network_phone_number=$(grep -A1 '<key>CDMANetworkPhoneNumber</key>' com.apple.commcenter.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
        network_phone_number=$(grep -A1 '<key>NetworkPhoneNumber</key>' com.apple.commcenter.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
        phone_number=$(grep -A1 '<key>PhoneNumber</key>' com.apple.commcenter.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
        sim_phone_number=$(grep -A1 '<key>SIMPhoneNumber</key>' com.apple.commcenter.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
        rm -f com.apple.commcenter.plist
        if [ -n "$cdma_network_phone_number" ] || [ -n "$network_phone_number" ] || [ -n "$phone_number" ] || [ -n "$sim_phone_number" ]; then
            echo_text "Possible Phone Number(s): "+$phone_number" "$network_phone_number" "$sim_phone_number" "$cdma_network_phone_number""
        fi
    fi
    
    killall iproxy > /dev/null 2>&1 || true
    if [ "$(uname)" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 || true
    fi
}

restore_activation() {
    if [ "$(uname)" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
        sudo killall usbmuxd > /dev/null 2>&1 || true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
    if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -e /mnt2/tmp"; then
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/mount_filesystems || true"
    fi
    ramdisk_version=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/sw_vers -productVersion")
    ramdisk_major_version=${ramdisk_version%%.*}
    if [ "$ramdisk_major_version" -ge 15 ]; then
        serial_number=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/mnt1/usr/sbin/ioreg -l | grep IOPlatformSerialNumber | sed 's/.*IOPlatformSerialNumber\" = \"\(.*\)\"/\1/' | cut -d '\"' -f4")
    else
        serial_number=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/ioreg -l | grep IOPlatformSerialNumber | sed 's/.*IOPlatformSerialNumber\" = \"\(.*\)\"/\1/' | cut -d '\"' -f4")
    fi
    if [ ! -e saved/activation_records/$serial_number ]; then
        echo_error "Activation files not found in saved/activation_records"
        killall iproxy > /dev/null 2>&1 || true
        if [ "$(uname)" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 || true
        fi
        exit
    fi
    if [ ! -s saved/activation_records/$serial_number/*_record.plist ]; then
        echo_error "activation_record.plist not found in saved/activation_records/$serial_number"
    else
        "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no saved/activation_records/$serial_number/*_record.plist root@127.0.0.1:/mnt2/tmp
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no 'mkdir -p "$(find /mnt2/containers/Data/System -type d -name internal)"/../activation_records'
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -vf /mnt2/tmp/*_record.plist /mnt2/containers/Data/System/*/Library/activation_records"
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 666 /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist"
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:nobody /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist"
    fi
    if [ ! -s saved/activation_records/$serial_number/com.apple.commcenter.device_specific_nobackup.plist ]; then
        echo_error "com.apple.commcenter.device_specific_nobackup.plist not found in saved/activation_records/$serial_number"
    else
        "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no saved/activation_records/$serial_number/com.apple.commcenter.device_specific_nobackup.plist root@127.0.0.1:/mnt2/tmp
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -vf /mnt2/tmp/com.apple.commcenter.device_specific_nobackup.plist /mnt2/wireless/Library/Preferences"
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 600 /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown _wireless:_wireless /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
    fi
    if [ ! -s saved/activation_records/$serial_number/IC-Info.sisv ]; then
        echo_error "IC-Info.sisv not found in saved/activation_records/$serial_number"
    else
        "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no saved/activation_records/$serial_number/IC-Info.sisv root@127.0.0.1:/mnt2/tmp
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mkdir -p /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -vf /mnt2/tmp/IC-Info.sisv /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes || true"
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/tmp/IC-Info.sisv"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -vf /mnt2/tmp/IC-Info.sisv /mnt2/mobile/Media/Downloads; mv -vf /mnt2/mobile/Media/Downloads/IC-Info.sisv /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"    # For iOS 17+
        fi
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 664 /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:mobile /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
    fi
    if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist" && "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist" && "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"; then
        echo_text "Activation files restored to device"
    else
        echo_error "Failed to restore one or more activation files, please check saved/activation_records/$serial_number folder and these paths on device:"
        echo_code "/mnt2/containers/Data/System/*/Library/activation_records/activation_record.plist (or pod_record.plist)"
        echo_code "/mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        echo_code "/mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
    fi
    if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Library/Caches/com.apple.MobileGestalt.plist"; then
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/plutil -key CacheExtra -key a6vjPkzcRjrsXmniFsm0dg -true /mnt2/mobile/Library/Caches/com.apple.MobileGestalt.plist"    # 9.3-10.1.1 do not recognize activation_record.plist, this is to hacktivate 10.0-10.1.1
    fi
    killall iproxy > /dev/null 2>&1 || true
    if [ "$(uname)" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 || true
    fi
}

backup_activation_ios789() {
    if [ "$(uname)" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
        sudo killall usbmuxd > /dev/null 2>&1 || true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
    "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s1 /mnt1 2>&1 | grep -v 'Could not create property for re-key environment check' || true"
    "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt1/System/Library/CoreServices/SystemVersion.plist . || true
    if [ ! -s SystemVersion.plist ]; then
        echo_error "Failed to mount filesystems as HFS+, probably iOS 10.3+, backup/restore activation files as usual and do not use this option"
        killall iproxy > /dev/null 2>&1 || true
        if [ "$(uname)" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 || true
        fi
        exit
    fi
    device_build_version=$(grep -A1 '<key>ProductBuildVersion</key>' SystemVersion.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
    device_version=$(grep -A1 '<key>ProductVersion</key>' SystemVersion.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
    device_major_version=$(echo "$device_version" | cut -d. -f1)
    device_minor_version=$(echo "$device_version" | cut -d. -f2)
    echo_text "Device Version: "$device_version" ("$device_build_version")"
    rm -f SystemVersion.plist
    if [ "$device_major_version" -eq 8 ] && [ "$device_minor_version" -le 2 ] || [ "$device_major_version" -eq 7 ]; then
        echo_warn "On 64-bit iOS 7.0-8.2, activation_record.plist cannot be restored through SSH ramdisk, which will cause bootloop. This means only com.apple.commcenter.device_specific_nobackup.plist and IC-Info.sisv will be restored, and the device will not be able to activate properly. Do not proceed if this is not what you expected"
        pause
    fi
    if [ "$device_major_version" -ge 10 ]; then
        echo_error "On iOS 10 and above, data partition can be properly mounted, backup/restore activation files as usual and do not use this option"
        killall iproxy > /dev/null 2>&1 || true
        if [ "$(uname)" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 || true
        fi
        exit
    elif [ "$device_major_version" -eq 9 ] && [ "$device_minor_version" -eq 3 ]; then
        echo_warn "On 9.3.x activation_record.plist won't be recognized, you will need to hacktivate the device later, do not proceed if this is not what you expected"; pause
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 2>&1 | grep -v 'Could not create property for re-key environment check' || true"
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -v /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist /mnt2/mobile/Media || true"
        else
            echo_error "activation_record.plist not found on device"
        fi
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -v /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist /mnt2/mobile/Media || true"
        else
            echo_error "com.apple.commcenter.device_specific_nobackup.plist not found on device"
        fi
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -v /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv /mnt2/mobile/Media || true"
        else
            echo_error "IC-Info.sisv not found on device"
        fi
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 777 /mnt2/mobile/Media/*_record.plist /mnt2/mobile/Media/com.apple.commcenter.device_specific_nobackup.plist /mnt2/mobile/Media/IC-Info.sisv || true"
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/*_record.plist" && "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/com.apple.commcenter.device_specific_nobackup.plist" && "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/IC-Info.sisv"; then
            echo_text "Activation files moved to /private/var/mobile/Media on device, and can be accessed in normal mode using iDescriptor"
        else
            echo_error "Failed to move one or more activation files, make sure device is activated properly"
        fi
        killall iproxy > /dev/null 2>&1 || true
        if [ "$(uname)" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 || true
        fi
    elif [ "$device_major_version" -eq 9 ] && [ "$device_minor_version" -le 2 ] || [ "$device_major_version" -eq 8 ]; then
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 2>&1 | grep -v 'Could not create property for re-key environment check' || true"
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Library/mad/activation_records/*_record.plist"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -v /mnt2/mobile/Library/mad/activation_records/*_record.plist /mnt2/mobile/Media || true"
        else
            echo_error "activation_record.plist not found on device"
        fi
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -v /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist /mnt2/mobile/Media || true"
        else
            echo_error "com.apple.commcenter.device_specific_nobackup.plist not found on device"
        fi
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -v /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv /mnt2/mobile/Media || true"
        else
            echo_error "IC-Info.sisv not found on device"
        fi
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 777 /mnt2/mobile/Media/*_record.plist /mnt2/mobile/Media/com.apple.commcenter.device_specific_nobackup.plist /mnt2/mobile/Media/IC-Info.sisv || true"
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/*_record.plist" && "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/com.apple.commcenter.device_specific_nobackup.plist" && "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/IC-Info.sisv"; then
            echo_text "Activation files moved to /private/var/mobile/Media on device, and can be accessed in normal mode using iDescriptor"
        else
            echo_error "Failed to move one or more activation files, make sure device is activated properly"
        fi
        killall iproxy > /dev/null 2>&1 || true
        if [ "$(uname)" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 || true
        fi
    elif [ "$device_major_version" -eq 7 ]; then
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 2>&1 | grep -v 'Could not create property for re-key environment check' || true"
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/root/Library/Lockdown/activation_records/*_record.plist"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -v /mnt2/root/Library/Lockdown/activation_records/*_record.plist /mnt2/mobile/Media || true"
        else
            echo_error "activation_record.plist not found on device"
        fi
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -v /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv /mnt2/mobile/Media || true"
        else
            echo_error "IC-Info.sisv not found on device"
        fi
        echo_text "Skipping com.apple.commcenter.device_specific_nobackup.plist on iOS 7, as it does not contain kPostponementTicket"
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 777 /mnt2/mobile/Media/*_record.plist /mnt2/mobile/Media/IC-Info.sisv || true"
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/*_record.plist" && "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/IC-Info.sisv"; then
            echo_text "Activation files moved to /private/var/mobile/Media on device, and can be accessed in normal mode using iDescriptor"
        else
            echo_error "Failed to move one or more activation files, make sure device is activated properly"
        fi
        killall iproxy > /dev/null 2>&1 || true
        if [ "$(uname)" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 || true
        fi
    else
        echo_error "Unable to get device version, cannot continue"
        killall iproxy > /dev/null 2>&1 || true
        if [ "$(uname)" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 || true
        fi
    fi
}

restore_activation_ios789() {
    if [ "$(uname)" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
        sudo killall usbmuxd > /dev/null 2>&1 || true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
    "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s1 /mnt1 2>&1 | grep -v 'Could not create property for re-key environment check' || true"
    "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt1/System/Library/CoreServices/SystemVersion.plist . || true
    if [ ! -s SystemVersion.plist ]; then
        echo_error "Failed to mount filesystems as HFS+, probably iOS 10.3+, backup/restore activation files as usual and do not use this option"
        killall iproxy > /dev/null 2>&1 || true
        if [ "$(uname)" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 || true
        fi
        exit
    fi
    device_build_version=$(grep -A1 '<key>ProductBuildVersion</key>' SystemVersion.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
    device_version=$(grep -A1 '<key>ProductVersion</key>' SystemVersion.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
    device_major_version=$(echo "$device_version" | cut -d. -f1)
    device_minor_version=$(echo "$device_version" | cut -d. -f2)
    echo_text "Device Version: "$device_version" ("$device_build_version")"
    rm -f SystemVersion.plist
    if [ "$device_major_version" -ge 10 ]; then
        echo_error "On iOS 10 and above, data partition can be properly mounted, backup/restore activation files as usual and do not use this option"
        killall iproxy > /dev/null 2>&1 || true
        if [ "$(uname)" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 || true
        fi
        exit
    # On 9.3.x activation_record.plist won't be recognized, to hacktivate device, add key a6vjPkzcRjrsXmniFsm0dg in CacheExtra item in com.apple.MobileGestalt.plist
    elif [ "$device_major_version" -eq 9 ] && [ "$device_minor_version" -eq 3 ]; then
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 2>&1 | grep -v 'Could not create property for re-key environment check' || true"
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/*_record.plist"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no 'mkdir -p "$(find /mnt2/containers/Data/System -type d -name internal)"/../activation_records'
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -vf /mnt2/mobile/Media/*_record.plist /mnt2/containers/Data/System/*/Library/activation_records"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 666 /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:nobody /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist"
        else
            echo_error "activation_record.plist not found in /mnt2/mobile/Media"
        fi
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/com.apple.commcenter.device_specific_nobackup.plist"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -vf /mnt2/mobile/Media/com.apple.commcenter.device_specific_nobackup.plist /mnt2/wireless/Library/Preferences"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 600 /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown _wireless:_wireless /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        else
            echo_error "com.apple.commcenter.device_specific_nobackup.plist not found in /mnt2/mobile/Media"
        fi
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/IC-Info.sisv"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mkdir -p /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -vf /mnt2/mobile/Media/IC-Info.sisv /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 664 /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:mobile /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
        else
            echo_error "IC-Info.sisv not found in /mnt2/mobile/Media"
        fi
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/containers/Data/System/*/Library/activation_records/*_record.plist" && "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist" && "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"; then
            echo_text "Activation files restored to device"
        else
            echo_error "Failed to restore one or more activation files, please import activation_record.plist, com.apple.commcenter.device_specific_nobackup.plist, IC-Info.sisv to /private/var/mobile/Media in normal mode"
        fi
        echo_warn "On 9.3.x activation_record.plist won't be recognized, to hacktivate device, add key a6vjPkzcRjrsXmniFsm0dg in CacheExtra item in com.apple.MobileGestalt.plist, you may use xplist to do this. Move the file to /mnt2/mobile/Media instead of directly downloading it"
        killall iproxy > /dev/null 2>&1 || true
        if [ "$(uname)" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 || true
        fi
    elif ([ "$device_major_version" -eq 8 ] && [ "$device_minor_version" -ge 3 ]) || ([ "$device_major_version" -eq 9 ] && [ "$device_minor_version" -le 2 ]); then
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 2>&1 | grep -v 'Could not create property for re-key environment check' || true"
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/*_record.plist"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mkdir -p /mnt2/mobile/Library/mad/activation_records"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -vf /mnt2/mobile/Media/*_record.plist /mnt2/mobile/Library/mad/activation_records"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 666 /mnt2/mobile/Library/mad/activation_records/*_record.plist"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:nobody /mnt2/mobile/Library/mad/activation_records/*_record.plist"
        else
            echo_error "activation_record.plist not found in /mnt2/mobile/Media"
        fi
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/com.apple.commcenter.device_specific_nobackup.plist"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -vf /mnt2/mobile/Media/com.apple.commcenter.device_specific_nobackup.plist /mnt2/wireless/Library/Preferences"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 600 /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown _wireless:_wireless /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        else
            echo_error "com.apple.commcenter.device_specific_nobackup.plist not found in /mnt2/mobile/Media"
        fi
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/IC-Info.sisv"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mkdir -p /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -vf /mnt2/mobile/Media/IC-Info.sisv /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 664 /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:mobile /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
        else
            echo_error "IC-Info.sisv not found in /mnt2/mobile/Media"
        fi
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Library/mad/activation_records/*_record.plist" && "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist" && "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"; then
            echo_text "Activation files restored to device"
        else
            echo_error "Failed to restore one or more activation files, please import activation_record.plist, com.apple.commcenter.device_specific_nobackup.plist, IC-Info.sisv to /private/var/mobile/Media in normal mode"
        fi
        killall iproxy > /dev/null 2>&1 || true
        if [ "$(uname)" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 || true
        fi
    elif [ "$device_major_version" -eq 8 ] && [ "$device_minor_version" -le 2 ]; then
        echo_warn "Restoring activation_record.plist through SSH ramdisk is not supported on 64-bit iOS 7.0-8.2, which will cause bootloop, and DO NOT do this manually! Only com.apple.commcenter.device_specific_nobackup.plist and IC-Info.sisv will be restored"; pause
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 2>&1 | grep -v 'Could not create property for re-key environment check' || true"
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/com.apple.commcenter.device_specific_nobackup.plist"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -vf /mnt2/mobile/Media/com.apple.commcenter.device_specific_nobackup.plist /mnt2/wireless/Library/Preferences"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 600 /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown _wireless:_wireless /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        else
            echo_error "com.apple.commcenter.device_specific_nobackup.plist not found in /mnt2/mobile/Media"
        fi
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/IC-Info.sisv"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mkdir -p /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -vf /mnt2/mobile/Media/IC-Info.sisv /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 664 /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:mobile /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
        else
            echo_error "IC-Info.sisv not found in /mnt2/mobile/Media"
        fi
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist" && "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"; then
            echo_text "com.apple.commcenter.device_specific_nobackup.plist and IC-Info.sisv restored to device"
        else
            echo_error "Failed to restore one or more activation files, please import com.apple.commcenter.device_specific_nobackup.plist and IC-Info.sisv to /private/var/mobile/Media in normal mode"
        fi
        killall iproxy > /dev/null 2>&1 || true
        if [ "$(uname)" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 || true
        fi
    elif [ "$device_major_version" -eq 7 ]; then
        echo_warn "Restoring activation_record.plist through SSH ramdisk is not supported on 64-bit iOS 7.0-8.2, which will cause bootloop, and DO NOT do this manually! Only com.apple.commcenter.device_specific_nobackup.plist and IC-Info.sisv will be restored"; pause
        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 2>&1 | grep -v 'Could not create property for re-key environment check' || true"
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Media/IC-Info.sisv"; then
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mkdir -p /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -vf /mnt2/mobile/Media/IC-Info.sisv /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 664 /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:mobile /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
        else
            echo_error "IC-Info.sisv not found in /mnt2/mobile/Media"
        fi
        echo_text "Skipping com.apple.commcenter.device_specific_nobackup.plist on iOS 7, as it does not contain kPostponementTicket"
        if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"; then
            echo_text "IC-Info.sisv restored to device"
        else
            echo_error "Failed to restore IC-Info.sisv, please import IC-Info.sisv to /private/var/mobile/Media in normal mode"
        fi
        killall iproxy > /dev/null 2>&1 || true
        if [ "$(uname)" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 || true
        fi
    else
        echo_error "Unable to get device version, cannot continue"
        killall iproxy > /dev/null 2>&1 || true
        if [ "$(uname)" = 'Linux' ]; then
            sudo killall usbmuxd > /dev/null 2>&1 || true
        fi
    fi
}

boot_ramdisk() {
    if ! ("$(uname)"/"$(uname -m)"/irecovery -q | grep 'MODE: DFU' > /dev/null 2>&1); then
        echo_text "Waiting for device in DFU mode"
    fi
    while ! ("$(uname)"/"$(uname -m)"/irecovery -q | grep 'MODE: DFU' > /dev/null 2>&1); do
        sleep 1
    done
    check=$("$(uname)"/"$(uname -m)"/irecovery -q | grep CPID | sed 's/CPID: //')
    replace=$("$(uname)"/"$(uname -m)"/irecovery -q | grep MODEL | sed 's/MODEL: //')
    
    if [ ! -e saved/sshramdisk/iBSS.img4 ] || [ ! -e saved/sshramdisk/iBEC.img4 ] || [ ! -e saved/sshramdisk/kernelcache.img4 ] || [ ! -e saved/sshramdisk/devicetree.img4 ] || [ ! -e saved/sshramdisk/ramdisk.img4 ]; then
        echo_error "Ramdisk incomplete, please re-create ramdisk"; exit
    fi
    if [ ! -e saved/sshramdisk/"$replace" ]; then
        echo_error "Ramdisk model does not match device model, please re-create ramdisk"; exit
    fi
    ramdisk_major_version=$(cat saved/sshramdisk/version | cut -d. -f1)
    echo_text "Ramdisk Version: "$(cat saved/sshramdisk/version)""
    
    if [ "$check" = '0x8960' ] && [ "$(uname)" = 'Linux' ]; then
        if [ -z "$("$(uname)"/"$(uname -m)"/irecovery -q | grep PWND | cut -c 7-)" ]; then
            echo_warn "Linux and A7 device detected, please use ipwnder_lite to enter pwnDFU mode first, you may continue booting, but pwnDFU process will likely fail"; pause
            echo_text "gaster pwn"
            "$(uname)"/"$(uname -m)"/gaster pwn
        else
            echo_text "Pwned: "$("$(uname)"/"$(uname -m)"/irecovery -q | grep PWND | cut -c 7-)""
        fi
    else
        echo_text "gaster pwn"
        "$(uname)"/"$(uname -m)"/gaster pwn
    fi
    echo_text "gaster reset"
    "$(uname)"/"$(uname -m)"/gaster reset
    echo_text "irecovery -f iBSS.img4"
    "$(uname)"/"$(uname -m)"/irecovery -f saved/sshramdisk/iBSS.img4
    sleep 5
    echo_text "irecovery -f iBEC.img4"
    "$(uname)"/"$(uname -m)"/irecovery -f saved/sshramdisk/iBEC.img4
    if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
        echo_text "irecovery -c go"
        "$(uname)"/"$(uname -m)"/irecovery -c go
    fi
    sleep 5
    if ! ("$(uname)"/"$(uname -m)"/irecovery -q | grep 'MODE: Recovery' > /dev/null 2>&1); then
        echo_error "Unable to find device in recovery mode, unplug and replug device now"
    fi
    while ! ("$(uname)"/"$(uname -m)"/irecovery -q | grep 'MODE: Recovery' > /dev/null 2>&1); do
        sleep 1
    done
    if [ -s saved/sshramdisk/logo.img4 ]; then
        echo_text "irecovery -f logo.img4"
        "$(uname)"/"$(uname -m)"/irecovery -f saved/sshramdisk/logo.img4
        echo_text "irecovery -c 'setpicture 0x1'"
        "$(uname)"/"$(uname -m)"/irecovery -c "setpicture 0x1"
    fi
    echo_text "irecovery -f ramdisk.img4"
    "$(uname)"/"$(uname -m)"/irecovery -f saved/sshramdisk/ramdisk.img4
    echo_text "irecovery -c ramdisk"
    "$(uname)"/"$(uname -m)"/irecovery -c ramdisk
    if [ "$ramdisk_major_version" -ge 16 ] || [ -s saved/sshramdisk/sep-firmware.img4 ]; then
        echo_text "irecovery -f sep-firmware.img4"
        "$(uname)"/"$(uname -m)"/irecovery -f saved/sshramdisk/sep-firmware.img4
        echo_text "irecovery -c rsepfirmware"
        "$(uname)"/"$(uname -m)"/irecovery -c rsepfirmware
    fi
    echo_text "irecovery -f devicetree.img4"
    "$(uname)"/"$(uname -m)"/irecovery -f saved/sshramdisk/devicetree.img4
    echo_text "irecovery -c devicetree"
    "$(uname)"/"$(uname -m)"/irecovery -c devicetree
    if [ "$ramdisk_major_version" -ge 12 ] || [ -s saved/sshramdisk/trustcache.img4 ]; then
        echo_text "irecovery -f trustcache.img4"
        "$(uname)"/"$(uname -m)"/irecovery -f saved/sshramdisk/trustcache.img4
        echo_text "irecovery -c firmware"
        "$(uname)"/"$(uname -m)"/irecovery -c firmware
    fi
    echo_text "irecovery -f kernelcache.img4"
    "$(uname)"/"$(uname -m)"/irecovery -f saved/sshramdisk/kernelcache.img4
    echo_text "irecovery -c bootx"
    "$(uname)"/"$(uname -m)"/irecovery -c bootx

    sleep 6; ramdisk_mode_menu
}

create_ramdisk() {
    read -p "$(echo_input "Ramdisk Version: ")" ramdisk_version
    ramdisk_major_version=$(echo "$ramdisk_version" | cut -d. -f1)
    ramdisk_minor_version=$(echo "$ramdisk_version" | cut -d. -f2)
    if [ "$ramdisk_major_version" -eq 8 ]; then
        echo_warn "iOS 8 ramdisk is only for exiting black screen recovery loop on A7 iOS 7 devices, which is caused by loading a higher version ramdisk. DO NOT use iOS 8 ramdisk in any other cases"; pause
    fi
    if [ "$ramdisk_major_version" -eq 7 ] || [ "$ramdisk_major_version" -eq 9 ]; then
        echo_warn "iOS "$ramdisk_major_version" ramdisk created by SSHRD_Script is unusable, use 10.0.1 ramdisk if your device is on iOS 7-9"; pause
    fi
    if ! ("$(uname)"/"$(uname -m)"/irecovery -q | grep 'MODE: DFU' > /dev/null 2>&1); then
        echo_text "Waiting for device in DFU mode"
    fi
    while ! ("$(uname)"/"$(uname -m)"/irecovery -q | grep 'MODE: DFU' > /dev/null 2>&1); do
        sleep 1
    done
    check=$("$(uname)"/"$(uname -m)"/irecovery -q | grep CPID | sed 's/CPID: //')
    replace=$("$(uname)"/"$(uname -m)"/irecovery -q | grep MODEL | sed 's/MODEL: //')
    deviceid=$("$(uname)"/"$(uname -m)"/irecovery -q | grep PRODUCT | sed 's/PRODUCT: //')

    if ([ "$deviceid" = 'iPad7,11' ] || [ "$deviceid" = 'iPad7,12' ]) && [ "$ramdisk_major_version" -ge 18 ]; then
        echo_warn "Unable to patch 18.x iBSS and iBEC with current iBoot64Patcher, will create 17.0 ramdisk"; pause
        ipswurl=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$(uname)"/"$(uname -m)"/jq '.firmwares | .[] | select(.version=="'17.0'")' | "$(uname)"/"$(uname -m)"/jq -s '.[0] | .url' --raw-output)
    elif ([ "$deviceid" = 'iPad6,3' ] || [ "$deviceid" = 'iPad6,4' ] || [ "$deviceid" = 'iPad6,7' ] || [ "$deviceid" = 'iPad6,8' ] || [ "$deviceid" = 'iPad6,11' ] || [ "$deviceid" = 'iPad6,12' ]) && [ "$ramdisk_major_version" -eq 16 ]; then
        echo_warn "Unable to patch A9(X) 16.x iBSS and iBEC with current iBoot64Patcher, will create 16.4 ramdisk with pre-made iBSS.img4 and iBEC.img4"; pause
        ipswurl=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$(uname)"/"$(uname -m)"/jq '.firmwares | .[] | select(.version=="'16.4'")' | "$(uname)"/"$(uname -m)"/jq -s '.[0] | .url' --raw-output)
    else
        ipswurl=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$(uname)"/"$(uname -m)"/jq '.firmwares | .[] | select(.version=="'$ramdisk_version'")' | "$(uname)"/"$(uname -m)"/jq -s '.[0] | .url' --raw-output)
    fi

    if [ "$check" = '0x8960' ] && [ "$(uname)" = 'Linux' ]; then
        if [ -z "$("$(uname)"/"$(uname -m)"/irecovery -q | grep PWND | cut -c 7-)" ]; then
            echo_warn "Linux and A7 device detected, please use ipwnder_lite to enter pwnDFU mode first, otherwise boot process will likely fail"; pause
        fi
    else
        "$(uname)"/"$(uname -m)"/gaster pwn
    fi
    
    rm -rf saved/sshramdisk tmp; mkdir tmp
    "$(uname)"/"$(uname -m)"/img4tool -e -s resources/shsh/"$check".shsh2 -m tmp/IM4M
    "$(uname)"/"$(uname -m)"/img4 -i resources/bootlogo.im4p -o tmp/logo.img4 -M tmp/IM4M -A -T rlgo
    cd tmp
    ../"$(uname)"/"$(uname -m)"/pzb -g BuildManifest.plist "$ipswurl"
    echo_text "iBSS"
    ../"$(uname)"/"$(uname -m)"/pzb -g "$(awk "/""$replace""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
    echo_text "iBEC"
    ../"$(uname)"/"$(uname -m)"/pzb -g "$(awk "/""$replace""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
    echo_text "DeviceTree"
    ../"$(uname)"/"$(uname -m)"/pzb -g "$(awk "/""$replace""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
    echo_text "Kernelcache"
    ../"$(uname)"/"$(uname -m)"/pzb -g "$(awk "/""$replace""/{x=1}x&&/kernelcache.release/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
    echo_text "Restore Ramdisk"
    if [ "$(uname)" = 'Darwin' ]; then
        ../"$(uname)"/"$(uname -m)"/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl"
    else
        ../"$(uname)"/"$(uname -m)"/pzb -g "$(../"$(uname)"/"$(uname -m)"/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" "$ipswurl"
    fi
    if [ "$ramdisk_major_version" -ge 12 ]; then
        echo_text "Trustcache"
        if [ "$(uname)" = 'Darwin' ]; then
            ../"$(uname)"/"$(uname -m)"/pzb -g Firmware/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache "$ipswurl"
        else
            ../"$(uname)"/"$(uname -m)"/pzb -g Firmware/"$(../"$(uname)"/"$(uname -m)"/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')".trustcache "$ipswurl"
        fi
    fi
    if [ "$ramdisk_major_version" -ge 16 ]; then
        echo_text "SEP-Firmware"
        ../"$(uname)"/"$(uname -m)"/pzb -g "$(awk "/""$replace""/{x=1}x&&/sep-firmware[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
    fi
    cd ..

    # Use local ivkey file as a workaround for A7 pwndfu issue on Linux, avoiding `gaster decrypt` command
    devicetree_ivkey="$(sed -n "s/^"$replace"_"$ramdisk_version"_DeviceTree=\"\([^\"]*\)\"$/\1/p" resources/ivkey)"
    ibec_ivkey="$(sed -n "s/^"$replace"_"$ramdisk_version"_iBEC=\"\([^\"]*\)\"$/\1/p" resources/ivkey)"
    ibss_ivkey="$(sed -n "s/^"$replace"_"$ramdisk_version"_iBSS=\"\([^\"]*\)\"$/\1/p" resources/ivkey)"
    kernelcache_ivkey="$(sed -n "s/^"$replace"_"$ramdisk_version"_Kernelcache=\"\([^\"]*\)\"$/\1/p" resources/ivkey)"
    restoreramdisk_ivkey="$(sed -n "s/^"$replace"_"$ramdisk_version"_RestoreRamdisk=\"\([^\"]*\)\"$/\1/p" resources/ivkey)"

    if [ "$check" = '0x8960' ]; then
        "$(uname)"/"$(uname -m)"/img4 -i tmp/"$(awk "/""$replace""/{x=1}x&&/iBSS[.]/{print;exit}" tmp/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" -o tmp/iBSS.dec -k "$ibss_ivkey"
        "$(uname)"/"$(uname -m)"/img4 -i tmp/"$(awk "/""$replace""/{x=1}x&&/iBEC[.]/{print;exit}" tmp/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" -o tmp/iBEC.dec -k "$ibec_ivkey"
    else
        "$(uname)"/"$(uname -m)"/gaster decrypt tmp/"$(awk "/""$replace""/{x=1}x&&/iBSS[.]/{print;exit}" tmp/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" tmp/iBSS.dec
        "$(uname)"/"$(uname -m)"/gaster decrypt tmp/"$(awk "/""$replace""/{x=1}x&&/iBEC[.]/{print;exit}" tmp/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" tmp/iBEC.dec
    fi
    if ([ "$ramdisk_major_version" -eq 10 ] && [ "$ramdisk_minor_version" -le 2 ] || [ "$ramdisk_major_version" -le 9 ]) || ([ "$ramdisk_major_version" -le 12 ] && ([ "$deviceid" = 'iPad6,3' ] || [ "$deviceid" = 'iPad6,4' ] || [ "$deviceid" = 'iPad6,7' ] || [ "$deviceid" = 'iPad6,8' ] || [ "$deviceid" = 'iPad6,11' ] || [ "$deviceid" = 'iPad6,12' ])); then
        "$(uname)"/"$(uname -m)"/kairos tmp/iBSS.dec tmp/iBSS.patched
        "$(uname)"/"$(uname -m)"/img4 -i tmp/iBSS.patched -o tmp/iBSS.img4 -M tmp/IM4M -A -T ibss
        "$(uname)"/"$(uname -m)"/kairos tmp/iBEC.dec tmp/iBEC.patched -b "rd=md0 debug=0x2014e -v wdt=-1 `if [ "$check" = '0x8960' ] || [ "$check" = '0x7000' ] || [ "$check" = '0x7001' ]; then echo "nand-enable-reformat=1 -restore"; fi` `if [ "$ramdisk_major_version" -le 9 ]; then echo "amfi=0xff cs_enforcement_disable=1"; fi`" -n
        "$(uname)"/"$(uname -m)"/img4 -i tmp/iBEC.patched -o tmp/iBEC.img4 -M tmp/IM4M -A -T ibec
    elif ([ "$deviceid" = 'iPad6,3' ] || [ "$deviceid" = 'iPad6,4' ] || [ "$deviceid" = 'iPad6,7' ] || [ "$deviceid" = 'iPad6,8' ] || [ "$deviceid" = 'iPad6,11' ] || [ "$deviceid" = 'iPad6,12' ]) && [ "$ramdisk_major_version" -eq 16 ]; then
        cp -v resources/16.4/"$replace"_16.4_iBSS.img4 tmp/iBSS.img4
        cp -v resources/16.4/"$replace"_16.4_iBEC.img4 tmp/iBEC.img4
    else
        "$(uname)"/"$(uname -m)"/iBoot64Patcher tmp/iBSS.dec tmp/iBSS.patched
        "$(uname)"/"$(uname -m)"/img4 -i tmp/iBSS.patched -o tmp/iBSS.img4 -M tmp/IM4M -A -T ibss
        "$(uname)"/"$(uname -m)"/iBoot64Patcher tmp/iBEC.dec tmp/iBEC.patched -b "rd=md0 debug=0x2014e -v wdt=-1 `if [ "$check" = '0x8960' ] || [ "$check" = '0x7000' ] || [ "$check" = '0x7001' ]; then echo "nand-enable-reformat=1 -restore"; fi`" -n
        "$(uname)"/"$(uname -m)"/img4 -i tmp/iBEC.patched -o tmp/iBEC.img4 -M tmp/IM4M -A -T ibec
    fi   

    if [ "$ramdisk_major_version" -le 9 ]; then
        if [ "$check" != '0x8960' ]; then
            kbag=$("$(uname)"/"$(uname -m)"/img4 -i tmp/"$(awk "/""$replace""/{x=1}x&&/kernelcache.release/{print;exit}" tmp/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -b | head -n 1)
            iv=$("$(uname)"/"$(uname -m)"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ',' -f 1 | cut -d ' ' -f 2)
            key=$("$(uname)"/"$(uname -m)"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ' ' -f 4)
            kernelcache_ivkey="$iv$key"
        fi
        "$(uname)"/"$(uname -m)"/img4 -i tmp/"$(awk "/""$replace""/{x=1}x&&/kernelcache.release/{print;exit}" tmp/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o tmp/kernelcache.im4p -k "$kernelcache_ivkey" -D
        "$(uname)"/"$(uname -m)"/img4 -i tmp/kernelcache.im4p -o tmp/kernelcache.img4 -M tmp/IM4M -T rkrn
    else
        "$(uname)"/"$(uname -m)"/img4 -i tmp/"$(awk "/""$replace""/{x=1}x&&/kernelcache.release/{print;exit}" tmp/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o tmp/kcache.raw
        "$(uname)"/"$(uname -m)"/KPlooshFinder tmp/kcache.raw tmp/kcache.patched
        "$(uname)"/"$(uname -m)"/kerneldiff tmp/kcache.raw tmp/kcache.patched tmp/kc.bpatch
        "$(uname)"/"$(uname -m)"/img4 -i tmp/"$(awk "/""$replace""/{x=1}x&&/kernelcache.release/{print;exit}" tmp/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o tmp/kernelcache.img4 -M tmp/IM4M -T rkrn -P tmp/kc.bpatch `if [ "$(uname)" = 'Linux' ]; then echo "-J"; fi`
    fi 

    if [ "$ramdisk_major_version" -eq 10 ] && [ "$ramdisk_minor_version" -le 2 ]; then
        "$(uname)"/"$(uname -m)"/img4 -i tmp/"$(awk "/""$replace""/{x=1}x&&/DeviceTree[.]/{print;exit}" tmp/BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash[.].*[.]production[/]//')" -o tmp/devicetree.img4 -M tmp/IM4M -T rdtr
    elif [ "$ramdisk_major_version" -le 9 ]; then
        if [ "$check" != '0x8960' ]; then
            kbag=$("$(uname)"/"$(uname -m)"/img4 -i tmp/"$(awk "/""$replace""/{x=1}x&&/DeviceTree[.]/{print;exit}" tmp/BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash[.].*[.]production[/]//')" -b | head -n 1)
            iv=$("$(uname)"/"$(uname -m)"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ',' -f 1 | cut -d ' ' -f 2)
            key=$("$(uname)"/"$(uname -m)"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ' ' -f 4)
            devicetree_ivkey="$iv$key"
        fi
        "$(uname)"/"$(uname -m)"/img4 -i tmp/"$(awk "/""$replace""/{x=1}x&&/DeviceTree[.]/{print;exit}" tmp/BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash[.].*[.]production[/]//')" -o tmp/dtree.raw -k "$devicetree_ivkey"
        "$(uname)"/"$(uname -m)"/img4 -i tmp/dtree.raw -o tmp/devicetree.img4 -A -M tmp/IM4M -T rdtr
    else
        "$(uname)"/"$(uname -m)"/img4 -i tmp/"$(awk "/""$replace""/{x=1}x&&/DeviceTree[.]/{print;exit}" tmp/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]//')" -o tmp/devicetree.img4 -M tmp/IM4M -T rdtr
    fi   

    if [ "$ramdisk_major_version" -ge 16 ]; then
        "$(uname)"/"$(uname -m)"/img4 -i tmp/"$(awk "/""$replace""/{x=1}x&&/sep-firmware[.]/{print;exit}" tmp/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]//')" -o tmp/sep-firmware.img4 -M tmp/IM4M -T rsep
    fi

    if [ "$(uname)" = 'Darwin' ]; then
        if [ "$ramdisk_major_version" -ge 12 ]; then
            "$(uname)"/"$(uname -m)"/img4 -i tmp/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - tmp/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache -o tmp/trustcache.img4 -M tmp/IM4M -T rtsc
        fi
        if [ "$ramdisk_major_version" -le 9 ]; then
            if [ "$check" != '0x8960' ]; then
                kbag=$("$(uname)"/"$(uname -m)"/img4 -i tmp/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - tmp/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -b | head -n 1)
                iv=$("$(uname)"/"$(uname -m)"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ',' -f 1 | cut -d ' ' -f 2)
                key=$("$(uname)"/"$(uname -m)"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ' ' -f 4)
                restoreramdisk_ivkey="$iv$key"
            fi
            "$(uname)"/"$(uname -m)"/img4 -i tmp/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - tmp/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -o tmp/ramdisk.dmg -k "$restoreramdisk_ivkey"
        else
            "$(uname)"/"$(uname -m)"/img4 -i tmp/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - tmp/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -o tmp/ramdisk.dmg
        fi
    else
        if [ "$ramdisk_major_version" -ge 12 ]; then
            "$(uname)"/"$(uname -m)"/img4 -i tmp/"$("$(uname)"/"$(uname -m)"/PlistBuddy tmp/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')".trustcache -o tmp/trustcache.img4 -M tmp/IM4M -T rtsc
        fi
        if [ "$ramdisk_major_version" -le 9 ]; then
            if [ "$check" != '0x8960' ]; then
                kbag=$("$(uname)"/"$(uname -m)"/img4 -i tmp/"$("$(uname)"/"$(uname -m)"/PlistBuddy tmp/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" -b | head -n 1)
                iv=$("$(uname)"/"$(uname -m)"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ',' -f 1 | cut -d ' ' -f 2)
                key=$("$(uname)"/"$(uname -m)"/gaster decrypt_kbag "$kbag" | tail -n 1 | cut -d ' ' -f 4)
                restoreramdisk_ivkey="$iv$key"
            fi
            "$(uname)"/"$(uname -m)"/img4 -i tmp/"$("$(uname)"/"$(uname -m)"/PlistBuddy tmp/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" -o tmp/ramdisk.dmg -k "$restoreramdisk_ivkey"
        else
            "$(uname)"/"$(uname -m)"/img4 -i tmp/"$("$(uname)"/"$(uname -m)"/PlistBuddy tmp/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" -o tmp/ramdisk.dmg
        fi
    fi

    if [ "$(uname)" = 'Darwin' ]; then
        if [ "$ramdisk_major_version" -eq 16 ] && [ "$ramdisk_minor_version" -ge 1 ] || [ "$ramdisk_major_version" -gt 16 ]; then
            :
        elif [ "$ramdisk_major_version" -eq 11 ] && [ "$ramdisk_minor_version" -le 2 ] || [ "$ramdisk_major_version" -eq 10 ] || [ "$ramdisk_major_version" -eq 9 ]; then
            hdiutil resize -size 110MB tmp/ramdisk.dmg
        elif [ "$ramdisk_major_version" -eq 7 ] || [ "$ramdisk_major_version" -eq 8 ]; then
            hdiutil resize -size 50MB tmp/ramdisk.dmg
        else
            hdiutil resize -size 200MB tmp/ramdisk.dmg
        fi
        hdiutil attach -mountpoint /tmp/SSHRD tmp/ramdisk.dmg -owners off
    
        if [ "$ramdisk_major_version" -eq 16 ] && [ "$ramdisk_minor_version" -ge 1 ] || [ "$ramdisk_major_version" -gt 16 ]; then
            hdiutil create -size 200m -imagekey diskimage-class=CRawDiskImage -format UDZO -fs HFS+ -layout NONE -srcfolder /tmp/SSHRD -copyuid root tmp/ramdisk_hfs.dmg
            hdiutil detach -force /tmp/SSHRD
            hdiutil attach -mountpoint /tmp/SSHRD tmp/ramdisk_hfs.dmg -owners off
        fi
    
        if [ "$replace" = 'j42dap' ]; then
            "$(uname)"/"$(uname -m)"/gtar -x --no-overwrite-dir -f resources/sshtars/atvssh.tar.gz -C /tmp/SSHRD/
        elif [ "$check" = '0x8012' ]; then
            "$(uname)"/"$(uname -m)"/gtar -x --no-overwrite-dir -f resources/sshtars/t2ssh.tar.gz -C /tmp/SSHRD/
            echo_warn "T2 MIGHT HANG AND DO NOTHING WHEN BOOTING THE RAMDISK!"
        else
            if [ "$ramdisk_major_version" -lt 12 ]; then
                ipswurl12=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$(uname)"/"$(uname -m)"/jq '.firmwares | .[] | select(.version=="'12.0'")' | "$(uname)"/"$(uname -m)"/jq -s '.[0] | .url' --raw-output)
                cd tmp
                ../"$(uname)"/"$(uname -m)"/pzb -g BuildManifest.plist "$ipswurl12"
                ../"$(uname)"/"$(uname -m)"/pzb -g "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" "$ipswurl12"
                ../"$(uname)"/"$(uname -m)"/img4 -i "$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -o ramdisk12.dmg
                hdiutil attach -mountpoint /tmp/12rd ramdisk12.dmg -owners off
                cp -v /tmp/12rd/usr/lib/libiconv.2.dylib /tmp/12rd/usr/lib/libcharset.1.dylib /tmp/SSHRD/usr/lib/
                hdiutil detach -force /tmp/12rd
                cd ..
            fi
            if [ "$ramdisk_major_version" -eq 7 ] || [ "$ramdisk_major_version" -eq 8 ]; then
                "$(uname)"/"$(uname -m)"/gtar -x --no-overwrite-dir -f resources/sshtars/iram.tar.gz -C /tmp/SSHRD/
                mkdir -p saved/sshramdisk; touch saved/sshramdisk/device_port_44
            else
                "$(uname)"/"$(uname -m)"/gtar -x --no-overwrite-dir -f resources/sshtars/ssh.tar.gz -C /tmp/SSHRD/
            fi
            if [ "$check" = '0x8960' ] || [ "$check" = '0x7000' ] || [ "$check" = '0x7001' ]; then
                tar -xvf resources/sbplist.tar -C /tmp/SSHRD/
            fi
        fi
        hdiutil detach -force /tmp/SSHRD
        if [ "$ramdisk_major_version" -eq 16 ] && [ "$ramdisk_minor_version" -ge 1 ] || [ "$ramdisk_major_version" -gt 16 ]; then
            hdiutil resize -sectors min tmp/ramdisk_hfs.dmg
        else
            hdiutil resize -sectors min tmp/ramdisk.dmg
        fi
    else
        if [ "$ramdisk_major_version" -eq 16 ] && [ "$ramdisk_minor_version" -ge 1 ] || [ "$ramdisk_major_version" -gt 16 ]; then
            "$(uname)"/"$(uname -m)"/apfs-tool tmp/ramdisk.dmg grow 200000000
        elif [ "$ramdisk_major_version" -eq 11 ] && [ "$ramdisk_minor_version" -le 2 ] || [ "$ramdisk_major_version" -eq 10 ] || [ "$ramdisk_major_version" -eq 9 ]; then
            "$(uname)"/"$(uname -m)"/hfsplus tmp/ramdisk.dmg grow 110000000
        elif [ "$ramdisk_major_version" -eq 7 ] || [ "$ramdisk_major_version" -eq 8 ]; then
            "$(uname)"/"$(uname -m)"/hfsplus tmp/ramdisk.dmg grow 50000000
        else
            "$(uname)"/"$(uname -m)"/hfsplus tmp/ramdisk.dmg grow 200000000
        fi

        if [ "$replace" = 'j42dap' ]; then
            if [ ! -f resources/sshtars/atvssh.tar ]; then
                gzip -d -k resources/sshtars/atvssh.tar.gz
            fi
            "$(uname)"/"$(uname -m)"/hfsplus tmp/ramdisk.dmg untar resources/sshtars/atvssh.tar
        elif [ "$check" = '0x8012' ]; then
            if [ ! -f resources/sshtars/t2ssh.tar ]; then
                gzip -d -k resources/sshtars/t2ssh.tar.gz
            fi
            "$(uname)"/"$(uname -m)"/hfsplus tmp/ramdisk.dmg untar resources/sshtars/t2ssh.tar
            echo_warn "T2 MIGHT HANG AND DO NOTHING WHEN BOOTING THE RAMDISK!"
        else
            if [ "$ramdisk_major_version" -lt 12 ]; then
                ipswurl12=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$(uname)"/"$(uname -m)"/jq '.firmwares | .[] | select(.version=="'12.0'")' | "$(uname)"/"$(uname -m)"/jq -s '.[0] | .url' --raw-output)
                cd tmp
                ../"$(uname)"/"$(uname -m)"/pzb -g BuildManifest.plist "$ipswurl12"
                ../"$(uname)"/"$(uname -m)"/pzb -g "$(../"$(uname)"/"$(uname -m)"/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" "$ipswurl12"
                ../"$(uname)"/"$(uname -m)"/img4 -i "$(../"$(uname)"/"$(uname -m)"/PlistBuddy BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" -o ramdisk12.dmg
                ../"$(uname)"/"$(uname -m)"/hfsplus ramdisk12.dmg extract usr/lib/libcharset.1.dylib libcharset.1.dylib
                ../"$(uname)"/"$(uname -m)"/hfsplus ramdisk12.dmg extract usr/lib/libiconv.2.dylib libiconv.2.dylib
                ../"$(uname)"/"$(uname -m)"/hfsplus ramdisk.dmg add libiconv.2.dylib usr/lib/libiconv.2.dylib
                ../"$(uname)"/"$(uname -m)"/hfsplus ramdisk.dmg add libcharset.1.dylib usr/lib/libcharset.1.dylib
                cd ..
            fi
            if [ "$ramdisk_major_version" -eq 7 ] || [ "$ramdisk_major_version" -eq 8 ]; then
                if [ ! -f resources/sshtars/iram.tar ]; then
                    gzip -d -k resources/sshtars/iram.tar.gz
                fi
                "$(uname)"/"$(uname -m)"/hfsplus tmp/ramdisk.dmg untar resources/sshtars/iram.tar
                mkdir -p saved/sshramdisk; touch saved/sshramdisk/device_port_44
            elif [ "$ramdisk_major_version" -eq 16 ] && [ "$ramdisk_minor_version" -ge 1 ] || [ "$ramdisk_major_version" -gt 16 ]; then
                if [ ! -f resources/sshtars/ssh.tar ]; then
                    gzip -d -k resources/sshtars/ssh.tar.gz
                fi
                "$(uname)"/"$(uname -m)"/apfs-tool tmp/ramdisk.dmg untar resources/sshtars/ssh.tar
            else
                if [ ! -f resources/sshtars/ssh.tar ]; then
                    gzip -d -k resources/sshtars/ssh.tar.gz
                fi
                "$(uname)"/"$(uname -m)"/hfsplus tmp/ramdisk.dmg untar resources/sshtars/ssh.tar
            fi
            if [ "$check" = '0x8960' ] || [ "$check" = '0x7000' ] || [ "$check" = '0x7001' ]; then
                "$(uname)"/"$(uname -m)"/hfsplus tmp/ramdisk.dmg untar resources/sbplist.tar
            fi
        fi
    fi
    if [ "$(uname)" = 'Darwin' ] && ([ "$ramdisk_major_version" -eq 16 ] && [ "$ramdisk_minor_version" -ge 1 ] || [ "$ramdisk_major_version" -gt 16 ]); then
        "$(uname)"/"$(uname -m)"/img4 -i tmp/ramdisk_hfs.dmg -o tmp/ramdisk.img4 -M tmp/IM4M -A -T rdsk
    else
        "$(uname)"/"$(uname -m)"/img4 -i tmp/ramdisk.dmg -o tmp/ramdisk.img4 -M tmp/IM4M -A -T rdsk
    fi
    mkdir -p saved/sshramdisk
    mv tmp/*.img4 saved/sshramdisk
    echo "$ramdisk_version" > saved/sshramdisk/version
    touch saved/sshramdisk/"$replace"
    rm -rf tmp
    echo_input "Press Enter/Return to boot ramdisk (or press Ctrl+C to cancel)"; read
    boot_ramdisk
}

ramdisk_mode_menu() {
    local menu_items
    local selected
    menu_items=("SSH Into Device" "Dump Onboard Blobs" "Backup Activation Files" "Restore Activation Files" "Backup Activation Files (iOS 7-9)" "Restore Activation Files (iOS 7-9)" "Brute Force (iOS 7-8)" "Erase All (iOS 7-8)" "Erase All (iOS 9+)" "Install Trollstore" "Get Device Version" "Fix SSH Connection" "Disk Utilities" "Miscellaneous Utilities" "Reboot Device" "Exit")
    for ((;;)) do
    echo; echo_input "Select an option:"
    select opt in "${menu_items[@]}"; do
        selected="$opt"
        break
    done
    case $selected in
        "SSH Into Device" )
            echo_text "For accessing device with FileZilla, note the following:"
            echo_code "Host: sftp://127.0.0.1   User: root   Password: alpine   Port: 2222"
            echo_text "Mount filesystems (make sure ramdisk version is correct):"
            echo_code "10.3 and above: /usr/bin/mount_filesystems"
            echo_code "10.0-10.2.1: mount_hfs /dev/disk0s1s1 /mnt1 && /usr/libexec/seputil --load /mnt1/usr/standalone/firmware/sep-firmware.img4 && mount_hfs /dev/disk0s1s2 /mnt2"
            echo_code "7.0-9.3.5: mount_hfs /dev/disk0s1s1 /mnt1 && mount_hfs /dev/disk0s1s2 /mnt2"
            echo_text "Rename system snapshot (when first time modifying /mnt1 on 11.3-14.8.1):"
            echo_code '/usr/bin/snaputil -n "$(/usr/bin/snaputil -l /mnt1)" orig-fs /mnt1'
            echo_text "Erase device without updating (9.0+):"
            echo_code "/usr/sbin/nvram oblit-inprogress=5"
            echo_text "Reboot:"
            echo_code "/sbin/reboot"
            echo_text "Remove Setup.app (up to 13.2.3 or 12.4.4; on 10.0+ the device must be erased afterwards, on 11.3+ also rename system snapshot):"
            echo_code "rm -rf /mnt1/Applications/Setup.app"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            if [ -e saved/sshramdisk/device_port_44 ]; then
                echo_text "If stuck here, unplug and replug device, SSH into device again"
                "$(uname)"/"$(uname -m)"/iproxy 2222 44 > /dev/null 2>&1 &
            else
                "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            fi
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no || true
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Dump Onboard Blobs" )
            mkdir -p saved/shsh2
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            ramdisk_version=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "sw_vers -productVersion")
            ramdisk_major_version=${ramdisk_version%%.*}
            if [ "$ramdisk_major_version" -ge 16 ]; then
                device=rdisk2
                echo_text "If your device is on 16.0+, it is recommended to use Legacy iOS Kit to dump fully useful blobs, go here for more details: https://github.com/LukeZGD/Legacy-iOS-Kit/wiki/Saving-onboard-SHSH-blobs-of-current-iOS-version"; pause
            else
                device=rdisk1
            fi
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "cat /dev/$device" | dd of=dump.raw bs=256 count=$((0x4000))
            "$(uname)"/"$(uname -m)"/img4tool --convert -s saved/shsh2/"$(date '+%Y-%m-%d_%H-%M-%S')".shsh2 dump.raw
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
            rm -f dump.raw
            echo_text "Onboard blobs dumped as saved/shsh2/"$(date '+%Y-%m-%d_%H-%M-%S')".shsh2"
        ;;
        "Backup Activation Files" ) backup_activation;;
        "Restore Activation Files" ) restore_activation;;
        "Backup Activation Files (iOS 7-9)" ) backup_activation_ios789;;
        "Restore Activation Files (iOS 7-9)" ) restore_activation_ios789;;
        "Brute Force (iOS 7-8)" )
            echo_warn "Only compatible with iOS 7-8"; pause
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s1 /mnt1 2>&1 | grep -v 'Could not create property for re-key environment check' || true"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 2>&1 | grep -v 'Could not create property for re-key environment check' || true"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt1/System/Library/CoreServices/SystemVersion.plist . || true
            device_build_version=$(grep -A1 '<key>ProductBuildVersion</key>' SystemVersion.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
            device_version=$(grep -A1 '<key>ProductVersion</key>' SystemVersion.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
            device_major_version=$(echo "$device_version" | cut -d. -f1)
            echo_text "Device Version: "$device_version" ("$device_build_version")"
            rm -f SystemVersion.plist
            if [ "$device_major_version" -ne 7 ] && [ "$device_major_version" -ne 8 ]; then
                echo_error "Incompatible version, unlimited passcode attempts is not supported"
                killall iproxy > /dev/null 2>&1 || true
                if [ "$(uname)" = 'Linux' ]; then
                    sudo killall usbmuxd > /dev/null 2>&1 || true
                fi
                exit
            fi
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "cp -vf /com.apple.springboard.plist /mnt1"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -vf /mnt2/mobile/Library/Preferences/com.apple.springboard.plist /mnt2/mobile/Library/Preferences/com.apple.springboard.plist.bak"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "ln -vs /com.apple.springboard.plist /mnt2/mobile/Library/Preferences/com.apple.springboard.plist"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "rm -rf /mnt2/mobile/Library/SpringBoard/LockoutStateJournal.plist"
            echo_text "Now the device should get unlimited passcode attempts"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Erase All (iOS 7-8)" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s1 /mnt1 2>&1 | grep -v 'Could not create property for re-key environment check' || true"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2 2>&1 | grep -v 'Could not create property for re-key environment check' || true"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt1/System/Library/CoreServices/SystemVersion.plist . || true
            device_build_version=$(grep -A1 '<key>ProductBuildVersion</key>' SystemVersion.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
            device_version=$(grep -A1 '<key>ProductVersion</key>' SystemVersion.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
            device_major_version=$(echo "$device_version" | cut -d. -f1)
            echo_text "Device Version: "$device_version" ("$device_build_version")"
            rm -f SystemVersion.plist
            if [ "$device_major_version" -ne 7 ] && [ "$device_major_version" -ne 8 ]; then
                echo_error "Incompatible version, you may select Erase All (iOS 9+) option"
                killall iproxy > /dev/null 2>&1 || true
                if [ "$(uname)" = 'Linux' ]; then
                    sudo killall usbmuxd > /dev/null 2>&1 || true
                fi
                exit
            fi
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "cp -vf /com.apple.springboard.plist /mnt1"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/plutil -key SBDeviceWipeEnabled -true /mnt1/com.apple.springboard.plist"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/plutil -key SBDeviceLockFailedAttempts -type int -value 10 /mnt1/com.apple.springboard.plist"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -vf /mnt2/mobile/Library/Preferences/com.apple.springboard.plist /mnt2/mobile/Library/Preferences/com.apple.springboard.plist.bak"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "ln -vs /com.apple.springboard.plist /mnt2/mobile/Library/Preferences/com.apple.springboard.plist"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "rm -rf /mnt2/mobile/Library/SpringBoard/LockoutStateJournal.plist"
            echo_text "Reboot to lock screen, enter a wrong passcode to erase device"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Erase All (iOS 9+)" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            echo_text "/usr/sbin/nvram oblit-inprogress=5"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/nvram oblit-inprogress=5"
            echo_text "Device should show a progress bar and erase all data after rebooting. If selecting this option by mistake, SSH into device, run /usr/sbin/nvram -c"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Install Trollstore" )
            echo_warn "Only compatible with iOS 14.0-16.6.1, 16.7 (20H18), 17.0"; pause
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -e /mnt2/tmp"; then
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/mount_filesystems || true"
            fi
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no 'test -e "$(find /mnt2/containers/Bundle/Application -type d -name Tips.app)"'; then
                echo_error "Tips app is not installed on device, cannot continue"; exit
            fi
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no 'mv -vn "$(find /mnt2/containers/Bundle/Application -type d -name Tips.app)"/Tips "$(find /mnt2/containers/Bundle/Application -type d -name Tips.app)"/Tips_TROLLSTORE_BACKUP'
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no 'cp -v /usr/trollstore/PersistenceHelper "$(find /mnt2/containers/Bundle/Application -type d -name Tips.app)"/Tips'
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no 'cp -v /usr/trollstore/trollstorehelper "$(find /mnt2/containers/Bundle/Application -type d -name Tips.app)"'
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no 'chmod 755 "$(find /mnt2/containers/Bundle/Application -type d -name Tips.app)"/Tips "$(find /mnt2/containers/Bundle/Application -type d -name Tips.app)"/trollstorehelper'
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no '/usr/sbin/chown _installd:_installd "$(find /mnt2/containers/Bundle/Application -type d -name Tips.app)"/Tips'
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no '/usr/sbin/chown root:wheel "$(find /mnt2/containers/Bundle/Application -type d -name Tips.app)"/trollstorehelper'
            "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no resources/TrollStore.tar root@127.0.0.1:/mnt2/tmp
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv /mnt2/tmp/TrollStore.tar /mnt2/mobile/Media"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:mobile /mnt2/mobile/Media/TrollStore.tar"
            echo_text "TrollStore helper installed to Tips app"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Get Device Version" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            ramdisk_version=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "sw_vers -productVersion")
            ramdisk_major_version=${ramdisk_version%%.*}
            if [ "$ramdisk_major_version" -ge 16 ]; then
                system_partition="/dev/disk1s1"
            else
                system_partition="/dev/disk0s1s1"
            fi
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt1/System/Library/CoreServices/SystemVersion.plist"; then
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_apfs "$system_partition" /mnt1 || true"
            fi
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt1/System/Library/CoreServices/SystemVersion.plist"; then
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs "$system_partition" /mnt1 2>&1 | grep -v 'Could not create property for re-key environment check' || true"
            fi
            "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt1/System/Library/CoreServices/SystemVersion.plist . || true
            if [ ! -s SystemVersion.plist ]; then
                echo_error "Unable to mount system partition, try using a higher ramdisk version"
                killall iproxy > /dev/null 2>&1 || true
                if [ "$(uname)" = 'Linux' ]; then
                    sudo killall usbmuxd > /dev/null 2>&1 || true
                fi
                exit
            fi
            device_build_version=$(grep -A1 '<key>ProductBuildVersion</key>' SystemVersion.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
            device_version=$(grep -A1 '<key>ProductVersion</key>' SystemVersion.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
            echo_text "Device Version: "$device_version" ("$device_build_version")"
            rm -f SystemVersion.plist
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Fix SSH Connection" ) rm -vrf ~/.ssh;;
        "Disk Utilities" ) disk_utilities;;
        "Miscellaneous Utilities" ) miscellaneous_utilities;;
        "Reboot Device" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            echo_text "/sbin/reboot"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/reboot"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
            exit
        ;;
        "Exit" ) exit;;
    esac
    done
}

disk_utilities() {
    echo_warn "Dangerous features ahead! There is a high risk of bootlooping, DO NOT proceed if you don't know what you are doing!"
    echo_text "Do not mount filesystems before proceeding"
    local menu_items
    local selected
    menu_items=("Dump /dev/disk0" "Restore /dev/disk0" "Dump /dev/disk0s1s1 (7.0-10.2.1)" "Restore /dev/disk0s1s1 (7.0-10.2.1)" "Dump /dev/disk0s1s2 (7.0-10.2.1)" "Restore /dev/disk0s1s2 (7.0-10.2.1)" "Go Back")
    for ((;;)) do
    echo; echo_input "Select an option:"
    select opt in "${menu_items[@]}"; do
        selected="$opt"
        break
    done
    case $selected in
        "Dump /dev/disk0" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            mkdir -p saved/disk
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            serial_number=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/ioreg -l | grep IOPlatformSerialNumber | sed 's/.*IOPlatformSerialNumber\" = \"\(.*\)\"/\1/' | cut -d '\"' -f4")
            if [ -s saved/disk/disk0_$serial_number.gz ]; then
                echo_error "File exists, please rename or remove saved/disk/disk0_$serial_number.gz first"
                killall iproxy > /dev/null 2>&1 || true
                if [ "$(uname)" = 'Linux' ]; then
                    sudo killall usbmuxd > /dev/null 2>&1 || true
                fi
                exit
            fi
            echo_text "Dumping /dev/disk0, this will take a long time"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "dd if=/dev/disk0 bs=64k | gzip -1 -" | dd of=saved/disk/disk0_$serial_number.gz bs=64k
            echo_text "/dev/disk0 dumped as saved/disk/disk0_$serial_number.gz"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Restore /dev/disk0" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            serial_number=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/ioreg -l | grep IOPlatformSerialNumber | sed 's/.*IOPlatformSerialNumber\" = \"\(.*\)\"/\1/' | cut -d '\"' -f4")
            if [ ! -s saved/disk/disk0_$serial_number.gz ]; then
                echo_error "saved/disk/disk0_$serial_number.gz not found"
                killall iproxy > /dev/null 2>&1 || true
                if [ "$(uname)" = 'Linux' ]; then
                    sudo killall usbmuxd > /dev/null 2>&1 || true
                fi
                exit
            fi
            echo_text "Restoring /dev/disk0, this will take a long time"
            dd if=saved/disk/disk0_$serial_number.gz bs=64k | "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "gzip -d | dd of=/dev/disk0 bs=64k"
            echo_text "saved/disk/disk0_$serial_number.gz restored to device"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Dump /dev/disk0s1s1 (7.0-10.2.1)" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            mkdir -p saved/disk
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            serial_number=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/ioreg -l | grep IOPlatformSerialNumber | sed 's/.*IOPlatformSerialNumber\" = \"\(.*\)\"/\1/' | cut -d '\"' -f4")
            if [ -s saved/disk/disk0s1s1_$serial_number.gz ]; then
                echo_error "File exists, please rename or remove saved/disk/disk0s1s1_$serial_number.gz first"
                killall iproxy > /dev/null 2>&1 || true
                if [ "$(uname)" = 'Linux' ]; then
                    sudo killall usbmuxd > /dev/null 2>&1 || true
                fi
                exit
            fi
            echo_text "Dumping /dev/disk0s1s1, this will take several minutes"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/umount /mnt1 > /dev/null 2>&1 || true"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "dd if=/dev/disk0s1s1 bs=64k | gzip -1 -" | dd of=saved/disk/disk0s1s1_$serial_number.gz bs=64k
            echo_text "/dev/disk0s1s1 dumped as saved/disk/disk0s1s1_$serial_number.gz"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Restore /dev/disk0s1s1 (7.0-10.2.1)" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            serial_number=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/ioreg -l | grep IOPlatformSerialNumber | sed 's/.*IOPlatformSerialNumber\" = \"\(.*\)\"/\1/' | cut -d '\"' -f4")
            if [ ! -s saved/disk/disk0s1s1_$serial_number.gz ]; then
                echo_error "saved/disk/disk0s1s1_$serial_number.gz not found"
                killall iproxy > /dev/null 2>&1 || true
                if [ "$(uname)" = 'Linux' ]; then
                    sudo killall usbmuxd > /dev/null 2>&1 || true
                fi
                exit
            fi
            echo_text "Restoring /dev/disk0s1s1, this will take several minutes"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/umount /mnt1 > /dev/null 2>&1 || true"
            dd if=saved/disk/disk0s1s1_$serial_number.gz bs=64k | "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "gzip -d | dd of=/dev/disk0s1s1 bs=64k"
            echo_text "saved/disk/disk0s1s1_$serial_number.gz restored to device"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Dump /dev/disk0s1s2 (7.0-10.2.1)" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            mkdir -p saved/disk
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            serial_number=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/ioreg -l | grep IOPlatformSerialNumber | sed 's/.*IOPlatformSerialNumber\" = \"\(.*\)\"/\1/' | cut -d '\"' -f4")
            if [ -s saved/disk/disk0s1s2_$serial_number.gz ]; then
                echo_error "File exists, please rename or remove saved/disk/disk0s1s2_$serial_number.gz first"
                killall iproxy > /dev/null 2>&1 || true
                if [ "$(uname)" = 'Linux' ]; then
                    sudo killall usbmuxd > /dev/null 2>&1 || true
                fi
                exit
            fi
            echo_text "Dumping /dev/disk0s1s2, this will take a long time"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/umount /mnt2 > /dev/null 2>&1 || true"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "dd if=/dev/disk0s1s2 bs=64k | gzip -1 -" | dd of=saved/disk/disk0s1s2_$serial_number.gz bs=64k
            echo_text "/dev/disk0s1s2 dumped as saved/disk/disk0s1s2_$serial_number.gz"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Restore /dev/disk0s1s2 (7.0-10.2.1)" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            serial_number=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/ioreg -l | grep IOPlatformSerialNumber | sed 's/.*IOPlatformSerialNumber\" = \"\(.*\)\"/\1/' | cut -d '\"' -f4")
            if [ ! -s saved/disk/disk0s1s2_$serial_number.gz ]; then
                echo_error "saved/disk/disk0s1s2_$serial_number.gz not found"
                killall iproxy > /dev/null 2>&1 || true
                if [ "$(uname)" = 'Linux' ]; then
                    sudo killall usbmuxd > /dev/null 2>&1 || true
                fi
                exit
            fi
            echo_text "Restoring /dev/disk0s1s2, this will take a long time"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/umount /mnt2 > /dev/null 2>&1 || true"
            dd if=saved/disk/disk0s1s2_$serial_number.gz bs=64k | "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "gzip -d | dd of=/dev/disk0s1s2 bs=64k"
            echo_text "saved/disk/disk0s1s2_$serial_number.gz restored to device"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Go Back" ) return;;
    esac
    done
}

miscellaneous_utilities() {
    local menu_items
    local selected
    menu_items+=("Remove Setup.app" "Disable OTA & Reset" "Disable OTA" "Disable Reset" "Disable Thermalmonitord" "Remove iCloud Account" "Skip Setup Steps" "Update Device Time" "Clear NVRAM" "Go Back")
    for ((;;)) do
    echo; echo_input "Select an option:"
    select opt in "${menu_items[@]}"; do
        selected="$opt"
        break
    done
    case $selected in
        "Remove Setup.app" )
            echo_warn "This feature is only for hello screen devices, on iOS 10+ the device will be erased, and on iOS 11.3+ system snapshot will be renamed to orig-fs, proceed at your own risk"; pause
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            ramdisk_version=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "sw_vers -productVersion")
            ramdisk_major_version=${ramdisk_version%%.*}
            if [ "$ramdisk_major_version" -ge 16 ]; then
                system_partition="/dev/disk1s1"
            else
                system_partition="/dev/disk0s1s1"
            fi
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt1/System/Library/CoreServices/SystemVersion.plist"; then
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_apfs "$system_partition" /mnt1 || true"
            fi
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt1/System/Library/CoreServices/SystemVersion.plist"; then
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs "$system_partition" /mnt1 2>&1 | grep -v 'Could not create property for re-key environment check' || true"
            fi
            "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt1/System/Library/CoreServices/SystemVersion.plist . || true
            if [ ! -s SystemVersion.plist ]; then
                echo_error "Unable to mount system partition, cannot continue"
                killall iproxy > /dev/null 2>&1 || true
                if [ "$(uname)" = 'Linux' ]; then
                    sudo killall usbmuxd > /dev/null 2>&1 || true
                fi
                exit
            fi
            device_build_version=$(grep -A1 '<key>ProductBuildVersion</key>' SystemVersion.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
            device_version=$(grep -A1 '<key>ProductVersion</key>' SystemVersion.plist | grep '<string>' | sed -E 's/.*<string>([^<]+)<\/string>.*/\1/')
            device_major_version=$(echo "$device_version" | cut -d. -f1)
            device_minor_version=$(echo "$device_version" | cut -d. -f2)
            device_patch_version=$(echo "$device_version" | cut -d. -f3); device_patch_version=${device_patch_version:-0}
            echo_text "Device Version: "$device_version" ("$device_build_version")"
            rm -f SystemVersion.plist
            if [ "$device_major_version" -gt 13 ] || ([ "$device_major_version" -eq 13 ] && [ "$device_minor_version" -ge 3 ]) || ([ "$device_major_version" -eq 12 ] && [ "$device_minor_version" -ge 5 ]) || ([ "$device_major_version" -eq 12 ] && [ "$device_minor_version" -eq 4 ] && [ "$device_patch_version" -ge 5 ]); then
                echo_error "Removing Setup.app is not supported on "$device_version" (up to 13.2.3 or 12.4.4)"; return
            else
                echo_text "rm -rf /mnt1/Applications/Setup.app"
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "rm -rf /mnt1/Applications/Setup.app"
                if [ "$device_major_version" -ge 10 ]; then
                    echo_text "/usr/sbin/nvram oblit-inprogress=5"
                    "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/nvram oblit-inprogress=5"
                fi
                if [ "$device_major_version" -eq 11 ] && [ "$device_minor_version" -ge 3 ] || [ "$device_major_version" -gt 11 ]; then
                    system_snapshot=$("$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/snaputil -l /mnt1")
                    if [ "$system_snapshot" != 'orig-fs' ]; then
                        echo_text "/usr/bin/snaputil -n "$system_snapshot" orig-fs /mnt1"
                        "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no '/usr/bin/snaputil -n "$(/usr/bin/snaputil -l /mnt1)" orig-fs /mnt1'
                    fi
                fi
            fi
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Disable OTA & Reset" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -e /mnt2/tmp"; then
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/mount_filesystems || true"
            fi
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/db/com.apple.xpc.launchd/disabled.plist"; then
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/plutil -create /mnt2/db/com.apple.xpc.launchd/disabled.plist; sleep 1"
            fi
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/plutil -key com.apple.mobile.softwareupdated -true /mnt2/db/com.apple.xpc.launchd/disabled.plist; /usr/bin/plutil -key com.apple.OTATaskingAgent -true /mnt2/db/com.apple.xpc.launchd/disabled.plist; /usr/bin/plutil -key com.apple.softwareupdateservicesd -true /mnt2/db/com.apple.xpc.launchd/disabled.plist; /usr/bin/plutil -key com.apple.mobile.obliteration -true /mnt2/db/com.apple.xpc.launchd/disabled.plist"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no resources/com.apple.MobileAsset.plist root@127.0.0.1:/mnt2/mobile/Library/Preferences
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:mobile /mnt2/mobile/Library/Preferences/com.apple.MobileAsset.plist"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Disable OTA" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -e /mnt2/tmp"; then
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/mount_filesystems || true"
            fi
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/db/com.apple.xpc.launchd/disabled.plist"; then
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/plutil -create /mnt2/db/com.apple.xpc.launchd/disabled.plist; sleep 1"
            fi
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/plutil -key com.apple.mobile.softwareupdated -true /mnt2/db/com.apple.xpc.launchd/disabled.plist; /usr/bin/plutil -key com.apple.OTATaskingAgent -true /mnt2/db/com.apple.xpc.launchd/disabled.plist; /usr/bin/plutil -key com.apple.softwareupdateservicesd -true /mnt2/db/com.apple.xpc.launchd/disabled.plist"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no resources/com.apple.MobileAsset.plist root@127.0.0.1:/mnt2/mobile/Library/Preferences
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:mobile /mnt2/mobile/Library/Preferences/com.apple.MobileAsset.plist"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Disable Reset" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -e /mnt2/tmp"; then
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/mount_filesystems || true"
            fi
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/db/com.apple.xpc.launchd/disabled.plist"; then
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/plutil -create /mnt2/db/com.apple.xpc.launchd/disabled.plist; sleep 1"
            fi
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/plutil -key com.apple.mobile.obliteration -true /mnt2/db/com.apple.xpc.launchd/disabled.plist"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Disable Thermalmonitord" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -e /mnt2/tmp"; then
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/mount_filesystems || true"
            fi
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -f /mnt2/db/com.apple.xpc.launchd/disabled.plist"; then
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/plutil -create /mnt2/db/com.apple.xpc.launchd/disabled.plist; sleep 1"
            fi
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/plutil -key com.apple.thermalmonitord -true /mnt2/db/com.apple.xpc.launchd/disabled.plist"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Remove iCloud Account" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -e /mnt2/tmp"; then
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/mount_filesystems || true"
            fi
            echo_text "rm -rf /mnt2/mobile/Library/Accounts"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "rm -rf /mnt2/mobile/Library/Accounts"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Skip Setup Steps" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            if ! "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -e /mnt2/tmp"; then
                "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/mount_filesystems || true"
            fi
            "$(uname)"/"$(uname -m)"/sshpass -p alpine scp -p -P2222 -o StrictHostKeyChecking=no resources/com.apple.purplebuddy.plist root@127.0.0.1:/mnt2/mobile/Library/Preferences
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:mobile /mnt2/mobile/Library/Preferences/com.apple.purplebuddy.plist"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "ls -l /mnt2/mobile/Library/Preferences/com.apple.purplebuddy.plist"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Update Device Time" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "date -s @$(date +%s)"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Clear NVRAM" )
            if [ "$(uname)" = 'Linux' ]; then
                sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
                sudo killall usbmuxd > /dev/null 2>&1 || true
                sleep .1
                sudo usbmuxd -pf > /dev/null 2>&1 &
                sleep .1
            fi
            "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
            echo_text "/usr/sbin/nvram -c"
            "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/nvram -c"
            killall iproxy > /dev/null 2>&1 || true
            if [ "$(uname)" = 'Linux' ]; then
                sudo killall usbmuxd > /dev/null 2>&1 || true
            fi
        ;;
        "Go Back" ) return;;
    esac
    done
}

main_menu() {
    local menu_items
    local selected
    if [ "$(uname)" = 'Linux' ]; then
        sudo systemctl stop usbmuxd > /dev/null 2>&1 || true
        sudo killall usbmuxd > /dev/null 2>&1 || true
        sleep .1
        sudo usbmuxd -pf > /dev/null 2>&1 &
        sleep .1
    fi
    "$(uname)"/"$(uname -m)"/iproxy 2222 22 > /dev/null 2>&1 &
    if "$(uname)"/"$(uname -m)"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "test -e /mnt2" > /dev/null 2>&1; then
        device_mode=ramdisk
    fi
    killall iproxy > /dev/null 2>&1 || true
    if [ "$(uname)" = 'Linux' ]; then
        sudo killall usbmuxd > /dev/null 2>&1 || true
    fi
    if [ "$device_mode" = 'ramdisk' ]; then
        echo_text "Device in SSH ramdisk mode"
        ramdisk_mode_menu
    else
        menu_items=("Create Ramdisk")
        if [ "$("$(uname)"/"$(uname -m)"/irecovery -q | grep -w MODE | sed 's/MODE: //')" = 'DFU' ]; then
            check=$("$(uname)"/"$(uname -m)"/irecovery -q | grep CPID | sed 's/CPID: //')
            replace=$("$(uname)"/"$(uname -m)"/irecovery -q | grep MODEL | sed 's/MODEL: //')
            deviceid=$("$(uname)"/"$(uname -m)"/irecovery -q | grep PRODUCT | sed 's/PRODUCT: //')
            ecid=$(printf "%d" "$("$(uname)"/"$(uname -m)"/irecovery -q | grep ECID | sed 's/ECID: //')")
            if [ -e saved/sshramdisk/"$replace" ]; then
                menu_items+=("Boot Ramdisk")
            fi
            menu_items+=("Enter pwnDFU Mode")
            echo_text "$("$(uname)"/"$(uname -m)"/irecovery -q | grep NAME | cut -c 7-) in DFU mode"
            if [ -n "$("$(uname)"/"$(uname -m)"/irecovery -q | grep PWND | cut -c 7-)" ]; then
                echo_text "Pwned: "$("$(uname)"/"$(uname -m)"/irecovery -q | grep PWND | cut -c 7-)""
            fi
            echo_text "CPID: "$check"   MODEL: "$replace"   PRODUCT: "$deviceid"   ECID: "$ecid""
        elif [ "$("$(uname)"/"$(uname -m)"/irecovery -q | grep -w MODE | sed 's/MODE: //')" = 'Recovery' ]; then
            check=$("$(uname)"/"$(uname -m)"/irecovery -q | grep CPID | sed 's/CPID: //')
            replace=$("$(uname)"/"$(uname -m)"/irecovery -q | grep MODEL | sed 's/MODEL: //')
            deviceid=$("$(uname)"/"$(uname -m)"/irecovery -q | grep PRODUCT | sed 's/PRODUCT: //')
            serial_number=$("$(uname)"/"$(uname -m)"/irecovery -q | grep SRNM | sed 's/SRNM: //')
            if [ -e saved/sshramdisk/"$replace" ]; then
                menu_items+=("Boot Ramdisk")
            fi
            menu_items+=("Query Device Info" "Exit Recovery Mode")
            echo_text "$("$(uname)"/"$(uname -m)"/irecovery -q | grep NAME | cut -c 7-) in recovery mode"
            echo_text "CPID: "$check"   MODEL: "$replace"   PRODUCT: "$deviceid"   SN: "$serial_number""
            iboot_version="$(echo "/exit" | "$(uname)"/"$(uname -m)"/irecovery -s | grep -a "iBoot-" | cut -c 15-)"; rm -f .irecovery
            if [ -z "$iboot_version" ]; then
                echo_warn "iBoot version unknown, re-enter recovery mode to get iBoot version"
            else
                echo_text "iBoot Version: "$iboot_version""
                echo_text "You may check approximate device version here: https://theapplewiki.com/wiki/IBoot_(Bootloader)"
            fi
        else
            :
        fi
    fi
    menu_items+=("Clear Temporary Files" "Exit")
    for ((;;)) do
    echo; echo_input "Select an option:"
    select opt in "${menu_items[@]}"; do
        selected="$opt"
        break
    done
    case $selected in
        "Create Ramdisk" ) create_ramdisk;;
        "Boot Ramdisk" ) boot_ramdisk;;
        "Enter pwnDFU Mode" ) "$(uname)"/"$(uname -m)"/gaster pwn; "$(uname)"/"$(uname -m)"/gaster reset; exit;;
        "Query Device Info" ) "$(uname)"/"$(uname -m)"/irecovery -q;;
        "Exit Recovery Mode" ) "$(uname)"/"$(uname -m)"/irecovery -n; exit;;
        "Clear Temporary Files" ) rm -vrf resources/sshtars/*.tar saved/sshramdisk tmp .DS_Store */.DS_Store */*/.DS_Store */*/*/.DS_Store; if [ ! -e saved/* ]; then rm -vrf saved; fi;;
        "Exit" ) exit;;
    esac
    done
}

main_menu
