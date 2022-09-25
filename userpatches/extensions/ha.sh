enable_extension "docker-ce"

# Stuff: download and install amd64 https://github.com/home-assistant/os-agent/releases/download/1.5.1/os-agent_1.5.1_linux_x86_64.deb
#                             arm64 https://github.com/home-assistant/os-agent/releases/download/1.5.1/os-agent_1.5.1_linux_aarch64.deb
#                             armhf https://github.com/home-assistant/os-agent/releases/download/1.5.1/os-agent_1.5.1_linux_armv7.deb

# @TODO: cgroupv1: systemd.unified_cgroup_hierarchy=false to kernel cmdline

function extension_prepare_config__home_assistant() {
	display_alert "Target image will be a Home Assistant Supervised machine" "${EXTENSION}" "info"
	declare -g EXTRA_BSP_NAME="${EXTRA_BSP_NAME}-ha" # Unique bsp name for this extension

	declare -g KEEP_ORIGINAL_OS_RELEASE="yes" # Keep original os-release file when installing bsp and preparing image

	# HA-Supervised wants cgroupsv1, no idea why, but such is life.
	declare -g GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} systemd.unified_cgroup_hierarchy=false" # GRUB version
	declare -g HA_UBOOT_EXTRAARGS="systemd.unified_cgroup_hierarchy=false"                                       # u-boot version, applied below

	# We need extra space in the rootfs for the Java build machine
	display_alert "Adding extra space" "current extra: ${EXTRA_ROOTFS_MIB_SIZE}" "info"
	if [[ ${EXTRA_ROOTFS_MIB_SIZE} -le 1024 ]]; then
		declare -g EXTRA_ROOTFS_MIB_SIZE=1024
		display_alert "Setting new EXTRA_ROOTFS_MIB_SIZE: ${EXTRA_ROOTFS_MIB_SIZE}" "${EXTENSION}" "info"
	fi

	declare -g HA_OS_AGENT_ARCH="${ARCH}"
	[[ "${ARCH}" == "arm64" ]] && declare -g HA_OS_AGENT_ARCH="aarch64"
	[[ "${ARCH}" == "amd64" ]] && declare -g HA_OS_AGENT_ARCH="x86_64"

	declare -g HA_OS_AGENT_VERSION="1.5.1"
	declare -g HA_OS_AGENT_FILENAME="os-agent_${HA_OS_AGENT_VERSION}_linux_${HA_OS_AGENT_ARCH}.deb"

	declare -g HA_OS_AGENT_URL="https://github.com/home-assistant/os-agent/releases/download/${HA_OS_AGENT_VERSION}/${HA_OS_AGENT_FILENAME}"
	declare -g HA_OS_AGENT_CACHE_DIR="${SRC}/cache/home_assistant_debs"
	declare -g HA_OS_AGENT_CACHE_FILE="${HA_OS_AGENT_CACHE_DIR}/${HA_OS_AGENT_FILENAME}"

	display_alert "Adding HA packages" "${EXTENSION}" "info"
	add_packages_to_image systemd-journal-remote apparmor

	EXTRA_IMAGE_SUFFIXES+=("-homeassistant") # global array

	[[ "${BUILDING_IMAGE}" != "yes" ]] && return 0

	display_alert "Fetching Home Assistant debs" "${EXTENSION}" "info"
	mkdir -p "${HA_OS_AGENT_CACHE_DIR}"
	if [[ -f "${HA_OS_AGENT_CACHE_FILE}" ]]; then
		display_alert "Using cached Home Assistant deb" "${HA_OS_AGENT_CACHE_FILE}" "info"
	else
		display_alert "Fetching Home Assistant deb" "${HA_OS_AGENT_URL}" "info"
		run_host_command_logged wget --progress=dot:giga --output-document="${HA_OS_AGENT_CACHE_FILE}" "${HA_OS_AGENT_URL}"
	fi

	# @TODO: at first run, install the supervised .deb.
}

function pre_install_kernel_debs__add_home_assistant_debs_to_image() {
	display_alert "Adding Home Assistant debs to image" "${EXTENSION}" "info"
	run_host_command_logged mkdir -p "${SDCARD}"/opt/hainstall
	run_host_command_logged cp -pv "${HA_OS_AGENT_CACHE_FILE}" "${SDCARD}/opt/hainstall/${HA_OS_AGENT_FILENAME}"
	chroot_sdcard ls -la /opt/hainstall
	chroot_sdcard_apt_get_install "/opt/hainstall/${HA_OS_AGENT_FILENAME}"
}

function image_specific_armbian_env_ready__set_cgroupsv1_in_armbianEnvTxt() {
	[[ ! -f "${SDCARD}/boot/armbianEnv.txt" ]] && exit_with_error "armbianEnv.txt not found at ${SDCARD}/boot/armbianEnv.txt"
	echo "extraargs=${HA_UBOOT_EXTRAARGS}" >> "${SDCARD}/boot/armbianEnv.txt"
	display_alert "armbianEnv.txt contents" "${SDCARD}/boot/armbianEnv.txt" "info"
	run_host_command_logged cat "${SDCARD}/boot/armbianEnv.txt"
}
