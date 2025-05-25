function user_config__metadata_cloud_config_common() {
	display_alert "Configuring cloud-init for real metadata" "cloud-metadata: common" "info"
	EXTRA_IMAGE_SUFFIXES+=("-metadata") # global array # For the 'real cloud' version, we skip the c-i config and add a version to the build
	declare -g SKIP_CLOUD_INIT_CONFIG="yes"
}

function user_config__metadata_cloud_config_arm64() {
	[[ "${ARCH}" != "arm64" ]] && return 0
	declare -g SERIALCON="ttyAMA0" # Default serial console for arm64
	display_alert "Configuring cloud-init for arm64 metadata" "cloud-metadata: arm64; SERIALCON=${SERIALCON}" "warn"
}

function user_config__metadata_cloud_config_amd64_x86() {
	[[ "${ARCH}" != "amd64" ]] && return 0
	declare -g SERIALCON="ttyS0" # Default serial console for amd64
	display_alert "Configuring cloud-init for amd64 metadata" "cloud-metadata: amd64; SERIALCON=${SERIALCON}" "warn"
}
