#!/bin/sh
# Bluetooth.pak — scan, pair, connect, and route audio over Bluetooth.
#
# The RTL8723D combo chip's BT side is brought up by the kernel at boot (H5 on
# ttyS1), so hci0 already exists; we only manage bluetoothd/power, pairing, and
# audio routing.
#
# Audio routing works by pointing ALSA's default PCM at bluez-alsa v4, which
# MinUI starts at boot from this pak's btstack/ (start-stack.sh). The
# stock /etc/asound.conf is preserved as /etc/asound.conf.stock and restored
# when BT audio is disabled. Turning BT audio on drops WiFi (shared antenna);
# turning it off brings WiFi back if it was connected.
#
# NOTE: A2DP adds latency (roughly 200ms even with a constrained buffer). Fine
# for music, menus, and slower games; not recommended for twitchy action games.

set -x
PAK_DIR="$(cd "$(dirname "$0")" && pwd)"  # absolute: BTSTACK is written into asound.conf
PAK_NAME="$(basename "$PAK_DIR")"
PAK_NAME="${PAK_NAME%.*}"

rm -f "$LOGS_PATH/$PAK_NAME.txt"
exec >>"$LOGS_PATH/$PAK_NAME.txt"
exec 2>&1

cd "$PAK_DIR" || exit 1
export PATH="$PAK_DIR/bin/arm:$PAK_DIR/bin/$PLATFORM:$PAK_DIR/bin:$PATH"

ASOUND=/etc/asound.conf
ASOUND_STOCK=/etc/asound.conf.stock
WIFI_DROPPED=/tmp/bluetooth-pak-dropped-wifi
SYSTEM_JSON=/mnt/UDISK/system.json

###############################################################################
# ui helpers
###############################################################################

kill_presenter() {
    i=0
    while pgrep -f minui-presenter >/dev/null 2>&1 && [ "$i" -lt 10 ]; do
        killall minui-presenter >/dev/null 2>&1 || true
        killall -9 minui-presenter >/dev/null 2>&1 || true
        sleep 0.1
        i=$((i + 1))
    done
}

show_busy() {
    kill_presenter
    minui-presenter --message "$1" --timeout -1 &
    sleep 0.2
}

show_message() {
    kill_presenter
    minui-presenter --message "$1" --timeout "${2:-2}"
}

###############################################################################
# bluetooth state
###############################################################################

bt_enabled() {
    pidof bluetoothd >/dev/null 2>&1 || return 1
    hciconfig hci0 2>/dev/null | grep -q "UP RUNNING" || return 1
    return 0
}

bt_on() {
    hciconfig hci0 up 2>/dev/null
    if ! pidof bluetoothd >/dev/null 2>&1; then
        bluetoothd -n >/dev/null 2>&1 &
        sleep 2
    fi
    ( echo "power on"; sleep 1; echo "agent on"; sleep 1; echo "default-agent"; sleep 1; echo "quit" ) | bluetoothctl >/dev/null 2>&1
    set_system_flag 1
    bt_enabled
}

bt_off() {
    audio_bt_off
    ( echo "power off"; sleep 1; echo "quit" ) | bluetoothctl >/dev/null 2>&1
    hciconfig hci0 down 2>/dev/null
    set_system_flag 0
    return 0
}

set_system_flag() {
    [ -f "$SYSTEM_JSON" ] || return 0
    jq ".bluetooth = $1" "$SYSTEM_JSON" > /tmp/system.json.tmp 2>/dev/null && \
        mv /tmp/system.json.tmp "$SYSTEM_JSON"
    return 0
}

connected_mac() {
    bluetoothctl devices | grep '^Device ' | awk '{print $2}' | while read -r mac; do
        if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
            echo "$mac"
            return
        fi
    done
}

device_name() {
    bluetoothctl info "$1" 2>/dev/null | grep '^\s*Name:' | sed 's/.*Name: //'
}

###############################################################################
# audio routing
###############################################################################

audio_bt_enabled() {
    grep -q "type bluealsa" "$ASOUND" 2>/dev/null
}

# usage: audio_bt_on [MAC]
# With no argument, routes to whichever device is currently connected. Callers
# that have just connected a specific device should pass its MAC explicitly,
# since connected_mac() is ambiguous when more than one device is connected.
BTSTACK="$PAK_DIR/btstack"  # started at boot by MinUI.pak while it exists

