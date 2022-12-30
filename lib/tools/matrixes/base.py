import logging

from matrixes.input import MatrixInput

log: logging.Logger = logging.getLogger("matrix_base")


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


# <Aggregators>
class BaseAggregator:
	def __init__(self, inputs: list[MatrixInput]):
		self.inputs: list[MatrixInput] = inputs
		pass
# </Aggregators>
