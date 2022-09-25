function user_config__serialconsole_cloud_config_common() {
	display_alert "Configuring cloud-init for real serialconsole" "cloud-serialconsole: common" "info"
	EXTRA_IMAGE_SUFFIXES+=("-serialconsole") # global array # For the 'real cloud' version, we skip the c-i config and add a version to the build
}

function user_config__serialconsole_cloud_config_arm64() {
	[[ "${ARCH}" != "arm64" ]] && return 0
	[[ "${BOARDFAMILY}" != uefi-* ]] && return 0
	declare -g SERIALCON="ttyAMA0" # Default serial console for arm64
	display_alert "Configuring cloud-init for arm64 serialconsole" "cloud-serialconsole: arm64; SERIALCON=${SERIALCON}" "warn"
}

function user_config__serialconsole_cloud_config_amd64_x86() {
	[[ "${ARCH}" != "amd64" ]] && return 0
	[[ "${BOARDFAMILY}" != uefi-* ]] && return 0
	declare -g SERIALCON="ttyS0" # Default serial console for amd64
	display_alert "Configuring cloud-init for amd64 serialconsole" "cloud-serialconsole: amd64; SERIALCON=${SERIALCON}" "warn"
}
