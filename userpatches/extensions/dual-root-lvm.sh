# Config
export DUAL_ROOT_FIXED_IMAGE_SIZE_GB=16 # 16gb is default. change in user config
export RESCUE_E2IMG=""                  # What e2img will be deployed to the fake/rescue root?
export DUAL_ROOT_OUTPUT_E2IMG_ONLY=no   # Will obliterate output/images of other images. Use with care.

# Hooks
user_config__050_find_rescue_e2img_for_dual_root() {
	local rescueVersionPrefix="${VENDOR}_${REVISION}_${BOARD^}_${RELEASE}_${BRANCH}"
	# Warning: We're using ${DEST}/images here and not DESTIMG since we need a previous run results, so output/images directly.
	# shellcheck disable=SC2012
	export RESCUE_E2IMG=$(ls -1t "${DEST}/images/${rescueVersionPrefix}"*rescue*.e2img | head -1)
	if [[ ! -f "${RESCUE_E2IMG}" ]]; then
		display_alert "Rescue e2img" "Not found!" "err"
		exit 2
	else
		display_alert "Rescue e2img" "${RESCUE_E2IMG}" "info"
	fi

	export ROOTFS_IN_ROOTFS_EXPORT_ONLY=yes # We'll move it ourselves, thanks
}

prepare_image_size__900_add_second_root_fixed_size() {
	display_alert "DUAL ROOT uefi" "Total size ${DUAL_ROOT_FIXED_IMAGE_SIZE_GB}Gb (was: ${FIXED_IMAGE_SIZE}Mb)" ""
	export FIXED_IMAGE_SIZE=$((DUAL_ROOT_FIXED_IMAGE_SIZE_GB * 1024))
	export FAST_CREATE_IMAGE=yes      # This is very slow to zero out, use truncate
	export USE_HOOK_FOR_PARTITION=yes # Makes create_partition_table() hook be called instead of parted's.
}

create_partition_table__create_uefi_dual_root_partition() {
	# In this setup everything is fixed percentual sizes.
	# UEFI is fixed and steals from real root.
	# Real root is around 66% (2/3) of size
	# Rescue root is around 33% (1/3) of size
	# So calculate FIXED_IMAGE_SIZE accordingly.

	parted -s "${SDCARD}.raw" -- mkpart efi fat32 "0%" "256Mb"    # efi stuff #1
	parted -s "${SDCARD}.raw" -- mkpart root ext4 "256Mb" "67%"   # real root #2
	parted -s "${SDCARD}.raw" -- mkpart rescue ext4 "67%" "99%"   # rescue root, a little bigger #3
	parted -s "${SDCARD}.raw" -- mkpart thinlvm ext4 "99%" "100%" # lvm marker for extra data #4
	parted -s "${SDCARD}.raw" -- print || true

	# Transpose stuff.
	# transpose so EFI is in sda15 and root in sda1; requires sgdisk, parted cant do numbers
	sgdisk --transpose 1:15 "${SDCARD}.raw" &> /dev/null || echo "*** TRANSPOSE 1 FAILED"
	sgdisk --transpose 2:1 "${SDCARD}.raw" &> /dev/null || echo "*** TRANSPOSE 2 FAILED"
	sgdisk --transpose 3:2 "${SDCARD}.raw" &> /dev/null || echo "*** TRANSPOSE 3 FAILED"
	sgdisk --transpose 4:3 "${SDCARD}.raw" &> /dev/null || echo "*** TRANSPOSE 4 FAILED"
	# set the ESP (efi) flag on 15
	parted -s "${SDCARD}.raw" -- set 15 esp on
	# show it again to make sure
	parted -s "${SDCARD}.raw" -- print || true

	display_alert "DUAL ROOT uefi" "Partitions created." ""
}

# At the end of build, with everything already unmounted, we'll populate ${RESCUE_LOOP_PART} via RESCUE_E2IMG
config_post_umount_final_image__850_deploy_rescue() {
	RESCUE_LOOP_PART="${LOOP}p2" # See above, after transposing rescue is part num 2
	display_alert "DUAL ROOT uefi" "Will deploy ${RESCUE_E2IMG} to ${RESCUE_LOOP_PART}" ""
	e2image -rap "${RESCUE_E2IMG}" "${RESCUE_LOOP_PART}"
	fsck -y -f "${RESCUE_LOOP_PART}"
	sync
	resize2fs "${RESCUE_LOOP_PART}"
	sync
	fsck -y -f "${RESCUE_LOOP_PART}"
	sync

	# mount it, include the new rootfs inside it, umount
	mkdir -p "${SRC}"/.tmp/rescue
	mount "${RESCUE_LOOP_PART}" "${SRC}"/.tmp/rescue
	cp "${SRC}"/.tmp/rootfs.ext4.e2img "${SRC}"/.tmp/rescue/root/rootfs.ext4.e2img
	sync

	# Now, fix the EFI reference in etc/fstab, otherwise rescue won't boot correctly AT ALL.
	# For the rescue, the efi is mounted read-only, since it will delegate to the
	# non-rescue /boot/grub/grub.cfg, and running update-grub from rescue should do nothing.
	mv "${SRC}"/.tmp/rescue/etc/fstab "${SRC}"/.tmp/rescue/etc/fstab.orig
	# shellcheck disable=SC2002
	cat "${SRC}"/.tmp/rescue/etc/fstab.orig | grep -v "${UEFI_MOUNT_POINT}" > "${SRC}"/.tmp/rescue/etc/fstab
	echo "UUID=$(blkid -s UUID -o value "${LOOP}p15") ${UEFI_MOUNT_POINT} vfat ro,defaults 0 2" >> "${SRC}"/.tmp/rescue/etc/fstab
	sync

	umount "${SRC}"/.tmp/rescue
	sync

	rmdir "${SRC}"/.tmp/rescue

	# set this so e2img is not exported again by rootfs extension
	export ROOTFS_IN_ROOTFS_EXPORT_ONLY=no
	rm -f "${SRC}"/.tmp/rootfs.ext4.e2img # clean up after ourselves, better off in rootfs extension

	# Now, export the rescue partition itself as a e2img.
	display_alert "DUAL ROOT uefi" "Exporting final dualroot rootfs" ""
	e2image -rap "${RESCUE_LOOP_PART}" "${SRC}"/.tmp/rootfs.dualroot.ext4.e2img > /dev/null 2>&1
	sync

	display_alert "DUAL ROOT uefi" "finished" ""
}

post_build_image__850_export_dualroot_e2img_rootfs() {
	if [[ "${DUAL_ROOT_OUTPUT_E2IMG_ONLY}" == "yes" ]]; then
		display_alert "Cleaning other images" "dual-root" "info"
		rm -f "${DESTIMG}"/*.img "${DESTIMG}"/*.img.txt "${DESTIMG}"/*.e2img || true
	fi

	display_alert "Exporting dualroot e2img" "${DESTIMG}/${version}.e2img" "info"
	mv "${SRC}"/.tmp/rootfs.dualroot.ext4.e2img "${DESTIMG}/${version}.e2img"
}
