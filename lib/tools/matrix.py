import logging
import sys
from collections import defaultdict

from tools.common import armbian_utils
from tools.common.matrix_utils import MatrixInput, MatrixKernel, MatrixUboot, MatrixRootFileSystemCLI, KernelAggregator

# Prepare logging
armbian_utils.setup_logging()
log: logging.Logger = logging.getLogger("matrix")
armbian_utils.show_incoming_environment()

# read the first argv parameter as json_file_name
json_file_name = sys.argv[1]

# read the file; use stdlib only
json_contents_str = open(json_file_name, "r").read()

# parse the JSON
json_contents = armbian_utils.parse_json(json_contents_str)

log.info(f"Loaded {len(json_contents)} entries from {json_file_name}")

# Convert json_contents to a list of MatrixInput objects
inputs: list[MatrixInput] = [MatrixInput(entry) for entry in json_contents]

# Filter only 'edge' branch @TODO: fake for testing
inputs = [input for input in inputs if input.BRANCH == "edge"]

log.info(f"Loaded {len(inputs)} entries from {json_file_name}")

# Group MatrixInput objects by kernel, uboot, and cli rootfs; more later
grouped_by_uboot_id: defaultdict[str, list[MatrixInput]] = defaultdict(list)
grouped_by_rootfs_cli_id: defaultdict[str, list[MatrixInput]] = defaultdict(list)
for entry in inputs:
	grouped_by_uboot_id[entry.uboot_id()].append(entry)
	grouped_by_rootfs_cli_id[entry.rootfs_cli_id()].append(entry)

aggregator_kernel = KernelAggregator(inputs)

# Instantiate MatrixUboot objects and add them to the u-boots list
u_boots = [MatrixUboot(ub_id, entries[0], entries) for ub_id, entries in grouped_by_uboot_id.items() if ub_id is not None]
# Sort u-boots by the number of all_items
u_boots.sort(key=lambda k: len(k.all_items), reverse=True)

# Instantiate MatrixRootFileSystemCLI objects and add them to the rootfs-clis list
rootfs_clis = [MatrixRootFileSystemCLI(rf_id, entries[0], entries) for rf_id, entries in grouped_by_rootfs_cli_id.items() if rf_id is not None]
# Sort rootfs-clis by the number of all_items
rootfs_clis.sort(key=lambda k: len(k.all_items), reverse=True)

log.info(f"Parsed {len(aggregator_kernel.kernels)} kernels")
for kernel in aggregator_kernel.kernels:
	log.info(f"{kernel}")

log.info(f"Parsed {len(u_boots)} u-boots")
for u_boot in u_boots:
	log.info(f"{u_boot}")

log.info(f"Parsed {len(rootfs_clis)} rootfs-cli")
for root_fs_cli in rootfs_clis:
	log.info(f"{root_fs_cli}")

# Now create GHA Workflow to build all this.
gha_workflow = dict()
gha_workflow["name"] = "fake"
gha_workflow["on"] = {"workflow_dispatch": {"inputs": {"name": {"description": "Name", "required": True, "default": "World"}}}}
gha_jobs = {}

for input in rootfs_clis:
	gha_jobs[input.gha_job_id()] = input.gha_job_definition()

aggregator_kernel.produce_gha_jobs(gha_jobs)

for input in inputs:
	gha_jobs[input.gha_job_id()] = input.gha_job_definition()

gha_workflow["jobs"] = gha_jobs

# Convert gha_workflow to YAML
gha_workflow_yaml = armbian_utils.to_yaml((gha_workflow))
log.info(f"YAML: \n{gha_workflow_yaml}")

# Write the YAML to a file
with open("/Users/rpardini/projects/armbian/armbian-release/.github/workflows/fake.yml", "w") as f:
	f.write(gha_workflow_yaml)
