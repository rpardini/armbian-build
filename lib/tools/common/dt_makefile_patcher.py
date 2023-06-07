# ‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹
#  SPDX-License-Identifier: GPL-2.0
#  Copyright (c) 2023 Ricardo Pardini <ricardo@pardini.net>
#  This file is a part of the Armbian Build Framework https://github.com/armbian/build/
# ‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹

import logging
import os

log: logging.Logger = logging.getLogger("dt_makefile_patcher")


def auto_patch_dt_makefile(GIT_WORK_DIR: str, DT_REL_DIR: str) -> dict[str, str]:
	ret: dict[str, str] = {}
	DT_PATH = os.path.join(GIT_WORK_DIR, DT_REL_DIR)
	# Bomb if it does not exist or is not a directory
	if not os.path.isdir(DT_PATH):
		raise ValueError(f"DT_PATH={DT_PATH} is not a directory")
	MAKEFILE_PATH = os.path.join(DT_PATH, "Makefile")
	# Bomb if it does not exist or is not a file
	if not os.path.isfile(MAKEFILE_PATH):
		raise ValueError(f"MAKEFILE_PATH={MAKEFILE_PATH} is not a file")

	ret["MAKEFILE_PATH"] = MAKEFILE_PATH

	# Grab the contents of the Makefile
	with open(MAKEFILE_PATH, "r") as f:
		makefile_contents = f.read()
	log.info(f"Read {len(makefile_contents)} bytes from {MAKEFILE_PATH}")
	log.debug(f"Contents:\n{makefile_contents}")
	# Parse it into a list of lines
	makefile_lines = makefile_contents.splitlines()
	log.info(f"Read {len(makefile_lines)} lines from {MAKEFILE_PATH}")
	import re
	regex = r"^dtb-\$\(([a-zA-Z_]+)\)\s+\+=\s+([a-zA-Z0-9-_]+)\.dtb"
	# For each line, check if it matches the regex, extract the groups
	line_counter = 0
	line_first_match = 0
	line_last_match = 0
	config_var_dict: set[str] = set()
	for line in makefile_lines:
		line_counter += 1
		match = re.match(regex, line)
		if match:
			line_first_match = line_counter if line_first_match == 0 else line_first_match
			line_last_match = line_counter
			config_var_dict.add(match.group(1))
	# Sanity check, make sure config_var_dict is not empty and has only one element
	if len(config_var_dict) != 1:
		raise ValueError(f"config_var_dict={config_var_dict} -- found too few or too many CONFIG_ARCH_xx variables in {MAKEFILE_PATH}")
	config_var = config_var_dict.pop()
	log.info(f"Found '{config_var}' in Makefile lines {line_first_match} to {line_last_match}")
	# Now compute the preambles and the postamble
	preamble_lines = makefile_lines[:line_first_match - 1]
	postamble_lines = makefile_lines[line_last_match:]
	# Find all .dts files in DT_PATH (not subdirectories), but add to the list without .dts suffix
	dts_files = []
	listdir: list[str] = os.listdir(DT_PATH)
	for file in listdir:
		if file.endswith(".dts"):
			dts_files.append(file[:-4])
	# sort the list. alpha-sort: `meson-sm1-a95xf3-air-gbit` should come sooner than `meson-sm1-a95xf3-air`? why?
	dts_files.sort()
	log.info(f"Found {len(dts_files)} .dts files in {DT_PATH}")
	# Show them all
	for dts_file in dts_files:
		log.debug(f"Found {dts_file}")
	# Create the mid-amble, which is the list of .dtb files to be built
	midamble_lines = []
	for dts_file in dts_files:
		midamble_lines.append(f"dtb-$({config_var}) += {dts_file}.dtb")

	# Late to the game: if DT_DIR/overlay/Makefile exists, add it to the midamble
	overlay_lines = []
	DT_OVERLAY_PATH = os.path.join(DT_PATH, "overlay")
	DT_OVERLAY_MAKEFILE_PATH = os.path.join(DT_OVERLAY_PATH, "Makefile")
	if os.path.isfile(DT_OVERLAY_MAKEFILE_PATH):
		ret["DT_OVERLAY_MAKEFILE_PATH"] = DT_OVERLAY_MAKEFILE_PATH
		ret["DT_OVERLAY_PATH"] = DT_OVERLAY_PATH
		overlay_lines.append("")
		overlay_lines.append("subdir-y       := $(dts-dirs) overlay")

	# Now join the preambles, midamble, postamble and overlay stuff into a single list
	new_makefile_lines = preamble_lines + midamble_lines + postamble_lines + overlay_lines
	# Rewrite the Makefile with the new contents
	with open(MAKEFILE_PATH, "w") as f:
		f.write("\n".join(new_makefile_lines))
	log.info(f"Wrote {len(new_makefile_lines)} lines to {MAKEFILE_PATH}")

	return ret