# Hand volume control to the device via AVRCP and set it to full.
# Without this, AirPods render the stream at their own (near-zero) volume.
bt_set_volume() {
    [ -x "$BTSTACK/bluealsa-cli" ] || return 0
    _m="$(echo "$1" | tr ':' '_')"
    _i=0
    while [ "$_i" -lt 6 ]; do
        _pcm="$(LD_LIBRARY_PATH="$BTSTACK" "$BTSTACK/bluealsa-cli" list-pcms 2>/dev/null | grep "$_m" | grep sink | head -1)"
        [ -n "$_pcm" ] && break
        sleep 1; _i=$((_i + 1))
    done
    [ -z "$_pcm" ] && return 1
    LD_LIBRARY_PATH="$BTSTACK" "$BTSTACK/bluealsa-cli" soft-volume "$_pcm" n >/dev/null 2>&1
    # Match the device's current volume rather than jumping to maximum.
    # bt-volume-sync.sh keeps them in step from here on.
    _hw="$(amixer -c 0 sget 'Lineout volume' 2>/dev/null | grep -o '\[[0-9]*%\]' | head -1 | tr -d '[]%')"
    [ -z "$_hw" ] && _hw=50
    _v=$(( _hw * 127 / 100 ))
    [ "$_v" -lt 1 ] && _v=1
    [ "$_v" -gt 127 ] && _v=127
    LD_LIBRARY_PATH="$BTSTACK" "$BTSTACK/bluealsa-cli" volume "$_pcm" "$_v" >/dev/null 2>&1
    return 0
}

audio_bt_on() {
    mac="$1"
    [ -z "$mac" ] && mac="$(connected_mac)"
    if [ -z "$mac" ]; then
        show_message "Connect a device first" 2
        return 1
    fi

    [ -f "$ASOUND_STOCK" ] || cp "$ASOUND" "$ASOUND_STOCK"
    cat > "$ASOUND" << CONFEOF
# --- bluetooth audio (written by Bluetooth.pak, bluez-alsa v4) ---
pcm_type.bluealsa { lib "$BTSTACK/libasound_module_pcm_bluealsa.so" }
ctl_type.bluealsa { lib "$BTSTACK/libasound_module_ctl_bluealsa.so" }
pcm.!default {
    type plug
    slave.pcm {
        type bluealsa
        service "org.bluealsa"
        device "$mac"
        profile "a2dp"
    }
}
CONFEOF
    bt_set_volume "$mac"

    # The RTL8723D shares one antenna between WiFi and Bluetooth, so an active
    # WiFi link steals airtime from A2DP and causes dropouts. Drop WiFi while
    # Bluetooth audio is in use; audio_bt_off brings it back (wifi_restore).
    if pidof wpa_supplicant >/dev/null 2>&1; then
        touch "$WIFI_DROPPED"
        killall wpa_supplicant 2>/dev/null
        killall udhcpc 2>/dev/null
        ifconfig wlan0 down 2>/dev/null
    fi

    echo "1" > "$AUDIO_FLAG" 2>/dev/null
    return 0
}

audio_bt_off() {
    if [ -f "$ASOUND_STOCK" ]; then
        cp "$ASOUND_STOCK" "$ASOUND"
        sync
    fi
    wifi_restore
    return 0
}

# Bring WiFi back if audio_bt_on dropped it. The driver stays loaded, so this
# is Wifi.pak's trimuismart service-on without the SDIO power-cycle (which could
# disturb the BT half of the same chip while a device is still connected).
# The marker lives in /tmp: after a reboot Wifi.pak's on-boot handles WiFi.
wifi_restore() {
    [ -f "$WIFI_DROPPED" ] || return 0
    rm -f "$WIFI_DROPPED"
    (
        ifconfig wlan0 up
        mkdir -p /etc/wifi/sockets
        wpa_supplicant -B -D nl80211 -iwlan0 -c /etc/wifi/wpa_supplicant.conf -O /etc/wifi/sockets &&
            udhcpc -i wlan0 -s /usr/share/udhcpc/default.script -b -q
    ) >/dev/null 2>&1 &
    return 0
}

###############################################################################
# screens
###############################################################################

main_screen() {
    list=/tmp/minui-list
    rm -f "$list" /tmp/minui-output

    mac="$(connected_mac)"
    if [ -n "$mac" ]; then
        cp "$PAK_DIR/res/settings.connected.json" "$list"
        name="$(device_name "$mac")"
        [ -z "$name" ] && name="$mac"
        sed -i "s/DEVICE_NAME/$name/" "$list"
    else
        cp "$PAK_DIR/res/settings.json" "$list"
    fi

    bt_enabled && sed -i "s/IS_ENABLED/1/" "$list" || sed -i "s/IS_ENABLED/0/" "$list"
    audio_bt_enabled && sed -i "s/IS_AUDIO_BT/1/" "$list" || sed -i "s/IS_AUDIO_BT/0/" "$list"

    kill_presenter
    minui-list --disable-auto-sleep --item-key settings --file "$list" \
        --format json --cancel-text "EXIT" --title "Bluetooth" \
        --write-location /tmp/minui-output --write-value state
}

scan_screen() {
    list=/tmp/minui-list
    rm -f "$list" /tmp/minui-output
    : > "$list"

    show_busy "Scanning for devices"
    ( echo "power on"; sleep 1; echo "scan on"; sleep 15; echo "scan off"; echo "quit" ) | bluetoothctl >/dev/null 2>&1
    bluetoothctl devices | grep '^Device ' | cut -d' ' -f3- | sort -u > "$list"

    if [ ! -s "$list" ]; then
        show_message "No devices found" 2
        return 1
    fi

    kill_presenter
    minui-list --disable-auto-sleep --file "$list" --format text \
        --confirm-text "CONNECT" --title "Bluetooth Devices" \
        --write-location /tmp/minui-output
}

