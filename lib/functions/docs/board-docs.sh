#
# SPDX-License-Identifier: GPL-2.0
# Copyright (c) 2023 Ricardo Pardini <ricardo@pardini.net>
# This file is a part of the Armbian Build Framework https://github.com/armbian/build/
#

function prepare_board_docs_via_exts() {
	# Run the hooks, which writes to stdout, in a subshell, and capture stdout into a variable.
	declare board_docs=""
	board_docs="$(
		call_extension_method "board_docs" <<- 'BOARD_DOCS'
			*write documentation about the board/branch combination*
			you should write Markdown to stdout. it runs late in the build process. output will be processed and rendered into ANSI/HTML.
		BOARD_DOCS
	)"

	if [[ "${board_docs}" != "" ]]; then
		display_alert "Board documentation" "${board_docs}" "info"
	fi
}

function post_build_image__board_docs() {
	prepare_board_docs_via_exts || true # don't fail
}
