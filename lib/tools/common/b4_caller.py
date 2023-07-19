# ‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹
#  SPDX-License-Identifier: GPL-2.0
#  Copyright (c) 2023 Ricardo Pardini <ricardo@pardini.net>
#  This file is a part of the Armbian Build Framework https://github.com/armbian/build/
# ‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹‹
import argparse
import logging

import b4
import b4.mbox

log: logging.Logger = logging.getLogger("b4_caller")


def get_patch_via_b4(lore_link):
	# Fool get_msgid with a fake argparse.Namespace
	msgid_args = argparse.Namespace()
	msgid_args.msgid = lore_link
	msgid = b4.get_msgid(msgid_args)
	log.debug(f"msgid: {msgid}")

	msgs = b4.get_pi_thread_by_msgid(msgid)

	count = len(msgs)
	log.debug('Analyzing %s messages in the thread', count)

	lmbx = b4.LoreMailbox()
	for msg in msgs:
		lmbx.add_message(msg)

	lser = lmbx.get_series()

	# hack at the "main config" to avoid attestation etc; b4's config is a global MAIN_CONFIG
	config = b4.get_main_config()
	config['attestation-policy'] = "off"

	# hack at the "user config", since there is not really an user here; its a global USER_CONFIG
	uconfig = b4.get_user_config()
	uconfig['name'] = "Armbian Autopatcher"
	uconfig['email'] = "auto.patcher@next.armbian.com"
	log.warning(f"uconfig: {uconfig}")

	# prepare for git am
	am_msgs = lser.get_am_ready(addlink=True, linkmask='https://lore.kernel.org/r/%s')
	log.debug('Total patches: %s', len(am_msgs))

	top_msgid = None
	for lmsg in lser.patches:
		if lmsg is not None:
			top_msgid = lmsg.msgid
			break

	if top_msgid is None:
		raise Exception(f"Could not find any patches in the series '{lore_link}'.")

	# slug for possibly naming the file
	slug = lser.get_slug(extended=True)
	log.debug('slug: %s', slug)

	# final contents of patch file for our purposes
	body = b''

	for msg in am_msgs:
		body += b'From git@z Thu Jan  1 00:00:00 1970\n'  # OH! the b4-marker!
		body += b4.LoreMessage.get_msg_as_bytes(msg, headers='decode')

	log.info("Done")

	return {"body": body, "slug": slug}

# b4.save_git_am_mbox(am_msgs, fh)


# msgid, msgs = b4.retrieve_messages(cmdargs)
