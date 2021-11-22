function extension_prepare_config__prepare_vlc_remote() {
	display_alert "Adding VLC remote" "${EXTENSION}" "info"

	# DISABLED: we use PulseAudio, but alsa-utils is essential for startup scrips and mixer fixups
	# local PULSEAUDIO_PACKAGES="pulseaudio pavucontrol pulseaudio-module-bluetooth pulseaudio-module-zeroconf pulseaudio-utils"

	local VLC_PACKAGES="vlc vlc-plugin-access-extra xauth avahi-daemon libnss-mdns" # Disabled:  ${PULSEAUDIO_PACKAGES}
	local EXTRA_PACKAGES="cloud-initramfs-growroot bluez"                           # this will grow root partition during initrd before mounting it

	export PACKAGE_LIST="${PACKAGE_LIST} ${VLC_PACKAGES} ${EXTRA_PACKAGES}" # To cached rootfs.

	remove_packages_everywhere unattended-upgrades # really not the best place to decide this

	export EXTRA_BSP_NAME="${EXTRA_BSP_NAME}-vlc" # Unique bsp name for this extension, so things don't get mixed up later

	# hack: Armbian param parsing eats up this, just have a hardcoded list for now
	export VLC_WANTED_DEVICES="surround71:CARD=ICUSBAUDIO7D,front:CARD=CODEC"

	declare WANTED_DEVICES_LIST="" WANTED_DEVICE=""
	WANTED_DEVICES_LIST="$(echo -n "${VLC_WANTED_DEVICES}" | tr "," " ")"
	display_alert "Early VLC wanted devices:" "${WANTED_DEVICES_LIST}" "warn"
	for WANTED_DEVICE in ${WANTED_DEVICES_LIST}; do
		display_alert "Early VLC wanted device:" "${WANTED_DEVICE}" "warn"
	done
}

# Add vlc user, member of video audio etc groups.
# Add vlc user to pulse-access group for pulseaudio access.
# Setup systemd unit for cvlc

function pre_customize_image__060_vlc_service() {
	display_alert "Adding VLC user and group" "${EXTENSION}" "info"

	chroot_sdcard addgroup --quiet "vlc"
	chroot_sdcard adduser --quiet --gecos "VLC" --disabled-password --ingroup "vlc" --shell /bin/bash "vlc"
	chroot_sdcard adduser "vlc" "video"
	chroot_sdcard adduser "vlc" "audio"
	# Disabled: chroot_sdcard adduser "vlc" "pulse-access"

	declare WANTED_DEVICES_LIST="" WANTED_DEVICE=""
	WANTED_DEVICES_LIST="$(echo -n "${VLC_WANTED_DEVICES}" | tr "," " ")"
	display_alert "VLC wanted devices:" "${WANTED_DEVICES_LIST}" "warn"
	for WANTED_DEVICE in ${WANTED_DEVICES_LIST}; do
		display_alert "VLC wanted device:" "${WANTED_DEVICE}" "warn"
	done

	# Write launcher script. This finds an appropriate ALSA device and launches VLC, or dies. Will be restarted by systemd.
	cat <<- EOD > "${SDCARD}/usr/local/sbin/vlc-alsa-launcher.sh"
		#! /bin/bash

		set -x

		echo "Listing all ALSA devices..."
		aplay -L

		declare WANTED_DEVICE="" VLC_ALSA_DEVICE=""
		for WANTED_DEVICE in ${WANTED_DEVICES_LIST}; do
			echo "Looking for ALSA device '\${WANTED_DEVICE}'..."
			aplay -L | grep -v "^\ " | grep "^\${WANTED_DEVICE}"
			VLC_ALSA_DEVICE="\$(aplay -L | grep -v "^\ " | grep "^\${WANTED_DEVICE}")"

			if [[ "x\${VLC_ALSA_DEVICE}x" != "xx" ]]; then
				echo "Found ALSA device: '\${VLC_ALSA_DEVICE}'"
				break
			fi
		done

		if [[ "x\${VLC_ALSA_DEVICE}x" != "xx" ]]; then
			echo "Using final ALSA device: '\${VLC_ALSA_DEVICE}'"
			exec cvlc --alsa-audio-channels 4967 --alsa-audio-device "\${VLC_ALSA_DEVICE}" --http-password "vlcremote" --no-metadata-network-access --no-auto-preparse --intf http --no-dbus --no-daemon --verbose 2 ${VLC_MEDIA_START_PLAYLIST}
		else
			echo "Could not find ALSA devices from list '${WANTED_DEVICES_LIST}'"
			sleep 5
			exit 123
		fi
	EOD
	chroot_sdcard chmod -v +x "/usr/local/sbin/vlc-alsa-launcher.sh"

	display_alert "Adding VLC systemd service" "${EXTENSION}" "info"
	cat <<- EOD > "${SDCARD}/usr/lib/systemd/system/vlc.service"
		[Unit]
		Description=VLC
		After=syslog.target audio.target
		Requires=network.target
		# Disabled: pulseaudio.service
		StartLimitIntervalSec=0

		[Service]
		User=vlc
		Group=vlc
		SyslogIdentifier=vlc
		ExecStartPre=/usr/bin/sleep 1
		ExecStart=bash /usr/local/sbin/vlc-alsa-launcher.sh
		Restart=always

		[Install]
		WantedBy=multi-user.target
	EOD
	chroot_sdcard systemctl enable vlc.service

}

