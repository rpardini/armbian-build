enable_extension "image-output-qcow2" # Output should be qcow2
enable_extension "cloud-metadata"

function user_config__metadata_qcow_initrd() {
	display_alert "Configuring cloud-init" "cloud-metadata-qcow2-initrd: initrd & qcow2" "info"
	declare -g UEFI_EXPORT_KERNEL_INITRD="yes" # Export the initrd and kernel for meta, just like DKB
}
