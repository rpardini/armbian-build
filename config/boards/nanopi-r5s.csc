# Rockchip RK3568 quad core 4GB RAM eMMC NVMe 2x USB3 1x GbE 2x 2.5GbE
BOARD_NAME="NanoPi R5S"
BOARDFAMILY="rockchip64"
BOARD_MAINTAINER="utlark"
BOOT_SOC="rk3568"
KERNEL_TARGET="legacy,vendor,current,edge"     # legacy & vendor are defined in hooks, below
KERNEL_TEST_TARGET="current"
BOOT_FDT_FILE="rockchip/rk3568-nanopi-r5s.dtb" # for mainline; vendor & legacy use different DTBs, see hooks below
SRC_EXTLINUX="no"
ASOUND_STATE="asound.state.station-m2" # TODO verify me
IMAGE_PARTITION_TABLE="gpt"
FULL_DESKTOP="yes"
BOOT_LOGO="desktop"

BOOTBRANCH_BOARD="tag:v2024.04"
BOOTPATCHDIR="v2024.04"
BOOTCONFIG="nanopi-r5s-rk3568_defconfig"
BOOT_SCENARIO="spl-blobs" # Only really used for legacy/vendor; current/edge use binman

OVERLAY_PREFIX="rockchip-rk3568"
DEFAULT_OVERLAYS="nanopi-r5s-leds"

BL32_BLOB='rk35/rk3568_bl32_v2.11.bin'         # Only for legacy/vendor u-boot

if [[ "${BRANCH}" == "legacy" || "${BRANCH}" == "vendor" ]]; then
	# Use extlinux and u-boot-menu extension; vendor u-boot gags on .scr
	declare -g SRC_EXTLINUX="yes"
	declare -g SRC_CMDLINE="loglevel=7 console=ttyS2,1500000 console=tty0"
	enable_extension "u-boot-menu"
fi

function post_family_config__uboot_config() {
	[[ "${BRANCH}" == "edge" || "${BRANCH}" == "current" ]] || return 0
	display_alert "$BOARD" "u-boot ${BOOTBRANCH_BOARD} overrides" "info"
	BOOTDELAY=2 # Wait for UART interrupt to enter UMS/RockUSB mode etc
	UBOOT_TARGET_MAP="ROCKCHIP_TPL=${RKBIN_DIR}/${DDR_BLOB} BL31=$RKBIN_DIR/$BL31_BLOB spl/u-boot-spl u-boot.bin flash.bin;;idbloader.img u-boot.itb"
}

function post_family_tweaks__nanopir5s_udev_network_interfaces() {
	[[ "${BRANCH}" == "edge" || "${BRANCH}" == "current" ]] || return 0
	display_alert "$BOARD" "Renaming interfaces WAN LAN1 LAN2" "info"

	mkdir -p $SDCARD/etc/udev/rules.d/
	cat <<- EOF > "${SDCARD}/etc/udev/rules.d/70-persistent-net.rules"
		SUBSYSTEM=="net", ACTION=="add", KERNELS=="fe2a0000.ethernet", NAME:="wan"
		SUBSYSTEM=="net", ACTION=="add", KERNELS=="0000:01:00.0", NAME:="lan1"
		SUBSYSTEM=="net", ACTION=="add", KERNELS=="0001:01:00.0", NAME:="lan2"
	EOF
}

# We've an overlay (DEFAULT_OVERLAYS="nanopi-r5s-leds") to drive the LEDs. Disable armbian-led-state service.
function pre_customize_image__nanopi-r5s_leds_kernel_only() {
	display_alert "$BOARD" "Disabling armbian-led-state service since we have DEFAULT_OVERLAYS='${DEFAULT_OVERLAYS}'" "info"
	chroot_sdcard systemctl --no-reload disable armbian-led-state
}

