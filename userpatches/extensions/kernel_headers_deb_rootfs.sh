## Configuration
export COPY_HEADERS_DEB=yes # do copy the headers .deb to rootfs for easy later install?

# Copies a build linux-headers .deb inside the rootfs at /usr/src/
# Much faster than installing it on rootfs.
post_install_kernel_debs__copy_headers_deb_to_rootfs() {
	[[ "${COPY_HEADERS_DEB}" != "yes" ]] && return 0

	declare headers_deb="${CHOSEN_KERNEL/image/headers}_${REVISION}_${ARCH}.deb"
	if [[ -f "${DEB_STORAGE}/${headers_deb}" ]]; then
		display_alert "Including headers package in image" "/usr/src/${headers_deb}" "info"
		run_host_command_logged ls -lah "${DEB_STORAGE}/${headers_deb}"
		run_host_command_logged cp -vp "${DEB_STORAGE}/${headers_deb}" "${SDCARD}"/usr/src
	else
		display_alert "Headers package not found, will not be included in image" "${headers_deb}" "warn"
	fi

}
