# This extension enables cloud-init.
# It sets up in a way that the user-data, meta-data and network-config reside in /boot (CLOUD_INIT_CONFIG_LOCATION)
# it can be used to setup users, passwords, ssh keys, install packages, install and delegate to ansible, etc.
# cloud providers allow setting user-data, but provide network-config and meta-data themselves; here we try
function extension_prepare_config__950_prepare_cloud_init() { # do it very late so others can set their stuff first
	# Config for cloud-init.
	export SKIP_CLOUD_INIT_CONFIG="${SKIP_CLOUD_INIT_CONFIG:-no}"               # if yes, installs but does not configure anything.
	export CLOUD_INIT_USER_DATA_URL="${CLOUD_INIT_USER_DATA_URL:-files}"        # "files" to use config files, or an URL to go straight to it
	export CLOUD_INIT_INSTANCE_ID="${CLOUD_INIT_INSTANCE_ID:-armbian-${BOARD}}" # "files" to use config files, or an URL to go straight to it
	export CLOUD_INIT_CONFIG_LOCATION="${CLOUD_INIT_CONFIG_LOCATION:-/boot}"    # where on the sdcard c-i will look for user-data, network-config, meta-data files
	export CLOUD_INIT_EXTRA_VERSION="${CLOUD_INIT_EXTRA_VERSION:-}"             # extra stuff to be added to version string
	export CLOUD_INIT_USE_NETPLAN="${CLOUD_INIT_USE_NETPLAN:-yes}"              # use netplan.io and the systemd/networkd renderer.

	# Default to using e* devices with dhcp, but not wait for them, so user-data needs to be local-only
	# Change to eth0-dhcp-wait to use https:// includes in user-data, or to something else for non-ethernet devices
	export CLOUD_INIT_NET_CONFIG_FILE="${CLOUD_INIT_NET_CONFIG_FILE:-eth0-dhcp}"
}

# not so early hook
extension_prepare_config__990_late_finish_cloud_init_config() {
	display_alert "Enabling cloud-init for" "${DISTRIBUTION}" "info"
	export EXTRA_BSP_NAME="${EXTRA_BSP_NAME}-cloud" # Unique bsp name for this extension: more like ubuntu cloud

	# Sanity check: a "cloud desktop" would make absolutely no sense.
	if [[ "${BUILD_DESKTOP}" == "yes" ]]; then
		exit_with_error "Cloud-init does not make sense with a desktop build."
	fi

	export CLOUD_INIT_REMOVE_IFUPDOWN="yes"
	if [[ "${DISTRIBUTION}" == "Debian" ]] && [[ "${CLOUD_INIT_USE_NETPLAN}" == "yes" ]]; then
		display_alert "${DISTRIBUTION} requires ifupdown for cloud-init" "${DISTRIBUTION}" "wrn"
		export CLOUD_INIT_REMOVE_IFUPDOWN="no"
	fi

	local CLOUD_INIT_NETWORK_PACKAGE_INSTALL=""
	local CLOUD_INIT_NETWORK_PACKAGE_REMOVE=""
	if [[ "${CLOUD_INIT_USE_NETPLAN}" == "yes" ]]; then
		if [[ "${CLOUD_INIT_REMOVE_IFUPDOWN}" == "yes" ]]; then
			display_alert "Using netplan.io in place of ifupdown" "${DISTRIBUTION}" "info"
			CLOUD_INIT_NETWORK_PACKAGE_INSTALL="netplan.io"
			CLOUD_INIT_NETWORK_PACKAGE_REMOVE="ifupdown ifenslave resolvconf"
			export DEBOOTSTRAP_LIST="${DEBOOTSTRAP_LIST//ifupdown/netplan.io}" # Replace ifupdown with netplan during debootstrap.
		else
			display_alert "Using netplan.io + ifupdown" "${DISTRIBUTION}" "info"
			CLOUD_INIT_NETWORK_PACKAGE_INSTALL="netplan.io"
			CLOUD_INIT_NETWORK_PACKAGE_REMOVE="ifenslave resolvconf"
			#export DEBOOTSTRAP_LIST="${DEBOOTSTRAP_LIST} netplan.io}" # ifupdown + netplan
		fi
	fi

	CLOUD_INIT_PKGS="cloud-init cloud-initramfs-growroot eatmydata curl tree ${CLOUD_INIT_NETWORK_PACKAGE_INSTALL}"
	EXTRA_WANTED_PACKAGES="lvm2 thin-provisioning-tools systemd-timesyncd" # networkd-dispatcher

	# Release specific packages; @TODO: needed?
	if [[ "${DISTRIBUTION}" == "Ubuntu" ]]; then
		export DEBOOTSTRAP_COMPONENTS="main,universe"

		if [[ "${RELEASE}" == "kinetic" ]]; then
			display_alert "Hack for Ubuntu Kinetic" "${DISTRIBUTION} ${RELEASE} split systemd-resolved from systemd" "wrn"
			EXTRA_WANTED_PACKAGES="${EXTRA_WANTED_PACKAGES} systemd-resolved"
		fi
	fi

	# Enable cloud-init; this changes bring-up process radically.
	export PACKAGE_LIST="${PACKAGE_LIST} ${EXTRA_WANTED_PACKAGES} ${CLOUD_INIT_PKGS}"

	# Remove hostapd. Its a cloud-like image, not an access point. @TODO, why not?
	# Note WPA-supplicant can still be used via network-config... but only as a client.
	# Remove more end-user oriented stuff.
	# shellcheck disable=SC2086 # no, lets expand. it's fun.
	remove_packages_everywhere network-manager-openvpn network-manager ${CLOUD_INIT_NETWORK_PACKAGE_REMOVE}
}

