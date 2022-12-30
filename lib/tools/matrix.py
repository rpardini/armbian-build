import logging
import sys

from matrixes.input import MatrixInput
from matrixes.kernel import KernelAggregator
from matrixes.rootfs import RootFileSystemCLIAggregator
from matrixes.uboot import UBootAggregator
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
inputs = [input for input in inputs if input.BRANCH == "edge"]

log.info(f"Loaded {len(inputs)} entries from {json_file_name}")

# Group MatrixInput objects by kernel, uboot, and cli rootfs; more later
aggregator_kernel = KernelAggregator(inputs)
aggregator_u_boot = UBootAggregator(inputs)
aggregator_rootfs_cli = RootFileSystemCLIAggregator(inputs)

log.info(f"Parsed {len(aggregator_kernel.kernels)} kernels")
for kernel in aggregator_kernel.kernels:
	log.info(f"{kernel}")

log.info(f"Parsed {len(aggregator_u_boot.u_boots)} u-boots")
for u_boot in aggregator_u_boot.u_boots:
	log.info(f"{u_boot}")

log.info(f"Parsed {len(aggregator_rootfs_cli.rootfs_clis)} rootfs-cli")
for root_fs_cli in aggregator_rootfs_cli.rootfs_clis:
	log.info(f"{root_fs_cli}")

# Now create GHA Workflow to build all this.
gha_workflow = dict()
gha_workflow["name"] = "fake"
gha_workflow["on"] = {"workflow_dispatch": {"inputs": {"name": {"description": "Name", "required": True, "default": "World"}}}}
gha_jobs = {}

aggregator_rootfs_cli.produce_gha_jobs(gha_jobs)
aggregator_kernel.produce_gha_jobs(gha_jobs)

for input in inputs:
	gha_jobs[input.gha_job_id()] = input.gha_job_definition()

gha_workflow["jobs"] = gha_jobs

# Convert gha_workflow to YAML
gha_workflow_yaml = armbian_utils.to_yaml(gha_workflow)
log.info(f"YAML: \n{gha_workflow_yaml}")

# Write the YAML to a file
with open("/Users/rpardini/projects/armbian/armbian-release/.github/workflows/fake.yml", "w") as f:
	f.write(gha_workflow_yaml)
