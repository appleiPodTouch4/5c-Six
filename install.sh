#!/usr/bin/env bash
ssh_port=2222
if [[ $no_color != 1 ]]; then
    TERM=xterm-256color # fix colors for msys2 terminal
    color_R=$(tput setaf 9)
    color_G=$(tput setaf 10)
    color_B=$(tput setaf 12)
    color_Y=$(tput setaf 208)
    color_N=$(tput sgr0)
fi

print() {
    echo "${color_B}${1}${color_N}"
}

input() {
    echo "${color_Y}[Input] ${1}${color_N}"
}

log() {
    echo "${color_G}[Log] ${1}${color_N}"
}

warn() {
    echo "${color_Y}[WARN] ${1}${color_N}"
}

error() {
    echo -e "${color_R}[ERROR] ${1}\n${color_Y}${*:2}${color_N}"
}

pause() {
    if [[ -z $1 ]]; then
        input "Press Enter/Return to continue (or press Ctrl+C to cancel)"
    else
        input "$1"
    fi
    read -s
}

oscheck() {
    if [[ -f ../resources/current_platform ]]; then
        local local_platform_message=$(cat ../resources/current_platform 2>/dev/null)
    else
        local local_platform_message=""
    fi
    arch_path=
    platform_check=$(uname)
    arch_check=$(uname -m)
    if [[ "$platform_check" == "Darwin" ]]; then
        platform=macos
        if [[ "$arch_check" == "x86_64" ]]; then
            platform_arch=x86_64
        elif [[ "$arch_check" == "arm64" ]]; then
            platform_arch=arm64
        else
            error "Unsupport platform,please use support platform"
            exit
        fi
    elif [[ "$platform_check" == "Linux" ]]; then
        platform=linux
        if [[ "$arch_check" == "x86_64" ]]; then
            platform_arch=x86_64
        elif [[ "$arch_check" == "arm64" ]]; then
            platform_arch=arm64
        else
            error "Unsupport platform,please use support platform"
            exit
        fi
    else
        error "Unsupport platform,please use support platform"
        exit
    fi
    if [[ "$platform" == "macos" ]]; then
        if [[ "$platform_arch" == "arm64" ]]; then
                warn "Using M-series chips may cause compatibility issues; please use with caution."
                pause Press Enter to ignore this issue.  
            dir="../tools/macos/arm64"
        else
            dir="../tools/macos"
        fi
        macos_ver="${1:-$(sw_vers -productVersion)}"
        macos_major_ver="${macos_ver:0:2}"
        if [[ $macos_major_ver == 10 ]]; then
            macos_minor_ver=${macos_ver:3}
            macos_minor_ver=${macos_minor_ver%.*}
            if (( macos_minor_ver < 11 )); then
                    error "Your macOS version is too old. Please upgrade to macOS High Sierra or later."
                    exit
            fi
            case $macos_minor_ver in
                #11 ) macos_name="El Capitan";; too old
                #12 ) macos_name="Sierra";; too old
                13 ) macos_name="High Sierra";;
                14 ) macos_name="Mojave";;
                15 ) macos_name="Catalina";;
            esac
        fi
        case $macos_major_ver in
            11 ) macos_name="Big Sur";;
            12 ) macos_name="Monterey";;
            13 ) macos_name="Ventura";;
            14 ) macos_name="Sonoma";;
            15 ) macos_name="Sequoia";;
            26 ) macos_name="Tahoe";;
        esac
        if (( macos_major_ver > 12 )); then
            warn "There may be compatibility issues when using devices running macOS Monterey or later. Do you want to continue?"
            yesno continue?
                if [[ $? == 1 ]]; then
                :
            else
                exit
            fi
        fi
        platform_message="macOS ${macos_name}($platform_arch)"
    elif [[ "$platform" == "linux" ]]; then
        #warn The Linux version is still being adapted, and some features have not yet been fixed. Should we continue using it?
        #pause Press Enter to continue.
        #check_sudo
        ##linux_part
        #arch_path="linux/"
        #linux_name=$(grep '^NAME=' /etc/os-release | cut -d'"' -f2)
        #platform_message="${linux_name} ($platform_arch)"
        #dir="../tools/linux"
        #if [[ $linux_name != Ubuntu ]]; then
        #    error "Support ubuntu only"
        #    yesno
        #    if [[ $? != 1 ]]; then
        #        exit
        #    fi
        #fi
        warn "Unsupport for linux in current version,waiting for update"
        exit
    fi
    if [[ $platform_message != $local_platform_message ]]; then
        install_depends
    fi

}

linux_part() {
    if [[ -n $UBUNTU_CODENAME ]]; then
        case $UBUNTU_CODENAME in
            "jammy" | "kinetic"   ) ubuntu_ver=22;;
            "lunar" | "mantic"    ) ubuntu_ver=23;;
            "noble" | "oracular"  ) ubuntu_ver=24;;
            "plucky" | "questing" ) ubuntu_ver=25;;
        esac
        if [[ -z $ubuntu_ver ]]; then
            source /etc/upstream-release/lsb-release 2>/dev/null
            ubuntu_ver="$(echo "$DISTRIB_RELEASE" | cut -c -2)"
        fi
        if [[ -z $ubuntu_ver ]]; then
            ubuntu_ver="$(echo "$VERSION_ID" | cut -c -2)"
        fi
    elif [[ -e /etc/debian_version ]]; then
        debian_ver=$(cat /etc/debian_version)
        case $debian_ver in
            *"sid" | "kali"* ) debian_ver="sid";;
            * ) debian_ver="$(echo "$debian_ver" | cut -c -2)";;
        esac
    elif [[ $ID == "fedora" || $ID_LIKE == "fedora" || $ID == "nobara" ]]; then
        fedora_ver=$VERSION_ID
    fi
    if [[ $ID == "arch" || $ID_LIKE == "arch" || $ID == "artix" ]]; then
        distro="arch"
    elif (( ubuntu_ver >= 22 )) || (( debian_ver >= 12 )) || [[ $debian_ver == "sid" ]]; then
        distro="debian"
    elif (( fedora_ver >= 40 )); then
        distro="fedora"
        if [[ $(command -v rpm-ostree) ]]; then
            distro="fedora-atomic"
        fi
    elif [[ $ID == "opensuse-tumbleweed" ]]; then
        distro="opensuse"
    elif [[ $ID == "gentoo" || $ID_LIKE == "gentoo" || $ID == "pentoo" ]]; then
        distro="gentoo"
    elif [[ $ID == "void" ]]; then
        distro="void"
    elif [[ -n $ubuntu_ver || -n $debian_ver || -n $fedora_ver ]]; then
        error "Your distro version ($platform_ver - $platform_arch) is not supported. See the repo README for supported OS versions/distros"
    else
        warn "Your distro ($platform_ver - $platform_arch) is not detected/supported. See the repo README for supported OS versions/distros"
        print "* You may still continue, but you will need to install required packages and libraries manually as needed."
        sleep 5
        pause
    fi
}

check_sudo() {
    if [ -z "$SUDO_USER" ]; then
        log "Please enter your password."
        if sudo -v >/dev/null 2>&1; then
            clear
            return 0
        else
            error "Unable to obtain sudo privileges"
            exit 1
        fi
    else
        clear
        return 0
    fi
}


