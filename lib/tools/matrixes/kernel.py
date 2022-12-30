import logging
from collections import Counter, defaultdict

from matrixes.base import BaseAggregator, BaseMatrixAggregate
from matrixes.input import MatrixInput

log: logging.Logger = logging.getLogger("matrix_kernel")


class KernelAggregator(BaseAggregator):
	def __init__(self, inputs: list[MatrixInput]):
		super().__init__(inputs)
		grouped_by_kernel_id: defaultdict[str, list[MatrixInput]] = defaultdict(list)
		for entry in inputs:
			grouped_by_kernel_id[entry.kernel_id()].append(entry)
		self.kernels: list[MatrixKernel] = [
			MatrixKernel(k_id, entries[0], entries, self) for k_id, entries in grouped_by_kernel_id.items() if k_id is not None]
		# Sort kernels by the number of all_items
		self.kernels.sort(key=lambda k: len(k.all_items), reverse=True)

		# Now create the preparation job
		self.kernel_prepare_job: KernelPrepareJob = KernelPrepareJob(self)

	def produce_gha_jobs(self, gha_jobs: dict[str, object]):
		# Prep job
		gha_jobs[self.kernel_prepare_job.gha_job_id()] = self.kernel_prepare_job.gha_job_definition()
		# Each kernel
		for input in self.kernels:
			gha_jobs[input.gha_job_id()] = input.gha_job_definition()


# @TODO: common publish-to-repo job for all kernels


class MatrixKernel(BaseMatrixAggregate):

	def __init__(self, aggregate_id: str, item: MatrixInput, all_items: list[MatrixInput], aggregator: "KernelAggregator"):
		"""Parse build matrix items into a kernel object; do sanity check so most attributes are the same across all items.
		That should detect sneaky families that change source/branch without changing the LINUXFAMILY"""
		super().__init__(aggregate_id, item, all_items)
		self.aggregator: KernelAggregator = aggregator
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

	def gha_job_id(self) -> str:
		return f"kernel-{self.aggregate_id}"

	def gha_job_definition(self):
		gha_job = {}

		# Only build if not already up to date
		expression = f"needs.{self.aggregator.kernel_prepare_job.gha_job_id()}.outputs.uptodate_kernel-{self.aggregate_id}"
		gha_job["if"] = '${{ ' + expression + " == 'no' }}"
		outputs = {}
		outputs["up-to-date"] = '${{ ' + expression + " }}"
		gha_job["outputs"] = outputs

		gha_job["runs-on"] = ["self-hosted", "Linux", "armbian"]  # Fake
		gha_job["needs"] = []
		gha_job["needs"].append(self.aggregator.kernel_prepare_job.gha_job_id())
		steps = []
		fake_step = {"name": f"Build Kernel '{self.aggregate_id}'", "run": f'echo "fake kernel: {self.aggregate_id}"'}
		steps.append(fake_step)
		gha_job["steps"] = steps
		return gha_job


class KernelPrepareJob:
	def __init__(self, k_aggr: "KernelAggregator"):
		self.k_aggr: KernelAggregator = k_aggr

	def gha_job_id(self) -> str:
		return f"kernel-prepare-all"

	def gha_job_definition(self):
		gha_job = {}
		gha_job["runs-on"] = ["self-hosted", "Linux", "armbian"]  # Fake
		steps = []
		outputs = {}

		for one_kernel in self.k_aggr.kernels:
			run = f'echo "fake kernel prepare: {one_kernel.aggregate_id}"\necho "uptodate=$((( RANDOM % 2 )) && echo -n "yes" || echo -n "no")" >> $GITHUB_OUTPUT'
			step_id = f"prepare_{one_kernel.aggregate_id}"
			fake_step = {"id": step_id, "name": f"Prepare Kernel '{one_kernel.aggregate_id}'", "run": run}
			steps.append(fake_step)
			outputs[f"desc_{one_kernel.gha_job_id()}"] = f"fake output for {one_kernel.gha_job_id()}"
			outputs[f"uptodate_{one_kernel.gha_job_id()}"] = f"${{{{ steps.{step_id}.outputs.uptodate }}}}"

		gha_job["steps"] = steps
		gha_job["outputs"] = outputs
		return gha_job
