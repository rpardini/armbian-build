function extension_prepare_config__docker() {
	display_alert "Target image will have Docker Inc. preinstalled" "${EXTENSION}" "info"
}

function pre_customize_image__add_docker_to_image() {
	display_alert "Adding Docker Inc. package for release ${RELEASE}" "${EXTENSION}" "info"

	# Add gpg-key... Updated for Jammy, does not use apt-key.
	display_alert "Adding gpg-key for Docker Inc." "${EXTENSION}" "info"
	run_host_command_logged mkdir -pv "${SDCARD}"/usr/share/keyrings
	run_host_command_logged curl --max-time 60 -4 -fsSL "https://download.docker.com/linux/ubuntu/gpg" "|" gpg --dearmor -o "${SDCARD}"/usr/share/keyrings/docker.gpg

	# Add sources.list
	display_alert "Adding sources.list for Docker Inc." "${EXTENSION}" "info"
	run_host_command_logged echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${RELEASE} stable" "|" tee "${SDCARD}"/etc/apt/sources.list.d/docker.list

	display_alert "Updating package lists with Docker Inc. repos" "${EXTENSION}" "info"
	chroot_sdcard_apt_get update

	display_alert "Installing Docker Inc. packages" "${EXTENSION}: 'docker-ce' et al" "info"
	chroot_sdcard_apt_get_install docker-ce docker-ce-cli containerd.io docker-compose-plugin
}
