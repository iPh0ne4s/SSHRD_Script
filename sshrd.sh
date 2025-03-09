#!/usr/bin/env sh
if [ ! -e logs ]; then
mkdir logs | true
fi
$(rm logs/*.log 2> /dev/null)
{
set -e
oscheck=$(uname)

version="$1"

major=$(echo "$version" | cut -d. -f1)
minor=$(echo "$version" | cut -d. -f2)
patch=$(echo "$version" | cut -d. -f3)
    
ERR_HANDLER () {
    [ $? -eq 0 ] && exit
    echo "[-] An error occurred"
    rm -rf work 12rd | true
    killall iproxy 2>/dev/null | true

    # echo "[-] Uploading logs. If this fails, it's not a big deal."
    for file in logs/*.log; do
        mv "$file" logs/FAILURE_${file##*/}
    done
    curl -A SSHRD_Script -F "fileToUpload=@$(ls logs/*.log)" https://nathan4s.lol/SSHRD_Script/log_upload.php > /dev/null 2>&1 | true
    # echo "[!] Done uploading logs, I'll be sure to look at them and fix the issue you are facing"
}

trap ERR_HANDLER EXIT

if [ ! -e sshtars/README.md ]; then
    git submodule update --init --recursive
fi

if [ -e sshtars/ssh.tar.gz ]; then
    if [ "$oscheck" = 'Linux' ]; then
        gzip -d sshtars/ssh.tar.gz
        gzip -d sshtars/t2ssh.tar.gz
        gzip -d sshtars/atvssh.tar.gz
    fi
fi

if [ ! -e "$oscheck"/gaster ]; then
    curl -sLO https://nightly.link/verygenericname/gaster/workflows/makefile/main/gaster-"$oscheck".zip
    unzip gaster-"$oscheck".zip
    mv gaster "$oscheck"/
    rm -rf gaster gaster-"$oscheck".zip
fi

chmod +x "$oscheck"/*

if [ "$1" = 'clean' ]; then
    rm -rf sshramdisk work
    echo "[*] Removed the current created SSH ramdisk"
    exit
elif [ "$1" = 'dump-blobs' ]; then
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd 2>/dev/null | true
        sudo killall usbmuxd 2>/dev/null | true
        sleep .1
        sudo usbmuxd -pf 2>/dev/null &
        sleep .1
    fi
    "$oscheck"/iproxy 2222 22 &>/dev/null &
    version=$("$oscheck"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "sw_vers -productVersion")
    version=${version%%.*}
    if [ "$version" -ge 16 ]; then
        device=rdisk2
    else
        device=rdisk1
    fi
    "$oscheck"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "cat /dev/$device" | dd of=dump.raw bs=256 count=$((0x4000))
    "$oscheck"/img4tool --convert -s dumped.shsh dump.raw
    killall iproxy 2>/dev/null | true
    sudo killall usbmuxd 2>/dev/null | true
    rm dump.raw
    echo "[*] Onboard blobs should have dumped to the dumped.shsh file"
    exit
elif [ "$1" = 'reboot' ]; then
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd 2>/dev/null | true
        sudo killall usbmuxd 2>/dev/null | true
        sleep .1
        sudo usbmuxd -pf 2>/dev/null &
        sleep .1
    fi
    "$oscheck"/iproxy 2222 22 &>/dev/null &
    "$oscheck"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "/sbin/reboot"
    killall iproxy 2>/dev/null | true
    sudo killall usbmuxd 2>/dev/null | true
    echo "[*] Device should now reboot"
    exit
elif [ "$1" = 'ssh' ]; then
    echo "[*] Run mount_filesystems to mount filesystems"
    killall iproxy 2>/dev/null | true
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd 2>/dev/null | true
        sudo killall usbmuxd 2>/dev/null | true
        sleep .1
        sudo usbmuxd -pf 2>/dev/null &
        sleep .1
    fi
    "$oscheck"/iproxy 2222 22 &>/dev/null &
    "$oscheck"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost || true
    killall iproxy 2>/dev/null | true
    sudo killall usbmuxd 2>/dev/null | true
    exit
elif [ "$1" = '--backup-activation' ]; then
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd 2>/dev/null | true
        sudo killall usbmuxd 2>/dev/null | true
        sleep .1
        sudo usbmuxd -pf 2>/dev/null &
        sleep .1
    fi
    "$oscheck"/iproxy 2222 22 &>/dev/null &
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/mount_filesystems"
    "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt2/containers/Data/System/*/Library/activation_records/activation_record.plist .
    "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist .
    "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no root@127.0.0.1:/mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv .
    echo "[*] Activation files saved to SSHRD_Script directory, check if activation_record.plist, com.apple.commcenter.device_specific_nobackup.plist, IC-Info.sisv all exist and are not empty"
    killall iproxy 2>/dev/null | true
    sudo killall usbmuxd 2>/dev/null | true
    exit
