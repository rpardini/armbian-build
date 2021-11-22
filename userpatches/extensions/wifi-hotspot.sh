function extension_prepare_config__prepare_wifi_hotspot() {
	display_alert "Adding Wifi Hotspot" "${EXTENSION} - ${PRODUCT_VENDOR}" "info"
	export PACKAGE_LIST="${PACKAGE_LIST} dnsmasq dns-root-data tree ccze"             # To cached rootfs?
	export PACKAGE_LIST="${PACKAGE_LIST} uuid"                                        # UUID Generator
	export PACKAGE_LIST="${PACKAGE_LIST} liblockfile-bin liblockfile1 lockfile-progs" # Dependencies of usbmount, for all releases.

	# Jammy does not have this package anymore.
	if [[ "${RELEASE}" != "jammy" ]]; then
		export PACKAGE_LIST="${PACKAGE_LIST} usbmount" # For USBkey autoconfiguration
	fi

	export PACKAGE_LIST="${PACKAGE_LIST} python3-pip"      # For ImprovWifi Python stuff
	remove_packages_everywhere networkd-dispatcher         # not needed and causes confusion; NM has it's own
	remove_packages_everywhere ifupdown                    # not needed and causes massive confusion
	remove_packages_everywhere nfs-kernel-server           # not needed
	export EXTRA_BSP_NAME="${EXTRA_BSP_NAME}-wifi-hotspot" # Unique bsp name for this extension, so things don't get mixed up.
}

function pre_customize_image__010_add_early_and_auto_config_and_systemd() {
	display_alert "Early autoconfig" "${EXTENSION}" "info"

	helper_function2script board_side_early_autoconfig "${SDCARD}"/usr/local/sbin/early-autoconfig.sh
	helper_function2script board_side_apply_autoconfig "${SDCARD}"/usr/local/sbin/apply-autoconfig.sh

	# @TODO: /etc/NetworkManager/dispatcher.d/05-autoconfig - match uuid's and set leds blinking

	# This depends on both the filesystem, early networking, and DBus socket.
	cat <<- EOD > "${SDCARD}/usr/lib/systemd/system/early-autoconfig.service"
		[Unit]
		Description=Early autoconfig for ${PRODUCT_VENDOR}
		Wants=network-pre.target local-fs.target avahi-daemon.service armbian-hardware-optimize.service armbian-resize-filesystem.service
		Requires=dbus.socket
		Before=network-pre.target avahi-daemon.service
		After=local-fs.target dbus.socket armbian-hardware-optimize.service armbian-resize-filesystem.service
		DefaultDependencies=false

		[Service]
		Type=oneshot
		ExecStart=/bin/bash -c "/usr/local/sbin/early-autoconfig.sh"
		RemainAfterExit=yes

		[Install]
		WantedBy=network.target
	EOD
	chroot_sdcard systemctl enable early-autoconfig.service
}

function pre_customize_image__068_setup_improv_wifi() {
	display_alert "Configuring Improv-Wifi" "${EXTENSION} - ImprovWifi - ${PRODUCT_VENDOR}" "warn"

	# Clone host-side, into the chroot.
	run_host_command_logged git clone https://github.com/rpardini/improv-wifi-python-nm.git "${SDCARD}"/opt/improv-wifi-python-nm
	chroot_sdcard pip3 install bluez-peripheral==0.1.5

	cat <<- SYSTEMD_IMPROV_WIFI > "${SDCARD}"/usr/lib/systemd/system/improv-wifi.service
		[Unit]
		Description=Improv-Wifi Service
		After=syslog.target early-autoconfig.service bluetooth.service
		Requires=syslog.target early-autoconfig.service bluetooth.service
		StartLimitIntervalSec=0

		[Service]
		SyslogIdentifier=improv-wifi
		ExecStart=/usr/bin/python3 -u /opt/improv-wifi-python-nm/improv-wifi.py
		Restart=always

		[Install]
		WantedBy=bluetooth.target
	SYSTEMD_IMPROV_WIFI

	chroot_sdcard systemctl enable improv-wifi.service

	# Now, hack the bluetoothd service file, to disable auto-reading of Battery, which causes spurious pairing requests.
	sed -i -e 's/\/usr\/lib\/bluetooth\/bluetoothd/\/usr\/lib\/bluetooth\/bluetoothd -P battery/' "${SDCARD}"/lib/systemd/system/bluetooth.service

	# write the connect helper from a function
	helper_function2script board_side_improv_wifi_connect "${SDCARD}"/usr/local/sbin/improv-config.sh
	helper_function2script board_side_improv_wifi_status "${SDCARD}"/usr/local/sbin/improv-status.sh
	helper_function2script board_side_improv_wifi_identify "${SDCARD}"/usr/local/sbin/improv-identify.sh
}