# Hack, add media to /media from the host.
function pre_customize_image__065_add_media() {
	local host_src="${VLC_MEDIA_HOST_PATH}"
	local device_dest="${VLC_MEDIA_DEVICE_PATH}"

	if [[ "${host_src}" == "" ]] && [[ "${device_dest}" == "" ]]; then
		display_alert "VLC: no media found" "Set VLC_MEDIA_HOST_PATH and VLC_MEDIA_DEVICE_PATH" "warn"
		#display_alert "Adding sample S3M media" "${EXTENSION}" "warn"
		#run_host_command_logged wget -O "${SDCARD}${device_dest}"/PANIC.S3M "https://api.modarchive.org/downloads.php?moduleid=52695#PANIC.S3M"
		#run_host_command_logged wget -O "${SDCARD}${device_dest}"/2NDPM.S3M "https://api.modarchive.org/downloads.php?moduleid=60395#2ND_PM.S3M"
		return 0
	fi

	mkdir -p "${SDCARD}${device_dest}"
	if [[ -d "${host_src}" ]]; then
		display_alert "Adding media from host's ${host_src}" "${EXTENSION}" "info"
		run_host_command_logged cp -rvp "${host_src}"/* "${SDCARD}${device_dest}"/
	else
		display_alert "Missing media at host's ${host_src}" "${EXTENSION}" "warn"
	fi

	display_alert "Making media folder owned by vlc" "${EXTENSION}" "info"
	chroot_sdcard chown -v -R vlc:vlc "${device_dest}"
}

# Setup pulseaudio system daemon. Always running and takes control of audio devices. Allows for Bluetooth audio.
# @TODO: DISABLED, vlc now goes straight to ALSA
function DISABLED_pre_customize_image__050_pulseaudio_system_wide() {
	display_alert "Adding PulseAudio systemd service for VLC" "${EXTENSION}" "info"

	# @TODO: possibly split pulseaudio off to its own extension. it's very useful for other stuff as well
	# @TODO: configuration for pulse will be key, provide a way to either auto-generate or use preexisting
	# @TODO: suppose user switches audio device? (should be handled internally, but config has to enable auto-moving of outputs et al)
	# @TODO: make it network accessible too, so `PULSE_SERVER=xxx pavucontrol` works as a last resort.
	# @TODO: of course do this in the chroot
	configure_system_pulseaudio

	# See https://www.freedesktop.org/software/systemd/man/systemd.special.html
	cat <<- EOD > "${SDCARD}/usr/lib/systemd/system/pulseaudio.service"
		[Unit]
		Description=PulseAudio Sound Service
		Requires=network.target sound.target network.target avahi-daemon.service

		[Service]
		ExecStart=/usr/bin/pulseaudio --system --disallow-exit --exit-idle-time=-1 --disable-shm --enable-memfd --verbose
		Restart=on-failure
		#Environment=PULSE_STATE_PATH=/storage/.config/pulse
		#Environment=PULSE_CONFIG_PATH=/storage/.config/pulse

		[Install]
		WantedBy=multi-user.target
	EOD
	chroot_sdcard systemctl enable pulseaudio.service
}

function configure_system_pulseaudio() {
	display_alert "Setting up PulseAudio system mode configuration" "${EXTENSION}" "info"

	cat <<- EOD > "${SDCARD}/etc/pulse/daemon.conf"
		deferred-volume-safety-margin-usec = 1
		default-fragment-size-msec = 15
	EOD

	cat <<- EOD > "${SDCARD}/etc/pulse/system.pa"
		#!/usr/bin/pulseaudio -nF

		### Load protocols, both local and network, NO AUTH
		load-module module-native-protocol-unix auth-anonymous=1 auth-cookie-enabled=0
		load-module module-native-protocol-tcp auth-anonymous=1

		### Use hot-plugged devices like Bluetooth or USB automatically
		load-module module-switch-on-connect

		### Automatically restore the default sink/source when changed by the user during runtime
		### NOTE: This should be loaded as early as possible so that subsequent modules that look up the default sink/source get the right value
		load-module module-default-device-restore

		# output to bluetooth and udev (which autodetects alsa)
		load-module module-bluetooth-policy
		load-module module-bluetooth-discover

		# alsa devices auto discovered by udev
		load-module module-udev-detect

		# Extra (slow protocols) zeroconf = avahi
		load-module module-zeroconf-publish
	EOD

}

# Remove stuff from BSP; @TODO: mostly copied from mluc, fix later
function post_family_tweaks_bsp__vlc_remote_rootlogin() {
	display_alert "VLC: Removing stuff from BSP" "${EXTENSION}" "warn"

	# Lets obliterate stuff in mass from the bsp, no autologin, no firstrun
	find "$destination" -type f | grep \
		-e "bootsplash" \
		-e "autologin" \
		-e "firstrun" \
		-e "zram" \
		-e "periodic" \
		-e "NetworkManager" \
		-e "profile-sync-daemon" \
		-e "logrotate" \
		-e "ramlog" | xargs rm

	display_alert "Hacking at the BSP" "more-like-ubuntu-cloud" "info"
	# remove a bunch of stuff from bsp so it behaves more like regular ubuntu
	RM_OPTIONS="-f"
	rm ${RM_OPTIONS} "$destination"/etc/apt/apt.conf.d/02-armbian-compress-indexes

	rm ${RM_OPTIONS} "$destination"/etc/cron.d/armbian-truncate-logs
	rm ${RM_OPTIONS} "$destination"/etc/cron.d/armbian-updates
	rm ${RM_OPTIONS} "$destination"/etc/cron.daily/armbian-ram-logging

	rm ${RM_OPTIONS} "$destination"/etc/default/armbian-ramlog.dpkg-dist
	rm ${RM_OPTIONS} "$destination"/etc/default/armbian-zram-config.dpkg-dist

	rm ${RM_OPTIONS} "$destination"/etc/profile.d/armbian-check-first-login.sh

	rm ${RM_OPTIONS} "$destination"/etc/lib/systemd/system/systemd-journald.service.d/override.conf

	rm ${RM_OPTIONS} "$destination"/etc/lib/systemd/system/armbian-firstrun.service
	rm ${RM_OPTIONS} "$destination"/etc/lib/systemd/system/armbian-ramlog.service
	rm ${RM_OPTIONS} "$destination"/etc/lib/systemd/system/armbian-zram-config.service

	rm ${RM_OPTIONS} "$destination"/lib/systemd/system/armbian-firstrun-config.service
	rm ${RM_OPTIONS} "$destination"/lib/systemd/system/armbian-firstrun.service
	rm ${RM_OPTIONS} "$destination"/lib/systemd/system/armbian-zram-config.service
	rm ${RM_OPTIONS} "$destination"/lib/systemd/system/armbian-disable-autologin.service
	rm ${RM_OPTIONS} "$destination"/lib/systemd/system/armbian-ramlog.service

	return 0
}

# Disable the Armbian onboarding stuff
function pre_customize_image__020_auto_login_root() {
	# cleanup -- cloud-init makes some Armbian stuff actually get in the way
	[[ -f "${SDCARD}/boot/armbian_first_run.txt.template" ]] && rm -f "${SDCARD}/boot/armbian_first_run.txt.template"
	[[ -f "${SDCARD}/root/.not_logged_in_yet" ]] && rm -f "${SDCARD}/root/.not_logged_in_yet"

	# Enable motd generator, first-run will not run, so enable it directly here.
	run_host_command_logged chmod +x "${SDCARD}/etc/update-motd.d/"*

	return 0 # short-circuit above
}
