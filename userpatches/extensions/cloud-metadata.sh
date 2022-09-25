enable_extension "image-output-qcow2" # Output should be qcow2

function user_config__metadata_cloud_config_common() {
	display_alert "Configuring cloud-init for real metadata" "cloud-metadata: common" "info"
	export UEFI_EXPORT_KERNEL_INITRD="yes"     # Export the initrd and kernel for meta, just like DKB
	export CLOUD_INIT_EXTRA_VERSION="metadata" # For the 'real cloud' version, we skip the c-i config and add a version to the build
	export SKIP_CLOUD_INIT_CONFIG="yes"
}

function user_config__metadata_cloud_config_arm64() {
	[[ "${ARCH}" != "arm64" ]] && return 0
	display_alert "Configuring cloud-init for arm64 metadata" "cloud-metadata: arm64" "info"
	export SERIALCON="ttyAMA0" # For ORACLE cloud vm; others with serial console
}

function user_config__metadata_cloud_config_amd64_x86() {
	[[ "${ARCH}" != "amd64" ]] && return 0
	display_alert "Configuring cloud-init for amd64 metadata" "cloud-metadata: amd64" "info"
	export SERIALCON="ttyS0" # For Oracle VMs on AMD micro stuff; AWS with serial console, etc.
}