function pre_customize_image__069_setup_usbmount() {
	display_alert "Configuring USB autoconfig" "${EXTENSION} - usbmount - ${PRODUCT_VENDOR}" "warn"

	# Hack, Jammy does not carry usbmount anymore, manually install it.
	if [[ "${RELEASE}" == "jammy" ]]; then
		display_alert "Installing usbmount from impish to Jammy" "${EXTENSION}" "info"
		run_host_command_logged wget -O "${SDCARD}"/root/usbmount.deb "http://nl.archive.ubuntu.com/ubuntu/pool/universe/u/usbmount/usbmount_0.0.22_all.deb"
		chroot_sdcard apt install /root/usbmount.deb
		run_host_command_logged rm -vf "${SDCARD}"/root/usbmount.deb
	fi

	# configure automount, accept exfat and ntfs as well
	mkdir -p "${SDCARD}"/etc/usbmount/mount.d # make sure it exists # @TODO: Jammy does not have usbmount...
	cat <<- USB_MOUNT_CONF > "${SDCARD}"/etc/usbmount/usbmount.conf
		ENABLED=1
		MOUNTPOINTS="/media/usb0 /media/usb1 /media/usb2 /media/usb3 /media/usb4 /media/usb5 /media/usb6 /media/usb7"
		FILESYSTEMS="exfat ntfs vfat ext2 ext3 ext4 hfsplus"
		MOUNTOPTIONS="ro,sync,noexec,nodev,noatime,nodiratime"
		FS_MOUNTOPTIONS=""
		VERBOSE=y
	USB_MOUNT_CONF

	# add mounter hook triggering the autoconfigure script
	helper_function2script board_side_usbmounter_hook_mounted "${SDCARD}"/etc/usbmount/mount.d/01_autoconfigure_usb
}

function pre_customize_image__070_setup_hotspot_networkmanager() {
	display_alert "Disabling hostapd" "${EXTENSION}" "warn"
	chroot_sdcard systemctl disable hostapd.service || true

	display_alert "Configuring Hotspot via NetworkManager" "${EXTENSION}" "warn"
	chroot_sdcard systemctl disable dnsmasq.service || true        # dnsmasq service gets in the way. NM manages it.
	chroot_sdcard systemctl disable wpa_supplicant.service || true # wpa_supplicant service gets in the way. NM manages it?

	#display_alert "Tree /etc/NetworkManager" "${EXTENSION}" "warn"
	#run_host_command_logged tree -C -h "${SDCARD}"/etc/NetworkManager # debug

	#display_alert "Tree /usr/lib/NetworkManager" "${EXTENSION}" "warn"
	#run_host_command_logged tree -C -h "${SDCARD}"/usr/lib/NetworkManager # debug

	#display_alert "Contents /etc/NetworkManager/NetworkManager.conf" "${EXTENSION}" "warn"
	#run_host_command_logged cat "${SDCARD}"/etc/NetworkManager/NetworkManager.conf # debug 2

	# Keep wifi at full power
	chroot_sdcard rm -v /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf || true # nope, full power.

	mkdir -p "${SDCARD}"/etc/NetworkManager/system-connections

	cat <<- EOD > "${SDCARD}"/etc/NetworkManager/NetworkManager.conf
		[main]
		plugins=keyfile

		[device]
		wifi.scan-rand-mac-address=no
	EOD

	# For OOB workings, the hotspot is auto-enabled. This is a last-resort fallback.
	HOTSPOT_NAME="Hotspot-${BOARD}" create_hotspot_config_contents > "${SDCARD}"/etc/NetworkManager/system-connections/Hotspot.nmconnection
	chroot_sdcard chmod -v g-rwx,o-rwx /etc/NetworkManager/system-connections/Hotspot.nmconnection

}

