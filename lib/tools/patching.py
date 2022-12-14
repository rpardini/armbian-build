#! /bin/env python3
import logging
import traceback

# Let's use GitPython to query and manipulate the git repo
from git import Repo, GitCmdObjectDB, InvalidGitRepositoryError

import common.armbian_utils as armbian_utils
import common.patching_utils as patching_utils
from common.md_asset_log import SummarizedMarkdownWriter

# Prepare logging
armbian_utils.setup_logging()
log: logging.Logger = logging.getLogger("patching")

# Show the environment variables we've been called with
armbian_utils.show_incoming_environment()

# Let's start by reading environment variables.
# Those are always needed, and we should bomb if they're not set.
SRC = armbian_utils.get_from_env_or_bomb("SRC")
PATCH_TYPE = armbian_utils.get_from_env_or_bomb("PATCH_TYPE")
PATCH_DIRS_TO_APPLY = armbian_utils.parse_env_for_tokens("PATCH_DIRS_TO_APPLY")
APPLY_PATCHES = armbian_utils.get_from_env("APPLY_PATCHES")
PATCHES_TO_GIT = armbian_utils.get_from_env("PATCHES_TO_GIT")
REWRITE_PATCHES = armbian_utils.get_from_env("REWRITE_PATCHES")
apply_patches = APPLY_PATCHES == "yes"
apply_patches_to_git = PATCHES_TO_GIT == "yes"
rewrite_patches_in_place = REWRITE_PATCHES == "yes"

# Those are optional.
GIT_WORK_DIR = armbian_utils.get_from_env("GIT_WORK_DIR")
BOARD = armbian_utils.get_from_env("BOARD")
TARGET = armbian_utils.get_from_env("TARGET")
USERPATCHES_PATH = armbian_utils.get_from_env("USERPATCHES_PATH")

# Some path possibilities
CONST_PATCH_ROOT_DIRS = []
for patch_dir_to_apply in PATCH_DIRS_TO_APPLY:
	if USERPATCHES_PATH is not None:
		CONST_PATCH_ROOT_DIRS.append(
			patching_utils.PatchRootDir(f"{USERPATCHES_PATH}/{PATCH_TYPE}/{patch_dir_to_apply}", "user",
						    PATCH_TYPE, USERPATCHES_PATH))
	CONST_PATCH_ROOT_DIRS.append(
		patching_utils.PatchRootDir(f"{SRC}/patch/{PATCH_TYPE}/{patch_dir_to_apply}", "core", PATCH_TYPE, SRC))

# Some sub-path possibilities:
CONST_PATCH_SUB_DIRS = []
if TARGET is not None:
	CONST_PATCH_SUB_DIRS.append(patching_utils.PatchSubDir(f"target_{TARGET}", "target"))
if BOARD is not None:
	CONST_PATCH_SUB_DIRS.append(patching_utils.PatchSubDir(f"board_{BOARD}", "board"))
CONST_PATCH_SUB_DIRS.append(patching_utils.PatchSubDir("", "common"))

# Prepare the full list of patch directories to apply
ALL_DIRS = []
for patch_root_dir in CONST_PATCH_ROOT_DIRS:
	for patch_sub_dir in CONST_PATCH_SUB_DIRS:
		ALL_DIRS.append(patching_utils.PatchDir(patch_root_dir, patch_sub_dir, SRC))

# Now, loop over ALL_DIRS, and find the patch files in each directory
for one_dir in ALL_DIRS:
	one_dir.find_patch_files()

# Gather all the PatchFileInDir objects into a single list
ALL_DIR_PATCH_FILES: list[patching_utils.PatchFileInDir] = []
for one_dir in ALL_DIRS:
	for one_patch_file in one_dir.patch_files:
		ALL_DIR_PATCH_FILES.append(one_patch_file)

ALL_DIR_PATCH_FILES_BY_NAME: dict[(str, patching_utils.PatchFileInDir)] = {}
for one_patch_file in ALL_DIR_PATCH_FILES:
	# Hack: do a single one: DO NOT ENABLE THIS
	# if one_patch_file.file_name == "board-pbp-add-dp-alt-mode.patch":
	ALL_DIR_PATCH_FILES_BY_NAME[one_patch_file.file_name] = one_patch_file

# sort the dict by the key (file_name, sans dir...)
ALL_DIR_PATCH_FILES_BY_NAME = dict(sorted(ALL_DIR_PATCH_FILES_BY_NAME.items()))

