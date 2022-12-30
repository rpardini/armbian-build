import logging
from collections import Counter

log: logging.Logger = logging.getLogger("matrix_utils")


# Here's the JSON we're dealing with:
# {
# 	"BOARD_DESC_ID": "espressobin",
# 	"BOARD_FILE_HARDWARE_DESC": "Marvell Armada 37x 512MB-2GB RAM SoC 1xmPCIe 1xSATA 3xGBE USB3.0 eMMC SPI",
# 	"BOARD_POSSIBLE_BRANCHES": [
# 		"current",
# 		"edge"
# 	],
# 	"config_ok": true,
# 	"in": {
# 		"BOARD": "espressobin",
# 		"BRANCH": "current",
# 		"BUILD_DESKTOP": "no",
# 		"BUILD_MINIMAL": "no",
# 		"CLEAN_LEVEL": "debs",
# 		"CLOUD_IMAGE": "yes",
# 		"CONFIG_DEFS_ONLY": "yes",
# 		"DEB_COMPRESS": "none",
# 		"EXPERT": "yes",
# 		"KERNEL_CONFIGURE": "no",
# 		"KERNEL_ONLY": "no",
# 		"RELEASE": "jammy",
# 		"SHOW_LOG": "yes",
# 		"SKIP_EXTERNAL_TOOLCHAINS": "yes"
# 	},
# 	"out": {
# 		"AGGREGATED_DEBOOTSTRAP_COMPONENTS_COMMA": "main,universe,restricted",
# 		"AGGREGATED_DESKTOP_BSP_POSTINST": "",
# 		"AGGREGATED_DESKTOP_BSP_PREPARE": "",
# 		"AGGREGATED_DESKTOP_CREATE_DESKTOP_PACKAGE": "",
# 		"AGGREGATED_DESKTOP_POSTINST": "...",
# 		"AGGREGATED_ROOTFS_HASH": "45a3600c135f97b07f80e870bb692d01",
# 		"APT_MIRROR": "ports.ubuntu.com/",
# 		"ARCH": "arm64",
# 		"ARCHITECTURE": "arm64",
# 		"ARMBIAN_WILL_BUILD_KERNEL": "linux-image-current-mvebu64-arm64",
# 		"ARMBIAN_WILL_BUILD_UBOOT": "yes",
# 		"ATFBRANCH": "branch:master",
# 		"ATFDIR": "arm-trusted-firmware-espressobin",
# 		"ATFPATCHDIR": "atf-mvebu64",
# 		"ATFSOURCE": "https://git.trustedfirmware.org/TF-A/trusted-firmware-a.git",
# 		"ATFSOURCEDIR": "arm-trusted-firmware-espressobin/master",
# 		"ATF_COMPILE": "yes",
# 		"ATF_COMPILER": "aarch64-linux-gnu-",
# 		"ATF_TARGET_MAP": [
# 			[
# 				"USE_COHERENT_MEM=0 LOG_LEVEL=20 SECURE=0 CLOCKSPRESET=CPU_800_DDR_800 DDR_TOPOLOGY=2 BOOTDEV=SPINOR PARTNUM=0 PLAT=a3700;;build/a3700/release/bl31.bin"
# 			]
# 		],
# 		"ATF_USE_GCC": "> 7.2",
# 		"AUFS": "yes",
# 		"BOARDFAMILY": "mvebu64",
# 		"BOARD_NAME": "Espressobin",
# 		"BOARD_SOURCE_FILE": "${SRC}/config/boards/espressobin.conf",
# 		"BOARD_SOURCE_FILES": " ${SRC}/config/boards/espressobin.conf",
# 		"BOARD_TYPE": "conf",
# 		"BOOTBRANCH": "branch:v2022.04",
# 		"BOOTCONFIG": "mvebu_espressobin-88f3720_defconfig",
# 		"BOOTCONFIG_VAR_NAME": "BOOTCONFIG_CURRENT",
# 		"BOOTDIR": "u-boot",
# 		"BOOTENV_FILE": "mvebu64.txt",
# 		"BOOTPATCHDIR": "v2022.07",
# 		"BOOTSCRIPT": "boot-espressobin.cmd:boot.cmd",
# 		"BOOTSCRIPT_OUTPUT": "boot.scr",
# 		"BOOTSOURCE": "https://source.denx.de/u-boot/u-boot.git",
# 		"BOOTSOURCEDIR": "u-boot-worktree/u-boot/v2022.04",
# 		"BSP_CLI_PACKAGE_FULLNAME": "armbian-bsp-cli-espressobin_23.02.0-trunk_arm64",
# 		"BSP_CLI_PACKAGE_NAME": "armbian-bsp-cli-espressobin",
# 		"BSP_DESKTOP_PACKAGE_FULLNAME": "armbian-bsp-desktop-espressobin_23.02.0-trunk_arm64",
# 		"BSP_DESKTOP_PACKAGE_NAME": "armbian-bsp-desktop-espressobin",
# 		"BTRFS_COMPRESSION": "zlib",
# 		"CCACHE": "ccache",
# 		"CHOSEN_DESKTOP": "armbian-jammy-desktop-",
# 		"CHOSEN_KERNEL": "linux-image-current-mvebu64",
# 		"CHOSEN_KERNEL_WITH_ARCH": "linux-image-current-mvebu64-arm64",
# 		"CHOSEN_KSRC": "linux-source-current-mvebu64",
# 		"CHOSEN_ROOTFS": "armbian-bsp-cli-espressobin",
# 		"CHOSEN_UBOOT": "linux-u-boot-current-espressobin",
# 		"CHROOT_CACHE_VERSION": "7",
# 		"CONSOLE_AUTOLOGIN": "yes",
# 		"CONSOLE_CHAR": "UTF-8",
# 		"CPUMAX": "1300000",
# 		"CPUMIN": "200000",
# 		"CPUS": "16",
# 		"CRYPTROOT_PARAMETERS": "--pbkdf pbkdf2",
# 		"CRYPTROOT_SSH_UNLOCK": "yes",
# 		"CRYPTROOT_SSH_UNLOCK_PORT": "2022",
# 		"CTHREADS": "-j24",
# 		"DEBIAN_MIRROR": "deb.debian.org/debian",
# 		"DEBIAN_SECURTY": "security.debian.org/",
# 		"DEB_STORAGE": "${SRC}/output/debs",
# 		"DEST_LANG": "en_US.UTF-8",
# 		"DISABLE_IPV6": "true",
# 		"DISTRIBUTION": "Ubuntu",
# 		"EXIT_PATCHING_ERROR": "",
# 		"EXTRAWIFI": "yes",
# 		"EXTRA_BSP_NAME": "",
# 		"EXTRA_BUILD_DEPS": "",
# 		"EXTRA_ROOTFS_MIB_SIZE": "0",
# 		"FAST_CREATE_IMAGE": "yes",
# 		"FINALDEST": "${SRC}/output/images",
# 		"FINAL_HOST_DEPS": "xxx ",
# 		"GITHUB_SOURCE": "https://github.com",
# 		"GOVERNOR": "ondemand",
# 		"HAS_VIDEO_OUTPUT": "no",
# 		"HOOK_ORDER": "1",
# 		"HOOK_POINT": "run_after_build",
# 		"HOOK_POINT_TOTAL_FUNCS": "1",
# 		"HOST": "espressobin",
# 		"HOSTRELEASE": "jammy",
# 		"IMAGE_PARTITION_TABLE": "msdos",
# 		"IMAGE_TYPE": "user-built",
# 		"INITRD_ARCH": "arm64",
# 		"KERNELBRANCH": "branch:linux-5.15.y",
# 		"KERNELDIR": "linux-mainline",
# 		"KERNELPATCHDIR": "mvebu64-current",
# 		"KERNELSOURCE": "git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git",
# 		"KERNEL_COMPILER": "aarch64-linux-gnu-",
# 		"KERNEL_HAS_WORKING_HEADERS": "yes",
# 		"KERNEL_HAS_WORKING_HEADERS_FULL_SOURCE": "no",
# 		"KERNEL_IMAGE_TYPE": "Image",
# 		"KERNEL_MAJOR": "5",
# 		"KERNEL_MAJOR_MINOR": "5.15",
# 		"KERNEL_MAJOR_SHALLOW_TAG": "v5.15-rc1",
# 		"KERNEL_TARGET": "current,edge",
# 		"KERNEL_USE_GCC": "< 9.2",
# 		"LANGUAGE": "en_US:en",
# 		"LINUXCONFIG": "linux-mvebu64-current",
# 		"LINUXFAMILY": "mvebu64",
# 		"LINUXSOURCEDIR": "linux-kernel-worktree/5.15__mvebu64__arm64",
# 		"MAINLINE_FIRMWARE_SOURCE": "git://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git",
# 		"MAINLINE_KERNEL_COLD_BUNDLE_URL": "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/clone.bundle",
# 		"MAINLINE_KERNEL_DIR": "linux-mainline",
# 		"MAINLINE_KERNEL_SOURCE": "git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git",
# 		"MAINLINE_KERNEL_STABLE_BUNDLE_URL": "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/clone.bundle",
# 		"MAINLINE_KERNEL_TORVALDS_BUNDLE_URL": "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/clone.bundle",
# 		"MAINLINE_UBOOT_DIR": "u-boot",
# 		"MAINLINE_UBOOT_SOURCE": "https://source.denx.de/u-boot/u-boot.git",
# 		"MAINTAINER": "Igor Pecovnik",
# 		"MAINTAINERMAIL": "igor.pecovnik@****l.com",
# 		"MAIN_CMDLINE": "rw no_console_suspend consoleblank=0 fsck.fix=yes fsck.repair=yes net.ifnames=0 bootsplash.bootfile=bootsplash.armbian",
# 		"NAMESERVER": "1.0.0.1",
# 		"NAME_INITRD": "uInitrd",
# 		"NAME_KERNEL": "Image",
# 		"NM_IGNORE_DEVICES": "interface-name:eth*,interface-name:wan*,interface-name:lan*,interface-name:br*",
# 		"OFFSET": "4",
# 		"PACKAGE_LIST_BOARD": [
# 			""
# 		],
# 		"PACKAGE_LIST_BOARD_REMOVE": [
# 			""
# 		],
# 		"PACKAGE_LIST_FAMILY": [
# 			""
# 		],
# 		"PACKAGE_LIST_FAMILY_REMOVE": [
# 			""
# 		],
# 		"PLYMOUTH": "no",
# 		"QEMU_BINARY": "qemu-aarch64-static",
# 		"REPO_CONFIG": "aptly.conf",
# 		"REPO_STORAGE": "${SRC}/output/repository",
# 		"REVISION": "23.02.0-trunk",
# 		"ROOTFS_CACHE_MAX": "200",
# 		"ROOTFS_TYPE": "ext4",
# 		"ROOTPWD": "1234",
# 		"ROOT_MAPPER": "armbian-root",
# 		"SELECTED_CONFIGURATION": "cli_standard",
# 		"SERIALCON": "ttyMV0",
# 		"SHOW_WARNING": "yes",
# 		"SKIP_BOOTSPLASH": "yes",
# 		"TTY_X": "115",
# 		"TTY_Y": "25",
# 		"TZDATA": "Etc/UTC",
# 		"UBOOT_COMPILER": "aarch64-linux-gnu-",
# 		"UBOOT_TARGET_MAP": [
# 			[
# 				"DEVICE_TREE=armada-3720-espressobin ;;flash-image-*.bin"
# 			]
# 		],
# 		"UBOOT_USE_GCC": "> 8.0",
# 		"UBUNTU_MIRROR": "ports.ubuntu.com/",
# 		"USEALLCORES": "yes",
# 		"VENDOR": "Armbian",
# 		"WIREGUARD": "yes"
# 	}
# },


