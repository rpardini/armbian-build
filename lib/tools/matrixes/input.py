import logging

log: logging.Logger = logging.getLogger("matrix_input")


class MatrixInput:
	def __init__(self, json):
		self.ref_kernel: "MatrixKernel | None" = None
		self.ref_u_boot: "MatrixUboot | None" = None
		self.ref_root_fs_cli: "MatrixRootFileSystemCLI | None" = None

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
		self.RELEASE: str = self.inputs["RELEASE"]

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
		return f"{self.ARCH}_{self.RELEASE}_{self.AGGREGATED_ROOTFS_HASH}"

	def gha_job_id(self):
		return f"image_cli_{self.board_id}-{self.BRANCH}"  # @TODO fake
		pass

	def gha_job_definition(self):
		gha_job = {}
		gha_job["runs-on"] = ["self-hosted", "Linux", "armbian"]  # Fake
		expression = f"needs.{self.ref_kernel.gha_job_id()}.outputs.up-to-date"
		gha_job["if"] = '${{ always() && ' + expression + " == 'no' }}"
		steps = []
		fake_step = {"name": f"Image CLI '{self.board_id}-{self.BRANCH}'", "run": f'echo "fake image: {self.board_id}-{self.BRANCH}"'}
		steps.append(fake_step)
		gha_job["steps"] = steps
		gha_job["needs"] = []
		if self.ref_kernel:
			gha_job["needs"].append(self.ref_kernel.gha_job_id())
		if self.ref_root_fs_cli:
			gha_job["needs"].append(self.ref_root_fs_cli.gha_job_id())
		return gha_job
