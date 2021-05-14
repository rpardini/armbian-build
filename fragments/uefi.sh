# Hooks
user_config__add_uefi_grub_packages() {
	export IMAGE_PARTITION_TABLE="gpt" # GPT partition table is essential for many UEFI-like implementations, eg Apple+Intel stuff.
	export UEFISIZE=256                # in MiB - grub EFI is tiny - but some EFI BIOSes ignore small too small EFI partitions
	export BOOTSIZE=0                  # No separate /boot when using UEFI.

	# This works for Ubuntu hirsute at least, but may be different for others, PR it in when you try Debian
	local UEFI_PACKAGES="os-prober grub-efi-amd64 grub-efi grub-efi-amd64-bin efibootmgr efivar"

	# Include in PACKAGE_LIST, so it gets cached in rootfs
	export PACKAGE_LIST="${PACKAGE_LIST} ${UEFI_PACKAGES}"
}

# @TODO: need a way to disable original initramfs creation, since that is a waste, I need to rebuild for all kernels anyway.

pre_umount_final_image__install_grub() {
	configure_grub
	local chroot_target=$MOUNT
	display_alert "Installing" "GRUB EFI" "info"

	# disarm bomb that was planted by the bsp. @TODO: move to bsp tweaks hook
	rm -f "$MOUNT"/etc/initramfs/post-update.d/99-uboot

	# getting rid of the dtb package is hard. for now just zap it, otherwise update-grub goes bananas
	rm -rf "$MOUNT"/boot/dtb* || true

	local install_grub_cmdline="update-initramfs -c -k all && update-grub && grub-install --no-nvram --removable" # nvram is global to the host, even across chroot. take care.
	display_alert "Installing Grub EFI..." "for all kernels" ""
	mount_chroot "$chroot_target/" # this already handles /boot/efi which is required for it to work.
	chroot "$chroot_target" /bin/bash -c "$install_grub_cmdline" >>"$DEST"/debug/install.log 2>&1 || {
		exit_with_error "${install_grub_cmdline} failed!"
	}

	local root_uuid
	root_uuid=$(blkid -s UUID -o value "${LOOP}p2") # get the uuid of the root partition

	# Create /boot/efi/EFI/BOOT/grub.cfg (EFI/ESP) which will load /boot/grub/grub.cfg (in the rootfs, generated by update-grub)
	cat <<grubEfiCfg >"${MOUNT}"/boot/efi/EFI/BOOT/grub.cfg
search.fs_uuid ${root_uuid} root
set prefix=(\$root)'/boot/grub'
configfile \$prefix/grub.cfg
grubEfiCfg

	## tree "${MOUNT}"/boot
	## echo "grub: "
	## cat "${MOUNT}"/boot/efi/EFI/BOOT/grub.cfg
	## echo "grub.cfg: "
	## cat "${MOUNT}"/boot/grub/grub.cfg | grep "\/boot"

	umount_chroot "$chroot_target/"

}

configure_grub() {
	cat <<EOF >>"${MOUNT}"/etc/default/grub.d/armbian-sd-uefi.cfg
GRUB_CMDLINE_LINUX_DEFAULT="console=ttyS0"               # extra Kernel cmdline is configured here
GRUB_TIMEOUT_STYLE=menu                                  # Show the menu with Kernel options (Armbian or -generic)...
GRUB_TIMEOUT=5                                           # ... for 5 seconds, then boot the Armbian default.
GRUB_DISTRIBUTOR="Armbian"                               # On GRUB menu will show up as "Armbian GNU/Linux" (will show up in some UEFI BIOS boot menu (F8?) as "armbian", not on others)
GRUB_DISABLE_OS_PROBER=true                              # Disable OS probing, since this is a SD card. Otherwise would include entries to boot the build host's other OSes
EOF
}
