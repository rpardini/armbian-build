# Rockchip RK3588 SoC octa core XXXX @TODO MONKA
declare -g BOARD_NAME="Mekotronics R58X-4x4"
declare -g BOARDFAMILY="rockchip-rk3588"
declare -g BOARD_MAINTAINER="monkaBlyat"
declare -g KERNEL_TARGET="vendor"
declare -g BOOTCONFIG="mekotronics_r58x-rk3588_defconfig"              # vendor u-boot; with NVMe and a DTS
declare -g BOOT_FDT_FILE="rockchip/rk3588-blueberry-r58-4X4-linux.dtb" # Specific to this board
declare -g UEFI_EDK2_BOARD_ID="r58x"                                   # This _only_ used for uefi-edk2-rk3588 extension

# Source vendor-specific configuration
source "${SRC}/config/sources/vendors/mekotronics/mekotronics-rk3588.conf.sh"

# DO NOT PR THIS -------------------\_/------------------------------------------------------
# Use fork for kernel as DT not yet sent nor landed - rk3588-blueberry-r58-4X4-linux.dts
function user_config__new_meko_use_fork_for_dt() {
	display_alert "$BOARD" "Using fork for vendor kernel DT -- DO NOT PR THIS" "warn"
	declare -g KERNELSOURCE="https://github.com/rpardini/armbian-linux-rockchip-rk3588.git"
	declare -g KERNELBRANCH='branch:armbian_rk-6.1-rkr3_20240727-add-meko'
	return 0
}
