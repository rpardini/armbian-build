#!/usr/bin/env bash

function do_with_logging() {
	# @TODO: check we're not currently logging (eg: this has been called 2 times without exiting)
	export CURRENT_LOGGING_SECTION=${LOG_SECTION:-build}
	mkdir -p "${SRC}/output/debug"
	[[ -n "${DEST}" ]] && export CURRENT_LOGFILE="${DEST}/${LOG_SUBPATH}/000.${CURRENT_LOGGING_SECTION}.log"

	# We now execute whatever was passed as parameters, in some different conditions:
	# In both cases, writing to stderr will display to terminal.
	# So whatever is being called, should prevent rogue stuff writing to stderr.
	# this is mostly handled by redirecting stderr to stdout: 2>&1

	local PREFIX_SED_CONTENTS="[ ${CURRENT_LOGGING_SECTION} ]  "
	local PREFIX_SED_CMD="s/^/${PREFIX_SED_CONTENTS}/;"
	local FAILED=1
	if [[ "${SLOW_LOG}" != "no" ]]; then
		# If showing log, use tee, so we log to file AND show the log. stderr will flow to screen.
		#echo "<START $1> Showing log for" "$@"
		# This is sick. Create a 3rd file descriptor sending it to sed. https://unix.stackexchange.com/questions/174849/redirecting-stdout-to-terminal-and-file-without-using-a-pipe
		exec 3> >(sed -e "${PREFIX_SED_CMD}") # tee -a "${CURRENT_LOGFILE}" |
		# tee_pid=$!
		{ "$@" && FAILED=0; } >&3
		#echo "<END $1> FAILED:${FAILED} Showing log for" "$@"
	else
		#echo "<START $1> NOT Showing log for" "$@"
		# If not showing the log, just send stdout to logfile. stderr will flow to screen.
		{ "$@" && FAILED=0; } >> "${CURRENT_LOGFILE}"
		#echo "<END $1> FAILED:${FAILED} NOT Showing log for" "$@"
	fi

	return $FAILED # hopefully not
}

display_alert() {
	# We'll be writing to stderr (" >&2"), so also write the message to the generic logfile, for context.
	[[ -n "${DEST}" ]] && echo "Displaying message:" "$@" >> "${DEST}/${LOG_SUBPATH}/output.log"

	local suffix=""
	[[ -n ${2} ]] && suffix="[\e[0;33m ${2} \x1B[0m]"

	case "${3}" in
		err | error)
			echo -e "[\e[0;31m error \x1B[0m] ${1} ${suffix}" >&2
			;;

		wrn | warn)
			echo -e "[\e[0;35m warn \x1B[0m] ${1} ${suffix}" >&2
			;;

		ext)
			echo -e "[\e[0;32m o.k. \x1B[0m] \e[1;32m${1}\x1B[0m ${suffix}" >&2
			;;

		info)
			echo -e "[\e[0;32m o.k. \x1B[0m] ${1} ${suffix}" >&2
			;;

		*)
			echo -e "[\e[0;32m .... \x1B[0m] ${1} ${suffix}" >&2
			;;
	esac
}
