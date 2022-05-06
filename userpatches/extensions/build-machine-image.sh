function extension_prepare_config__build_machine_image() {
	display_alert "Target image will be a build machine" "${EXTENSION}" "info"
	#export BUILD_KSRC=yes
}

function host_dependencies_ready__add_host_deps_to_package_list_board() {
	display_alert "Adding build dependencies for" "${EXTENSION}" "info"
	# FINAL_HOST_DEPS is exported by the host_dependencies_ready() hook.
	# display_alert "Adding to package list, for build machine" "${FINAL_HOST_DEPS}" "debug"

	# basic deps needed for building, from basic-deps.sh
	local basic_deps="uuid-runtime dialog psmisc acl curl gnupg gawk"

	# This is run late, when the package list is already populated/aggregated.
	# Add directly to the final list and hope for the best.
	export PACKAGE_MAIN_LIST="${PACKAGE_MAIN_LIST} ${FINAL_HOST_DEPS} ${basic_deps}"
}

post_install_kernel_debs__copy_kernel_sources_and_headers_to_rootfs() {
	display_alert "Adding source to BM's /root" "${EXTENSION}" "info"
	declare source_deb="${CHOSEN_KSRC}_${REVISION}_all.deb"
	if [[ -f "${DEB_STORAGE}/${source_deb}" ]]; then
		run_host_command_logged ls -lah "${DEB_STORAGE}/${source_deb}"
		run_host_command_logged cp -vp "${DEB_STORAGE}/${source_deb}" "${SDCARD}"/usr/src
	else
		display_alert "Can't find kernel source deb, wont be included in BM image" "${source_deb}" "warn"
	fi
}

function pre_umount_final_image__add_build_machine_suffix_to_version() {
	export version="${version}-armbian-bm"
}
