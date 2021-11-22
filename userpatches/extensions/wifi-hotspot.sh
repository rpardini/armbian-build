function extension_prepare_config__prepare_wifi_hotspot() {
	display_alert "Adding Wifi Hotspot" "${EXTENSION}" "info"
	export PACKAGE_LIST="${PACKAGE_LIST} dnsmasq dns-root-data tree ccze" # To cached rootfs?
	remove_packages_everywhere networkd-dispatcher # not needed and causes confusion; NM has it's own
	remove_packages_everywhere ifupdown            # not needed and causes massive confusion
	export EXTRA_BSP_NAME="${EXTRA_BSP_NAME}-wifi-hotspot" # Unique bsp name for this extension, so things don't get mixed up.
}

function pre_customize_image__070_setup_hotspot_networkmanager() {
	display_alert "Disabling hostapd" "${EXTENSION}" "warn"
	chroot_sdcard systemctl disable hostapd.service || true

	display_alert "Configuring Hotspot via NetworkManager" "${EXTENSION}" "warn"
	chroot_sdcard systemctl disable dnsmasq.service || true        # dnsmasq service gets in the way. NM manages it.
	chroot_sdcard systemctl disable wpa_supplicant.service || true # wpa_supplicant service gets in the way. NM manages it?

	display_alert "Tree /etc/NetworkManager" "${EXTENSION}" "warn"
	run_host_command_logged tree -C -h "${SDCARD}"/etc/NetworkManager # debug

	display_alert "Tree /usr/lib/NetworkManager" "${EXTENSION}" "warn"
	run_host_command_logged tree -C -h "${SDCARD}"/usr/lib/NetworkManager # debug

	display_alert "Contents /etc/NetworkManager/NetworkManager.conf" "${EXTENSION}" "warn"
	run_host_command_logged cat "${SDCARD}"/etc/NetworkManager/NetworkManager.conf # debug 2

	# Keep wifi at full power
	chroot_sdcard rm -v /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf || true # nope, full power.

	mkdir -p "${SDCARD}"/etc/NetworkManager/system-connections

	cat <<- EOD > "${SDCARD}"/etc/NetworkManager/NetworkManager.conf
		[main]
		plugins=keyfile

		[device]
		wifi.scan-rand-mac-address=no
	EOD

	# This does not specify the interface name; it changes. type=wifi is enough
	cat <<- EOD > "${SDCARD}"/etc/NetworkManager/system-connections/Hotspot.nmconnection
		[connection]
		id=Hostspot
		uuid=39a418e6-4002-4f5d-b3ab-8012b0bf2f79
		type=wifi
		autoconnect=true
		permissions=

		[wifi]
		band=bg
		mac-address-blacklist=
		mode=ap
		ssid=Hotspot-${BOARD}

		[wifi-security]
		key-mgmt=wpa-psk
		psk=12345678

		[ipv4]
		dns-search=
		method=shared

		[ipv6]
		addr-gen-mode=stable-privacy
		dns-search=
		method=auto

		[proxy]
	EOD
	chroot_sdcard chmod -v g-rwx,o-rwx /etc/NetworkManager/system-connections/Hotspot.nmconnection

}
