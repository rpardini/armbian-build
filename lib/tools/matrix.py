import logging
import sys

from matrixes.base import BaseAggregator
from matrixes.gha import WorkflowFactory
from matrixes.image import ImageAggregator
from matrixes.input import MatrixInput
from matrixes.kernel import KernelAggregator
from tools.common import armbian_utils

# Prepare logging
armbian_utils.setup_logging()
log: logging.Logger = logging.getLogger("matrix")
armbian_utils.show_incoming_environment()

json_file_name = sys.argv[1]
json_contents_str = open(json_file_name, "r").read()
json_contents = armbian_utils.parse_json(json_contents_str)

log.info(f"Loaded {len(json_contents)} entries from {json_file_name}")

# Convert json_contents to a list of MatrixInput objects
inputs: list[MatrixInput] = [MatrixInput(entry) for entry in json_contents]

# Filter only 'edge' branch @TODO: fake for testing
inputs = [m_input for m_input in inputs if m_input.BRANCH == "edge"]

log.info(f"Loaded {len(inputs)} entries from {json_file_name}")

# Create aggregators in the order wanted.
all_aggregators: list[BaseAggregator] = \
	[
		(KernelAggregator(inputs)),
		# (RootFileSystemCLIAggregator(inputs)), # disabled for now
		# (UBootAggregator(inputs)), # disabled for now
		#(ImageAggregator(inputs))
	]

for aggregator in all_aggregators:
	aggregator.show_entries()

wf = WorkflowFactory()
for aggregator in all_aggregators:  # ordering important
	aggregator.produce_gha_jobs(wf)

# Convert gha_workflow to YAML
gha_workflow_yaml = armbian_utils.to_yaml(wf.render_yaml())
# log.info(f"YAML: \n{gha_workflow_yaml}")

# Write the YAML to a file
with open("/Users/rpardini/projects/armbian/armbian-release/.github/workflows/fake.yml", "w") as f:
	f.write(gha_workflow_yaml)
