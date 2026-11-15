#!/bin/sh
# MiniUI.pak

# recover from readonly SD card -------------------------------
touch /mnt/writetest
sync
if [ -f /mnt/writetest ] ; then
	rm -f /mnt/writetest
else
	e2fsck -p /dev/root > /mnt/SDCARD/RootRecovery.txt
	reboot
fi

#######################################

export PLATFORM="trimuismart"
export SDCARD_PATH="/mnt/SDCARD"
export BIOS_PATH="$SDCARD_PATH/Bios"
export SAVES_PATH="$SDCARD_PATH/Saves"
export SYSTEM_PATH="$SDCARD_PATH/.system/$PLATFORM"
export CORES_PATH="$SYSTEM_PATH/cores"
export USERDATA_PATH="$SDCARD_PATH/.userdata/$PLATFORM"
export SHARED_USERDATA_PATH="$SDCARD_PATH/.userdata/shared"
export LOGS_PATH="$USERDATA_PATH/logs"
export DATETIME_PATH="$SHARED_USERDATA_PATH/datetime.txt"

# Constrain SDL's ALSA buffer. By default SDL 1.2 lets ALSA pick the buffer
# size, which over bluealsa comes out around 24000 frames (~500ms of audio
# latency). With this set, SDL calls snd_pcm_hw_params_set_buffer_size_near()
# so the buffer tracks the requested period size instead.
export SDL_AUDIO_ALSA_SET_BUFFER_SIZE=1

mkdir -p "$USERDATA_PATH"
mkdir -p "$LOGS_PATH"
mkdir -p "$SHARED_USERDATA_PATH/.minui"

#######################################

echo A,B,X,Y,L,R > /sys/module/gpio_keys_polled/parameters/button_config

echo userspace > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
CPU_PATH=/sys/devices/system/cpu/cpu0/cpufreq/scaling_setspeed
CPU_SPEED_PERF=1536000
echo $CPU_SPEED_PERF > $CPU_PATH

#######################################

export LD_LIBRARY_PATH=$SYSTEM_PATH/lib:/usr/trimui/lib:$LD_LIBRARY_PATH
export PATH=$SYSTEM_PATH/bin:/usr/trimui/bin:$PATH

leds_off

killall -9 MtpDaemon
killall -9 wpa_supplicant
ifconfig wlan0 down

keymon.elf &

#######################################

# init datetime
if [ -f "$DATETIME_PATH" ]; then
	DATETIME=`cat "$DATETIME_PATH"`
	date +'%F %T' -s "$DATETIME"
	DATETIME=`date +'%s'`
	date -u -s "@$DATETIME"
fi

#######################################

# Bluetooth: while Bluetooth.pak is on the card, replace the stock BlueZ 5.54 /
# bluealsa with the pak's BlueZ 5.66 + bluez-alsa v4 (btstack/start-stack.sh;
# runs in the background because it waits for dbus). Once the pak is deleted,
# put back the rootfs files the stack changed, before the stock BT service
# starts, so the factory driver comes back as shipped.
AUTO_PATH=$USERDATA_PATH/auto.sh
BTSTACK_PATH=$SDCARD_PATH/Tools/$PLATFORM/Bluetooth.pak/btstack
# cards set up by hand started a card-root stack from auto.sh; drop that hook
if [ -f "$AUTO_PATH" ] && grep -q '# BTSTACK-BEGIN' "$AUTO_PATH"; then
	sed -i '/# BTSTACK-BEGIN/,/# BTSTACK-END/d' "$AUTO_PATH"
fi
# test builds shipped the stack in .system; updating never deletes files, so drop it
[ -d "$SYSTEM_PATH/btstack" ] && rm -rf "$SYSTEM_PATH/btstack"
if [ -f "$BTSTACK_PATH/start-stack.sh" ]; then
	sh "$BTSTACK_PATH/start-stack.sh" &
else
	for f in /etc/asound.conf /usr/share/alsa/alsa.conf.d/20-bluealsa.conf; do
		if [ -f "$f.stock" ] && grep -q 'btstack/libasound_module' "$f" 2>/dev/null; then
			cp "$f.stock" "$f"
		fi
	done
	f=/etc/dbus-1/system.d/bluealsa.conf
	if [ -f "$f.stock" ] && grep -q own_prefix "$f" 2>/dev/null; then
		cp "$f.stock" "$f"
	fi
	sync
fi

#######################################

if [ -f "$AUTO_PATH" ]; then
	"$AUTO_PATH"
fi

cd $(dirname "$0")

#######################################

EXEC_PATH="/tmp/minui_exec"
NEXT_PATH="/tmp/next"
touch "$EXEC_PATH"  && sync
while [ -f $EXEC_PATH ]; do
	minui.elf &> $LOGS_PATH/minui.txt
	echo $CPU_SPEED_PERF > $CPU_PATH
	echo `date +'%F %T'` > "$DATETIME_PATH"
	sync
	
	if [ -f $NEXT_PATH ]; then
		CMD=`cat $NEXT_PATH`
		eval $CMD
		rm -f $NEXT_PATH
		echo $CPU_SPEED_PERF > $CPU_PATH
		echo `date +'%F %T'` > "$DATETIME_PATH"
		sync
	fi
	
	# physical powerswitch, enter low power mode
	if [ -f "/tmp/poweroff" ]; then
		rm -f "/tmp/poweroff"
		killall keymon.elf
		shutdown
		echo 60000 > $CPU_PATH
		LED_ON=true
		while :; do
			if $LED_ON; then
				LED_ON=false
				leds_off
			else
				LED_ON=true
				leds_on
			fi
			sleep 0.5
		done
	fi
done

poweroff # just in case