# For UMS/RockUSB to work in u-boot, &usb_host0_xhci { dr_mode = "otg" } is required. See 0002-usb-otg-mode.patch
# Attention: the Power USB-C port is NOT the OTG port; instead, the USB-A closest to the edge is the OTG port.
function post_config_uboot_target__extra_configs_for_nanopi-r5s() {
	[[ "${BRANCH}" == "edge" || "${BRANCH}" == "current" ]] || return 0

	display_alert "u-boot for ${BOARD}" "u-boot: enable preboot & flash all LEDs and do PCI/NVMe enumeration in preboot" "info"
	run_host_command_logged scripts/config --enable CONFIG_USE_PREBOOT
	run_host_command_logged scripts/config --set-str CONFIG_PREBOOT "'led led-power on; led led-lan1 on; led led-lan2 on; led led-wan on; pci enum; nvme scan; led led-lan1 off; led led-lan2 off; led led-wan off'" # double quotes required due to run_host_command_logged's quirks

	display_alert "u-boot for ${BOARD}" "u-boot: enable EFI debugging command" "info"
	run_host_command_logged scripts/config --enable CMD_EFIDEBUG
	run_host_command_logged scripts/config --enable CMD_NVEDIT_EFI

	display_alert "u-boot for ${BOARD}" "u-boot: enable more compression support" "info"
	run_host_command_logged scripts/config --enable CONFIG_LZO
	run_host_command_logged scripts/config --enable CONFIG_BZIP2
	run_host_command_logged scripts/config --enable CONFIG_ZSTD

	display_alert "u-boot for ${BOARD}" "u-boot: enable gpio LED support" "info"
	run_host_command_logged scripts/config --enable CONFIG_LED
	run_host_command_logged scripts/config --enable CONFIG_LED_GPIO

	display_alert "u-boot for ${BOARD}" "u-boot: enable networking cmds" "info"
	run_host_command_logged scripts/config --enable CONFIG_CMD_NFS
	run_host_command_logged scripts/config --enable CONFIG_CMD_WGET
	run_host_command_logged scripts/config --enable CONFIG_CMD_DNS
	run_host_command_logged scripts/config --enable CONFIG_PROT_TCP
	run_host_command_logged scripts/config --enable CONFIG_PROT_TCP_SACK
	run_host_command_logged scripts/config --enable CONFIG_SERVERIP_FROM_PROXYDHCP # Enable ProxyDHCP support

	# UMS, RockUSB, gadget stuff
	declare -a enable_configs=("CONFIG_CMD_USB_MASS_STORAGE" "CONFIG_USB_GADGET" "USB_GADGET_DOWNLOAD" "CONFIG_USB_FUNCTION_ROCKUSB" "CONFIG_USB_FUNCTION_ACM" "CONFIG_CMD_ROCKUSB" "CONFIG_CMD_USB_MASS_STORAGE")
	for config in "${enable_configs[@]}"; do
		display_alert "u-boot for ${BOARD}/${BRANCH}" "u-boot: enable ${config}" "info"
		run_host_command_logged scripts/config --enable "${config}"
	done
	# Auto-enabled by the above, force off...
	run_host_command_logged scripts/config --disable USB_FUNCTION_FASTBOOT
}

function nanopi_r5s_common_legacy_vendor_uboot_and_kernel_stuff() {
	declare -g -i KERNEL_GIT_CACHE_TTL=120 # 2 minutes

	# Use a different DTB
	declare -g BOOT_FDT_FILE="rockchip/rk3568-nanopi5-rev05.dtb" # wth, FE. "rev05" == "FriendlyElec NanoPi R5S LTS"; "rev01" == "FriendlyElec NanoPi R5S
	declare -g OVERLAY_PREFIX='rk35xx'
	unset DEFAULT_OVERLAYS # no LED overlay in legacy

	# Vendor u-boot
	declare -g BOOTSOURCE='https://github.com/friendlyarm/uboot-rockchip.git'
	declare -g BOOTBRANCH='branch:nanopi5-v2017.09'
	declare -g BOOTPATCHDIR="legacy/u-boot-khadas-edge2-rk3588" # yeah exact same situation with tee.bin; thanks Efe
	declare -g BOOTCONFIG="nanopi5_defconfig"
}

function post_family_config_branch_vendor__kernel_rk35xx_nanopi-r5s() {
	# Copypasta from rockchip-rk3588.conf family file -- we _really_ gotta find a better way!
	declare -g KERNEL_MAJOR_MINOR="6.1" # Major and minor versions of this kernel.
	declare -g KERNELSOURCE='https://github.com/armbian/linux-rockchip.git'
	declare -g KERNELBRANCH='branch:rk-6.1-rkr1'
	declare -g KERNELPATCHDIR='rk35xx-vendor-6.1'
	declare -g LINUXFAMILY=rk35xx
	nanopi_r5s_common_legacy_vendor_uboot_and_kernel_stuff
}

function post_family_config_branch_legacy__kernel_rk35xx_nanopi-r5s() {
	# Copypasta from rockchip-rk3588.conf family file -- we _really_ gotta find a better way!
	declare -g KERNEL_MAJOR_MINOR="5.10" # Major and minor versions of this kernel.
	declare -g KERNELSOURCE='https://github.com/armbian/linux-rockchip.git'
	declare -g KERNELBRANCH='branch:rk-5.10-rkr6'
	declare -g KERNELPATCHDIR='rk35xx-legacy'
	declare -g LINUXFAMILY=rk35xx
	nanopi_r5s_common_legacy_vendor_uboot_and_kernel_stuff
}