function pre_customize_image__071_setup_nm_dispatcher() {
	display_alert "Configuring NM dispatcher" "${EXTENSION} - NMdispatcher - ${PRODUCT_VENDOR}" "warn"

	# add mounter hook triggering the autoconfigure script
	helper_function2script board_side_nm_dispatcher "${SDCARD}"/etc/NetworkManager/dispatcher.d/02-wifi-leds
	# fix perms, NM requires it
	run_host_command_logged chmod -v g-w,o-w "${SDCARD}"/etc/NetworkManager/dispatcher.d/02-wifi-leds
}

# This runs board side
function board_side_nm_dispatcher() {
	# Only act when Hotspot or WifiClient, and when 'up' or 'down'. Blinking on up, off when down.
	case "${CONNECTION_ID}-${NM_DISPATCHER_ACTION}" in
		WifiClient-up)
			board_side_log "WifiClient is up!"
			board_side_led green blink
			;;
		WifiClient-down)
			board_side_log "WifiClient is down!"
			board_side_led green off
			;;
		Hotspot-up)
			board_side_log "Hotspot is up!"
			board_side_led yellow blink
			;;
		Hotspot-down)
			board_side_log "Hotspot is down!"
			board_side_led yellow off
			;;
		*)
			board_side_log "Ignoring dispatch: ${CONNECTION_ID}-${NM_DISPATCHER_ACTION}"
			;;
	esac
	exit 0
}

