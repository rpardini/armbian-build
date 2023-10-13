#
# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2023 Ricardo Pardini <ricardo@pardini.net>
# This file is a part of the Armbian Build Framework https://github.com/armbian/build/
#

# This add's amazingfate's PPAs to the the image, and installs all needed packages.
# It only works on LINUXFAMILY="rk3588-legacy" and RELEASE=jammy and BRANCH=legacy
# if on a desktop, installs more useful packages, and tries to coerce lightdm to use gtk-greeter and a Wayland session.
function extension_prepare_config__amazingfated_rk3588() {
	display_alert "Preparing amazingfated's rk3588 extension" "${EXTENSION}" "info"
	# Add to the image suffix.
	EXTRA_IMAGE_SUFFIXES+=("-amazingfated") # global array

	[[ "${BUILDING_IMAGE}" != "yes" ]] && return 0

	if [[ "${LINUXFAMILY}" != "rockchip-rk3588" && "${LINUXFAMILY}" != "rk35xx" ]]; then
		exit_with_error "${EXTENSION} only works on LINUXFAMILY=rockchip-rk3588/rk35xx, currently on '${LINUXFAMILY}'"
	fi

	if [[ "${BRANCH}" != "legacy" ]]; then
		exit_with_error "${EXTENSION} only works on BRANCH=legacy, currently on '${BRANCH}'"
	fi

	if [[ "${RELEASE}" != "jammy" ]]; then
		exit_with_error "${EXTENSION} only works on RELEASE=jammy, currently on '${RELEASE}'"
	fi
}

function post_install_kernel_debs__amazingfated_rk358() {
	display_alert "Adding amazingfated's rk3588 PPAs" "${EXTENSION}" "info"
	do_with_retries 3 chroot_sdcard add-apt-repository ppa:liujianfeng1994/panfork-mesa --yes --no-update
	do_with_retries 3 chroot_sdcard add-apt-repository ppa:liujianfeng1994/rockchip-multimedia --yes --no-update

	display_alert "Updating sources list, after amazingfated's rk3588 PPAs" "${EXTENSION}" "info"
	do_with_retries 3 chroot_sdcard_apt_get_update

	declare -a pkgs=(mali-g610-firmware)
	if [[ "${BUILD_DESKTOP}" == "yes" ]]; then
		pkgs+=(chromium-browser libwidevinecdm rockchip-multimedia-config)
	fi

	# DISABLED, needs handling in core armbian
	# pkgs+=(lightdm-gtk-greeter) # hack, since the slick-greeter refuses to understand wayland sessions

	display_alert "Installing amazingfated's rk3588 packages" "${EXTENSION} :: ${pkgs[*]}" "info"
	do_with_retries 3 chroot_sdcard_apt_get_install "${pkgs[@]}"

	display_alert "Upgrading amazingfated's rk3588 packages" "${EXTENSION}" "info"
	do_with_retries 3 chroot_sdcard_apt_get upgrade

	display_alert "Installed amazingfated's rk3588 packages" "${EXTENSION}" "info"

	return 0
}

# @TODO: DISABLED, this needs handling in core armbian
function DISABLED_pre_customize_image_amazingfated_prefer_wayland_session() {
	display_alert "Setting up amazingfated's rk3588 for Wayland" "${EXTENSION}" "info"

	# If not BUILD_DESKTOP="yes", then we don't need to do anything.
	if [[ "${BUILD_DESKTOP}" != "yes" ]]; then
		display_alert "Not building desktop, skipping amazingfated's rk3588 Wayland setup" "${EXTENSION}" "info"
		return 0
	fi

	declare sessions_dir="${SDCARD}/usr/share/wayland-sessions"
	declare lightdm_conf_dir="${SDCARD}/etc/lightdm/lightdm.conf.d"

	if [[ ! -d "${sessions_dir}" ]]; then
		display_alert "Wayland sessions directory '${sessions_dir}' not found" "${EXTENSION}" "warn"
		return 0
	fi

	if [[ ! -d "${lightdm_conf_dir}" ]]; then
		display_alert "LightDM configuration directory '${lightdm_conf_dir}' not found" "${EXTENSION}" "warn"
		return 0
	fi

	declare -a sessions_in_order=("plasmawayland" "gnome-wayland" "ubuntu-wayland")
	declare chosen_session=""
	for session in "${sessions_in_order[@]}"; do
		if [[ -f "${sessions_dir}/${session}.desktop" ]]; then
			chosen_session="${session}"
			break
		fi
	done

	display_alert "Setting up amazingfated's rk3588 for Wayland, chosen session '${chosen_session}'" "${EXTENSION}" "info"

	declare chosen_session_file="${sessions_dir}/${chosen_session}.desktop"
	if [[ ! -f "${chosen_session_file}" ]]; then
		display_alert "Wayland session '${chosen_session}' not found" "${EXTENSION}" "warn"
		return 0
	fi

	# HACK: Those lightdm greeters get really confused when there's multiple sessions available.
	# This hack is only for first boot, those things can get replaced by upgrades of packages.
	# Delete all files from the (X11) sessions directory, so only the Wayland session is available.
	run_host_command_logged rm -f "${SDCARD}/usr/share/xsessions/"*.desktop
	# Delete files from the (Wayland) sessions directory except the chosen_session_file
	run_host_command_logged find "${sessions_dir}" -type f -not -name "$(basename "${chosen_session_file}")" -delete

	# List the final contents of the sessions directory
	run_host_command_logged ls -la "${sessions_dir}"

	# Now lets configure lightdm to use the chosen session & the gtk greeter.
	# Armbian's armbian-firstlogin will do all kinds of weird stuff to 11-armbian.conf and 22-?.conf
	# Let's use 50-use-wayland.conf so it hopefully overrides all of that.
	declare lightdm_conf="${lightdm_conf_dir}/50-use-wayland.conf"
	cat <<- EOD > "${lightdm_conf}"
		[Seat:*]
		user-session=${chosen_session}
		greeter-session=lightdm-gtk-greeter
	EOD

	display_alert "Setting up amazingfated's rk3588 for Wayland, session configured '${chosen_session}' OK" "${EXTENSION}" "info"

	return 0
}
