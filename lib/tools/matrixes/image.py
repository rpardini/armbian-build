import logging

from matrixes.base import BaseAggregator, BaseMatrixAggregate
from matrixes.input import MatrixInput
from matrixes.kernel import MatrixKernel
from matrixes.rootfs import MatrixRootFileSystemCLI
from matrixes.uboot import MatrixUboot

log: logging.Logger = logging.getLogger("matrix_kernel")


class ImageAggregator(BaseAggregator):
	"""A ridiculous non-aggregator; every input is an output"""

	def __init__(self, inputs: list[MatrixInput]):
		super().__init__(inputs)
		self.images: list[MatrixImage] = [MatrixImage(entry.image_id(), entry, [entry], self) for entry in inputs]

	def produce_gha_jobs(self, gha_jobs: dict[str, object]):
		for image in self.images:
			gha_jobs[image.gha_job_id()] = image.gha_job_definition()


class MatrixImage(BaseMatrixAggregate):

	def __init__(self, aggregate_id: str, item: MatrixInput, all_items: list[MatrixInput], aggregator: "ImageAggregator"):
		super().__init__(aggregate_id, item, all_items)

		self.ref_kernel: MatrixKernel = item.ref_kernel
		self.ref_u_boot: MatrixUboot = item.ref_u_boot
		self.ref_root_fs_cli: MatrixRootFileSystemCLI = item.ref_root_fs_cli

		self.board_id: str = self.sanity_check_same(lambda x: x.board_id)
		self.aggregator: ImageAggregator = aggregator
		self.branch: str = self.sanity_check_same(lambda i: i.BRANCH)
		self.release: str = self.sanity_check_same(lambda i: i.RELEASE)
		self.arch: str = self.sanity_check_same(lambda i: i.ARCH)
		self.boards: set[str] = self.unique(lambda i: i.board_id)
		if aggregate_id is not None:
			for one_item in all_items:
				one_item.ref_image = self

	def __str__(self) -> str:
		return f'<Image id="{self.aggregate_id}" branch="{self.branch}" />'

	def gha_job_id(self):
		return f"image_cli_{self.board_id}-{self.branch}-{self.release}"  # @TODO desktops extensions etc
		pass

	def gha_job_definition(self):
		gha_job = {"runs-on": ["self-hosted", "Linux", "armbian"]}
		expression = f"needs.{self.ref_kernel.gha_job_id()}.outputs.up-to-date"
		gha_job["if"] = '${{ always() && ' + expression + " == 'no' }}"
		steps = []
		fake_step = {"name": f"Image CLI '{self.board_id}-{self.branch}'", "run": f'echo "fake image: {self.board_id}-{self.branch}"'}
		steps.append(fake_step)
		gha_job["steps"] = steps
		gha_job["needs"] = []
		if self.ref_kernel:
			gha_job["needs"].append(self.ref_kernel.gha_job_id())
		if self.ref_root_fs_cli:
			gha_job["needs"].append(self.ref_root_fs_cli.gha_job_id())
		return gha_job
