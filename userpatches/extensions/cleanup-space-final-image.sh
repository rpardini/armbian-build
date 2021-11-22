add_host_dependencies__ovf_host_deps() {
	export EXTRA_BUILD_DEPS="${EXTRA_BUILD_DEPS} zerofree"
}

function post_customize_image__998_cleanup_apt_stuff() {
	display_alert "Cleaning up apt package lists and cache" "cleanup-space-final-image" "info"
	chroot_sdcard "apt-get clean && rm -rf /var/lib/apt/lists"

	declare -a too_big_firmware=("netronome" "qcom" "mrv" "qed" "mellanox") # maybe: "amdgpu" "radeon" but I have an AMD GPU.
	for big_firm in "${too_big_firmware[@]}"; do
		local firm_dir="${SDCARD}/usr/lib/firmware/${big_firm}"
		if [[ -d "${firm_dir}" ]]; then
			display_alert "Cleaning too-big firmware" "${big_firm}" "info"
			rm -rf "${firm_dir}"
		fi
	done
}

# Zerofree the image early after umounting it
function post_umount_final_image__200_zerofree() {
	display_alert "Zerofreeing image" "cleanup-space-final-image" "info"
	# I'm too lazy. Just zerofree all partitions in the loop
	declare -i ONE_WORKED=0
	for partDev in "${LOOP}"p?; do
		display_alert "Zerofreeing partition ${partDev}" "cleanup-space-final-image" "info"
		run_host_command_logged zerofree "${partDev}" && ONE_WORKED=1
	done
	if [[ $ONE_WORKED -lt 1 ]]; then
		display_alert "Zerofree failed" "cleanup-space-final-image" "err"
	fi
}

function pre_umount_final_image__999_show_space_usage() {
	display_alert "Calculating used space in image" "cleanup-space-final-image" "info"
	run_host_command_logged "cd ${MOUNT} && " du -h -d 4 -x "." "| sort -h | tail -20"
}
