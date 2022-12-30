import logging
from collections import defaultdict

from matrixes.base import BaseAggregator, BaseMatrixAggregate
from matrixes.input import MatrixInput

log: logging.Logger = logging.getLogger("matrix_u-boot")


class UBootAggregator(BaseAggregator):
	def __init__(self, inputs: list[MatrixInput]):
		super().__init__(inputs)
		grouped_by_uboot_id: defaultdict[str, list[MatrixInput]] = defaultdict(list)
		for entry in inputs:
			grouped_by_uboot_id[entry.uboot_id()].append(entry)

		# Instantiate MatrixUboot objects and add them to the u-boots list
		self.u_boots: list[MatrixUboot] = [
			MatrixUboot(ub_id, entries[0], entries, self) for ub_id, entries in grouped_by_uboot_id.items() if ub_id is not None]
		# Sort u-boots by the number of all_items
		self.u_boots.sort(key=lambda k: len(k.all_items), reverse=True)

	def produce_gha_jobs(self, gha_jobs: dict[str, object]):
		# @TODO, uboots are complex and have a previous aggregation step, since they might just be the same
		# across BRANCHes in the same BOARD.
		# for input in self.u_boots:
		#	gha_jobs[input.gha_job_id()] = input.gha_job_definition()
		pass


class MatrixUboot(BaseMatrixAggregate):

	def __init__(self, aggregate_id: str, item: MatrixInput, all_items: list[MatrixInput], aggregator: "UBootAggregator"):
		super().__init__(aggregate_id, item, all_items)
		self.aggregator: UBootAggregator = aggregator
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
