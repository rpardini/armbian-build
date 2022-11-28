#!/usr/local/bin/python3

# Now using unidiff package
# https://pypi.org/project/unidiff/
# https://github.com/matiasb/python-unidiff

from unidiff import PatchSet
import mailbox
import os

patch_dir = '/Users/rpardini/projects/armbian/armbian-build/patch/kernel/archive/meson64-6.0'
# find all the files in the patch directory that end in .patch
patch_files = [os.path.join(patch_dir, f) for f in os.listdir(patch_dir) if f.endswith('.patch')]
# sort the files by name
patch_files.sort()

# loop over the files
for patch_file in patch_files:
	print('patch_file: ', patch_file)

	# parse the file as a mailbox
	mbox = mailbox.mbox(patch_file)
	print(f"mbox: {mbox}")
	# print how many emails are in there
	print(f"mbox length: {len(mbox)}")
	# if there is no emails, it's a pure patch file
	if len(mbox) == 0:
		print('pure patch file')
		continue

	# loop over the emails in the mbox
	for msg in mbox:
		subject = msg['Subject']
		patch = msg.get_payload()
		print(f"---- SUBJECT: {subject}")
		# print(patch)

		# split the patch itself and the description from the payload
		# split at most 2
		desc, patch_contents = patch.split("---\n", 1)
		print(f"desc: {desc}")
		# parse the patch, using the unidiff package
		patch_set = PatchSet(patch_contents)
		print(f"patch_set: {patch_set}")
		# make sure the patch is valid
		# loop over the files in the patch
		for patch_file in patch_set:
			print(f"patch_file: {patch_file}")
			# loop over the hunks in the patch
			for hunk in patch_file:
				print(f"hunk: {hunk}")
				# loop over the lines in the hunk
				for line in hunk:
					print(f"line: {line}")
	



