function artifact_kernel_cli_adapter_pre_run() {
	declare -g ARMBIAN_COMMAND_REQUIRE_BASIC_DEPS="yes" # Require prepare_host_basic to run before the command.

	# "gimme root on a Linux machine"
	cli_standard_relaunch_docker_or_sudo
}

function artifact_kernel_cli_adapter_config_prep() {
	declare KERNEL_ONLY="yes"                             # @TODO: this is a hack, for the board/family code's benefit...
	use_board="yes" prep_conf_main_minimal_ni < /dev/null # no stdin for this, so it bombs if tries to be interactive.
}

# This is run in a logging section.
function artifact_kernel_prepare_version() {
	artifact_version="undetermined"        # outer scope
	artifact_version_reason="undetermined" # outer scope

	# Prepare the version, "sans-repos": just the armbian/build repo contents are available.
	# It is OK to reach out to the internet for a curl or ls-remote, but not for a git clone.

	# - Given KERNELSOURCE and KERNELBRANCH, get:
	#    - SHA1 of the commit (this is generic... and used for other pkgs)
	#    - The first 10 lines of the root Makefile at that commit (cached lookup, same SHA1=same Makefile)
	#      - This gives us the full version plus codename.
	#    - Make sure this is sane, ref KERNEL_MAJOR_MINOR.
	# - Get the drivers patch hash (given LINUXFAMILY and the vX.Z.Y version)
	# - Get the kernel patches hash. (could just hash the KERNELPATCHDIR non-disabled contents, or use Python patching proper?)
	# - Get the kernel .config hash, composed of
	#    - KERNELCONFIG? .config hash
	#    - extensions mechanism, have an array of hashes that is then hashed together.
	# - Hash of the relevant lib/ bash sources involved, say compilation-kernel*.sh etc
	# All those produce a version string like:
	# 6.1.8-<4-digit-SHA1>_<4_digit_drivers>-<4_digit_patches>-<4_digit_config>-<4_digit_libs>
	# 6.2-rc5-a0b1-c2d3-e4f5-g6h7-i8j9

	debug_var BRANCH
	debug_var REVISION
	debug_var KERNELSOURCE
	debug_var KERNELBRANCH
	debug_var LINUXFAMILY
	debug_var BOARDFAMILY
	debug_var KERNEL_MAJOR_MINOR
	debug_var KERNELPATCHDIR

	declare short_hash_size=4

	declare -A GIT_INFO=([GIT_SOURCE]="${KERNELSOURCE}" [GIT_REF]="${KERNELBRANCH}")
	run_memoized GIT_INFO "git2info" memoized_git_ref_to_info "include_makefile_body"
	debug_dict GIT_INFO

	declare short_sha1="${GIT_INFO[SHA1]:0:${short_hash_size}}"

	# get the drivers hash...
	declare kernel_drivers_patch_hash
	do_with_hooks kernel_drivers_create_patches_hash_only
	declare kernel_drivers_hash_short="${kernel_drivers_patch_hash:0:${short_hash_size}}"

	# get the kernel patches hash...
	# @TODO: why not just delegate this to the python patching, with some "dry-run" / hash-only option?
	declare patches_hash="undetermined"
	declare hash_files="undetermined"
	calculate_hash_for_all_files_in_dirs "${SRC}/patch/kernel/${KERNELPATCHDIR}" "${USERPATCHES_PATH}/kernel/${KERNELPATCHDIR}"
	patches_hash="${hash_files}"
	declare kernel_patches_hash_short="${patches_hash:0:${short_hash_size}}"

	# get the .config hash... also userpatches...
	declare kernel_config_source_filename="" # which actual .config was used?
	prepare_kernel_config_core_or_userpatches
	declare hash_files="undetermined"
	calculate_hash_for_files "${kernel_config_source_filename}"
	config_hash="${hash_files}"
	declare config_hash_short="${config_hash:0:${short_hash_size}}"

	# @TODO: get the extensions' .config modyfing hashes...
	# @TODO: include the compiler version? host release?

	# get the hashes of the lib/ bash sources involved...
	declare hash_files="undetermined"
	calculate_hash_for_files "${SRC}"/lib/functions/compilation/kernel*.sh # maybe also this file, "${SRC}"/lib/functions/artifacts/kernel.sh
	declare bash_hash="${hash_files}"
	declare bash_hash_short="${bash_hash:0:${short_hash_size}}"

	# outer scope
	artifact_version="${GIT_INFO[MAKEFILE_VERSION]}-S${short_sha1}-D${kernel_drivers_hash_short}-P${kernel_patches_hash_short}-C${config_hash_short}-B${bash_hash_short}"
	# @TODO: validate it begins with a digit, and is at max X chars long.

	declare -a reasons=(
		"version \"${GIT_INFO[MAKEFILE_FULL_VERSION]}\""
		"git revision \"${GIT_INFO[SHA1]}\""
		"codename \"${GIT_INFO[MAKEFILE_CODENAME]}\""
		"drivers hash \"${kernel_drivers_patch_hash}\""
		"patches hash \"${patches_hash}\""
		".config hash \"${config_hash}\""
		"framework bash hash \"${bash_hash}\""
	)

	artifact_version_reason="${reasons[*]}" # outer scope

	# map what "compile_kernel()" will produce - legacy deb names and versions
	artifact_map_versions_legacy=(
		["linux-image-${BRANCH}-${LINUXFAMILY}"]="${REVISION}_${ARCH}"
		["linux-dtb-${BRANCH}-${LINUXFAMILY}"]="${REVISION}_${ARCH}"
		["linux-headers-${BRANCH}-${LINUXFAMILY}"]="${REVISION}_${ARCH}"
	)

	# now, one for each file in the artifact... we've 3 packages produced, all the same version
	artifact_map_versions=(
		["linux-image-${BRANCH}-${LINUXFAMILY}"]="${artifact_version}_${ARCH}"
		["linux-dtb-${BRANCH}-${LINUXFAMILY}"]="${artifact_version}_${ARCH}"
		["linux-headers-${BRANCH}-${LINUXFAMILY}"]="${artifact_version}_${ARCH}"
	)

	artifact_name="kernel-${LINUXFAMILY}-${BRANCH}"
	artifact_type="deb-tar" # this triggers processing of .deb files in the maps to produce a tarball
	artifact_final_file="${DEST}/debs/${artifact_name}_${artifact_version}.tar"

	return 0
}

function artifact_kernel_is_available_in_local_cache() {
	is_artifact_available_in_local_cache
}

function artifact_kernel_is_available_in_remote_cache() {
	is_artifact_available_in_remote_cache
}

function artifact_kernel_obtain_from_remote_cache() {
	obtain_artifact_from_remote_cache
}

function artifact_kernel_build_from_sources() {
	compile_kernel
	capture_rename_legacy_debs_into_artifacts
}

function artifact_kernel_deploy_to_remote_cache() {
	upload_artifact_to_oci
}
