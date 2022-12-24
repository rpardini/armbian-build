function kernel_driver_prepare() {
	declare kernel_version="${1}" # passed in as first parameter by build system

	# TEMP: outputs
	declare -A kernel_driver_config=()
	declare kernel_driver_id=""
	declare kernel_driver_name=""
	declare kernel_driver_github_user_repo=""
	declare kernel_driver_git_version=""
	declare kernel_driver_enable="no"

	kernel_driver_id="rtl88x2bu"                                                # the driver id; there can be only one with the same name.
	kernel_driver_name="Realtek USB WiFi RTL882x2bu"                            # descriptive name; used in the resulting patch
	kernel_driver_github_user_repo="morrownr/88x2bu-20210702"                   # the github user/repo to fetch from
	kernel_driver_git_version="commit:2590672d717e2516dd2e96ed66f1037a6815bced" # the git version to fetch
	kernel_driver_config["CONFIG_RTL8822BU"]="m"                                # add to the dictionary of kernel config options to enable

	# Validate the condition(s) under which we will enable this driver.
	# Return with 0 if driver shouldn't be enabled.
	if ! linux-version compare "${kernel_version}" ge 5.0; then
		display_alert "Kernel version too old: ${kernel_version} -- requires 5.0+" "Skipping ${kernel_driver_name}" "warn"
		return 0
	fi

	# If the above condition(s) are met, then enable the driver.
	kernel_driver_enable="yes"

	#fetch_from_repo "https://github.com/morrownr/88x2bu-20210702" "rtl88x2bu" "${rtl88x2buver}" "yes"
}

function kernel_driver_apply() {
	
	
	
}

function custom_kernel_config__realtek_wifi_rtl882x2bu() {
	display_alert "Adding kernel config" "CONFIG_RTL8822BU=m" "warn"
	# enable RTL8822BU in .config
	run_host_command_logged ./scripts/config --module CONFIG_RTL8822BU
}

function patch_kernel_for_driver__realtek_wifi_rtl882x2bu() {
	display_alert "Patching Kernel for Driver" "Realtek WiFi RTL882x2bu: ${version} in ${kernel_work_dir}" "info"

	if ! linux-version compare "${version}" ge 5.0; then
		display_alert "Kernel version too old: ${version} -- requires 5.0+" "Skipping ${EXTENSION}" "warn"
		return 0
	fi

	display_alert "Adding" "Wireless drivers for Realtek 88x2bu chipsets ${rtl88x2buver}" "info"

	run_host_command_logged rm -rfv "${kernel_work_dir}/drivers/net/wireless/rtl88x2bu"
	run_host_command_logged mkdir -pv "${kernel_work_dir}/drivers/net/wireless/rtl88x2bu/"
	run_host_command_logged cp -Rpv "${SRC}/cache/sources/rtl88x2bu/${rtl88x2buver#*:}"/{core,hal,include,os_dep,platform,halmac.mk,rtl8822b.mk} "${kernel_work_dir}/drivers/net/wireless/rtl88x2bu"

	# Makefile
	run_host_command_logged cp -pv "${SRC}/cache/sources/rtl88x2bu/${rtl88x2buver#*:}/Makefile" "${kernel_work_dir}/drivers/net/wireless/rtl88x2bu/Makefile"

	# Kconfig
	sed -i 's/---help---/help/g' "${SRC}/cache/sources/rtl88x2bu/${rtl88x2buver#*:}/Kconfig"
	run_host_command_logged cp -pv "${SRC}/cache/sources/rtl88x2bu/${rtl88x2buver#*:}/Kconfig" "${kernel_work_dir}/drivers/net/wireless/rtl88x2bu/Kconfig"

	# Adjust path
	sed -i 's/include $(src)\/rtl8822b.mk /include $(TopDIR)\/drivers\/net\/wireless\/rtl88x2bu\/rtl8822b.mk/' "${kernel_work_dir}/drivers/net/wireless/rtl88x2bu/Makefile"

	# Add to section Makefile
	echo "obj-\$(CONFIG_RTL8822BU) += rtl88x2bu/" >> "${kernel_work_dir}/drivers/net/wireless/Makefile"
	sed -i '/source "drivers\/net\/wireless\/ti\/Kconfig"/a source "drivers\/net\/wireless\/rtl88x2bu\/Kconfig"' "${kernel_work_dir}/drivers/net/wireless/Kconfig"

	display_alert "Done patching kernel ${version} for" "${EXTENSION}" "info"
}
