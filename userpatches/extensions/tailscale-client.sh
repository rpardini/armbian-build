function extension_prepare_config__prepare_tailscale_client() {
	display_alert "Tailscale client extension enabled" "${EXTENSION}" "info"
}

function pre_customize_image__080_add_tailscale_package() {
	display_alert "Adding Tailscale package for release ${RELEASE}" "${EXTENSION}" "info"
	# Might be unstable as well
	chroot_sdcard curl --max-time 60 -4 -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${RELEASE}.list" "|" tee /etc/apt/sources.list.d/tailscale.list
	# This is deprecated on Jammy, still works, but complains.
	chroot_sdcard curl --max-time 60 -4 -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${RELEASE}.gpg" "|" apt-key add -
	chroot_sdcard_apt_get update
	chroot_sdcard_apt_get_install tailscale
}

function pre_customize_image__081_add_tailscale_autoup() {
	[[ "x${TAILSCALE_LOGIN_URL}x" == "xx" ]] && return 0
	[[ "x${TAILSCALE_AUTH_KEY}x" == "xx" ]] && return 0

	display_alert "Deploying tailscale auto up" "${EXTENSION}" "info"

	cat <<- EOD > "${SDCARD}/usr/local/sbin/tailscale-autoup.sh"
		#! /bin/bash
		set -x
		set +e
		sleep 1
		while true; do
			tailscale up --login-server "${TAILSCALE_LOGIN_URL}" --authkey "${TAILSCALE_AUTH_KEY}" && exit 0
			sleep 3
		done
	EOD

	chroot_sdcard chmod -v +x "/usr/local/sbin/tailscale-autoup.sh"

	cat <<- EOD > "${SDCARD}/usr/lib/systemd/system/tailscale-autoup.service"
		[Unit]
		Description=tailscale up automatically
		Requires=tailscaled.service syslog.target network.target
		After=tailscaled.service syslog.target network.target

		[Service]
		Type=exec
		ExecStart=/bin/bash -c "/usr/local/sbin/tailscale-autoup.sh"
		RemainAfterExit=yes

		[Install]
		WantedBy=multi-user.target
	EOD
	chroot_sdcard systemctl enable tailscale-autoup.service
}
