import logging
from collections import defaultdict

from matrixes.base import BaseAggregator, BaseMatrixAggregate
from matrixes.gha import WorkflowFactory, BaseWorkflowJob
from matrixes.input import MatrixInput

log: logging.Logger = logging.getLogger("matrix_rootfs")


class RootFileSystemCLIAggregator(BaseAggregator):
	def __init__(self, inputs: list[MatrixInput]):
		super().__init__(inputs)
		grouped_by_rootfs_cli_id: defaultdict[str, list[MatrixInput]] = defaultdict(list)
		for entry in inputs:
			grouped_by_rootfs_cli_id[entry.rootfs_cli_id()].append(entry)

		self.rootfs_clis: list[MatrixRootFileSystemCLI] = [
			MatrixRootFileSystemCLI(rf_id, entries[0], entries) for rf_id, entries in grouped_by_rootfs_cli_id.items() if rf_id is not None]
		self.rootfs_clis.sort(key=lambda k: len(k.all_items), reverse=True)

		# group the groupings, by arch
		grouped_by_arch: defaultdict[str, list[MatrixRootFileSystemCLI]] = defaultdict(list)
		for entry in self.rootfs_clis:
			grouped_by_arch[entry.arch].append(entry)

		# prepare jobs, one per arch
		self.prepare_job_per_arch: dict[str, RootfsArchPrepareJob] = {}
		for arch, entries in grouped_by_arch.items():
			self.prepare_job_per_arch[arch] = RootfsArchPrepareJob(self, arch, entries)

	def produce_gha_jobs(self, wf: WorkflowFactory):
		# Prep job
		for arch, job in self.prepare_job_per_arch.items():
			wf.add_job(job)

		for rootfs in self.rootfs_clis:
			rootfs.rootfs_job = wf.add_job(RootfsBuildJob(self, rootfs))


class MatrixRootFileSystemCLI(BaseMatrixAggregate):

	def __init__(self, aggregate_id: str, item: MatrixInput, all_items: list[MatrixInput]):
		super().__init__(aggregate_id, item, all_items)
		self.rootfs_job: "RootfsBuildJob | None" = None
		self.boards: set[str] = self.unique(lambda i: i.board_id)
		self.arch: str = self.sanity_check_same(lambda i: i.ARCH)
		self.release: str = self.sanity_check_same(lambda i: i.RELEASE)
		if aggregate_id is not None:
			for one_item in all_items:
				one_item.ref_root_fs_cli = self

	def __str__(self) -> str:
		return f'<RootFSCLI name="{self.aggregate_id}"  boards="{len(self.boards)}" />'

	def gha_job_id(self) -> str:
		return f"rootfs-cli-{self.aggregate_id}"

	def gha_job_definition(self):
		gha_job = {}
		gha_job["runs-on"] = ["self-hosted", "Linux", "armbian"]  # Fake
		steps = []
		fake_step = {"name": f"Build CLI RootFS '{self.aggregate_id}'", "run": f'echo "fake rootfs: {self.aggregate_id}"'}
		steps.append(fake_step)
		gha_job["steps"] = steps
		return gha_job


class RootfsBuildJob(BaseWorkflowJob):
	def __init__(self, r_aggr: "RootFileSystemCLIAggregator", rootfs: MatrixRootFileSystemCLI):
		super().__init__(f"rootfs-build-{rootfs.aggregate_id}", f"RootFS build job for {rootfs.aggregate_id}")


class RootfsArchPrepareJob(BaseWorkflowJob):
	def __init__(self, r_aggr: "RootFileSystemCLIAggregator", arch: str, entries: list[MatrixRootFileSystemCLI]):
		super().__init__(f"rootfs-arch-{arch}", f"Common jobs for all rootfs of arch {arch}")
		self.arch = arch
		self.entries = entries
		self.r_aggr = r_aggr

	def gha_job_definition(self):
		gha_job = {}
		gha_job["runs-on"] = ["self-hosted", "Linux", "armbian"]  # Fake
		steps = []
		outputs = {}

		for one_rootfs in self.rs_in_arch:
			run = f'echo "fake rootfs prepare: {one_rootfs.aggregate_id}"\necho "uptodate=$((( RANDOM % 2 )) && echo -n "yes" || echo -n "no")" >> $GITHUB_OUTPUT'
			step_id = f"prepare_{one_rootfs.aggregate_id}"
			fake_step = {"id": step_id, "name": f"Prepare Kernel '{one_rootfs.aggregate_id}'", "run": run}
			steps.append(fake_step)
			outputs[f"desc_{one_rootfs.gha_job_id()}"] = f"fake output for {one_rootfs.gha_job_id()}"
			outputs[f"uptodate_{one_rootfs.gha_job_id()}"] = f"${{{{ steps.{step_id}.outputs.uptodate }}}}"

		gha_job["steps"] = steps
		gha_job["outputs"] = outputs
		return gha_job