# Important: this runs BOARD-SIDE. I use a function and trickery so to avoid templating it and use my IDE for all
function board_side_apply_autoconfig() {
	AUTOCONFIG_CALLED_BY="${AUTOCONFIG_CALLED_BY:-unknown}"
	board_side_led yellow off
	board_side_led green off

	declare WIFI_SSID=""                            # default none
	declare WIFI_PWD=""                             # default none
	declare MODE="hotspot"                          # default to hotspot mode
	declare -g MAC_ADDRESS="unknown"                # target for below call
	board_side_get_mac_address_variable             # grab it from phy
	declare HOTSPOT_NAME="Hotspot-${MAC_ADDRESS}"   # use mac for hotspot name
	declare NAME="${PRODUCT_VENDOR}-${MAC_ADDRESS}" # default to product vendor and mac address part

	# shellcheck disable=SC1090 # not supposed to follow this.
	[[ -f "/etc/${PRODUCT_VENDOR}/${PRODUCT_VENDOR}.conf" ]] && source "/etc/${PRODUCT_VENDOR}/${PRODUCT_VENDOR}.conf"

	# if WIFI_SSID && WIFI_PWD set in config, change mode to client
	if [[ "x${WIFI_SSID}x" != "xx" ]] && [[ "x${WIFI_PWD}x" != "xx" ]]; then
		board_side_log "Using client mode for Wifi for SSID '${WIFI_SSID}'..."
		MODE="client"
	fi

	# Set the NAME from the config or default to system hostname
	PREVIOUS_HOSTNAME="$(cat /etc/hostname)"
	board_side_log "Setting hostname to '${NAME}'..."
	echo -n "${NAME}" > /etc/hostname
	hostnamectl set-hostname "${NAME}" || echo "Failed set-hostname '${NAME}' via dbus"
	NEW_HOSTNAME="$(cat /etc/hostname)"

	# If hostname changed, restart vlc and avahi if those are active right ow
	if [[ "${PREVIOUS_HOSTNAME}" != "${NEW_HOSTNAME}" ]]; then
		board_side_log "HOSTNAME CHANGE from '${PREVIOUS_HOSTNAME}' to '${NEW_HOSTNAME}'"
		if systemctl is-active avahi-daemon.service; then
			board_side_log "HOSTNAME CHANGE from '${PREVIOUS_HOSTNAME}' to '${NEW_HOSTNAME}' - Avahi active, restarting"
			systemctl restart avahi-daemon.service || true
		else
			board_side_log "HOSTNAME CHANGE from '${PREVIOUS_HOSTNAME}' to '${NEW_HOSTNAME}' - Avahi not active, skipping restart."
		fi

		if systemctl is-active vlc; then
			board_side_log "HOSTNAME CHANGE from '${PREVIOUS_HOSTNAME}' to '${NEW_HOSTNAME}' - VLC active, restarting"
			systemctl restart vlc.service || true
		else
			board_side_log "HOSTNAME CHANGE from '${PREVIOUS_HOSTNAME}' to '${NEW_HOSTNAME}' - VLC not active, skipping restart."
		fi
	else
		board_side_log "HOSTNAME DID NOT CHANGE... '${PREVIOUS_HOSTNAME}' == '${NEW_HOSTNAME}'"
	fi

	# Feed the vendor info... VENDOR_INFO_DIR is set by launcher.
	mkdir -p "${VENDOR_INFO_DIR}"

	# Always set the name, which is a file.
	rm -f "${VENDOR_INFO_DIR}"/*.name || true
	touch "${VENDOR_INFO_DIR}/${NAME}.name"
	echo "${NAME}" > "${VENDOR_INFO_DIR}/name.set"
	board_side_log "Setting NAME to ${VENDOR_INFO_DIR}/${NAME}.name"

	# Set the UUID, if not done before. UUID does not change even if Name does.
	if [[ ! -f "${VENDOR_INFO_DIR}/uuid.set" ]]; then
		rm -f "${VENDOR_INFO_DIR}"/*.uuid || true
		NEW_UUID="$(uuid | tr "[:lower:]" "[:upper:]")"
		board_side_log "Setting UUID (once) to ${VENDOR_INFO_DIR}/${NEW_UUID}.name"
		touch "${VENDOR_INFO_DIR}/${NEW_UUID}.uuid"
		echo "${NEW_UUID}" > "${VENDOR_INFO_DIR}/uuid.set" # for reference
		echo "${NEW_UUID}" > "/etc/machine.uuid"           # for reference
	fi

	chown -Rv vlc:vlc "${VENDOR_INFO_DIR}" || true

	# After setting the UUID and Name, generate the Avahi service, which will have the UUID as hostname, and both in TXT records.
	AVAHI_DEVICE_UUID="$(cat "${VENDOR_INFO_DIR}/uuid.set")" AVAHI_DEVICE_NAME="$(cat "${VENDOR_INFO_DIR}/name.set")" create_avahi_service_with_uuid_and_name

	if [[ "${MODE}" == "hotspot" ]]; then
		board_side_led yellow on # solid, will blink when NM is up
		board_side_log "Mode: hotspot, writing nm config... '${HOTSPOT_NAME}'"
		create_hotspot_config_contents > /etc/NetworkManager/system-connections/Hotspot.nmconnection # write new conf
		chmod -v g-rwx,o-rwx /etc/NetworkManager/system-connections/Hotspot.nmconnection             # permissions
		rm -f /etc/NetworkManager/system-connections/WifiClient.nmconnection                         # remove wificlient config
	else
		board_side_led green on # solid, will blink when NM is up
		board_side_log "Mode: wifi client, writing nm config... SSID '${WIFI_SSID}'"
		create_wifi_client_config_contents > /etc/NetworkManager/system-connections/WifiClient.nmconnection # write new conf
		chmod -v g-rwx,o-rwx /etc/NetworkManager/system-connections/WifiClient.nmconnection                 # permissions
		rm -rf /etc/NetworkManager/system-connections/Hotspot.nmconnection                                  # remove hotspot connection
	fi

	board_side_log "Reload NM connections..."
	nmcli connection reload || true # reload stuff in NM

	if [[ "${MODE}" == "hotspot" ]]; then
		nmcli --wait=0 connection down WifiClient || true
		nmcli --wait=0 connection up Hotspot || true
	else
		nmcli --wait=0 connection down Hotspot || true
		nmcli --wait=0 connection up WifiClient || true
	fi

	board_side_log "Done"
	board_side_led red blink
}

# Important: this runs BOARD-SIDE. I use a function and trickery so to avoid templating it and use my IDE for all
function board_side_early_autoconfig() {
	declare MAC_ADDRESS NEW_HOST_NAME
	board_side_get_mac_address_variable
	declare NEW_HOST_NAME="${PRODUCT_VENDOR}-${MAC_ADDRESS}"

	echo -n "${NEW_HOST_NAME}" > /etc/hostname
	hostnamectl set-hostname "${NEW_HOST_NAME}" || echo "Failed set-hostname '${NEW_HOST_NAME}' via dbus"

	# red LED solid. this runs very early; will start blinking after autoconfig is done.
	board_side_led red on
	board_side_led yellow off
	board_side_led green off

	# run the apply autoconfig too, to override the default above via config.
	export AUTOCONFIG_CALLED_BY="${AUTOCONFIG_CALLED_BY}-early-autoconfig-sh"
	exec /usr/local/sbin/apply-autoconfig.sh "$@"
}

# Important: this runs BOARD-SIDE.
# Run by the improv-wifi Python service, with the SSID and password.
function board_side_improv_wifi_connect() {
	declare SSID PASSWORD
	SSID="$1"
	PASSWORD="$2"

	# write the config file, as if it was read from usbmount. @TODO: what if pwd contains double quote?
	mkdir -p "/etc/${PRODUCT_VENDOR}"
	cat <<- WIFI_CONFIG_FILE > "/etc/${PRODUCT_VENDOR}/${PRODUCT_VENDOR}.conf"
		WIFI_SSID="${SSID}"
		WIFI_PWD="${PASSWORD}"
	WIFI_CONFIG_FILE

	# run the apply autoconfig too, to override the default above via config.
	export AUTOCONFIG_CALLED_BY="${AUTOCONFIG_CALLED_BY}-improv-wifi-connect"
	exec /usr/local/sbin/apply-autoconfig.sh "$@"
}

# Runs board-side. Returns the Wifi status for Improv-Wifi.
# Statuses:
# 0 - Wifi is setup and connected
# 1 - Wifi is setup but not connected
# 10 - Hotspot is setup and connected
# 11 - Hotspot is setup but not connected
# 55 - Unknown
function board_side_improv_wifi_status() {
	if [[ ! -f /etc/NetworkManager/system-connections/WifiClient.nmconnection ]]; then
		board_side_log "No Wifi config, checking hotspot for status"
		if nmcli --get-values TYPE,NAME,STATE,ACTIVE,DEVICE,TIMESTAMP connection show | grep "802-11-wireless:Hotspot:activated:yes"; then
			board_side_log "HotSpot is connected"
			exit 10
		else
			board_side_log "Hotspot is not connected"
			exit 11
		fi
	else
		board_side_log "Wifi is configured. Checking connection status..."
		if nmcli --get-values TYPE,NAME,STATE,ACTIVE,DEVICE,TIMESTAMP connection show | grep "802-11-wireless:WifiClient:activated:yes"; then
			board_side_log "Wifi is connected"
			exit 0
		else
			board_side_log "Wifi is not connected"
			exit 1
		fi
	fi
	board_side_log "Unknown status"
	exit 55
}

# Runs board side, flashing all LEDs. To identify the physical device in case of many.
function board_side_improv_wifi_identify() {
	declare -A leds_original_triggers=()
	declare -a leds_to_blink=()

	function all_leds_set() {
		local state="$1"
		local duration="$2"
		for led_to_blink in "${leds_to_blink[@]}"; do
			echo "${state}" > "/sys/class/leds/${led_to_blink}/trigger"
		done
		sleep "${duration}"
	}

	# make sure we have the modules we need
	modprobe ledtrig-default-on || true

	# Find leds, and store their original triggers; skip mmc/input ones that are not real.
	for led_id in /sys/class/leds/*; do
		led_name="$(basename "${led_id}")"
		led_trigger="/sys/class/leds/${led_name}/trigger"
		[[ ! -f $led_trigger ]] && continue
		case ${led_name} in
			mmc* | input*)
				continue
				;;
		esac
		led_original_trigger="$(cat "${led_trigger}" | awk -F'[][]' '{print $2}')"
		leds_original_triggers["${led_name}"]="${led_original_trigger}"
		echo "LED: ${led_name} trigger: ${led_original_trigger}"
		leds_to_blink+=("${led_name}")
	done

	# Flash the LEDs 5 times
	for counter in {1..5}; do
		all_leds_set "default-on" "0.1"
		all_leds_set "none" "0.1"
	done

	# Restore the original triggers.
	for led_name in "${!leds_original_triggers[@]}"; do
		echo "LED: ${led_name} original trigger: ${leds_original_triggers[${led_name}]}"
		echo "${leds_original_triggers[${led_name}]}" > "/sys/class/leds/${led_name}/trigger"
	done
}

# Important: this runs BOARD-SIDE.
# This might run very early in boot if the USB is inserted during boot.
function board_side_usbmounter_hook_mounted() {
	echo "Starting USB autoconfig... ${UM_MOUNTPOINT}"

	board_side_led red off
	board_side_led yellow blink

	sleep 2 # give it 2 seconds

	if [[ ! -f "${UM_MOUNTPOINT}/${PRODUCT_VENDOR}.conf" ]]; then
		echo "could not find ${PRODUCT_VENDOR}.conf in USB stuff"
		board_side_led red blink
		exit 0
	fi

	# We have the file. Assume it is valid for now
	mkdir -p "/etc/${PRODUCT_VENDOR}"
	# backup if not already there
	if [[ -f "/etc/${PRODUCT_VENDOR}/${PRODUCT_VENDOR}.conf" ]]; then
		if [[ ! -f "/etc/${PRODUCT_VENDOR}/${PRODUCT_VENDOR}.conf.orig" ]]; then
			cp "/etc/${PRODUCT_VENDOR}/${PRODUCT_VENDOR}.conf" "/etc/${PRODUCT_VENDOR}/${PRODUCT_VENDOR}.conf.orig"
		fi
	fi
	cp -v "${UM_MOUNTPOINT}/${PRODUCT_VENDOR}.conf" "/etc/${PRODUCT_VENDOR}/${PRODUCT_VENDOR}.conf"
	sync # make sure

	# then exec off the autoconfig.
	export AUTOCONFIG_CALLED_BY="${AUTOCONFIG_CALLED_BY}-usbmount"
	exec /usr/local/sbin/apply-autoconfig.sh
}

function board_side_get_mac_address_variable() {
	# shellcheck disable=SC2012 # let me be, no find here.
	declare -g MAC_ADDRESS
	MAC_ADDRESS="$(ls /sys/class/net/e*/address | sort -h | head -1 | xargs cat | tr -d ":" | tr -d "0")"
	echo "Detected MAC address: ${MAC_ADDRESS}"

	if [[ "x${MAC_ADDRESS}x" == "xx" ]]; then
		echo "Couldn't find Ethernet mac address."
		MAC_ADDRESS="unknown"
	fi
}

