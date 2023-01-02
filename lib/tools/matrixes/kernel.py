import logging
from collections import Counter, defaultdict

from matrixes.base import BaseAggregator, BaseMatrixAggregate
from matrixes.gha import WorkflowFactory, BaseWorkflowJob, WorkflowJobStep, WorkflowJobOutput
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

		# Now create the preparation job; this is used by the build jobs
		self.kernel_prepare_job: KernelPrepareJob = KernelPrepareJob(self)

	def produce_gha_jobs(self, wf: WorkflowFactory):
		# Prep job
		wf.add_job(self.kernel_prepare_job)
		# Each kernel
		for kernel in self.kernels:
			kernel.kernel_job = wf.add_job(KernelBuildJob(self, kernel))

	def show_entries(self):
		log.info(f"Parsed {len(self.kernels)} kernels")
		for kernel in self.kernels:
			log.info(f"{kernel}")


# @TODO: common publish-to-repo job for all kernels


class MatrixKernel(BaseMatrixAggregate):

	def __init__(self, aggregate_id: str, item: MatrixInput, all_items: list[MatrixInput], aggregator: "KernelAggregator"):
		"""Parse build matrix items into a kernel object; do sanity check so most attributes are the same across all items.
		That should detect sneaky families that change source/branch without changing the LINUXFAMILY"""
		super().__init__(aggregate_id, item, all_items)

		self.kernel_job: "KernelBuildJob | None" = None
		self.kernel_prepare_job_step: WorkflowJobStep | None = None
		self.kpjo_uptodate: WorkflowJobOutput | None = None

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


class KernelPrepareJob(BaseWorkflowJob):
	def __init__(self, k_aggr: "KernelAggregator"):
		super().__init__("kernel-prepare-all", "Prepare all kernels; each step determines the version hash and if it is already available.")
		self.k_aggr: KernelAggregator = k_aggr

		# Create a step for each kernel in the aggregator. Each step has 2 outputs: the version and is-it-up-to-date
		for one_kernel in self.k_aggr.kernels:
			step = self.add_step(
				f"prepare_{one_kernel.aggregate_id}", f"Calculate the version and up-to-date-ness for kernel {one_kernel.aggregate_id}")
			one_kernel.kernel_prepare_job_step = step  # @TODO: undeeded?
			step.run = f'echo "fake kernel prepare: {one_kernel.aggregate_id}"\necho "uptodate=$((( RANDOM % 2 )) && echo -n "yes" || echo -n "no")" >> $GITHUB_OUTPUT'
			one_kernel.kpjo_uptodate = self.add_job_output_from_step(step, "uptodate")


class KernelBuildJob(BaseWorkflowJob):
	def __init__(self, k_aggr: "KernelAggregator", kernel: MatrixKernel):
		super().__init__(f"kernel-{kernel.aggregate_id}", f"Some kernel {kernel.aggregate_id}")
		self.kernel = kernel
		self.k_aggr = k_aggr

		build_step = self.add_step(f"build_kernel_{kernel.aggregate_id}", f"Build Kernel {kernel.aggregate_id}")
		build_step.run = f'echo "fake kernel: {kernel.aggregate_id}"'

		uptodate_input = self.add_job_input_from_needed_job_output(kernel.kpjo_uptodate)
		self.add_job_output_from_input("up-to-date", uptodate_input)

		self.add_condition_from_input(uptodate_input, "== 'no'")
