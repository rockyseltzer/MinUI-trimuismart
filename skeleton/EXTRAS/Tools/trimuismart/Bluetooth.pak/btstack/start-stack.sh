#!/bin/sh
# Start the modern BT stack (BlueZ 5.66 + bluez-alsa v4).
# Started in the background by MinUI.pak/launch.sh at boot (only while
# Bluetooth.pak/btstack is on the card), which fires before dbus and before the
# stock bluetoothd/bluealsa - so we wait for dbus, then replace them.
# Every rootfs file changed here gets a .stock backup first; MinUI.pak restores
# them at boot once Bluetooth.pak is deleted. Logs go to LOGS_PATH.
BT="$(cd "$(dirname "$0")" && pwd)"
LOG="${LOGS_PATH:-/tmp}"
mkdir -p "$LOG"
[ -d "$BT" ] || exit 0
chmod +x "$BT"/bluealsa4 "$BT"/bluealsa-cli "$BT"/bluetoothd 2>/dev/null

# 1. wait for the dbus system socket (up to 60s)
i=0
while [ ! -S /var/run/dbus/system_bus_socket ] && [ "$i" -lt 60 ]; do
    sleep 1; i=$((i + 1))
done
[ -S /var/run/dbus/system_bus_socket ] || { echo "$(date): no dbus socket" >> "$LOG/btstack-boot.txt"; exit 1; }
sleep 5   # let the stock daemons finish starting so we can replace them

# 2. v4 plugin definitions (file must exist - blanking it breaks ALSA parsing)
A4=/usr/share/alsa/alsa.conf.d/20-bluealsa.conf
[ -f "$A4.stock" ] || cp "$A4" "$A4.stock" 2>/dev/null
cat > "$A4" << V4
pcm_type.bluealsa { lib "$BT/libasound_module_pcm_bluealsa.so" }
ctl_type.bluealsa { lib "$BT/libasound_module_ctl_bluealsa.so" }
V4

DP=/etc/dbus-1/system.d/bluealsa.conf
[ -f "$DP" ] && [ ! -f "$DP.stock" ] && ! grep -q own_prefix "$DP" && cp "$DP" "$DP.stock"
cp "$BT/bluealsa-dbus.conf" "$DP" 2>/dev/null

# 2a. an asound.conf written by an older install may point at a stack location
# that no longer exists (e.g. /mnt/SDCARD/btstack); repoint it here
if grep -q 'btstack/libasound_module' /etc/asound.conf 2>/dev/null && ! grep -q "$BT/libasound_module" /etc/asound.conf; then
    sed -i "s#\"[^\"]*/btstack/libasound_module#\"$BT/libasound_module#g" /etc/asound.conf
fi
kill -HUP "$(pidof dbus-daemon)" 2>/dev/null

# 2c. Stop the stock BT service outright rather than racing it.
# S96bluetoothservice starts stock bluetoothd + bluealsa; it can fire after us.
[ -x /etc/init.d/bluetoothservice ] && /etc/init.d/bluetoothservice stop >/dev/null 2>&1

# 3. replace both daemons
killall bluealsa 2>/dev/null
killall bluetoothd 2>/dev/null
sleep 3

# 2b. BlueZ 5.54 stored device entries as files; 5.66 needs directories.
# A leftover file blocks the store and silently discards every pairing.
for _a in /etc/lib/bluetooth/*; do
    [ -d "$_a" ] || continue
    for _e in "$_a"/*; do
        _b="$(basename "$_e")"
        case "$_b" in cache|settings|*.conf) continue ;; esac
        [ -f "$_e" ] && [ ! -d "$_e" ] && rm -f "$_e"
    done
done

"$BT/bluetoothd" -n > "$LOG/btstack-bluetoothd.txt" 2>&1 &
sleep 5
# The S3 is a single-core A7; SBC encoding competes with the emulator, so keep
# the encoder as cheap as possible:
#   --sbc-quality=low   smallest bitpool
#   --a2dp-force-mono   one channel instead of two
# Note: no --a2dp-force-audio-cd. Cores output 48kHz natively and forcing 44.1k
# makes SDL resample every sample, which costs CPU and adds artefacts.
LD_LIBRARY_PATH="$BT" nice -n -15 "$BT/bluealsa4" -p a2dp-source \
    --sbc-quality=low --a2dp-force-mono > "$LOG/btstack-bluealsa.txt" 2>&1 &
sleep 3

# 3b. mirror the hardware volume buttons onto the BT stream
[ -x "$BT/bt-volume-sync.sh" ] && "$BT/bt-volume-sync.sh" >/dev/null 2>&1 &

# 4. the stock init may restart bluealsa after us - keep it dead for a while
( n=0
  while [ "$n" -lt 30 ]; do
      pidof bluealsa >/dev/null && killall bluealsa 2>/dev/null
      pidof bluetoothd >/dev/null || "$BT/bluetoothd" -n >> "$LOG/btstack-bluetoothd.txt" 2>&1 &
      sleep 2; n=$((n + 1))
  done ) &

echo "$(date): bluetoothd=$(pidof bluetoothd) bluealsa4=$(pidof bluealsa4) stock_bluealsa=$(pidof bluealsa)" >> "$LOG/btstack-boot.txt"