forget_screen() {
    list=/tmp/minui-list
    rm -f "$list" /tmp/minui-output
    bluetoothctl paired-devices | grep '^Device ' | cut -d' ' -f3- | sort -u > "$list"

    if [ ! -s "$list" ]; then
        show_message "No paired devices" 2
        return 1
    fi

    kill_presenter
    minui-list --disable-auto-sleep --file "$list" --format text \
        --confirm-text "FORGET" --title "Paired Devices" \
        --write-location /tmp/minui-output
}

mac_for_name() {
    bluetoothctl devices | grep '^Device ' | while read -r _ mac name; do
        if [ "$name" = "$1" ]; then
            echo "$mac"
            return
        fi
    done
}

connect_device() {
    name="$1"
    mac="$(mac_for_name "$name")"
    if [ -z "$mac" ]; then
        show_message "Could not resolve device" 2
        return 1
    fi

    show_busy "Connecting to
$name"
    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes"; then
        # already paired - re-pairing drops AirPods, so only connect
        (
            echo "power on"; sleep 1
            echo "connect $mac"; sleep 10
            echo "quit"
        ) | bluetoothctl >/dev/null 2>&1
    else
        # Not paired yet. Pair ONLY - pairing and connecting in one
        # bluetoothctl session makes AirPods drop the link.
        show_busy "Pairing with
$name"
        (
            echo "power on"; sleep 1
            echo "agent on"; sleep 1
            echo "default-agent"; sleep 1
            echo "pair $mac"; sleep 12
            echo "trust $mac"; sleep 3
            echo "quit"
        ) | bluetoothctl >/dev/null 2>&1

        if bluetoothctl info "$mac" 2>/dev/null | grep -q "Paired: yes"; then
            show_message "Paired with
$name

Choose Connect again" 4
        else
            show_message "Could not pair with
$name" 3
        fi
        return 0
    fi
    bt_set_volume "$mac"

    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
        # if BT audio is on, repoint it at the device we just connected
        if audio_bt_enabled; then
            audio_bt_on "$mac"
        fi
        show_message "Connected to
$name" 2
        return 0
    fi

    show_message "Failed to connect to
$name" 2
    return 1
}

forget_device() {
    name="$1"
    mac="$(mac_for_name "$name")"
    [ -z "$mac" ] && return 1
    ( echo "remove $mac"; sleep 2; echo "quit" ) | bluetoothctl >/dev/null 2>&1
    show_message "Forgot
$name" 2
    return 0
}

###############################################################################

cleanup() {
    rm -f /tmp/stay_awake /tmp/minui-list /tmp/minui-output
    kill_presenter
}

main() {
    echo "1" >/tmp/stay_awake
    trap cleanup EXIT INT TERM HUP QUIT

    for b in minui-list minui-presenter jq; do
        if ! command -v "$b" >/dev/null 2>&1; then
            show_message "$b not found" 2
            return 1
        fi
    done

    while true; do
        main_screen
        [ $? -ne 0 ] && break

        out="$(cat /tmp/minui-output)"
        idx="$(echo "$out" | jq -r '.selected')"
        sel="$(echo "$out" | jq -r ".settings[$idx].name")"

        case "$sel" in
        "Enable"|"Audio to Bluetooth")
            # Enable
            o="$(echo "$out" | jq -r ".settings[0].selected")"
            v="$(echo "$out" | jq -r ".settings[0].options[$o]")"
            if [ "$v" = "On" ]; then
                if ! bt_enabled; then
                    show_busy "Enabling Bluetooth"
                    bt_on || show_message "Failed to enable Bluetooth" 2
                fi
            else
                if bt_enabled; then
                    show_busy "Disabling Bluetooth"
                    bt_off
                fi
            fi

            # Audio to Bluetooth
            o="$(echo "$out" | jq -r ".settings[1].selected")"
            v="$(echo "$out" | jq -r ".settings[1].options[$o]")"
            if [ "$v" = "On" ]; then
                audio_bt_enabled || { show_busy "Routing audio to Bluetooth"; audio_bt_on; }
            else
                audio_bt_enabled && { show_busy "Routing audio to speaker"; audio_bt_off; }
            fi
            kill_presenter
            ;;
        "Connect a device")
            if ! bt_enabled; then
                show_busy "Enabling Bluetooth"
                bt_on || { show_message "Failed to enable Bluetooth" 2; continue; }
            fi
            if scan_screen; then
                name="$(cat /tmp/minui-output)"
                [ -n "$name" ] && connect_device "$name"
            fi
            kill_presenter
            ;;
        "Forget a device")
            if forget_screen; then
                name="$(cat /tmp/minui-output)"
                [ -n "$name" ] && forget_device "$name"
            fi
            kill_presenter
            ;;
        esac
    done
}

main "$@"