pre_umount_final_image__300_prepare_cloud_init_startup() {
	local CI_TARGET="${MOUNT}"

	# remove any networkd config leftover from armbian build
	rm -f "${CI_TARGET}"/etc/systemd/network/*.network || true

	# cleanup -- cloud-init makes some Armbian stuff actually get in the way
	[[ -f "${CI_TARGET}/boot/armbian_first_run.txt.template" ]] && rm -f "${CI_TARGET}/boot/armbian_first_run.txt.template"
	[[ -f "${CI_TARGET}/root/.not_logged_in_yet" ]] && rm -f "${CI_TARGET}/root/.not_logged_in_yet"

	# if disabled skip configuration
	if [[ "${SKIP_CLOUD_INIT_CONFIG}" == "yes" ]]; then
		display_alert "Cloud-init config" "skipped, use cloud-native metadata" ""
		return 0
	fi

	display_alert "Configuring cloud-init at" "${CLOUD_INIT_CONFIG_LOCATION}"

	cp "${EXTENSION_DIR}"/config/cloud-cfg.yaml "${CI_TARGET}"/etc/cloud/cloud.cfg.d/99-armbian-boot.cfg

	# Learn how Ubuntu does things by reading lxd docs...:
	# https://lxd.readthedocs.io/en/latest/cloud-init

	cp "${EXTENSION_DIR}"/config/meta-data.yaml "${CI_TARGET}${CLOUD_INIT_CONFIG_LOCATION}"/meta-data
	echo -e "\n\ninstance-id: ${CLOUD_INIT_INSTANCE_ID}" >> "${CI_TARGET}${CLOUD_INIT_CONFIG_LOCATION}"/meta-data

	cp "${EXTENSION_DIR}"/config/user-data.yaml "${CI_TARGET}${CLOUD_INIT_CONFIG_LOCATION}"/user-data

	# This module has hook points, just like the regular Armbian build system. So extensions can influence other extensions. Neat?
	# In this case, extensions compete to modify CLOUD_INIT_NET_CONFIG_FILE, so the ordering of the hooks is extremely important.
	[[ $(type -t cloud_init_determine_network_config_template) == function ]] && cloud_init_determine_network_config_template

	# Hack, some wierd bug with c-i causes "match:" devices to not be brought up.
	# For now just don't write a default network-config, c-i's default/fallback detection will dhcp it anyway (and that works).
	if [[ ${CLOUD_INIT_NET_CONFIG_FILE} == *"eth0-dhcp"* ]]; then
		display_alert "dhcp-variant (${CLOUD_INIT_NET_CONFIG_FILE})" "written as ${CLOUD_INIT_CONFIG_LOCATION}/network-config.sample" ""
		cp "${EXTENSION_DIR}"/config/network-configs/${CLOUD_INIT_NET_CONFIG_FILE}.yaml "${CI_TARGET}${CLOUD_INIT_CONFIG_LOCATION}"/network-config.sample
	else
		display_alert "Using network-config" "network-configs/${CLOUD_INIT_NET_CONFIG_FILE}.yaml" "info"
		cp "${EXTENSION_DIR}"/config/network-configs/${CLOUD_INIT_NET_CONFIG_FILE}.yaml "${CI_TARGET}${CLOUD_INIT_CONFIG_LOCATION}"/network-config
	fi

	# overwrite default (user-oriented) user-data with direct #include via CLOUD_INIT_USER_DATA_URL (automation oriented)
	if [[ "a${CLOUD_INIT_USER_DATA_URL}" != "afiles" ]]; then
		display_alert "Cloud-init user-data points directly to" "${CLOUD_INIT_USER_DATA_URL}" "wrn"
		echo -e "#include\n${CLOUD_INIT_USER_DATA_URL}" > "${CI_TARGET}${CLOUD_INIT_CONFIG_LOCATION}"/user-data
	fi

	# Configure logging for cloud-init. INFO is too little and DEBUG too much (as always)
	cp "${EXTENSION_DIR}"/config/debug_logging.yaml "${CI_TARGET}"/etc/cloud/cloud.cfg.d/05_logging.cfg

	# seed the /var/lib/cloud/seed/nocloud directory with symlinks to ${CLOUD_INIT_CONFIG_LOCATION}/*-data|config
	# symlinks always there, be dangling or not.
	local seed_dir="${CI_TARGET}"/var/lib/cloud/seed/nocloud
	mkdir -p "${seed_dir}"
	ln -s "${CLOUD_INIT_CONFIG_LOCATION}/network-config" "${seed_dir}"/network-config
	ln -s "${CLOUD_INIT_CONFIG_LOCATION}/user-data" "${seed_dir}"/user-data
	ln -s "${CLOUD_INIT_CONFIG_LOCATION}/meta-data" "${seed_dir}"/meta-data
}

user_config_post_aggregate_packages__900_confirm_cloudinit_packages() {
	# Make sure the package aggregation is not insane / changed too much
	# by checking that the final PACKAGE_LIST contains 'cloud-init' and 'netplan.io'
	if [[ ${PACKAGE_LIST} == *"cloud-init"* ]]; then
		display_alert "Package found OK." "cloud-init"
	else
		display_alert "Package not found in package list." "cloud-init" "wrn"
		read
	fi

	# could be nice checking that network-manager is NOT there too
	if [[ ${PACKAGE_LIST} == *"network-manager"* ]]; then
		display_alert "Package found in package list -- should not be!" "network-manager" "wrn"
	else
		display_alert "Package not being installed" "network-manager"
	fi

}

config_post_debootstrap_tweaks__restore_systemd_resolved() {
	# do away with the resolv.conf leftover in the image.
	# set up systemd-resolved which is the way cloud images generally work
	rm -f "${SDCARD}"/etc/resolv.conf
	ln -s ../run/systemd/resolve/stub-resolv.conf "${SDCARD}"/etc/resolv.conf
}

config_pre_install_distribution_specific__preserve_pristine_etc_systemd() {
	# Preserve some stuff from systemd that Armbian build will touch. This way we can let armbian do its thing
	# and then just revert back to the preserved state.
	cp -rp "${SDCARD}"/etc/systemd "${SDCARD}"/etc/systemd.orig
}

function pre_customize_image__lockdown_root_and_password_logins() {
	display_alert "Disabling root password and SSH password logins" "cloud ${DISTRIBUTION} ${RELEASE}" "info"
	run_host_command_logged sed -i -e "'s/PermitRootLogin yes/PermitRootLogin without-password/g'" "${SDCARD}"/etc/ssh/sshd_config
	run_host_command_logged sed -i -e "'s/#PasswordAuthentication yes/PasswordAuthentication no/g'" "${SDCARD}"/etc/ssh/sshd_config
	run_host_command_logged cat "${SDCARD}"/etc/ssh/sshd_config
	chroot_sdcard passwd -l root
}

pre_customize_image__restore_preserved_systemd_and_netplan_stuff() {
	# Enable motd, that is disabled in distro-agnostic because will enabled by firstrun.
	# cloud-init has no firstrun, but I want motd, so
	chmod +x "${SDCARD}"/etc/update-motd.d/*

	# Restore some stuff we preserved in config_pre_install_distribution_specific()
	cp -p "${SDCARD}"/etc/systemd.orig/journald.conf "${SDCARD}"/etc/systemd/journald.conf
	if [[ "${CLOUD_INIT_USE_NETPLAN}" == "yes" ]]; then
		if [[ -f "${SDCARD}"/etc/systemd.orig/resolved.conf ]]; then
			cp -p "${SDCARD}"/etc/systemd.orig/resolved.conf "${SDCARD}"/etc/systemd/resolved.conf
		else
			display_alert "No resolved.conf found in preserved systemd directory" "cloud ${DISTRIBUTION} ${RELEASE}" "wrn"
		fi
	fi

	# Remove the preserved dir
	rm -rf "${SDCARD}"/etc/systemd.orig || true

	# Clean netplan config. Cloud-init will create its own.
	rm -f "${SDCARD}"/etc/netplan/armbian-default.yaml

	# If not using netplan, make sure /etc/network/interfaces exists, otherwise c-i will ignore "eni"/ifupdown
	if [[ "${CLOUD_INIT_USE_NETPLAN}" == "no" ]]; then
		display_alert "Cloud-init configuring" "/etc/network/interfaces" "info"
		cat <<- EOD > "${SDCARD}"/etc/network/interfaces
			# Include files from /etc/network/interfaces.d:
			source-directory /etc/network/interfaces.d

			# Cloud images dynamically generate config extensions for newly
			# attached interfaces. See /etc/udev/rules.d/75-cloud-ifupdown.rules
			# and /etc/network/cloud-ifupdown-helper. Dynamically generated
			# configuration extensions are stored in /run:
			source-directory /run/network/interfaces.d
		EOD
	fi

	# Update Debian's c-i template for apt, due to bullseye security layout change.
	if [[ "${DISTRIBUTION}" == "Debian" ]]; then
		display_alert "Cloud-init sources.list.debian.tmpl" "${DISTRIBUTION} ${RELEASE}" "info"
		wget --quiet --output-document="${SDCARD}/etc/cloud/templates/sources.list.debian.tmpl" "https://raw.githubusercontent.com/canonical/cloud-init/main/templates/sources.list.debian.tmpl" || display_alert "Failed to update c-i apt template for" "${RELEASE}" "err"
	fi
}

pre_umount_final_image__200_add_ci_suffix_to_version() {
	export version="${version}-cloud"
	if [[ "a${CLOUD_INIT_EXTRA_VERSION}" != "a" ]]; then
		export version="${version}-${CLOUD_INIT_EXTRA_VERSION}"
	fi
	if [[ "${SKIP_CLOUD_INIT_CONFIG}" != "yes" ]]; then
		if [[ "a${CLOUD_INIT_USER_DATA_URL}" != "afiles" ]]; then
			export version="${version}-custom-userdata"
		fi
	fi
	display_alert "Cloud-init setting version to" "${version}" "info"
}