function board_side_log() {
	echo "${PRODUCT_VENDOR}-autoconfig${AUTOCONFIG_CALLED_BY}:" "$@" 1>&2
	echo "$@" | logger -t "${PRODUCT_VENDOR}-autoconfig${AUTOCONFIG_CALLED_BY}"
}

# board_side_led red blink/on/off
function board_side_led() {
	local led="${1}"
	local state="${2}"

	local led_dev="" trigger=""
	case ${led} in
		green) led_dev="act-led" ;;
		yellow) led_dev="rsv-led" ;;
		red) led_dev="pwr-led" ;;
	esac

	case ${state} in
		on) trigger="default-on" ;;
		blink) trigger="heartbeat" ;;
		off) trigger="none" ;;
	esac

	board_side_log "LED '${led}' '${state}'"
	if [[ -f /sys/class/leds/${led_dev}/trigger ]]; then
		echo "${trigger}" > /sys/class/leds/${led_dev}/trigger || true
	fi
}

# Interestingly, this is used both at build-time and board/run-time.
function create_hotspot_config_contents() {
	# This does not specify the interface name; it changes. type=wifi is enough
	cat <<- EOD
		[connection]
		id=Hotspot
		uuid=11111111-1111-1111-1111-111111111111
		type=wifi
		autoconnect=true
		permissions=

		[wifi]
		band=bg
		mac-address-blacklist=
		mode=ap
		ssid=${HOTSPOT_NAME:-"Hotspot-unknown"}

		[wifi-security]
		key-mgmt=wpa-psk
		psk=${HOTSPOT_PWD:-"12345678"}

		[ipv4]
		dns-search=
		method=shared

		[ipv6]
		addr-gen-mode=stable-privacy
		dns-search=
		method=auto

		[proxy]
	EOD
}

