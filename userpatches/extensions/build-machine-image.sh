function extension_prepare_config__build_machine_image() {
	display_alert "Target image will be a build machine" "${EXTENSION}" "info"
	export BUILD_KSRC=yes
}

function host_dependencies_ready__add_host_deps_to_package_list_board() {
	display_alert "Adding build dependencies to board" "${EXTENSION}" "info"
	# FINAL_HOST_DEPS is exported by the host_dependencies_ready() hook.
	export PACKAGE_LIST="${PACKAGE_LIST} ${FINAL_HOST_DEPS}"
}

post_install_kernel_debs__copy_kernel_sources_and_headers_to_rootfs() {
	display_alert "Adding kernel headers and source to BM's /root" "${EXTENSION}" "info"
	ls -la "${DEB_STORAGE}/${CHOSEN_KERNEL/image/headers}_${REVISION}_${ARCH}.deb"
	ls -la "${DEB_STORAGE}/${CHOSEN_KSRC}_${REVISION}_all.deb"
	cp -v "${DEB_STORAGE}/${CHOSEN_KERNEL/image/headers}_${REVISION}_${ARCH}.deb" "${SDCARD}"/usr/src
	cp -v "${DEB_STORAGE}/${CHOSEN_KSRC}_${REVISION}_all.deb" "${SDCARD}"/usr/src
}

function pre_umount_final_image__add_build_machine_suffix_to_version() {
	export version="${version}-armbian-bm"
}
