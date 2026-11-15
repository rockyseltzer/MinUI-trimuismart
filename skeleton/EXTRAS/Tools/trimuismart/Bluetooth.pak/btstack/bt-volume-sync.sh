#!/bin/sh
# Mirror MinUI's hardware volume onto the Bluetooth stream.
#
# MinUI's libmsettings.so drives the codec's 'Lineout volume' control directly,
# so the volume buttons never reach a Bluetooth sink. That control still tracks
# the buttons while BT audio is active, so we poll it and push the same level to
# the bluealsa PCM via AVRCP.
BT="$(cd "$(dirname "$0")" && pwd)"
last=""
while :; do
    pidof bluealsa4 >/dev/null || { sleep 5; continue; }
    pcm=$("$BT/bluealsa-cli" list-pcms 2>/dev/null | grep sink | head -1)
    [ -z "$pcm" ] && { sleep 3; last=""; continue; }

    # hardware volume as a percentage
    hw=$(amixer -c 0 sget 'Lineout volume' 2>/dev/null | grep -o '\[[0-9]*%\]' | head -1 | tr -d '[]%')
    [ -z "$hw" ] && { sleep 2; continue; }

    if [ "$hw" != "$last" ]; then
        bt=$(( hw * 127 / 100 ))
        [ "$bt" -gt 127 ] && bt=127
        [ "$bt" -lt 0 ] && bt=0
        LD_LIBRARY_PATH="$BT" "$BT/bluealsa-cli" volume "$pcm" "$bt" >/dev/null 2>&1
        last="$hw"
    fi
    sleep 1
done
