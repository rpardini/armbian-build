# update_initramfs
#
# this should be invoked as late as possible for any modifications by
# customize_image (userpatches) and prepare_partitions to be reflected in the
# final initramfs
#
# especially, this needs to be invoked after /etc/crypttab has been created
# for cryptroot-unlock to work:
# https://serverfault.com/questions/907254/cryproot-unlock-with-dropbear-timeout-while-waiting-for-askpass
#
# since Debian buster, it has to be called within create_image() on the $MOUNT
# path instead of $SDCARD (which can be a tmpfs and breaks cryptsetup-initramfs).
# see: https://github.com/armbian/build/issues/1584
update_initramfs() {
	local chroot_target=$1
	local target_dir="$(find "${chroot_target}/lib/modules"/ -maxdepth 1 -type d -name "*${VER}*")"
	local initrd_kern_ver initrd_file initrd_cache_key initrd_cache_file_path initrd_hash
	if [ "$target_dir" != "" ]; then
		initrd_kern_ver="$(basename "$target_dir")"
		initrd_file="${chroot_target}/boot/initrd.img-${initrd_kern_ver}"

		update_initramfs_cmd="update-initramfs -uv -k ${initrd_kern_ver}"
	else
		exit_with_error "No kernel installed for the version" "${VER}"
	fi

	# Caching.
	# Find all modules and all firmware in the target.
	# Find all initramfs configuration in /etc
	# Find all bash, cpio and gzip binaries in /bin
	# Hash the contents of them all.
	# If there's a match, use the cache.

	display_alert "computing initrd cache hash" "${chroot_target}" "debug"
	initrd_hash="$(find "${target_dir}" "${chroot_target}/usr/bin/bash" "${chroot_target}/etc/initramfs" "${chroot_target}/etc/initramfs-tools" -type f | parallel -X md5sum | md5sum | cut -d ' ' -f 1)"
	initrd_cache_key="initrd.img-${initrd_kern_ver}-${initrd_hash}"
	mkdir -p "${SRC}/cache/initrd"
	initrd_cache_file_path="${SRC}/cache/initrd/${initrd_cache_key}"
	display_alert "initrd cache hash" "${initrd_hash}" "debug"

	if [[ -f "${initrd_cache_file_path}" ]]; then
		display_alert "initrd cache HIT" "${initrd_cache_key}" "info"
		run_host_command_logged cp -pv "${initrd_cache_file_path}" "${initrd_file}"
	else
		display_alert "Cache miss for initrd cache" "${initrd_cache_key}" "debug"

		display_alert "Updating initramfs..." "$update_initramfs_cmd" ""
		cp "/usr/bin/$QEMU_BINARY" "$chroot_target/usr/bin"/
		mount_chroot "$chroot_target/"

		local logging_filter="2>&1 | grep --line-buffered -v -e '.xz' -e 'ORDER ignored' -e 'Adding binary ' -e 'Adding module ' -e 'Adding firmware ' "
		chroot_custom_long_running "$chroot_target" "$update_initramfs_cmd" "${logging_filter}"
		display_alert "Updated initramfs." "${update_initramfs_cmd}" "info"

		display_alert "Storing initrd in cache" "${initrd_cache_key}" "debug"
		# @TODO: clean old cache files so they don't pile up forever.
		run_host_command_logged cp -pv "${initrd_file}" "${initrd_cache_file_path}"

		display_alert "Re-enabling" "initramfs-tools hook for kernel"
		chroot_custom "$chroot_target" chmod -v +x /etc/kernel/postinst.d/initramfs-tools

		umount_chroot "$chroot_target/"
		rm "$chroot_target/usr/bin/$QEMU_BINARY"

	fi

}
