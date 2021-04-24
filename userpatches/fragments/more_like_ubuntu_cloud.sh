# This is run inside the chroot building the bsp (armbian-config) package.
# Stuff done here will persist across reinstalls of the bsp package.
# Stuff done in image_tweaks_pre_customize() only applies to rootfs on the SD card.
config_tweaks_bsp__be_more_like_ubuntu_cloud() {
	# remove a bunch of stuff from bsp so it behaves more like regular ubuntu
	rm -f "$destination"/etc/apt/apt.conf.d/02-armbian-compress-indexes

	rm -f "$destination"/etc/cron.d/armbian-truncate-logs
	rm -f "$destination"/etc/cron.d/armbian-updates
	rm -f "$destination"/etc/cron.daily/armbian-ram-logging

	rm -f "$destination"/etc/default/armbian-ramlog.dpkg-dist
	rm -f "$destination"/etc/default/armbian-zram-config.dpkg-dist

	rm -f "$destination"/etc/profile.d/armbian-check-first-login.sh

	rm -f "$destination"/etc/lib/systemd/system/systemd-journald.service.d/override.conf

	rm -f "$destination"/etc/lib/systemd/system/armbian-firstrun.service
	rm -f "$destination"/etc/lib/systemd/system/armbian-ramlog.service
	rm -f "$destination"/etc/lib/systemd/system/armbian-resize-filesystem.service
	rm -f "$destination"/etc/lib/systemd/system/armbian-zram-config.service

	rm -f "$destination"/lib/systemd/system/armbian-firstrun-config.service
	rm -f "$destination"/lib/systemd/system/armbian-firstrun.service
	rm -f "$destination"/lib/systemd/system/armbian-resize-filesystem.service
	rm -f "$destination"/lib/systemd/system/armbian-zram-config.service
	rm -f "$destination"/lib/systemd/system/armbian-disable-autologin.service
	rm -f "$destination"/lib/systemd/system/armbian-ramlog.service

	# echo "tree for destination in config_tweaks_bsp"
	# tree $destination
}
