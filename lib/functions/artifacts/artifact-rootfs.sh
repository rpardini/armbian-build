function artifact_rootfs_prepare_version() {
	artifact_version="undetermined"        # outer scope
	artifact_version_reason="undetermined" # outer scope

	assert_requires_aggregation # Bombs if aggregation has not run

	declare -g rootfs_cache_id="none_yet"

	#LOG_SECTION="prepare_rootfs_build_params_and_trap" do_with_logging
	prepare_rootfs_build_params_and_trap

	#LOG_SECTION="calculate_rootfs_cache_id" do_with_logging
	calculate_rootfs_cache_id # sets rootfs_cache_id

	display_alert "Going to build rootfs" "packages_hash: '${packages_hash:-}' cache_type: '${cache_type:-}' rootfs_cache_id: '${rootfs_cache_id}'" "info"

	# @TODO: ROOT_FS_CREATE_VERSION is only here for compatibility with legacy code, which requires the exact amount of dashes in the filename

	declare -a reasons=(
		"arch \"${ARCH}\"" "release \"${RELEASE}\"" "type \"${cache_type}\""
		"cache_id \"${rootfs_cache_id}\"" "legacy version \"${ROOT_FS_CREATE_VERSION}\""
	)

	# @TODO: "rootfs_cache_id" contains "cache_type", split so we don't repeat ourselves
	# @TODO: gotta include the extensions rootfs-modifying id to cache_type...

	# outer scope
	artifact_version="${rootfs_cache_id}"
	artifact_version_reason="${reasons[*]}"
	artifact_name="rootfs/rootfs-${ARCH}/rootfs-${ARCH}-${RELEASE}-${cache_type}"
	artifact_type="tar.zst"
	artifact_base_dir="${SRC}/cache/rootfs"
	artifact_final_file="${SRC}/cache/rootfs/${ARCH}-${RELEASE}-${rootfs_cache_id}-${ROOT_FS_CREATE_VERSION}.tar.zst"

	return 0
}

function artifact_rootfs_build_from_sources() {
	# "rootfs" CLI skips over a lot goes straight to create the rootfs. It doesn't check cache etc.
	LOG_SECTION="create_new_rootfs_cache" do_with_logging create_new_rootfs_cache

	reset_uid_owner "${BUILT_ROOTFS_CACHE_FILE}"

	display_alert "Rootfs build complete" "${BUILT_ROOTFS_CACHE_NAME}" "info"
	display_alert "Rootfs build complete, file: " "${BUILT_ROOTFS_CACHE_FILE}" "info"
}

function artifact_rootfs_cli_adapter_pre_run() {
	declare -g ARMBIAN_COMMAND_REQUIRE_BASIC_DEPS="yes" # Require prepare_host_basic to run before the command.

	# "gimme root on a Linux machine"
	cli_standard_relaunch_docker_or_sudo
}

function artifact_rootfs_cli_adapter_config_prep() {
	declare -g ROOTFS_COMPRESSION_RATIO="${ROOTFS_COMPRESSION_RATIO:-"15"}" # default to Compress stronger when we make rootfs cache

	# If BOARD is set, use it to convert to an ARCH.
	if [[ -n ${BOARD} ]]; then
		display_alert "BOARD is set, converting to ARCH for rootfs building" "'BOARD=${BOARD}'" "warn"
		# Convert BOARD to ARCH; source the BOARD and FAMILY stuff
		LOG_SECTION="config_source_board_file" do_with_conditional_logging config_source_board_file
		LOG_SECTION="source_family_config_and_arch" do_with_conditional_logging source_family_config_and_arch
		display_alert "Done sourcing board file" "'${BOARD}' - arch: '${ARCH}'" "warn"
	fi

	declare -a vars_need_to_be_set=("RELEASE" "ARCH")
	# loop through all vars and check if they are not set and bomb out if so
	for var in "${vars_need_to_be_set[@]}"; do
		if [[ -z ${!var} ]]; then
			exit_with_error "Param '${var}' is not set but needs to be set for rootfs CLI."
		fi
	done

	declare -r __wanted_rootfs_arch="${ARCH}"
	declare -g -r RELEASE="${RELEASE}" # make readonly for finding who tries to change it
	declare -g -r NEEDS_BINFMT="yes"   # make sure binfmts are installed during prepare_host_interactive

	# prep_conf_main_only_rootfs_ni is prep_conf_main_only_rootfs_ni() + mark_aggregation_required_in_default_build_start()
	prep_conf_main_only_rootfs_ni < /dev/null # no stdin for this, so it bombs if tries to be interactive.

	declare -g -r ARCH="${ARCH}" # make readonly for finding who tries to change it
	if [[ "${ARCH}" != "${__wanted_rootfs_arch}" ]]; then
		exit_with_error "Param 'ARCH' is set to '${ARCH}' after config, but different from wanted '${__wanted_rootfs_arch}'"
	fi

	declare -g ROOT_FS_CREATE_VERSION
	if [[ -z ${ROOT_FS_CREATE_VERSION} ]]; then
		ROOT_FS_CREATE_VERSION="$(date --utc +"%Y%m%d")"
		display_alert "ROOT_FS_CREATE_VERSION is not set, defaulting to current date" "ROOT_FS_CREATE_VERSION=${ROOT_FS_CREATE_VERSION}" "info"
	else
		display_alert "ROOT_FS_CREATE_VERSION is set" "ROOT_FS_CREATE_VERSION=${ROOT_FS_CREATE_VERSION}" "info"
	fi
}

function artifact_rootfs_get_default_oci_target() {
	artifact_oci_target_base="ghcr.io/rpardini/armbian-release/"
}

function artifact_rootfs_is_available_in_local_cache() {
	is_artifact_available_in_local_cache
}

function artifact_rootfs_is_available_in_remote_cache() {
	is_artifact_available_in_remote_cache
}

function artifact_rootfs_obtain_from_remote_cache() {
	obtain_artifact_from_remote_cache
}

function artifact_rootfs_deploy_to_remote_cache() {
	upload_artifact_to_oci
}
