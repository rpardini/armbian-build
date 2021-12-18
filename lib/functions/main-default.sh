# Some utility functions
branch2dir() {
	[[ "${1}" == "head" ]] && echo "HEAD" || echo "${1##*:}"
}

cleanup_list() {
	local varname="${1}"
	local list_to_clean="${!varname}"
	list_to_clean="${list_to_clean#"${list_to_clean%%[![:space:]]*}"}"
	list_to_clean="${list_to_clean%"${list_to_clean##*[![:space:]]}"}"
	echo ${list_to_clean}
}

# This does NOT run under the logging manager. We should invoke the do_with_logging wrapper for
# strategic parts of this. Attention: build_rootfs_image does it's own logging, so just let that be.
main_default_build() {
	start=$(date +%s)
	# Check and install dependencies, directory structure and settings
	# The OFFLINE_WORK variable inside the function
	LOG_SECTION="prepare_host" do_with_logging prepare_host

	[[ "${JUST_INIT}" == "yes" ]] && exit 0

	[[ $CLEAN_LEVEL == *sources* ]] && cleaning "sources"

	# ignore updates help on building all images - for internal purposes
	if [[ $IGNORE_UPDATES != yes ]]; then
		fetch_sources_kernel_uboot_atf

		fetch_and_build_host_tools

		for option in $(tr ',' ' ' <<< "$CLEAN_LEVEL"); do
			[[ $option != sources ]] && cleaning "$option"
		done
	fi

	# Don't build u-boot at all if the BOOTCONFIG is 'none'.
	if [[ "${BOOTCONFIG}" != "none" ]]; then
		# Compile u-boot if packed .deb does not exist or use the one from repository
		if [[ ! -f "${DEB_STORAGE}"/${CHOSEN_UBOOT}_${REVISION}_${ARCH}.deb ]]; then
			if [[ -n "${ATFSOURCE}" && "${REPOSITORY_INSTALL}" != *u-boot* ]]; then
				compile_atf
			fi
			[[ "${REPOSITORY_INSTALL}" != *u-boot* ]] && compile_uboot
		fi
	fi

	# Compile kernel if packed .deb does not exist or use the one from repository
	if [[ ! -f ${DEB_STORAGE}/${CHOSEN_KERNEL}_${REVISION}_${ARCH}.deb ]]; then
		export KDEB_CHANGELOG_DIST=$RELEASE
		[[ -n $KERNELSOURCE ]] && [[ "${REPOSITORY_INSTALL}" != *kernel* ]] && compile_kernel
	fi

	# Compile armbian-config if packed .deb does not exist or use the one from repository
	if [[ ! -f ${DEB_STORAGE}/armbian-config_${REVISION}_all.deb ]]; then
		[[ "${REPOSITORY_INSTALL}" != *armbian-config* ]] && compile_armbian-config
	fi

	# Compile armbian-zsh if packed .deb does not exist or use the one from repository
	if [[ ! -f ${DEB_STORAGE}/armbian-zsh_${REVISION}_all.deb ]]; then
		[[ "${REPOSITORY_INSTALL}" != *armbian-zsh* ]] && compile_armbian-zsh
	fi

	# Compile armbian-firmware if packed .deb does not exist or use the one from repository
	if ! ls "${DEB_STORAGE}/armbian-firmware_${REVISION}_all.deb" 1> /dev/null 2>&1 || ! ls "${DEB_STORAGE}/armbian-firmware-full_${REVISION}_all.deb" 1> /dev/null 2>&1; then

		if [[ "${REPOSITORY_INSTALL}" != *armbian-firmware* ]]; then
			if [[ "${INSTALL_ARMBIAN_FIRMWARE:-yes}" == "yes" ]]; then # Build firmware by default.
				# Build the light version of firmware package
				FULL="" REPLACE="-full" compile_firmware
				# Build the full version of firmware package
				FULL="-full" REPLACE="" compile_firmware
			fi
		fi
	fi

	overlayfs_wrapper "cleanup"

	# create board support package
	[[ -n $RELEASE && ! -f ${DEB_STORAGE}/$RELEASE/${BSP_CLI_PACKAGE_FULLNAME}.deb ]] && create_board_package

	# create desktop package
	[[ -n $RELEASE && $DESKTOP_ENVIRONMENT && ! -f ${DEB_STORAGE}/$RELEASE/${CHOSEN_DESKTOP}_${REVISION}_all.deb ]] && create_desktop_package
	[[ -n $RELEASE && $DESKTOP_ENVIRONMENT && ! -f ${DEB_STORAGE}/${RELEASE}/${BSP_DESKTOP_PACKAGE_FULLNAME}.deb ]] && create_bsp_desktop_package

	# build additional packages
	[[ $EXTERNAL_NEW == compile ]] && chroot_build_packages

	# end of kernel-only, so display what was built.
	if [[ $KERNEL_ONLY != yes ]]; then
		display_alert "Kernel build done" "@host" "target-reached"
		display_alert "Target directory" "${DEB_STORAGE}/" "info"
		display_alert "File name" "${CHOSEN_KERNEL}_${REVISION}_${ARCH}.deb" "info"
	fi

	# build rootfs, if not only kernel.
	if [[ $KERNEL_ONLY != yes ]]; then
		display_alert "Building image" "${BOARD}" "target-started"
		[[ $BSP_BUILD != yes ]] && build_rootfs_image # old debootstrap-ng. !!!LOGGING!!! handled inside, there are many sub-parts.
		display_alert "Done building image" "${BOARD}" "target-reached"
	fi

	call_extension_method "run_after_build" << 'RUN_AFTER_BUILD'
*hook for function to run after build, i.e. to change owner of `$SRC`*
Really one of the last hooks ever called. The build has ended. Congratulations.
- *NOTE:* this will run only if there were no errors during build process.
RUN_AFTER_BUILD

	end=$(date +%s)
	runtime=$(((end - start) / 60))
	display_alert "Runtime" "$runtime min" "info"

	# Make it easy to repeat build by displaying build options used
	[ "$(systemd-detect-virt)" == 'docker' ] && BUILD_CONFIG='docker'
	display_alert "Repeat Build Options" "./compile.sh ${BUILD_CONFIG} BOARD=${BOARD} BRANCH=${BRANCH} \
$([[ -n $RELEASE ]] && echo "RELEASE=${RELEASE} ")\
$([[ -n $BUILD_MINIMAL ]] && echo "BUILD_MINIMAL=${BUILD_MINIMAL} ")\
$([[ -n $BUILD_DESKTOP ]] && echo "BUILD_DESKTOP=${BUILD_DESKTOP} ")\
$([[ -n $KERNEL_ONLY ]] && echo "KERNEL_ONLY=${KERNEL_ONLY} ")\
$([[ -n $KERNEL_CONFIGURE ]] && echo "KERNEL_CONFIGURE=${KERNEL_CONFIGURE} ")\
$([[ -n $DESKTOP_ENVIRONMENT ]] && echo "DESKTOP_ENVIRONMENT=${DESKTOP_ENVIRONMENT} ")\
$([[ -n $DESKTOP_ENVIRONMENT_CONFIG_NAME ]] && echo "DESKTOP_ENVIRONMENT_CONFIG_NAME=${DESKTOP_ENVIRONMENT_CONFIG_NAME} ")\
$([[ -n $DESKTOP_APPGROUPS_SELECTED ]] && echo "DESKTOP_APPGROUPS_SELECTED=\"${DESKTOP_APPGROUPS_SELECTED}\" ")\
$([[ -n $DESKTOP_APT_FLAGS_SELECTED ]] && echo "DESKTOP_APT_FLAGS_SELECTED=\"${DESKTOP_APT_FLAGS_SELECTED}\" ")\
$([[ -n $COMPRESS_OUTPUTIMAGE ]] && echo "COMPRESS_OUTPUTIMAGE=${COMPRESS_OUTPUTIMAGE} ")\
" "ext"

}

function fetch_sources_kernel_uboot_atf() {
	display_alert "Downloading sources" "" "info"
	# fetch_from_repo <url> <dir> <ref> <subdir_flag>
	[[ -n $BOOTSOURCE ]] && fetch_from_repo "$BOOTSOURCE" "$BOOTDIR" "$BOOTBRANCH" "yes"
	[[ -n $KERNELSOURCE ]] && fetch_from_repo "$KERNELSOURCE" "$KERNELDIR" "$KERNELBRANCH" "yes"
	[[ -n $ATFSOURCE ]] && fetch_from_repo "$ATFSOURCE" "$ATFDIR" "$ATFBRANCH" "yes"

}

function fetch_and_build_host_tools() {
	call_extension_method "fetch_sources_tools" <<- 'FETCH_SOURCES_TOOLS'
		*fetch host-side sources needed for tools and build*
		Run early to fetch_from_repo or otherwise obtain sources for needed tools.
	FETCH_SOURCES_TOOLS

	call_extension_method "build_host_tools" <<- 'BUILD_HOST_TOOLS'
		*build needed tools for the build, host-side*
		After sources are fetched, build host-side tools needed for the build.
	BUILD_HOST_TOOLS

}
