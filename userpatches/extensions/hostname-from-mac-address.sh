function extension_prepare_config__prepare_hostname_from_mac_address() {
	display_alert "Hostname from MAC address extension enabled" "${EXTENSION}" "info"
}

function pre_customize_image__010_add_hostname_from_mac_address() {
	display_alert "Deploying Hostname from MAC address systemd service" "${EXTENSION}" "info"

	# This is of course not ideal. hostnamectl does not work at this stage, so system is half-changed
	cat <<- EOD > "${SDCARD}/usr/local/sbin/hostname-from-mac-address.sh"
		#! /bin/bash

		set -x

		declare MAC_ADDRESS="\$(ls /sys/class/net/e*/address | sort -h | head -1 | xargs cat | tr -d ":" | tr -d "0")"
		echo "Detected MAC address: \${MAC_ADDRESS}"

		if [[ "x\${MAC_ADDRESS}x" == "xx" ]]; then
			echo "Couldn't find ethernet mac address."
			MAC_ADDRESS="nomacaddr"
		fi

		declare NEW_HOST_NAME="${BOARD}-\${MAC_ADDRESS}"

		echo -n "\${NEW_HOST_NAME}" > /etc/hostname

		hostnamectl set-hostname "\${NEW_HOST_NAME}" || echo "Failed set-hostname via dbus"

		exit 0
	EOD
	chroot_sdcard chmod -v +x "/usr/local/sbin/hostname-from-mac-address.sh"

	# This depends on both the filesystem, early networking, and DBus socket.
	cat <<- EOD > "${SDCARD}/usr/lib/systemd/system/hostname-from-mac-address.service"
		[Unit]
		Description=Early Hostname from MAC Address
		Wants=network-pre.target local-fs.target
		Requires=dbus.socket
		Before=network-pre.target
		After=local-fs.target dbus.socket
		DefaultDependencies=false

		[Service]
		Type=oneshot
		ExecStart=/bin/bash -c "/usr/local/sbin/hostname-from-mac-address.sh"
		RemainAfterExit=yes

		[Install]
		WantedBy=network.target
	EOD
	chroot_sdcard systemctl enable hostname-from-mac-address.service
}
