function uboot_main_patching_python() {
	prepare_pip_packages_for_python_tools

	temp_file_for_output="$(mktemp)" # Get a temporary file for the output.
	# array with all parameters; will be auto-quoted by bash's @Q modifier below
	declare -a params_quoted=(
		"LOG_DEBUG=${SHOW_DEBUG}"                             # Logging level for python.
		"SRC=${SRC}"                                          # Armbian root
		"OUTPUT=${temp_file_for_output}"                      # Output file for the python script.
		"ASSET_LOG_BASE=$(print_current_asset_log_base_file)" # base file name for the asset log; to write .md summaries.
		"GIT_WORK_DIR=${uboot_work_dir}"                      # "Where to apply patches?"
		"PATCH_TYPE=u-boot"                                   # or, u-boot, or, atf
		"PATCH_DIRS_TO_APPLY=${BOOTPATCHDIR}"                 # A space-separated list of directories to apply...
		"BOARD=${BOARD}"                                      # BOARD is needed for the patchset selection logic; mostly for u-boot.
		"TARGET=${target_patchdir}"                           # TARGET is need for u-boot's SPI/SATA etc selection logic
		"USERPATCHES_PATH=${USERPATCHES_PATH}"                # Needed to find the userpatches.
	)
	display_alert "Calling Python patching script" "for u-boot target" "info"
	run_host_command_logged env -i "${params_quoted[@]@Q}" python3 "${SRC}/lib/tools/patching.py" "||" true
	#run_host_command_logged cat "${temp_file_for_output}"
	# shellcheck disable=SC1090
	#source "${temp_file_for_output}" # SOURCE IT!
	run_host_command_logged rm -f "${temp_file_for_output}"
	return 0
}