# <Class declarations>
class MatrixInput:
	def __init__(self, json):
		self.ref_kernel: MatrixKernel | None = None
		self.ref_u_boot: MatrixUboot | None = None
		self.ref_root_fs_cli: MatrixRootFileSystemCLI | None = None

		self.inputs: dict[str, str | object] = json["in"]
		self.outputs: dict[str, str | object] = json["out"]
		self.board_description: str = json["BOARD_FILE_HARDWARE_DESC"]
		self.board_id: str = json["BOARD_DESC_ID"]
		self.BRANCH: str = self.inputs["BRANCH"]
		self.ARCH: str = self.outputs["ARCH"]
		self.LINUXFAMILY: str = self.outputs["LINUXFAMILY"]
		self.BOARDFAMILY: str = self.outputs["BOARDFAMILY"]
		self.ARMBIAN_WILL_BUILD_KERNEL: bool = self.outputs["ARMBIAN_WILL_BUILD_KERNEL"] != ""
		self.CHOSEN_KERNEL: str = self.outputs["CHOSEN_KERNEL"]
		self.CHOSEN_KSRC: str = self.outputs["CHOSEN_KSRC"]
		self.KERNEL_MAJOR_MINOR: str = self.outputs["KERNEL_MAJOR_MINOR"]
		self.KERNELSOURCE: str = self.outputs["KERNELSOURCE"]
		self.KERNELBRANCH: str = self.outputs["KERNELBRANCH"]
		self.KERNEL_HAS_WORKING_HEADERS: str = self.outputs["KERNEL_HAS_WORKING_HEADERS"]

		self.ARMBIAN_WILL_BUILD_UBOOT: bool = self.outputs["ARMBIAN_WILL_BUILD_UBOOT"] == "yes"
		self.CHOSEN_UBOOT: str = self.outputs["CHOSEN_UBOOT"]
		self.BOOTSOURCE: str = self.outputs["BOOTSOURCE"] if "BOOTSOURCE" in self.outputs else None
		self.BOOTBRANCH: str = self.outputs["BOOTBRANCH"]
		self.BOOTCONFIG: str = self.outputs["BOOTCONFIG"]

		self.AGGREGATED_ROOTFS_HASH: str = self.outputs["AGGREGATED_ROOTFS_HASH"]

	def kernel_id(self) -> "str | None":
		if self.BRANCH == "ddk":
			return None
		return f"{self.LINUXFAMILY}-{self.BRANCH}"

	def uboot_id(self) -> "str | None":
		if not self.ARMBIAN_WILL_BUILD_UBOOT:
			return None
		return f"{self.CHOSEN_UBOOT}"

	def __str__(self) -> str:
		return f"{self.board_id}-{self.BRANCH}"

	def rootfs_cli_id(self):
		return f"{self.AGGREGATED_ROOTFS_HASH}"


