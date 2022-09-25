enable_extension "image-output-qcow2" # Output should be qcow2
enable_extension "cloud-metadata"
enable_extension "nofirmware"

function user_config__950_serialconsole_vz_cloud_config_arm64() {
	[[ "${ARCH}" != "arm64" ]] && return 0
	[[ "${BOARDFAMILY}" != uefi-* ]] && return 0
	declare -g SERIALCON="hvc0" # virtio console
	display_alert "Configuring cloud-init for arm64 serialconsole" "cloud-serialconsole: arm64; SERIALCON=${SERIALCON}" "warn"
}