# This is only used board-side.
function create_wifi_client_config_contents() {
	# This does not specify the interface name; it changes. type=wifi is enough
	cat <<- EOD
		[connection]
		id=WifiClient
		uuid=22222222-2222-2222-2222-222222222222
		type=wifi
		permissions=

		[wifi]
		mac-address-blacklist=
		mode=infrastructure
		ssid=${WIFI_SSID}

		[wifi-security]
		key-mgmt=wpa-psk
		psk=${WIFI_PWD}

		[ipv4]
		dns-search=
		method=auto

		[ipv6]
		addr-gen-mode=stable-privacy
		dns-search=
		method=auto

		[proxy]
	EOD
}

# Used board-side.
function create_avahi_service_with_uuid_and_name() {
	cat <<- EOD > "/etc/avahi/services/${VENDOR_AVAHI_NAME}.service"
		<?xml version="1.0" standalone='no'?><!--*-nxml-*-->
		<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
		<service-group>
			<name replace-wildcards="no">${AVAHI_DEVICE_UUID}</name>
			<service>
				<type>_${VENDOR_AVAHI_NAME}._tcp</type>
				<port>8080</port>
				<txt-record value-format="text">name=${AVAHI_DEVICE_NAME}</txt-record>
				<txt-record value-format="text">uuid=${AVAHI_DEVICE_UUID}</txt-record>
			</service>
		</service-group>
	EOD
	chmod -v g-w,o-w "/etc/avahi/services/${VENDOR_AVAHI_NAME}.service"
}

# A funky hack. `declare -f` dumps the source of the function. 1st line is deleted (function name).
function helper_function2script() {
	local function_name="$1"
	local target_file="$2"
	cat <<- GENERIC_FUNCTION_TO_SCRIPT > "${target_file}"
		#!/usr/bin/bash
		set -e

		$(declare -f "create_hotspot_config_contents")
		$(declare -f "create_wifi_client_config_contents")
		$(declare -f "board_side_get_mac_address_variable")
		$(declare -f "create_avahi_service_with_uuid_and_name")
		$(declare -f "board_side_log")
		$(declare -f "board_side_led")

		#set -x # GLOBAL DEBUG
		export PRODUCT_VENDOR="${PRODUCT_VENDOR}"
		export VENDOR_INFO_DIR="${VENDOR_INFO_DIR}"
		export VENDOR_AVAHI_NAME="${VENDOR_AVAHI_NAME}"
		export BOARD="${BOARD}"
		board_side_log "SCRIPT: ${function_name} STARTING..."
		$(declare -f "${function_name}" | sed '1d')
	GENERIC_FUNCTION_TO_SCRIPT
	chmod +x "${target_file}"
	LOG_ASSET="$(basename "${target_file}")" do_with_log_asset cat "${target_file}"
}