class BaseMatrixAggregate:
	def __init__(self, aggregate_id: str, item: MatrixInput, all_items: list[MatrixInput]):
		self.aggregate_id: str = aggregate_id
		self.item: MatrixInput = item
		self.all_items: list[MatrixInput] = all_items

	def sanity_check_same(self, extractor) -> str:
		unique = set([extractor(x) for x in self.all_items])
		if len(unique) != 1:
			raise Exception(f"Sanity check failed for '{self.aggregate_id}': {unique}")
		return unique.pop()

	def unique(self, extractor) -> set[str]:
		mapped = [extractor(x) for x in self.all_items]
		unique = set(mapped)
		return unique


class MatrixKernel(BaseMatrixAggregate):

	def __init__(self, aggregate_id: str, item: MatrixInput, all_items: list[MatrixInput]):
		"""Parse build matrix items into a kernel object; do sanity check so most attributes are the same across all items.
		That should detect sneaky families that change source/branch without changing the LINUXFAMILY"""
		super().__init__(aggregate_id, item, all_items)
		self.name: str = self.sanity_check_same(lambda i: i.CHOSEN_KERNEL)
		self.branch: str = self.sanity_check_same(lambda i: i.BRANCH)
		self.arch: str = self.sanity_check_same(lambda i: i.ARCH)
		self.major_minor: str = self.sanity_check_same(lambda i: i.KERNEL_MAJOR_MINOR)
		self.git_branch: str = self.sanity_check_same(lambda i: i.KERNELBRANCH)
		self.git_source: str = self.sanity_check_same(lambda i: i.KERNELSOURCE)
		self.board_families: set[str] = self.unique(lambda i: i.BOARDFAMILY)
		self.boards: set[str] = self.unique(lambda i: i.board_id)
		if aggregate_id is not None:
			for one_item in all_items:
				one_item.ref_kernel = self

	def __str__(self) -> str:
		families_counter = " ".join(
			f'family_{family}="{counter}"' for family, counter in dict(Counter(item.BOARDFAMILY for item in self.all_items)).items())
		return f'<Kernel id="{self.aggregate_id}" name="{self.name}" branch="{self.branch}" v="{self.major_minor}" b="{self.git_branch}" boards="{len(self.boards)}" {families_counter} />'


