function user_config__900_no_firmware() {
	display_alert "Disabling firmware" "nofirmware: Disable firmware inclusion" "warn"
	declare -g -r INSTALL_ARMBIAN_FIRMWARE=no
}