elif [ "$1" = '--restore-activation' ]; then
    if [ ! -e activation_record.plist ]; then
        echo "[*] Activation files not found"
        exit
    fi
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd 2>/dev/null | true
        sudo killall usbmuxd 2>/dev/null | true
        sleep .1
        sudo usbmuxd -pf 2>/dev/null &
        sleep .1
    fi
    "$oscheck"/iproxy 2222 22 &>/dev/null &
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/bin/mount_filesystems"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "rm -rf /mnt2/mobile/Media/Downloads/Activation /mnt2/mobile/Media/Activation"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mkdir -p /mnt2/mobile/Media/Downloads/Activation"
    "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no activation_record.plist root@127.0.0.1:/mnt2/mobile/Media/Downloads/Activation
    "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no com.apple.commcenter.device_specific_nobackup.plist root@127.0.0.1:/mnt2/mobile/Media/Downloads/Activation
    "$oscheck"/sshpass -p alpine scp -P2222 -o StrictHostKeyChecking=no IC-Info.sisv root@127.0.0.1:/mnt2/mobile/Media/Downloads/Activation
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/Downloads/Activation /mnt2/mobile/Media"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown -R mobile:mobile /mnt2/mobile/Media/Activation"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod -R 755 /mnt2/mobile/Media/Activation"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "cd /mnt2/containers/Data/System/*/Library/internal; mkdir -p ../activation_records"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/Activation/activation_record.plist /mnt2/containers/Data/System/*/Library/activation_records"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 666 /mnt2/containers/Data/System/*/Library/activation_records/activation_record.plist"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:nobody /mnt2/containers/Data/System/*/Library/activation_records/activation_record.plist"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/Activation/com.apple.commcenter.device_specific_nobackup.plist /mnt2/wireless/Library/Preferences"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 600 /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown _wireless:_wireless /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mkdir -p /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv -f /mnt2/mobile/Media/Activation/IC-Info.sisv /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "chmod 664 /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/usr/sbin/chown mobile:mobile /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
    echo "[*] Activation files restored to device"
    killall iproxy 2>/dev/null | true
    sudo killall usbmuxd 2>/dev/null | true
    exit
elif [ "$1" = '--dump-nand' ]; then
    ./sshrd.sh 12.0
    ./sshrd.sh boot
    sleep 10
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd 2>/dev/null | true
        sudo killall usbmuxd 2>/dev/null | true
        sleep .1
        sudo usbmuxd -pf 2>/dev/null &
        sleep .1
    fi
    echo "[*] Dumping /dev/disk0, this will take a long time"
    "$oscheck"/iproxy 2222 22 &>/dev/null &
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "dd if=/dev/disk0 bs=64k | gzip -1 -" | dd of=disk0.gz bs=64k
    echo "[*] Done!"
    killall iproxy 2>/dev/null | true
    sudo killall usbmuxd 2>/dev/null | true
    exit
elif [ "$1" = '--restore-nand' ]; then
    ./sshrd.sh 12.0
    ./sshrd.sh boot
    sleep 10
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd 2>/dev/null | true
        sudo killall usbmuxd 2>/dev/null | true
        sleep .1
        sudo usbmuxd -pf 2>/dev/null &
        sleep .1
    fi
    echo "[*] Restoring /dev/disk0, this will take a long time"
    "$oscheck"/iproxy 2222 22 &>/dev/null &
    dd if=disk0.gz bs=64k | "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "gzip -d | dd of=/dev/disk0 bs=64k"
    echo "[*] Done!"
    killall iproxy 2>/dev/null | true
    sudo killall usbmuxd 2>/dev/null | true
    exit
elif [ "$1" = '--brute-force' ]; then
    ./sshrd.sh 12.0
    ./sshrd.sh boot
    sleep 10
    if [ "$oscheck" = 'Linux' ]; then
        sudo systemctl stop usbmuxd 2>/dev/null | true
        sudo killall usbmuxd 2>/dev/null | true
        sleep .1
        sudo usbmuxd -pf 2>/dev/null &
        sleep .1
    fi
    "$oscheck"/iproxy 2222 22 &>/dev/null &
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s1 /mnt1"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/mount_hfs /dev/disk0s1s2 /mnt2"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "cp /com.apple.springboard.plist /mnt1"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "mv /mnt2/mobile/Library/Preferences/com.apple.springboard.plist /mnt2/mobile/Library/Preferences/com.apple.springboard.plist.bak"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "ln -s /com.apple.springboard.plist /mnt2/mobile/Library/Preferences/com.apple.springboard.plist"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "rm /mnt2/mobile/Library/SpringBoard/LockoutStateJournal.plist || :"
    "$oscheck"/sshpass -p alpine ssh root@127.0.0.1 -p2222 -o StrictHostKeyChecking=no "/sbin/reboot"
    echo "[*] Now the device should get unlimited passcode attempts"
    killall iproxy 2>/dev/null | true
    sudo killall usbmuxd 2>/dev/null | true
    exit
elif [ "$oscheck" = 'Darwin' ]; then
    if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
        echo "[*] Waiting for device in DFU mode"
    fi
    
    while ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); do
        sleep 1
    done
else
    if ! (lsusb 2> /dev/null | grep ' Apple, Inc. Mobile Device (DFU Mode)' >> /dev/null); then
        echo "[*] Waiting for device in DFU mode"
    fi
    
    while ! (lsusb 2> /dev/null | grep ' Apple, Inc. Mobile Device (DFU Mode)' >> /dev/null); do
        sleep 1
    done
fi

echo "[*] Getting device info and pwning... this may take a second"
check=$("$oscheck"/irecovery -q | grep CPID | sed 's/CPID: //')
replace=$("$oscheck"/irecovery -q | grep MODEL | sed 's/MODEL: //')
deviceid=$("$oscheck"/irecovery -q | grep PRODUCT | sed 's/PRODUCT: //')
ipswurl=$(curl -sL "https://api.ipsw.me/v4/device/$deviceid?type=ipsw" | "$oscheck"/jq '.firmwares | .[] | select(.version=="'$1'")' | "$oscheck"/jq -s '.[0] | .url' --raw-output)

if [ -e work ]; then
    rm -rf work
fi

if [ -e 12rd ]; then
    rm -rf 12rd
fi

if [ ! -e sshramdisk ]; then
    mkdir sshramdisk
fi

if [ "$1" = 'reset' ]; then
    if [ ! -e sshramdisk/iBSS.img4 ]; then
        echo "[-] Please create an SSH ramdisk first!"
        exit
    fi

    if [ "$check" = '0x8960' ]; then
        "$oscheck"/ipwnder > /dev/null
    else
        "$oscheck"/gaster pwn > /dev/null
    fi
    "$oscheck"/gaster reset > /dev/null
    "$oscheck"/irecovery -f sshramdisk/iBSS.img4
    sleep 2
    "$oscheck"/irecovery -f sshramdisk/iBEC.img4

    if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
        "$oscheck"/irecovery -c go
    fi

    sleep 2
    "$oscheck"/irecovery -c "setenv oblit-inprogress 5"
    "$oscheck"/irecovery -c saveenv
    "$oscheck"/irecovery -c reset

    echo "[*] Device should now show a progress bar and erase all data"
    exit
fi

if [ "$2" = 'TrollStore' ]; then
    if [ -z "$3" ]; then
        echo "[-] Please pass an uninstallable system app to use (Tips is a great choice)"
        exit
    fi
fi

if [ "$1" = 'boot' ]; then
    if [ ! -e sshramdisk/iBSS.img4 ]; then
        echo "[-] Please create an SSH ramdisk first!"
        exit
    fi

    major=$(cat sshramdisk/version.txt | awk -F. '{print $1}')
    minor=$(cat sshramdisk/version.txt | awk -F. '{print $2}')
    patch=$(cat sshramdisk/version.txt | awk -F. '{print $3}')
    major=${major:-0}
    minor=${minor:-0}
    patch=${patch:-0}
    
    if [ "$check" = '0x8960' ]; then
        "$oscheck"/ipwnder > /dev/null
    else
        "$oscheck"/gaster pwn > /dev/null
    fi
    "$oscheck"/gaster reset > /dev/null
    "$oscheck"/irecovery -f sshramdisk/iBSS.img4
    sleep 2
    "$oscheck"/irecovery -f sshramdisk/iBEC.img4

    if [ "$check" = '0x8010' ] || [ "$check" = '0x8015' ] || [ "$check" = '0x8011' ] || [ "$check" = '0x8012' ]; then
        "$oscheck"/irecovery -c go
    fi
    sleep 2
    "$oscheck"/irecovery -f sshramdisk/logo.img4
    "$oscheck"/irecovery -c "setpicture 0x1"
    "$oscheck"/irecovery -f sshramdisk/ramdisk.img4
    "$oscheck"/irecovery -c ramdisk
    "$oscheck"/irecovery -f sshramdisk/devicetree.img4
    "$oscheck"/irecovery -c devicetree
    if [ "$major" -lt 11 ] || ([ "$major" -eq 11 ] && ([ "$minor" -lt 4 ] || [ "$minor" -eq 4 ] && [ "$patch" -le 1 ] || [ "$check" != '0x8012' ])); then
    :
    else
    "$oscheck"/irecovery -f sshramdisk/trustcache.img4
    "$oscheck"/irecovery -c firmware
    fi
    "$oscheck"/irecovery -f sshramdisk/kernelcache.img4
    "$oscheck"/irecovery -c bootx

    echo "[*] Device should now show text on screen"
    echo "[*] Run ./sshrd.sh ssh to connect to SSH"
    exit
fi

if [ -z "$1" ]; then
    printf "1st argument: iOS version for the ramdisk\nExtra arguments:\nreset: wipes the device, without losing version.\nTrollStore: install trollstore to system app\n"
    exit
fi

if [ ! -e work ]; then
    mkdir work
fi

"$oscheck"/gaster pwn > /dev/null
"$oscheck"/img4tool -e -s other/shsh/"${check}".shsh -m work/IM4M

cd work
../"$oscheck"/pzb -g BuildManifest.plist "$ipswurl"
../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/iBSS[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/iBEC[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"
../"$oscheck"/pzb -g "$(awk "/""${replace}""/{x=1}x&&/DeviceTree[.]/{print;exit}" BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" "$ipswurl"

if [ "$oscheck" = 'Darwin' ]; then
    if [ "$major" -lt 11 ] || ([ "$major" -eq 11 ] && ([ "$minor" -lt 4 ] || [ "$minor" -eq 4 ] && [ "$patch" -le 1 ] || [ "$check" != '0x8012' ])); then
    :
    else
    ../"$oscheck"/pzb -g Firmware/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache "$ipswurl"
    fi
else
    if [ "$major" -lt 11 ] || ([ "$major" -eq 11 ] && ([ "$minor" -lt 4 ] || [ "$minor" -eq 4 ] && [ "$patch" -le 1 ] || [ "$check" != '0x8012' ])); then
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
if [ "$major" -gt 18 ] || [ "$major" -eq 18 ]; then
"$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/iBSS[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" -o work/iBSS.dec
"$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/iBEC[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" -o work/iBEC.dec
else
"$oscheck"/gaster decrypt work/"$(awk "/""${replace}""/{x=1}x&&/iBSS[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" work/iBSS.dec
"$oscheck"/gaster decrypt work/"$(awk "/""${replace}""/{x=1}x&&/iBEC[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]dfu[/]//')" work/iBEC.dec
fi
if [ "$major" -eq 10 ] && [ "$patch" -lt 3 ] || [ "$major" -lt 10 ]; then
    echo "iOS lower than 10.3 detected, using kairos for bootchain"
    "$oscheck"/kairos work/iBSS.dec work/iBSS.patched
    "$oscheck"/img4 -i work/iBSS.patched -o sshramdisk/iBSS.img4 -M work/IM4M -A -T ibss
    "$oscheck"/kairos work/iBEC.dec work/iBEC.patched -b "rd=md0 debug=0x2014e -v wdt=-1 `if [ -z "$2" ]; then :; else echo "$2=$3"; fi` `if [ "$check" = '0x8960' ] || [ "$check" = '0x7000' ] || [ "$check" = '0x7001' ]; then echo "nand-enable-reformat=1 -restore"; fi`" -n
    "$oscheck"/img4 -i work/iBEC.patched -o sshramdisk/iBEC.img4 -M work/IM4M -A -T ibec
else
    "$oscheck"/kairos work/iBSS.dec work/iBSS.patched
    "$oscheck"/img4 -i work/iBSS.patched -o sshramdisk/iBSS.img4 -M work/IM4M -A -T ibss
    "$oscheck"/kairos work/iBEC.dec work/iBEC.patched -b "rd=md0 debug=0x2014e -v wdt=-1 `if [ -z "$2" ]; then :; else echo "$2=$3"; fi` `if [ "$check" = '0x8960' ] || [ "$check" = '0x7000' ] || [ "$check" = '0x7001' ]; then echo "nand-enable-reformat=1 -restore"; fi`" -n
    "$oscheck"/img4 -i work/iBEC.patched -o sshramdisk/iBEC.img4 -M work/IM4M -A -T ibec
fi   


if [ "$major" -lt 10 ]; then
    echo "iOS lower than 10.0.1 detected, using Kernel64Patcher for kernel patching"
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o work/kcache.raw
    "$oscheck"/Kernel64Patcher work/kcache.raw work/kcache.patched -a
    "$oscheck"/kerneldiff work/kcache.raw work/kcache.patched work/kc.bpatch
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o sshramdisk/kernelcache.img4 -M work/IM4M -T rkrn -P work/kc.bpatch `if [ "$oscheck" = 'Linux' ]; then echo "-J"; fi`
else
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o work/kcache.raw
    "$oscheck"/KPlooshFinder work/kcache.raw work/kcache.patched
    "$oscheck"/kerneldiff work/kcache.raw work/kcache.patched work/kc.bpatch
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/kernelcache.release/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1)" -o sshramdisk/kernelcache.img4 -M work/IM4M -T rkrn -P work/kc.bpatch `if [ "$oscheck" = 'Linux' ]; then echo "-J"; fi`
fi 

if [ "$major" -eq 10 ] && [ "$patch" -lt 3 ] || [ "$major" -lt 10 ]; then
    echo "iOS lower than 10.3 detected, BuildManifest is little different"
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/DeviceTree[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' | cut -d\> -f2 | cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]all_flash[.].*[.]production[/]//')" -o sshramdisk/devicetree.img4 -M work/IM4M -T rdtr
else
    "$oscheck"/img4 -i work/"$(awk "/""${replace}""/{x=1}x&&/DeviceTree[.]/{print;exit}" work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | sed 's/Firmware[/]all_flash[/]//')" -o sshramdisk/devicetree.img4 -M work/IM4M -T rdtr
fi   

if [ "$oscheck" = 'Darwin' ]; then
    if [ "$major" -lt 11 ] || ([ "$major" -eq 11 ] && ([ "$minor" -lt 4 ] || [ "$minor" -eq 4 ] && [ "$patch" -le 1 ] || [ "$check" != '0x8012' ])); then
        :
        else
        "$oscheck"/img4 -i work/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)".trustcache -o sshramdisk/trustcache.img4 -M work/IM4M -T rtsc
    fi
    "$oscheck"/img4 -i work/"$(/usr/bin/plutil -extract "BuildIdentities".0."Manifest"."RestoreRamDisk"."Info"."Path" xml1 -o - work/BuildManifest.plist | grep '<string>' |cut -d\> -f2 |cut -d\< -f1 | head -1)" -o work/ramdisk.dmg
else
    if [ "$major" -lt 11 ] || ([ "$major" -eq 11 ] && ([ "$minor" -lt 4 ] || [ "$minor" -eq 4 ] && [ "$patch" -le 1 ] || [ "$check" != '0x8012' ])); then
    :
    else
    "$oscheck"/img4 -i work/"$(Linux/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')".trustcache -o sshramdisk/trustcache.img4 -M work/IM4M -T rtsc
    fi
    "$oscheck"/img4 -i work/"$(Linux/PlistBuddy work/BuildManifest.plist -c "Print BuildIdentities:0:Manifest:RestoreRamDisk:Info:Path" | sed 's/"//g')" -o work/ramdisk.dmg
fi

if [ "$oscheck" = 'Darwin' ]; then
    if [ "$major" -gt 16 ] || ([ "$major" -eq 16 ] && ([ "$minor" -gt 1 ] || [ "$minor" -eq 1 ] && [ "$patch" -ge 0 ])); then
    :
    elif ([ "$major" -eq 10 ] && [ "$minor" -eq 3 ]) || ([ "$major" -eq 11 ] && [ "$minor" -lt 3 ]); then
        hdiutil resize -size 105MB work/ramdisk.dmg
    else
        hdiutil resize -size 210MB work/ramdisk.dmg
    fi
    hdiutil attach -mountpoint /tmp/SSHRD work/ramdisk.dmg -owners off
    
    if [ "$major" -gt 16 ] || ([ "$major" -eq 16 ] && ([ "$minor" -gt 1 ] || [ "$minor" -eq 1 ] && [ "$patch" -ge 0 ])); then
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
        echo "[!] WARNING: T2 MIGHT HANG AND DO NOTHING WHEN BOOTING THE RAMDISK!"
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
        "$oscheck"/gtar -x --no-overwrite-dir -f sshtars/ssh.tar.gz -C /tmp/SSHRD/
    fi

    hdiutil detach -force /tmp/SSHRD
    if [ "$major" -gt 16 ] || ([ "$major" -eq 16 ] && ([ "$minor" -gt 1 ] || [ "$minor" -eq 1 ] && [ "$patch" -ge 0 ])); then
        hdiutil resize -sectors min work/ramdisk1.dmg
    else
        hdiutil resize -sectors min work/ramdisk.dmg
    fi
else
    if [ "$major" -gt 16 ] || ([ "$major" -eq 16 ] && ([ "$minor" -gt 1 ] || [ "$minor" -eq 1 ] && [ "$patch" -ge 0 ])); then
        echo "Sorry, 16.1 and above doesn't work on Linux at the moment!"
        exit
    elif ([ "$major" -eq 10 ] && [ "$minor" -eq 3 ]) || ([ "$major" -eq 11 ] && [ "$minor" -lt 3 ]); then
        "$oscheck"/hfsplus work/ramdisk.dmg grow 105000000 > /dev/null
    else
        "$oscheck"/hfsplus work/ramdisk.dmg grow 210000000 > /dev/null
    fi

    if [ "$replace" = 'j42dap' ]; then
        "$oscheck"/hfsplus work/ramdisk.dmg untar sshtars/atvssh.tar > /dev/null
    elif [ "$check" = '0x8012' ]; then
        "$oscheck"/hfsplus work/ramdisk.dmg untar sshtars/t2ssh.tar > /dev/null
        echo "[!] WARNING: T2 MIGHT HANG AND DO NOTHING WHEN BOOTING THE RAMDISK!"
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
        "$oscheck"/hfsplus work/ramdisk.dmg untar sshtars/ssh.tar > /dev/null
        "$oscheck"/hfsplus work/ramdisk.dmg untar other/sbplist.tar > /dev/null
    fi
fi
if [ "$oscheck" = 'Darwin' ]; then
if [ "$major" -gt 16 ] || ([ "$major" -eq 16 ] && ([ "$minor" -gt 1 ] || [ "$minor" -eq 1 ] && [ "$patch" -ge 0 ])); then
"$oscheck"/img4 -i work/ramdisk1.dmg -o sshramdisk/ramdisk.img4 -M work/IM4M -A -T rdsk
else
"$oscheck"/img4 -i work/ramdisk.dmg -o sshramdisk/ramdisk.img4 -M work/IM4M -A -T rdsk
fi
else
"$oscheck"/img4 -i work/ramdisk.dmg -o sshramdisk/ramdisk.img4 -M work/IM4M -A -T rdsk
fi
"$oscheck"/img4 -i other/bootlogo.im4p -o sshramdisk/logo.img4 -M work/IM4M -A -T rlgo
echo ""
echo "[*] Cleaning up work directory"
rm -rf work 12rd

 # echo "[*] Uploading logs. If this fails, your ramdisk is still created."
 set +e
 for file in logs/*.log; do
    mv "$file" logs/SUCCESS_${file##*/}
 done
 curl -A SSHRD_Script -F "fileToUpload=@$(ls logs/*.log)" https://nathan4s.lol/SSHRD_Script/log_upload.php > /dev/null 2>&1 | true
 set -e
 # echo "[*] Done uploading logs!"

echo ""
echo "[*] Finished! Please use ./sshrd.sh boot to boot your device"
echo $1 > sshramdisk/version.txt

 } | tee logs/"$(date +%T)"-"$(date +%F)"-"$(uname)"-"$(uname -r)".log