class MatrixUboot(BaseMatrixAggregate):

	def __init__(self, aggregate_id: str, item: MatrixInput, all_items: list[MatrixInput]):
		super().__init__(aggregate_id, item, all_items)
		self.name: str = self.sanity_check_same(lambda i: i.CHOSEN_UBOOT)
		self.branch: str = self.sanity_check_same(lambda i: i.BRANCH)
		self.arch: str = self.sanity_check_same(lambda i: i.ARCH)
		self.git_branch: str = self.sanity_check_same(lambda i: i.BOOTBRANCH)
		self.git_source: str = self.sanity_check_same(lambda i: i.BOOTSOURCE)
		self.uboot_defconfig: str = self.sanity_check_same(lambda i: i.BOOTCONFIG)
		self.boards: set[str] = self.unique(lambda i: i.board_id)
		if aggregate_id is not None:
			for one_item in all_items:
				one_item.ref_u_boot = self

	def __str__(self) -> str:
		return f'<U-boot id="{self.aggregate_id}" name="{self.name}" b="{self.git_branch}" defconfig="{self.uboot_defconfig}" boards="{len(self.boards)}" />'


class MatrixRootFileSystemCLI(BaseMatrixAggregate):

	def __init__(self, aggregate_id: str, item: MatrixInput, all_items: list[MatrixInput]):
		super().__init__(aggregate_id, item, all_items)
		self.boards: set[str] = self.unique(lambda i: i.board_id)
		if aggregate_id is not None:
			for one_item in all_items:
				one_item.ref_root_fs_cli = self

	def __str__(self) -> str:
		return f'<RootFSCLI name="{self.aggregate_id}"  boards="{len(self.boards)}" />'

# </Class declarations>
