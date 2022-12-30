import logging
import sys
from collections import defaultdict

from tools.common import armbian_utils
from tools.common.matrix_utils import MatrixInput, MatrixKernel, MatrixUboot, MatrixRootFileSystemCLI

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
inputs = [MatrixInput(entry) for entry in json_contents]

log.info(f"Loaded {len(inputs)} entries from {json_file_name}")

# Group MatrixInput objects by kernel_id
grouped_by_kernel_id = defaultdict(list)
grouped_by_uboot_id = defaultdict(list)
grouped_by_rootfs_cli_id = defaultdict(list)
for entry in inputs:
	grouped_by_kernel_id[entry.kernel_id()].append(entry)
	grouped_by_uboot_id[entry.uboot_id()].append(entry)
	grouped_by_rootfs_cli_id[entry.rootfs_cli_id()].append(entry)

# Instantiate MatrixKernel objects and add them to the kernels list
kernels = [MatrixKernel(kid, entries[0], entries) for kid, entries in grouped_by_kernel_id.items() if kid is not None]
# Sort kernels by the number of all_items
kernels.sort(key=lambda k: len(k.all_items), reverse=True)

# Instantiate MatrixUboot objects and add them to the u-boots list
u_boots = [MatrixUboot(ub_id, entries[0], entries) for ub_id, entries in grouped_by_uboot_id.items() if ub_id is not None]
# Sort u-boots by the number of all_items
u_boots.sort(key=lambda k: len(k.all_items), reverse=True)

# Instantiate MatrixRootFileSystemCLI objects and add them to the rootfs-clis list
rootfs_clis = [MatrixRootFileSystemCLI(rf_id, entries[0], entries) for rf_id, entries in grouped_by_rootfs_cli_id.items() if rf_id is not None]
# Sort rootfs-clis by the number of all_items
rootfs_clis.sort(key=lambda k: len(k.all_items), reverse=True)

log.info(f"Parsed {len(kernels)} kernels")
for kernel in kernels:
	log.info(f"{kernel}")

log.info(f"Parsed {len(u_boots)} u-boots")
for u_boot in u_boots:
	log.info(f"{u_boot}")

log.info(f"Parsed {len(rootfs_clis)} rootfs-cli")
for root_fs_cli in rootfs_clis:
	log.info(f"{root_fs_cli}")

