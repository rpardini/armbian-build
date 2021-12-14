#!/usr/bin/env bash

function do_with_logging() {
	# @TODO: check we're not currently logging (eg: this has been called 2 times without exiting)
	export CURRENT_LOGGING_SECTION=${LOG_SECTION:-build}
	mkdir -p "${SRC}/output/debug"
	[[ -n "${DEST}" ]] && export CURRENT_LOGFILE="${DEST}/${LOG_SUBPATH}/000.${CURRENT_LOGGING_SECTION}.log"

	# We now execute whatever was passed as parameters, in some different conditions:
	# In both cases, writing to stderr will display to terminal.
	if [[ "${SLOW_LOG}" == "yes" ]]; then
		# If showing log, use tee, so we log to file AND show the log. stderr will flow to screen.
		echo "Showing log for" "$@"
		"$@" | tee -a "${CURRENT_LOGFILE}"
	else
		echo "NOT Showing log for" "$@"
		# If not showing the log, just send stdout to logfile. stderr will flow to screen.
		"$@" >> "${CURRENT_LOGFILE}"
	fi
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