set_path() {
    if [[ "$script_dir/" =~ [[:space:]] ]]; then
        error "Directory path contains whitespace characters！" >&2
        error "Current directory: '$script_dir'" >&2
        pause Press enter to exit
        exit 1
    fi
    sudo="/usr/bin/sudo"
    if [[ $device_argmode == "none" ]]; then
        device_disable_sudoloop=1
        device_disable_usbmuxd=1
    fi
    if [[ $($sudo -V 2>&1) == "sudo-rs"* ]]; then
        if [[ -z $device_disable_sudoloop && -z $device_disable_usbmuxd ]]; then
            log "sudo-rs detected. Switching to sudo.ws"
        fi
        sudo+=".ws"
    fi
    chmod +x $dir/*
    if [[ "$platform" == "macos" ]]; then
        aria2c=""
        sshpass=""
        irecovery=""
        iproxy=""
        ipwnder32=""
        primepwn=""
        gaster=""
        idevicerestore=""
        ideviceinfo=""
        dmg=""
        zenity="$dir/zenity"
        iBoot32Patcher=""
        xpwntool=""
        dtbpatch=""
        hfsplus=""
        pzb=""
        jq=""
        gtar=""
        sha1sum="$(command -v shasum) -a 1"
        bspatch="$(command -v bspatch)"
    elif [[ "$platform" == "linux" ]]; then
        export LD_LIBRARY_PATH="$dir/lib"
        aria2c="sudo "
        sshpass="sudo "
        irecovery="sudo "
        iproxy="sudo "
        ipwnder32="sudo "
        primepwn="sudo "
        gaster="sudo "
        idevicerestore="sudo LD_LIBRARY_PATH=$dir/lib "
        ideviceinfo="sudo LD_LIBRARY_PATH=$dir/lib "
        dmg="sudo "
        zenity="sudo GSETTINGS_BACKEND=memory $(command -v zenity)"
        iBoot32Patcher="sudo "
        xpwntool="sudo "
        dtbpatch="sudo "
        hfsplus="sudo "
        pzb="sudo "
        jq="sudo "
        gtar="sudo "
    fi
    aria2c+=$dir/aria2c
    sshpass+=$dir/sshpass
    irecovery+="$dir/irecovery"
    iproxy+=$dir/iproxy
    ipwnder32+=$dir/ipwnder32
    primepwn+=$dir/primepwn
    gaster+=$dir/gaster
    idevicerestore+=$dir/idevicerestore
    ideviceinfo+=$dir/ideviceinfo
    dmg+=$dir/dmg
    iBoot32Patcher+=$dir/iBoot32Patcher
    xpwntool+=$dir/xpwntool
    hfsplus+=$dir/hfsplus
    dtbpatch+=$dir/dtbpatch
    pzb+=$dir/pzb
    jq+=$dir/jq
    img3maker+=$dir/img3maker
    gtar+=$dir/gtar

    sha1sum="$(command -v shasum) -a 1"
}


prepare_udev_rules() {
    local owner="$1"
    local group="$2"
    echo "ACTION==\"add\", SUBSYSTEM==\"usb\", ATTR{idVendor}==\"05ac\", ATTR{idProduct}==\"122[27]|128[0-3]|1338\", OWNER=\"$owner\", GROUP=\"$group\", MODE=\"0660\" TAG+=\"uaccess\"" > 39-libirecovery.rules
}

install_depends() {
    rm -f "../resources/current_platform"
    touch "../resources/current_platform"
    if [[ $platform == "linux" ]]; then
        print "Install depends now"
        print "* Enter your user password when prompted"
        pause
        prepare_udev_rules usbmux plugdev
        if [[ -n $ubuntu_ver ]]; then
            sudo add-apt-repository -y universe
        fi
        sudo apt update
        sudo apt install -y \
            aria2 \
            ca-certificates \
            curl \
            git \
            libimobiledevice6 \
            libimobiledevice-utils \
            libssl3 \
            libzstd1 \
            openssh-client \
            patch \
            python3 \
            python3-pip \
            sshfs \
            unzip \
            usbmuxd \
            usbutils \
            vim-common \
            xxd \
            zenity \
            zip \
            zlib1g
        

        pip3 install pyimg4 pylibfdt-iOS

        if [[ $(command -v systemctl 2>/dev/null) ]]; then
            sudo systemctl enable --now udev systemd-udevd usbmuxd 2>/dev/null
        fi

        echo "$platform_message" > "../resources/current_platform"

        if [[ $platform == "linux" ]]; then
            if [[ $(command -v systemctl) ]]; then
                sudo systemctl enable --now systemd-udevd usbmuxd 2>/dev/null
            fi
            sudo cp 39-libirecovery.rules /etc/udev/rules.d/39-libirecovery.rules
            sudo chown root:root /etc/udev/rules.d/39-libirecovery.rules
            sudo chmod 0644 /etc/udev/rules.d/39-libirecovery.rules
            sudo udevadm control --reload-rules
            sudo udevadm trigger -s usb
        fi

        log "Install depends done! Please run the script again to proceed(if it has some errors,try to ignore it)"

        exit
    else
        echo "$platform_message" > "../resources/current_platform"
    fi
}

validate_build() {
    local raw_build="$1"
    [[ -z "$raw_build" ]] && return 1

    local last_char="${raw_build: -1}"

    local formatted_build
    formatted_build=$(printf '%s' "$raw_build" | tr '[:lower:]' '[:upper:]')
    if [[ "$last_char" =~ ^[a-z]$ ]]; then
        formatted_build="${formatted_build%?}${last_char}"
    fi

    if [[ "$formatted_build" =~ ^[0-9]+[A-Z]+[0-9]+[a-z]?$ ]]; then
        return 0
    fi

    return 1
}

sha1sum() {
    local sha1
    sha1=$($sha1sum $2 | awk '{print $1}')
    echo $sha1
}

set_ssh_config() {
    if [ -z "$1" ]; then
        cp ../resources/ssh_config .
        if [[ $(ssh -V 2>&1 | grep -c SSH_8.8) == 1 || $(ssh -V 2>&1 | grep -c SSH_8.9) == 1 ||
            $(ssh -V 2>&1 | grep -c SSH_9.) == 1 || $(ssh -V 2>&1 | grep -c SSH_1) == 1 ]]; then
            echo "    PubkeyAcceptedAlgorithms +ssh-rsa" >> ./ssh_config
        elif [[ $(ssh -V 2>&1 | grep -c SSH_6) == 1 ]]; then
            cat ssh_config | sed "s,Add,#Add,g" | sed "s,HostKeyA,#HostKeyA,g" > ssh_config
        fi
    fi
    
    if [ -z "$1" ]; then
        ssh="$dir/sshpass -p alpine ssh -F ./ssh_config"
        scp="$dir/sshpass -p alpine scp -F ./ssh_config"
    fi
    
    if [[ "$1" == "pass" ]]; then
        ssh="$dir/sshpass -p $2 ssh -F ./ssh_config"
        scp="$dir/sshpass -p $2 scp -F ./ssh_config"
    fi
}

file_extract() {
    local archive="$1"
    local dest="$2"
    local arr=()
    if [[ $platform == "macos" ]]; then
        arr+=("-xzvf" "$archive")
        [[ -n $dest ]] && arr+=("-C" "$dest")
        tar "${arr[@]}"
        return
    fi
    arr+=("-o" "$archive")
    [[ -n $dest ]] && arr+=("-d" "$dest")
    unzip "${arr[@]}"
}

file_extract_from_archive() {
    local archive="$1"
    local file="$2"
    local dest="$3"
    [[ -z $dest ]] && dest=.
    local arr=()
    if [[ $platform == "macos" && $file != *"/"* ]]; then
        arr+=("-xzvOf" "$archive")
        arr+=("$file")
        tar "${arr[@]}" > "$dest/$file"
        return
    fi
    arr+=("-o" "-j" "$archive" "$file")
    [[ -n $dest ]] && arr+=("-d" "$dest")
    unzip "${arr[@]}"
}

file_download() {
    # usage: file_download {link} {target location} {sha1}
    local filename="$(basename $2)"
    log "Downloading $filename..."
    $aria2c "$1" -o $2
    [[ $? != 0 ]] && $curl -L "$1" -o $2
    if [[ ! -s $2 ]]; then
        error "Downloading $2 failed. Please run the script again"
        return 1
    fi
    if [[ -z $3 ]]; then
        return
    fi
    local sha1=$($sha1sum $2 | awk '{print $1}')
    if [[ $sha1 != "$3" ]]; then
        error "Verifying $filename failed. The downloaded file may be corrupted or incomplete. Please run the script again" \
        "* SHA1sum mismatch. Expected $3, got $sha1"
        return 1
    fi
}


checkmode() {
    if [[ $2 == irec ]] || [[ $platform == "linux" ]]; then
        local mode
        case $1 in
            nor )
            log "[*] Waiting for the device to enter Normal mode"
            while true; do
                device_ver=$($ideviceinfo -s 2>/dev/null | grep "ProductVersion:" | cut -d' ' -f2)
                if [[ $device_ver =~ ^[0-9]+\.[0-9]+(\.[0-9]+)*$ ]]; then
                    break
                fi
                sleep 1
            done
            ;;
            rec | DFU | DFUall )
            if [[ $1 == rec ]]; then
                local mode="Recovery"
            elif [[ $1 == DFU ]]; then
                local mode="DFU"
            elif [[ $1 == DFUall ]]; then
                local mode="DFU"
            fi
            log "[*] Waiting for the device to enter $mode mode"
            while true; do
                device_mode="$($irecovery -q 2>/dev/null | grep -w "MODE" | cut -c 7-)"
                if [[ $device_mode == "$mode" ]]; then
                    break
                elif [[ $device_mode == "WTF" ]]; then
                    break
                fi
                sleep 1
            done
            ;;
        esac
    else
        if [ "$1" = "DFU" ]; then
            if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
                if [[ "$2" != "none" ]]; then
                    log "[*] Waiting for the device to enter DFU mode"
                fi
            fi
            while ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); do
                sleep 1
            done
        elif [ "$1" = "rec" ]; then
            if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (Recovery Mode)' >> /dev/null); then
                if [[ "$2" != "none" ]]; then
                    log "[*] Waiting for the device to enter Recovery mode"
                fi
            fi
            while ! (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (Recovery Mode)' >> /dev/null); do
                sleep 1
            done
        elif [ "$1" = "nor" ]; then
            if ! (system_profiler SPUSBDataType 2> /dev/null | grep -E ' (iPod|iPhone|iPad)' >> /dev/null); then
                if [[ "$2" != "none" ]]; then
                    log "[*] Waiting for the device to enter Normal mode"
                fi
            fi
            while ! (system_profiler SPUSBDataType 2> /dev/null | grep -E ' (iPod|iPhone|iPad)' >> /dev/null); do
                sleep 1
            done
        elif [ "$1" = "DFUreal" ]; then
            if ! (system_profiler SPUSBDataType 2> /dev/null | grep ' USB DFU Device' >> /dev/null); then
                if [[ "$2" != "none" ]]; then
                    log "[*] Waiting for the device to enter DFU mode"
                fi
            fi
            while ! (system_profiler SPUSBDataType 2> /dev/null | grep ' USB DFU Device' >> /dev/null); do
                sleep 1
            done
        elif [ "$1" = "DFUall" ]; then
            log "[*] Waiting for the device to enter DFU mode"
            while true;do
                if (system_profiler SPUSBDataType 2> /dev/null | grep ' Apple Mobile Device (DFU Mode)' >> /dev/null); then
                    break
                fi
                sleep 1
                if (system_profiler SPUSBDataType 2> /dev/null | grep ' USB DFU Device' >> /dev/null); then
                    break
                fi
            done
        fi
    fi
    device_mode="$($irecovery -q 2>/dev/null | grep -w "MODE" | cut -c 7-)"
}

device_info() {
    local options=()
    if [[ $device_argmode != "none" ]]; then
        device_type=$($irecovery -q | grep -i "product" | awk -F': ' '{print $2}')
    else
        log "Select device type"
        options+=("iPhone5,3")
        options+=("iPhone5,4")
        select_option "${options[@]}"
        selected="${options[$?]}"
        device_type=$selected
    fi
    if [[ $device_type == "iPhone5,3" ]] || [[ $device_type == "iPhone5,4" ]]; then
        :
    else
        error "Your device is not compatible with this script."
    fi
    case $device_type in
        "iPhone5,3" ) device_model="n48" ;;
        "iPhone5,4" ) device_model="n49" ;;
    esac
    device_proc=6
    device_type_base="iPhone5,2"
    device_model_base="n42"
}

device_pwn() {
    local tool=ipwnder32
    log "Getting device info and pwning... this may take a second"
    device_pwnd="$($irecovery -q | grep "PWND" | cut -c 7-)"
    if [[ -n $device_pwnd ]]; then
        log "Device seems to be already in pwned DFU mode"
        print "* Pwned: $device_pwnd"
        case $device_proc in
            [56] ) device_send_unpacked_ibss;;
        esac
        return
    fi
    "$dir/ipwnder32" -p --noibss
    tool_pwned=$?
    sleep 1
    device_pwnd="$($irecovery -q | grep "PWND" | cut -c 7-)"
    log "Checking for device"
    if [[ -n $device_pwnd ]]; then
        log "Found device in pwned DFU mode."
        print "* Pwned: $device_pwnd"
        if [[ $device_proc == 6 ]]; then
            device_send_unpacked_ibss
        fi
    elif [[ $device_proc == 6 ]]; then
        device_srtg="$($irecovery -q | grep "SRTG" | cut -c 7-)"
        if [[ $device_srtg != "iBoot"* ]]; then
            log "Found device in pwned iBSS mode."
        else
            error "Pwn device failed,you can re-enter DFU and retry"
            exit
        fi
    fi
}

device_send_unpacked_ibss() {
    local pwnrec="pwned iBSS"
    local tool_pwned
    if [[ $device_boot4 == 1 ]]; then
        pwnrec="pwned recovery"
        cp iBSS.patched pwnediBSS
    else
        device_rd_build=
        patch_ibss
    fi
    if [[ $device_pwnd == *"wnder" ]]; then
        log "Sending packed iBSS..."
        $primepwn pwnediBSS.dfu
        tool_pwned=$?
    elif [[ $device_proc == 6 ]]; then
        log "gaster reset"
        $gaster reset
        sleep 1
        log "Sending iBSS..."
        $irecovery -f pwnediBSS.dfu
        tool_pwned=$?
    else
        log "Sending unpacked iBSS..."
        $primepwn pwnediBSS
        tool_pwned=$?
    fi
    rm -f pwnediBSS
    if [[ $tool_pwned != 0 ]]; then
        error "Failed to send iBSS. Your device has likely failed to enter PWNED DFU mode." \
              "* You might need to exit DFU and (re-)enter PWNED DFU mode before retrying."
    fi
    sleep 1
    log "Checking for device"
    local irec="$($irecovery -q 2>&1)"
    device_pwnd="$(echo "$irec" | grep "PWND" | cut -c 7-)"
    if [[ -z $device_pwnd && $irec != "ERROR"* ]]; then
        log "Device should now be in $pwnrec mode."
    elif [[ $device_proc == 5 ]]; then
        error "Device failed to enter $pwnrec mode." \
              "* If you are using Arduino for checkm8-a5, make sure you are using my (LukeZGD) or synackuk fork of checkm8-a5. Do not use a1exdandy checkm8-a5."
        exit 1
    else
        error "Device failed to enter $pwnrec mode."
        exit 1
    fi
}


cut_os_vers() {
    if [[ $1 != device ]]; then
        device_det=$(echo "$1" | cut -c 1)
        device_det2=$(echo "$1" | cut -c -2)
        device_det3=$(echo "$1" | cut -c 3)
        device_det4=$(echo "$1" | cut -c 4)
        device_det5=$(echo "$1" | cut -c 4-5)
        device_det6=$(echo "$1" | cut -c 5-6)
    else
        device_det=$(echo "$2" | cut -c 1)
        device_det2=$(echo "$2" | cut -c -2)
        device_det3=$(echo "$2" | cut -c 3)
        device_det4=$(echo "$2" | cut -c 4)
        device_det5=$(echo "$2" | cut -c 4-5)
        device_det6=$(echo "$2" | cut -c 5-6)
    fi
    if [[ $1 != device ]]; then
        if [[ $device_det == 1 ]]; then
            major_ver=$device_det2
            minor_ver=$device_det4
            nano_ver=$device_det6
            nano_ver_wtd=$(echo "$nano_ver" | cut -c 2)
        else
            major_ver=$device_det
            minor_ver=$device_det3
            nano_ver=$device_det5
            nano_ver_wtd=$(echo "$nano_ver" | cut -c 2)
        fi
    else
        if [[ $device_det == 1 ]]; then
            device_major_ver=$device_det2
            device_minor_ver=$device_det4
            device_nano_ver=$device_det6
            device_nano_ver_wtd=$(echo "$device_nano_ver" | cut -c 2)
        else
            device_major_ver=$device_det
            device_minor_ver=$device_det3
            device_nano_ver=$device_det5
            device_nano_ver_wtd=$(echo "$device_nano_ver" | cut -c 2)
        fi
    fi
}


get_ipsw_info() {
    local ipsw_file
    if [[ $1 == "base" ]]; then
        ipsw_file="$ipsw_base_path"
    else
        if [[ $1 == "target" ]]; then
            ipsw_file="$2"
        else
            ipsw_file="$ipsw_path"
        fi
    fi    
    if [ -z "$ipsw_file" ]; then
        warn Unable to get ipsw path
        exit
    fi
    if [[ $device_proc == 1 || $device_proc == 4 ]] && [[ $ipsw_file == *1.* || $ipsw_file == *2.* ]]; then
        plist="Restore.plist"
        plist_legacy=1
    else
        plist="BuildManifest.plist"
    fi
    unzip -p "$ipsw_file" "$plist" > "$plist" 2>/dev/null
    if [ $? -ne 0 ]; then
        if [[ $device_proc == 4 ]]; then
            plist="BuildManifest.plist"
            unzip -p "$ipsw_file" "$plist" > "$plist" 2>/dev/null
            if [[ ! -f $plist ]]; then
                error "Unable extract files from this ipsw"
                return 1
            fi
        else
            error "Unable extract files from this ipsw"
            return 1
        fi
    fi
    if [[ $platform == "macos" ]]; then
        if [[ $plist == "Restore.plist" ]]; then
            device_type_ipsw_temp=$(plutil -extract "ProductType" xml1 -o - "$plist" | sed -n 's/<string>\(.*\)<\/string>/\1/p')
        else
            device_type_ipsw_temp=$(plutil -extract "SupportedProductTypes" xml1 -o - "$plist" | sed -n 's/<string>\(.*\)<\/string>/\1/p')
        fi
        device_vers=$(plutil -extract "ProductVersion" xml1 -o - "$plist" | sed -n 's/<string>\(.*\)<\/string>/\1/p')
        device_build=$(plutil -extract "ProductBuildVersion" xml1 -o - "$plist" | sed -n 's/<string>\(.*\)<\/string>/\1/p')
        device_type_ipsw=$(echo "$device_type_ipsw_temp" | tr -d '\n\r' | xargs)
    else
        if [[ $plist == "Restore.plist" ]]; then
            device_type_ipsw_temp=$(cat "$plist" | grep -i ProductType -A 1 | grep -oPm1 "(?<=<string>)[^<]+")
        else
            device_type_ipsw_temp=$(cat $plist | grep -i SupportedProductTypes -A 1 | grep -oPm1 "(?<=<string>)[^<]+")
        fi
        device_vers=$(cat $plist | grep -i ProductVersion -A 1 | grep -oPm1 "(?<=<string>)[^<]+")
        device_build=$(cat $plist | grep -i ProductBuildVersion -A 1 | grep -oPm1 "(?<=<string>)[^<]+")
        device_type_ipsw=$(echo "$device_type_ipsw_temp" | tr -d '\n\r' | xargs)
    fi
    if [[ $1 == "base" ]]; then
        device_type_ipswbase="$device_type_ipsw"
        device_base_vers="$device_vers"
        device_base_build="$device_build"
        if [[ "$device_type" != "$device_type_ipswbase" ]]; then
            ipsw_base_select_wrong=1
            ipsw_path=""
        else
            ipsw_base_select_wrong=0
        fi
    else
        device_type_ipsw="$device_type_ipsw"
        device_ipsw_vers="$device_vers"
        device_ipsw_build="$device_build"
        if [[ "$device_type" != "$device_type_ipsw" ]]; then
            ipsw_select_wrong=1
            ipsw_path=""
        else
            ipsw_select_wrong=0
        fi
    fi
    rm -f "$plist"
    return 0
}


get_firmware_info() {
    local version=
    local build=
    local mode
    firmware_version=
    firmware_buildid=
    firmware_filesize=
    firmware_sha1=
    firmware_sha256=
    firmware_md5=
    firmware_signed=
    firmware_releasedate=
    firmware_uploaddate=
    firmware_url=

    if [[ $1 == "base" ]]; then
        local device_type=$device_type_base
    fi


    log "Get firmware info"
    if [[ $1 == "base" ]]; then
        validate_build $2
    else
        validate_build $1
    fi
    if [[ $? != 1 ]]; then
        mode="build"
    else
        mode="ver"
    fi

    if [[ $device_type == "iPod1,1" || $device_type == "iPod2,1" ]]; then
        if [[ $mode == "ver" ]] && [[ $1 == 2.* || $1 == 3.* ]]; then
            if [[ ! -f $saved/invoxiplaygames.html ]]; then
                log "Downloading html"
                file_download https://invoxiplaygames.uk/ipsw/ temp.html
                if [[ -f temp.html ]]; then
                    mv temp.html $saved/invoxiplaygames.html
                else
                    error "Unable to download html"
                    exit 1
                fi
            fi
            cp $saved/invoxiplaygames.html temp.html
            local namess=$(grep -oE 'iPod[0-9],[0-9]_[^"]+\.ipsw' temp.html)
            local names=$(echo "$namess" | grep "$device_type")
            local name=$(echo "$names" | grep -E "_${1}_" | head -n 1)
            if [[ -n $name ]]; then
                firmware_url="https://invoxiplaygames.uk/ipsw/$name"
                firmware_version="$(echo "$name" | cut -d'_' -f2)"
                firmware_buildid="$(echo "$name" | cut -d'_' -f3)"
                return 0
            fi
        elif [[ $mode == "build" ]] && [[ $1 == 5* || $1 == 7* ]]; then
            if [[ ! -f $saved/invoxiplaygames.html ]]; then
                log "Downloading html"
                file_download https://invoxiplaygames.uk/ipsw/ temp.html
                if [[ -f temp.html ]]; then
                    mv temp.html $saved/invoxiplaygames.html
                else
                    error "Unable to download html"
                    exit 1
                fi
            fi
            cp $saved/invoxiplaygames.html temp.html
            local namess=$(grep -oE 'iPod[0-9],[0-9]_[^"]+\.ipsw' temp.html)
            local names=$(echo "$namess" | grep "$device_type")
            local name=$(echo "$names" | grep -E "_[^_]+_${1}_" | head -n 1)
            if [[ -n $name ]]; then
                firmware_url="https://invoxiplaygames.uk/ipsw/$name"
                firmware_version="$(echo "$name" | cut -d'_' -f2)"
                firmware_buildid="$(echo "$name" | cut -d'_' -f3)"
                return 0
            fi
        fi
    fi


    curl -s -L "https://api.ipsw.me/v4/device/$device_type?type=ipsw" -o tmp.json

    if [[ ! -f "tmp.json" ]]; then
        error Unable to get json,please check internat connection
        exit
    fi
    if [[ $mode == "ver" ]]; then
        if [[ $1 == "base" ]]; then
            version=$2
        else
            version=$1
        fi
        if [[ "$device_type" == "iPod4,1" && "$version" == "4.1" ]]; then
            log Select version
            options=("8B117" "8B118")
            select_option "${options[@]}"
            selected_index=$?
            selected="${options[$selected_index]}"
            
            case $selected in
                "8B117" ) 
                    get_firmware_info 8B117
                    return $?
                    ;;
                "8B118" ) 
                    get_firmware_info 8B118
                    return $?
                    ;;
            esac
        fi
    elif [[ $mode == "build" ]]; then
        if [[ $1 == "base" ]]; then
            build=$2
        else
            build=$1
        fi
    fi
    if [[ $mode == "ver" ]]; then
        firmware_version=$($jq -r ".firmwares[] | select(.version == \"$version\") | .version" "tmp.json")
        firmware_buildid=$($jq -r ".firmwares[] | select(.version == \"$version\") | .buildid" "tmp.json")
        firmware_filesize=$($jq -r ".firmwares[] | select(.version == \"$version\") | .filesize" "tmp.json")
        firmware_url=$($jq -r ".firmwares[] | select(.version == \"$version\") | .url" "tmp.json")
        firmware_sha1=$($jq -r ".firmwares[] | select(.version == \"$version\") | .sha1sum" "tmp.json")
        firmware_sha256=$($jq -r ".firmwares[] | select(.version == \"$version\") | .sha256sum" "tmp.json")
        firmware_md5=$($jq -r ".firmwares[] | select(.version == \"$version\") | .md5sum" "tmp.json")
        firmware_signed=$($jq -r ".firmwares[] | select(.version == \"$version\") | .signed" "tmp.json")
        firmware_releasedate=$($jq -r ".firmwares[] | select(.version == \"$version\") | .releasedate" "tmp.json")
        firmware_uploaddate=$($jq -r ".firmwares[] | select(.version == \"$version\") | .uploaddate" "tmp.json")
    elif [[ $mode == "build" ]]; then
        firmware_version=$($jq -r ".firmwares[] | select(.buildid == \"$build\") | .version" "tmp.json")
        firmware_buildid=$($jq -r ".firmwares[] | select(.buildid == \"$build\") | .buildid" "tmp.json")
        firmware_filesize=$($jq -r ".firmwares[] | select(.buildid == \"$build\") | .filesize" "tmp.json")
        firmware_url=$($jq -r ".firmwares[] | select(.buildid == \"$build\") | .url" "tmp.json")
        firmware_sha1=$($jq -r ".firmwares[] | select(.buildid == \"$build\") | .sha1sum" "tmp.json")
        firmware_sha256=$($jq -r ".firmwares[] | select(.buildid == \"$build\") | .sha256sum" "tmp.json")
        firmware_md5=$($jq -r ".firmwares[] | select(.buildid == \"$build\") | .md5sum" "tmp.json")
        firmware_signed=$($jq -r ".firmwares[] | select(.buildid == \"$build\") | .signed" "tmp.json")
        firmware_releasedate=$($jq -r ".firmwares[] | select(.buildid == \"$build\") | .releasedate" "tmp.json")
        firmware_uploaddate=$($jq -r ".firmwares[] | select(.buildid == \"$build\") | .uploaddate" "tmp.json")
    fi

    validate_build $firmware_buildid
    if [[ $? == 1 ]]; then
        error "Get firmware info failed"
        exit 1
    fi

}



device_iproxy() {
    local port=22
    log "Running iproxy for SSH..."
    if [[ -n $2 ]]; then
        port=$2
    fi
    if [[ $1 == "no-logging" && $debug != 1 ]]; then
        "$dir/iproxy" $ssh_port $port -s 127.0.0.1 >/dev/null &
        iproxy_pid=$!
    else
        "$dir/iproxy" $ssh_port $port -s 127.0.0.1 &
        iproxy_pid=$!
    fi
    log "iproxy PID: $iproxy_pid"
    sleep 1
}


device_fw_key_check() {
    # check and download keys for device_target_build, then set the variable device_fw_key (or device_fw_key_base)
    #remove download part,replace use unzip
    local key
    local build="$device_target_build"
    if [[ $1 == "base" ]]; then
        build=$2
        local device_type=$device_type_base
    elif [[ $1 == "temp" ]]; then
        build="$2"
    else
        build="$1"
    fi
    device_fw_dir=../saved/$device_type/$build
    local keys_path="../saved/keys/$device_type/$build"
    if [[ ! -d $keys_path ]]; then
        mkdir -p $keys_path
    fi
    log "Checking firmware keys"
    if [[ $(cat "$keys_path/index.html" 2>/dev/null | grep -c "$build") != 1 ]]; then
        rm -f "$keys_path/index.html"
    fi
    if [[ ! -f "$keys_path/index.html" ]]; then
        cp ../resources/keys.zip .
        unzip -p keys.zip "Legacy-iOS-Kit-Keys-master/$device_type/$build/index.html" > index.html
    else
        cp $keys_path/index.html .
    fi

    if [[ $1 == "base" ]]; then
        device_fw_key_base="$(cat index.html)"
    elif [[ $1 == "temp" ]]; then
        device_fw_key_temp="$(cat index.html)"
    else
        device_fw_key="$(cat index.html)"
    fi
}

patch_ibss() {
    # creates file pwnediBSS to be sent to device
    local build_id
    case $device_type in
        iPad1,1 | iPod3,1 ) build_id="9B206";;
        iPhone2,1 | iPod4,1 ) build_id="10B500";;
        iPhone3,[123] ) build_id="11D257";;
        * ) build_id="12H321";;
    esac
    if [[ -n $device_rd_build ]]; then
        build_id="$device_rd_build"
    fi
    download_comp $build_id iBSS
    device_fw_key_check temp $build_id
    local iv=$(echo $device_fw_key_temp | $jq -j '.keys[] | select(.image == "iBSS") | .iv')
    local key=$(echo $device_fw_key_temp | $jq -j '.keys[] | select(.image == "iBSS") | .key')
    log "Decrypting iBSS..."
    "$dir/xpwntool" iBSS iBSS.dec -iv $iv -k $key
    log "Patching iBSS..."
    "$dir/iBoot32Patcher" iBSS.dec pwnediBSS --rsa
    "$dir/xpwntool" pwnediBSS pwnediBSS.dfu -t iBSS
    cp pwnediBSS pwnediBSS.dfu ../saved/
    log "Pwned iBSS saved at: saved/pwnediBSS"
    log "Pwned iBSS img3 saved at: saved/pwnediBSS.dfu"
}


download_comp() {
    # usage: download_comp [build_id] [comp]
    local build_id="$1"
    local comp="$2"
    get_firmware_info $build_id
    local ipsw_url=$firmware_url
    download_targetfile="$comp.$device_model"
    if [[ $build_id != "12"* ]]; then
        download_targetfile+="ap"
    fi
    download_targetfile+=".RELEASE"

    if [[ -e "../saved/$device_type/${comp}_$build_id.dfu" ]]; then
        cp "../saved/$device_type/${comp}_$build_id.dfu" ${comp}
    else
        log "Downloading ${comp}..."
        "$dir/pzb" -g "Firmware/dfu/$download_targetfile.dfu" -o ${comp} "$ipsw_url"
        cp ${comp} "../saved/$device_type/${comp}_$build_id.dfu"
    fi
}


main_info() {
    clear
    print  "*** 5c-Six ***"
    print  "- $platform_message -"
    print  "- Script by XiaoWZ MrY0000 -"
    print  "- Thanks LuckZGD -"
    print  "- Device type:$device_type -"
    print  "- Device model:$device_model -"
    if [[ $device_type == "iPhone5,4" ]]; then
        warn "Your device($device_type) haven't patches,cannot fix drivers"
        warn "Waiting for update"
        warn "Enable no driver flag"
        nodriver=1
    fi
    if [[ $nodriver == "1" ]]; then
        warn "No driver flag enabled,you will not install drivers"
    fi
    if [[ $skip_partition == "1" ]]; then
        warn "Skip partition flag enabled,you will skip partition disk"
        warn "Make sure you have partitioned disk,otherwise the installtion will fail"
    fi
}


main_menu() {
    local options=()
    local selected
    local mode
    main_info
    if [[ -z $main_mode ]]; then
        input "Select option:"
         options+=("Prepariing iOS6.1.4 RootFS")
        if [[ $device_argmode != "none" ]]; then
            options+=("Install iOS6.1.4 on device")
            options+=("Boot iOS6.1.4")
        fi
        if [[ $(whoami) == "mry0000" ]]; then
            options+=("Test")
        fi
        options+=("Exit")
        select_option "${options[@]}"
        selected="${options[$?]}"
        case $selected in
            "Install iOS6.1.4 on device" ) mode="install";;
            "Prepariing iOS6.1.4 RootFS" ) mode="prepare";;
            "Boot iOS6.1.4" ) mode="boot";;
            "Test" ) mode="test";;
            "Exit" ) mode="exit";;
        esac
    else
        mode=$main_mode
    fi
    
    if [[ $mode == "install" ]]; then
        checkmode DFU
        ramdisk 11A470a
        install_rootfs
    elif [[ $mode == "prepare" ]]; then
        ipsw_menu
        prepare_rootfs
    elif [[ $mode == "boot" ]]; then
        just_boot
    elif [[ $mode == "test" ]]; then
        ramdisk 11A470a
    fi
    if [[ $mode == "exit" ]]; then
        exit
    else
        main_menu
        return
    fi
}

ipsw_menu() {
    local options=()
    main_info
    if [[ -f ../saved/6.1.4.ipsw ]]; then
        log "Found exist ipsw"
        log "Check shasum"
        get_firmware_info base 6.1.4
        ipsw_sha1=$($sha1sum ../saved/6.1.4.ipsw | awk '{print $1}')
        if [[ $ipsw_sha1 != $firmware_sha1 ]]; then
            echo "$ipsw_sha1"
            log "$firmware_sha1"
            error "You downloaded wrong ipsw"
            pause
            rm ../saved/6.1.4.ipsw
            ipsw_path=
            ipsw_menu
            return
        else
            ipsw_path=../saved/6.1.4.ipsw
            return
        fi
    fi
    input "Select option:"
    options+=("Select iOS6.1.4 firmware")
    options+=("Download iOS6.1.4 firmware")
    if [[ -n $ipsw_path ]]; then
        options+=("Start make")
    fi
    select_option "${options[@]}"
    selected="${options[$?]}"
    case $selected in
        "Select iOS6.1.4 firmware" ) 
            ipsw_path="$($zenity --file-selection --file-filter='IPSW | *.ipsw' --title="Select IPSW file(s)")"
            log "Verify ipsw"
            ipsw_sha1=$($sha1sum $ipsw_path | awk '{print $1}')
            get_firmware_info base 6.1.4
            if [[ $ipsw_sha1 != $firmware_sha1 ]]; then
                error "You selected wrong ipsw"
                pause
                ipsw_path=
            fi
        ;;
        "Download iOS6.1.4 firmware" ) 
            get_firmware_info base 6.1.4
            log "Start download iOS 6.1.4 ipsw"
            file_download $firmware_url "6.1.4.ipsw" $firmware_sha1
            if [[ $? == 1 ]]; then
                error "Download ipsw failed,check your Internet connection"
                pause
                ipsw_path=
            else
                cp 6.1.4.ipsw ../saved/6.1.4.ipsw
                ipsw_path=../saved/6.1.4.ipsw
            fi
        ;;
        "Start make" ) return;;
    esac
    ipsw_menu
    return
}


prepare_rootfs() {
    local rootfs_name
    local iv
    local key
    local ivkey
    if [[ -f ../saved/rootfs.uzdo.dmg ]]; then
        log "RootFS exist"
        cp ../saved/rootfs.uzdo.dmg rootfs.uzdo.dmg
        return
    fi
    log "Get rootfs name and ivkey"
    device_fw_key_check base 10B350
    rootfs_name=$(echo $device_fw_key_base | $jq -j '.keys[] | select(.image == "'RootFS'") | .filename')
    iv=$(echo $device_fw_key_base | $jq -j '.keys[] | select(.image == "'RootFS'") | .iv')
    key=$(echo $device_fw_key_base | $jq -j '.keys[] | select(.image == "'RootFS'") | .key')
    ivkey=${iv}${key}
    log "RootFS name:$rootfs_name"
    log "ivkey:$ivkey"
    log "Extracting RootFS from $ipsw_path" $rootfs_name
    file_extract_from_archive $ipsw_path $rootfs_name
    mv $rootfs_name rootfs.dmg
    if [[ ! -f rootfs.dmg ]]; then
        error "Unable to extract rootfs"
        return 1
    fi
    log "Encrypting RootFS"
    $dmg extract rootfs.dmg rootfs.decrypted.dmg -k $key
    if [[ $? == 1 ]]; then
        error "Unable to make rootfs.decrypted.dmg"
        return 1
    fi
    log "Decrypting RootFS"
    $dmg build rootfs.decrypted.dmg rootfs.uzdo.dmg
    if [[ $? == 1 ]]; then
        error "Unable to make rootfs.uzdo.dmg"
        return 1
    fi

    cp rootfs.uzdo.dmg ../saved/rootfs.uzdo.dmg
    log "Done,prepare rootfs successfully"
    pause
}


install_rootfs() {
    local rootfs="rootfs.uzdo.dmg"
    local sshc="$ssh -p $ssh_port root@127.0.0.1" 
    warn "This destroys the current partition table and device data."
    yesno "Do you want to install?"
    if [[ $? != 1 ]]; then
        exit 1
    fi

    if [[ ! -f rootfs.uzdo.dmg ]]; then
        prepare_rootfs
    fi

    log "Making fw.tar"
    mkdir -p /tmp/rootfs-mount
    sudo hdiutil attach -quiet -nobrowse -mountpoint "/tmp/rootfs-mount" rootfs.uzdo.dmg
    if [[ $? != 0 ]]; then
        error "Cannot mount RootFS image"
        exit 1
    fi
    sudo diskutil enableOwnership "/tmp/rootfs-mount"
    if [[ $? != 0 ]]; then
        hdiutil detach "/tmp/rootfs-mount" -quiet
        error "Could not enable RootFS ownership"
        exit 1
    fi
    sudo "$gtar" --numeric-owner -cf ../saved/fw.tar -C "/tmp/rootfs-mount" .
    if [[ $? -ne 0 ]]; then
        hdiutil detach "/tmp/rootfs-mount" -quiet
        error "Could not create RootFS tar"
        exit 1
    fi
    hdiutil detach "/tmp/rootfs-mount" -quiet
    pause
    if [[ $skip_partition != "1" ]]; then
        log "Get last sectors"
        last_sector="$($sshc 'gptfdisk -l /dev/rdisk0s1' | awk 'tolower($0) ~ /last usable sector is/ {print $NF; exit}')"
        [[ $last_sector =~ ^[0-9]+$ ]] || { error "Could not read last usable GPT sector"; exit 1; }
        last_sector=$((last_sector - 4))
        (( last_sector > 524294 )) || { error "Disk geometry is too small"; exit 1; }
        log "Partitioning disk..."
        printf 'd\n1\nd\nn\n1\n\n524294\n\nn\n\n\n%s\n\nc\n1\nSystem\nc\n2\nData\nw\ny\n' "$last_sector" | $sshc 'gptfdisk /dev/rdisk0s1'
    fi
    log "Create filesystems"
    $sshc "/sbin/newfs_hfs -s -v System -J -b 4096 -n a=4096,c=4096,e=4096 /dev/disk0s1s1 && /sbin/newfs_hfs -s -v Data -J -P -b 4096 -n a=4096,c=4096,e=4096 /dev/disk0s1s2 && mkdir -p /mnt1 /mnt2"
    log "Restoring RootFS"
    $sshc "mount_hfs /dev/disk0s1s1 /mnt1"
    cat ../saved/fw.tar | $sshc 'cd /mnt1 && tar xpf -' || { error "RootFS transfer failed"; exit 1; }
    $sshc "mount_hfs /dev/disk0s1s2 /mnt2"
    log "Moving private var"
    $sshc "mv /mnt1/private/var/* /mnt2 && mkdir -p /mnt2/keybags && chown 0:0 /mnt2/keybags && chmod 755 /mnt2/keybags" 
    $sshc "mkdir -p /mnt2/.5c-six-config"
    $scp -P $ssh_port ../config/* ../resources/fixkeybag/fixkeybag root@127.0.0.1:/mnt2/.5c-six-config/
    $sshc "cp /mnt2/.5c-six-config/launchd.conf /mnt1/private/etc/launchd.conf && cp /mnt2/.5c-six-config/fixkeybag /mnt1/fixkeybag && chown 0:0 /mnt1/fixkeybag && chmod 755 /mnt1/fixkeybag" 
    if [[ $nodriver != "1" ]]; then
        log "Synthesizing ${device_model} SpringBoard plist"
        local ap_model=$(echo $device_model | tr '[:lower:]' '[:upper:]')
        $sshc "cp /mnt1/System/Library/CoreServices/SpringBoard.app/N42AP.plist /mnt1/System/Library/CoreServices/SpringBoard.app/${ap_model}AP.plist"
        log "Installing drivers"
        cat ../resources/drivers/drivers_${device_model}.tar | $sshc 'cd /mnt1 && tar xpvf -' || { error "Driver injection failed"; exit 1; }
    fi
    log "Jailbreaking"
    cat ../resources/jailbreak/jailbreak.tar | $sshc 'cd /mnt1 && tar xpvf -' || { error "Bootstrap injection failed"; exit 1; }
    log "Applying hacktivation patches"
    $scp -P $ssh_port ../resources/activation/lockdownd.patched root@127.0.0.1:/mnt1/usr/libexec/lockdownd
    $sshc "chown 0:0 /mnt1/usr/libexec/lockdownd && chmod 755 /mnt1/usr/libexec/lockdownd"
    $scp -P $ssh_port ../resources/activation/fstab root@127.0.0.1:/mnt1/private/etc/fstab
    $sshc "chown 0:0 /mnt1/private/etc/fstab"
    $sshc "rm -rf /mnt2/.5c-six-config"
    log "Rebooting"
    $sshc "nvram -c"
    $sshc "sync"
    $sshc "reboot_bak"
    log "Done, use ./install.sh boot to continue"
    pause
}

ramdisk() {
    local comps=("iBSS" "iBEC" "DeviceTree" "Kernelcache")
    local name
    local iv
    local key
    local path
    local url
    local decrypt
    local ramdisk_path
    local version
    local build_id
    local local_build_id
    local files
    local rec=2
    all_flash="Firmware/all_flash/all_flash.${device_model}ap.production"
    local bundle="../resources/firmware/FirmwareBundles/Down_"

    comps+=("RestoreRamdisk")
    device_target_build=$1
    get_firmware_info $device_target_build
    device_target_vers=$firmware_version
    device_target_build=$firmware_buildid
    device_fw_key_check $device_target_build
    ipsw_url=$firmware_url
    version=$device_target_vers
    build_id=$device_target_build
    bundle+="${device_type}_${version}_${build_id}.bundle"

    print "*Ramdisk version:$version($build_id)*"
    ramdisk_path="../saved/ramdisk_$build_id"
    
    
    if [[ -d $ramdisk_path ]]; then
        local ramdisk_files=("Ramdisk.dmg" "DeviceTree.dec" "Kernelcache.dec")
        for files in $ramdisk_files; do
            if [[ ! -f $ramdisk_path/$files ]]; then
                warn "$files missed,redownload"
                pause
                rm -rf $ramdisk_path
                break
            fi
        done
        if [[ -d $ramdisk_path ]]; then
            log "Ramdisk exist"
            ramdisk_boot
            return
        fi
    fi  

    mkdir $ramdisk_path 2>/dev/null

    for getcomp in "${comps[@]}"; do
        name=$(echo $device_fw_key | $jq -j '.keys[] | select(.image == "'$getcomp'") | .filename')
        iv=$(echo $device_fw_key | $jq -j '.keys[] | select(.image == "'$getcomp'") | .iv')
        key=$(echo $device_fw_key | $jq -j '.keys[] | select(.image == "'$getcomp'") | .key')
        log "iv:$iv"
        log "key $key"
        log "name:$name"
        case $getcomp in
            "iBSS" | "iBEC" ) path="Firmware/dfu/";;
            "DeviceTree" )
                path="Firmware/all_flash/"
                case $build_id in
                    14[EFG]* ) :;;
                    * ) path="$all_flash/";;
                esac
            ;;
            * ) path="";;
        esac
        if [[ -z $name ]]; then
            local hwmodel="$device_model"
            case $build_id in
                14[EFG]* )
                    case $device_type in
                        iPhone5,[12] ) hwmodel="iphone5";;
                        iPhone5,[34] ) hwmodel="iphone5b";;
                        iPad3,[456] )  hwmodel="ipad3b";;
                    esac
                ;;
                [12345789]* | 10* | 11* ) hwmodel+="ap";;
            esac
            case $getcomp in
                "iBSS" | "iBEC" ) name="$getcomp.$hwmodel.RELEASE.dfu";;
                "DeviceTree" )    
                    if [[ $plist_legacy == 1 && $device_ipsw_build == 3* ]]; then
                        name="$getcomp.${device_model}ap.img2"
                    else
                        name="$getcomp.${device_model}ap.img3"
                    fi
                    ;;
                "Kernelcache" ) 
                    if [[ $plist_legacy == 1 && $device_ipsw_build == 3* ]]; then
                        name="kernelcache.release.*"
                    else  
                        name="kernelcache.release.$hwmodel"
                    fi
                    ;;
            esac
        fi
        case $getcomp in
            "RestoreRamdisk" )
                case $name in
                    *.dmg.dmg )
                        name=$(basename $name .dmg)
                    ;;
                esac
                ;;
        esac
        log "$getcomp"
        if [[ -s $ramdisk_path/$name ]]; then
            cp $ramdisk_path/$name .
        else
            log "$dir/pzb -g ${path}$name -o $name $ipsw_url"
            "$dir/pzb" -g "${path}$name" -o "$name" "$ipsw_url"
        fi
        if [[ ! -s $name ]]; then
            error "Failed to get $name. Please run the script again."
        fi
        if [[ ! -s $ramdisk_path/$name ]]; then
            cp $name $ramdisk_path/
        fi
        mv $name $getcomp.orig
        if [[ $getcomp == "Kernelcache" || $getcomp == "iBSS" ]] && [[ $device_proc == 1 || $device_type == "iPod2,1" ]]; then
            decrypt="-iv $iv -k $key"
            "$dir/xpwntool" $getcomp.orig $getcomp.dec $decrypt
        elif [[ $build_id == "14"* ]]; then
            cp $getcomp.orig $getcomp.dec
        else
            "$dir/xpwntool" $getcomp.orig $getcomp.dec -iv $iv -k $key -decrypt
        fi
    done

    log "Patch RestoreRamdisk"
    "$dir/xpwntool" RestoreRamdisk.dec Ramdisk.raw
    "$dir/hfsplus" Ramdisk.raw grow 32000000
    "$dir/hfsplus" Ramdisk.raw untar ../resources/sbplist.tar


    "$dir/hfsplus" Ramdisk.raw untar ../resources/ssh.tar
    "$dir/hfsplus" Ramdisk.raw mv sbin/reboot sbin/reboot_bak
    "$dir/hfsplus" Ramdisk.raw mv sbin/halt sbin/halt_bak


    case $build_id in
            "12"* | "13"* | "14"* )
            echo '#!/bin/bash' > restored_external
            echo "/sbin/sshd; exec /usr/local/bin/restored_external_o" >> restored_external
            "$dir/hfsplus" Ramdisk.raw mv usr/local/bin/restored_external usr/local/bin/restored_external_o
            "$dir/hfsplus" Ramdisk.raw add restored_external usr/local/bin/restored_external
            "$dir/hfsplus" Ramdisk.raw chmod 755 usr/local/bin/restored_external
            "$dir/hfsplus" Ramdisk.raw chown 0:0 usr/local/bin/restored_external
        ;;
    esac
    "$dir/xpwntool" Ramdisk.raw Ramdisk.dmg -t RestoreRamdisk.dec

   log "Patch iBSS"
   #log "$dir/xpwntool iBSS.dec iBSS.raw"
   "$dir/xpwntool" iBSS.dec iBSS.raw
   "$dir/iBoot32Patcher" iBSS.raw iBSS.patched --rsa --debug -b "$device_bootargs"
   #log "$dir/xpwntool iBSS.patched iBSS -t iBSS.dec"
   "$dir/xpwntool" iBSS.patched iBSS -t iBSS.dec
   if [[ $build_id == "7"* || $build_id == "8"* ]] && [[ $device_type != "iPad"* ]]; then
       :
   else
        log "Patch iBEC"
        "$dir/xpwntool" iBEC.dec iBEC.raw
        local bootarg="rd=md0 -v amfi=0xff amfi_get_out_of_my_way=1 cs_enforcement_disable=1 pio-error=0"
        "$dir/iBoot32Patcher" iBEC.raw iBEC.patched --rsa --debug -b "$bootarg"
        "$dir/xpwntool" iBEC.patched iBEC -t iBEC.dec
   fi



    mv iBSS iBEC DeviceTree.dec Kernelcache.dec Ramdisk.dmg $ramdisk_path 2>/dev/null

    if [[ $build_id == "7"* || $build_id == "8"* ]] && [[ $device_type != "iPad"* ]]; then
        if [[ ! -f $ramdisk_path/DeviceTree.dec ]] || [[ ! -f $ramdisk_path/Kernelcache.dec ]] || [[ ! -f $ramdisk_path/Ramdisk.dmg ]] || [[ ! -f $ramdisk_path/iBSS ]]; then
            error "Make ramdisk failed,some files missed"
            exit 1
        fi
    elif [[ ! -f $ramdisk_path/DeviceTree.dec ]] || [[ ! -f $ramdisk_path/Kernelcache.dec ]] || [[ ! -f $ramdisk_path/Ramdisk.dmg ]] || [[ ! -f $ramdisk_path/iBSS ]] || [[ ! -f $ramdisk_path/iBEC ]]; then
        error "Make ramdisk failed,some files missed"
        exit 1
    fi
    log "Done creating SSH ramdisk files: ../saved/ramdisk_$build_id"
    if [[ $device_argmode == "none" ]]; then
        return
    else
        ramdisk_boot
        return
    fi
}

ramdisk_boot() {
    local ramdisk_path="../saved/ramdisk_$device_target_build"
    yesno "Do you want to boot ramdisk?"
    if [[ $? != 1 ]]; then
        return
    fi

    device_pwn
    if [[ $device_type == "iPad1,1" && $build_id != "9"* ]]; then
        patch_ibss
        log "Sending iBSS..."
        $irecovery -f pwnediBSS.dfu
        sleep 2
        log "Sending iBEC..."
        $irecovery -f $ramdisk_path/iBEC
    elif (( device_proc < 5 )) && [[ $device_pwnrec != 1 ]]; then
        log "Sending iBSS..."
        $irecovery -f $ramdisk_path/iBSS
    fi
    sleep 2
    if [[ $build_id != "7"* && $build_id != "8"* ]]; then
        if [[ $device_proc != 1 ]]; then
            log "Sending iBEC..."
            $irecovery -f $ramdisk_path/iBEC
            if [[ $device_pwnrec == 1 ]]; then
                $irecovery -c "go"
            fi
        fi
    fi
    sleep 3
    checkmode rec
    log "Sending ramdisk..."
    $irecovery -f $ramdisk_path/Ramdisk.dmg
    log "Running ramdisk"
    $irecovery -c "getenv ramdisk-delay"
    $irecovery -c ramdisk
    sleep 2
    log "Sending DeviceTree..."
    $irecovery -f $ramdisk_path/DeviceTree.dec
    log "Running devicetree"
    $irecovery -c devicetree
    log "Sending KernelCache..."
    $irecovery -f $ramdisk_path/Kernelcache.dec
    $irecovery -c bootx
    log "Booting, please wait..."
    sleep 6

    if [[ -n $1 ]]; then
        device_iproxy
    else
        device_iproxy no-logging
    fi
    local found
    log "Waiting for device..."
    print "* You may need to unplug and replug your device."
    local try=0
    while [[ $found != 1 ]]; do
        found=$($ssh -p $ssh_port root@127.0.0.1 "echo 1" 2>/dev/null)
        try=$((try + 1))
        if [[ $try == 10 ]]; then
            error "Unable to connect SSH, please try boot again"
            exit 1
        fi
        sleep 2
    done

    #$ssh -p $ssh_port root@127.0.0.1

    return

}

apply_table() {
    local tbl="$1" out="$2" off hex
    while IFS=' ' read -r off hex; do
        [ -z "$off" ] && continue
        printf '%b' "$(echo "$hex" | sed 's/../\\x&/g')" | dd of="$out" bs=1 seek="$off" conv=notrunc 2>/dev/null
    done < "$tbl"
}

just_boot() {
    local files="../saved/boot"
    local name
    local iv
    local key
    local name1
    local iv1
    local key1
    local path
    if [[ ! -d $files ]]; then
        mkdir -p $files
        log "Building iOS 7.0 11A470a iBSS/iBEC"
        log "Get device fw key"
        device_fw_key_check 11A470a
        if [[ -z $device_fw_key ]]; then
            error "Unable to get device fw key"
            exit 1
        fi
        get_firmware_info 11A470a
        local ipsw_url=$firmware_url
        for getcomp in iBSS iBEC; do

            case $getcomp in
                "iBSS" | "iBEC" ) path="Firmware/dfu/";;
            esac

            name=$(echo $device_fw_key | $jq -j '.keys[] | select(.image == "'$getcomp'") | .filename')
            iv=$(echo $device_fw_key | $jq -j '.keys[] | select(.image == "'$getcomp'") | .iv')
            key=$(echo $device_fw_key | $jq -j '.keys[] | select(.image == "'$getcomp'") | .key')
            log "iv:$iv"
            log "key $key"
            log "name:$name"
            log "Downloading $getcomp"
            log "$dir/pzb" -g "${path}$name" -o "$name" "$ipsw_url"
            "$dir/pzb" -g "${path}$name" -o "$name" "$ipsw_url"
            if [[ ! -f $name ]]; then
                error "Unale to download $getcomp"
                exit
            fi
            log "Patching $getcomp"
            log "$xpwntool $name $getcomp.raw -iv $iv -k $key"
            $xpwntool $name $getcomp.raw -iv $iv -k $key
            if [[ $? == 1 ]]; then
                error "Unale to patch iBSS"
                exit 1
            fi
            case $getcomp in
                "iBSS" )
                log "$iBoot32Patcher iBSS.raw iBSS.patched --rsa"
                $iBoot32Patcher iBSS.raw iBSS.patched --rsa
                log "$img3maker iBSS.patched -t ibss -o iBSS.img3"
                $img3maker -f iBSS.patched -t ibss -o iBSS.img3
                ;;
                "iBEC" )
                log "$iBoot32Patcher iBEC.raw iBEC.patched --rsa --debug -b -v amfi=0xff amfi_get_out_of_my_way=1 cs_enforcement_disable=1 pio-error=0" 
                $iBoot32Patcher iBEC.raw iBEC.patched --rsa --debug -b "-v amfi=0xff amfi_get_out_of_my_way=1 cs_enforcement_disable=1 pio-error=0"
                log "$img3maker iBEC.patched -t ibec -o iBEC.img3"
                $img3maker -f iBEC.patched -t ibec -o iBEC.img3
                ;;
            esac
            if [[ $? == 1 ]]; then
                error "Unale to patch $getcomp"
                exit 1
            fi
        done
        log "Decrypting iPhone5,2 10B350 DeviceTree and kernelcache"
        log "Get device fw key base"
        device_fw_key_check base 10B350
        if [[ -z $device_fw_key_base ]]; then
            error "Unable to get device fw key"
            exit 1
        fi
        get_firmware_info base 10B350
        local ipsw_url1=$firmware_url
        local all_flash="Firmware/all_flash/all_flash.${device_model_base}ap.production"
        for getcomps in DeviceTree Kernelcache; do
            case $getcomps in
                "DeviceTree" ) path="$all_flash/";;
                * ) path="";;
            esac
            name1=$(echo $device_fw_key_base | $jq -j '.keys[] | select(.image == "'$getcomps'") | .filename')
            iv1=$(echo $device_fw_key_base | $jq -j '.keys[] | select(.image == "'$getcomps'") | .iv')
            key1=$(echo $device_fw_key_base | $jq -j '.keys[] | select(.image == "'$getcomps'") | .key')
            log "iv:$iv1"
            log "key $key1"
            log "name:$name1"
            log "Downloading $getcomps"
            "$dir/pzb" -g "${path}$name1" -o "$name1" "$ipsw_url1"
            if [[ ! -f $name1 ]]; then
                error "Unale to download $getcomps"
                exit
            fi
            log "Patching $getcomps"
            case $getcomps in
                "DeviceTree" )
                if [[ $nodriver == "1" ]]; then
                    $xpwntool $name1 DeviceTree.img3 -iv $iv1 -k $key1 -decrypt
                    if [[ $? == 1 ]]; then
                        error "Unale to patch DeviceTree"
                        exit 1
                    fi
                else
                    "$dir/xpwntool" $name1 DeviceTree.dec -iv $iv1 -k $key1 -decrypt
                    if [[ $? == 1 ]]; then
                        error "Unable to decrypt DeviceTree"
                        exit 1
                    fi
                    "$dir/xpwntool" $name1 DeviceTree.dtb -iv $iv1 -k $key1
                    [[ $(stat -f%z DeviceTree.dtb) == 83852 ]] || { error "DeviceTree decrypt failed"; exit 1; }
                    "$dir/dtbpatch" DeviceTree.dtb ../resources/patches/devicetree_${device_model}.dtpatch DeviceTree.patched.dtb
                    if [[ $? != 0 ]] || [[ ! -f DeviceTree.patched.dtb ]]; then
                        error "Unable to patch DeviceTree"
                        exit 1
                    fi
                    "$dir/xpwntool" DeviceTree.patched.dtb DeviceTree.img3 -t DeviceTree.dec
                    log "DeviceTree generated ($(stat -f%z DeviceTree.patched.dtb) bytes)"
                fi
                ;;
                "Kernelcache" )
                $xpwntool $name1 Kernelcache.dec -iv $iv1 -k $key1 -decrypt
                if [[ $nodriver == "1" ]]; then
                    $xpwntool $name1 Kernelcache.raw -iv $iv1 -k $key1
                    while read -r offset expected replacement _; do
                        [[ -z $offset || $offset == \#* ]] && continue
                        actual="$(xxd -p -l 4 -s "$((16#$offset))" "Kernelcache.raw" | tr -d '\n')"
                        [[ $actual == "$expected" ]] || error "Kernel patch signature mismatch at 0x$offset" || exit 1
                        printf '%s' "$replacement" | xxd -r -p | dd of="Kernelcache.raw" bs=1 seek="$((16#$offset))" conv=notrunc 2>/dev/null
                        actual="$(xxd -p -l 4 -s "$((16#$offset))" "Kernelcache.raw" | tr -d '\n')"
                        [[ $actual == "$replacement" ]] || error "Kernel patch write failed at 0x$offset" || exit 1
                    done < "../config/kernelcache-10B350.tsv"
                    $xpwntool Kernelcache.raw Kernelcache.img3 -t Kernelcache.dec
                else
                    local out="../saved/kernelcache_n48.macho"
                    log "Decrypting 10B350 kernelcache"
                    "$dir/xpwntool" $name1 n42-kernel.macho -iv $iv1 -k $key1
                    [[ $(stat -f%z n42-kernel.macho) == 14204928 ]] || { error "Kernelcache decrypt failed"; exit 1; }
                    cp n42-kernel.macho "$out"
                    apply_table ../resources/patches/kernelcache_${device_model}.patches "$out"
                    apply_table ../resources/patches/kernelcache_${device_model}.repl "$out"
                    cat ../resources/patches/kernelcache_${device_model}.tail >> "$out"
                    [[ $(stat -f%z "$out") == 14381056 ]] || { error "Kernelcache size mismatch"; exit 1; }
                    log "Kernelcache generated: $out"
                    $xpwntool $out Kernelcache.img3 -t Kernelcache.dec
                fi
                ;;
            esac
        done
        if [[ -f "iBSS.img3" ]] && [[ -f "iBEC.img3" ]] && [[ -f "DeviceTree.img3" ]] && [[ -f "Kernelcache.img3" ]]; then
            mv iBSS.img3 iBEC.img3 DeviceTree.img3 Kernelcache.img3 "$files"
        fi
        
    elif [[ ! -f "$files/iBSS.img3" ]] || [[ ! -f "$files/iBEC.img3" ]] || [[ ! -f "$files/DeviceTree.img3" ]] || [[ ! -f "$files/Kernelcache.img3" ]]; then
        rm -r $files
        just_boot
        return
    fi
    
    yesno "Do you want to boot now?"
    if [[ $? != "1" ]]; then
        return
    fi
    checkmode DFU
    device_pwn
    log "Sending iBSS..."
    log "$irecovery -f $files/iBSS.img3"
    $irecovery -f $files/iBSS.img3
    log "Sending iBEC..."
    log "$irecovery -f $files/iBEC.img3"
    $irecovery -f $files/iBEC.img3
    sleep 3
    checkmode rec 20
    if [[ $nodriver == "1" ]]; then
        log "$irecovery -c setenv boot-args -v amfi=0xff amfi_get_out_of_my_way=1 cs_enforcement_disable=1 pio-error=0"
        $irecovery -c "setenv boot-args -v amfi=0xff amfi_get_out_of_my_way=1 cs_enforcement_disable=1 pio-error=0"
    else
        log "$irecovery -c setenv boot-args rd=disk0s1s1 -v debug=0x2014e wdt=-1 pio-error=0 amfi=0xff cs_enforcement_disable=1"
        $irecovery -c "setenv boot-args rd=disk0s1s1 -v debug=0x2014e wdt=-1 pio-error=0 amfi=0xff cs_enforcement_disable=1"
    fi
    sleep 2
    log "Sending DeviceTree..."
    log "$irecovery -f $files/DeviceTree.img3"
    $irecovery -f $files/DeviceTree.img3
    log "Running devicetree"
    log "$irecovery -c devicetree"
    $irecovery -c devicetree
    log "Sending KernelCache..."
    log "$irecovery -f $files/Kernelcache.img3"
    $irecovery -f $files/Kernelcache.img3
    log "$irecovery -c bootx"
    $irecovery -c bootx
    log "Booting, please wait..."
    sleep 6
    log "Done,device is booting now"
    pause
}



clean() {
    exit_message
    kill $httpserver_pid $iproxy_pid $anisette_pid $sshfs_pid 2>/dev/null
    popd &>/dev/null
    rm -rf "$(dirname "$0")/tmp$$/"* "$(dirname "$0")/iP"*/ "$(dirname "$0")/tmp$$/" 2>/dev/null
    rm -rf $(dirname "$0")/tmp*
    if [[ $platform == "macos" && $(ls "$(dirname "$0")" | grep -v tmp$$ | grep -c tmp) == 0 &&
          $no_finder != 1 ]]; then
        killall -CONT AMPDevicesAgent AMPDeviceDiscoveryAgent MobileDeviceUpdater
    fi
}