# Now, actually read the patch files.
# Patch files might be in mailbox format, and in that case contain more than one "patch".
# It might also be just a unified diff, with no mailbox headers.
# We need to read the file, and see if it's a mailbox file; if so, split into multiple patches.
# If not, just use the whole file as a single patch.
# We'll store the patches in a list of Patch objects.
VALID_PATCHES: list[patching_utils.PatchInPatchFile] = []
for key in ALL_DIR_PATCH_FILES_BY_NAME:
	patch_file_in_dir: patching_utils.PatchFileInDir = ALL_DIR_PATCH_FILES_BY_NAME[key]
	patches_from_file = patch_file_in_dir.split_patches_from_file()
	VALID_PATCHES.extend(patches_from_file)

# Now, some patches might not be mbox-formatted, or somehow else invalid. We can try and recover those.
# That is only possible if we're applying patches to git.
# Rebuilding description is only possible if we've the git repo where the patches themselves reside.
for patch in VALID_PATCHES:
	try:
		patch.parse_patch()  # this handles diff-level parsing; modifies itself; throws exception if invalid
	except Exception as invalid_exception:
		log.error(
			f"Exception while reading {patch.parent.full_file_path()}:{patch.counter}: {invalid_exception}")
		# log the exception stacktrace
		log.debug(traceback.format_exc())

# Now, for patches missing description, try to recover descriptions from the Armbian repo.
# It might be the SRC is not a git repo (say, when building in Docker), so we need to check.
if apply_patches_to_git:
	try:
		armbian_git_repo = Repo(SRC)
	except InvalidGitRepositoryError:
		armbian_git_repo = None
		log.warning(f"- SRC is not a git repo, so cannot recover descriptions from there.")
	if armbian_git_repo is not None:
		for patch in VALID_PATCHES:
			if patch.desc is None:
				patching_utils.perform_git_archeology(SRC, armbian_git_repo, patch)

# Create markdown about the patches
with SummarizedMarkdownWriter(f"patching_{PATCH_TYPE}.md", f"{PATCH_TYPE} patching") as md:
	patch_count = 0
	for one_patch in VALID_PATCHES:
		md.write(f"- `{one_patch}`\n")
		patch_count += 1
	if patch_count == 0:
		md.write(f"- No patches found.\n")
	md.add_summary(f"{patch_count} patches")

# Now, we need to apply the patches.
if not apply_patches:
	log.warning("Not applying patches.")
	exit(0)

log.info(f"- Applying {len(VALID_PATCHES)} patches...")

git_repo = Repo(GIT_WORK_DIR, odbt=GitCmdObjectDB)
BRANCH_FOR_PATCHES = armbian_utils.get_from_env_or_bomb("BRANCH_FOR_PATCHES")
BASE_GIT_REVISION = armbian_utils.get_from_env("BASE_GIT_REVISION")
BASE_GIT_TAG = armbian_utils.get_from_env("BASE_GIT_TAG")
if BASE_GIT_REVISION is None:
	if BASE_GIT_TAG is None:
		raise Exception("BASE_GIT_REVISION or BASE_GIT_TAG must be set")
	else:
		BASE_GIT_REVISION = git_repo.tags[BASE_GIT_TAG].commit.hexsha
		log.debug(f"Found BASE_GIT_REVISION={BASE_GIT_REVISION} for BASE_GIT_TAG={BASE_GIT_TAG}")

patching_utils.prepare_clean_git_tree_for_patching(git_repo, BASE_GIT_REVISION, BRANCH_FOR_PATCHES)

# Loop over the VALID_PATCHES, and apply them.
for one_patch in VALID_PATCHES:
	log.info(f"Applying patch {one_patch}")
	one_patch.apply_patch(GIT_WORK_DIR)
	if apply_patches_to_git:
		committed = one_patch.commit_changes_to_git(git_repo, (not rewrite_patches_in_place))
		if rewrite_patches_in_place:
			rewritten_patch = patching_utils.export_commit_as_patch(git_repo, committed['commit_hash'])
			one_patch.rewritten_patch = rewritten_patch

if rewrite_patches_in_place:
	# Now; we need to write the patches to files.
	# loop over the patches, and group them by the parent; the parent is the PatchFileInDir object.
	patch_files_by_parent: dict[(patching_utils.PatchFileInDir, list[patching_utils.PatchInPatchFile])] = {}
	for one_patch in VALID_PATCHES:
		if one_patch.parent not in patch_files_by_parent:
			patch_files_by_parent[one_patch.parent] = []
		patch_files_by_parent[one_patch.parent].append(one_patch)
	parent: patching_utils.PatchFileInDir
	for parent in patch_files_by_parent:
		patches = patch_files_by_parent[parent]
		parent.rewrite_patch_file(patches)