exit_message() {
    print "* Save the terminal output now if needed. (macOS: Cmd+S, Linux: Ctrl+Shift+S)"
    print "*Platform:$platform_message*"
    pause "Press Enter to exit"
}


function select_option() {
    if [[ $menu_old == 1 ]]; then
        select opt in "$@"; do
            selected=$((REPLY-1))
            break
        done
        return $selected
    fi

    # clear input buffer to prevent error
    if (( bash_ver > 3 )); then
        while read -s -t 0.01 -n 1; do :; done
    else
        local old=$(stty -g)
        stty -icanon -echo min 0 time 1
        dd bs=1 count=1000 if=/dev/tty of=/dev/null 2>/dev/null
        stty "$old"
    fi

    # little helpers for terminal print control and key input
    ESC=$( printf "\033")
    cursor_blink_on()  { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to()        { printf "$ESC[$1;${2:-1}H"; }
    print_option()     { printf "   $1  "; }
    print_selected()   { printf " ->$ESC[7m $1 $ESC[27m"; }
    get_cursor_row()   { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }
    key_input()        { read -s -n3 key 2>/dev/null >&2
                         if [[ $key = $ESC[A ]]; then echo up;    fi
                         if [[ $key = $ESC[B ]]; then echo down;  fi
                         if [[ $key = ""     ]]; then echo enter; fi; }

    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done

    # determine current screen position for overwriting the options
    local lastrow=`get_cursor_row`
    local startrow=$(($lastrow - $#))

    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off

    local selected=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done

        # user key control
        case `key_input` in
            enter) break;;
            up)    ((selected--));
                   if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
            down)  ((selected++));
                   if [ $selected -ge $# ]; then selected=0; fi;;
        esac
    done

    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on

    return $selected
}

function select_opt {
    select_option "$@" 1>&2
    local result=$?
    echo $result
    return $result
}

function yesno() {
    local msg="Do you want to continue?"
    if [[ -n $1 ]]; then
        msg="$1"
    fi
    if [[ $2 == 1 ]]; then
        msg+=" (Y/n): "
    else
        msg+=" (y/N): "
    fi
    local yesno=("No" "Yes") # default is "no" by default
    if [[ $2 == 1 ]]; then # default is "yes" if $2 is set to 1
        yesno=("Yes" "No")
    fi
    input "$msg"
    select_option "${yesno[@]}"
    local res=$?
    if [[ $2 == 1 ]]; then
        [[ $res == 0 ]] && return 1 || return 0
    fi
    return $res
}

trap clean EXIT
trap "exit 1" INT TERM
mkdir "$(dirname "$0")/tmp$$"
pushd "$(dirname "$0")/tmp$$" >/dev/null
mkdir ../saved 2>/dev/null

main() {
    local mode
    check_sudo
    oscheck
    set_ssh_config
    set_path
    for i in "$@"; do
        case "$i" in
            install ) mode="install";;
            boot ) mode="boot";;
            --no-device ) device_argmode="none";;
            --no-drivers ) nodriver=1;;
            --skip-partition ) skip_partition=1;;
            * ) warn "Unknown command,use"./install.sh help" to use right command"; exit;;
        esac
    done

    main_mode=$mode

    if [[ $device_argmode != "none" ]]; then
        checkmode DFUall
    fi

    device_info
    main_menu
}

for i in "$@"; do
    case "$i" in
        --debug )
            debug_mode=1
            menu_old=1
            set -x
        ;;
    esac
done


main $@

popd >/dev/null
