#!/usr/bin/env bash

function logging_error_show_log() {
	local message="$1"
	local context="$2"
	local stacktrace="$3"

	if [[ -f "${CURRENT_LOGFILE}" ]]; then
		local prefix_sed_contents="[👉]   "
		local prefix_sed_cmd="s/^/${prefix_sed_contents}/;"
		display_alert "👇 Showing logfile below 👇" "${CURRENT_LOGFILE}" "err"
		# shellcheck disable=SC2002 # my cat is great. thank you, shellcheck.
		cat "${CURRENT_LOGFILE}" | grep -v -e "^$" | sed -e "${prefix_sed_cmd}" 1>&2 # write it TO stderr!!
		display_alert "👆 Showing logfile above 👆" "${CURRENT_LOGFILE}" "err"
		display_alert "🦞 Error Msg" "$message" "err"
		display_alert "🐞 Error stacktrace" "$stacktrace" "err"
	else
		display_alert "✋ Error Log not Available" "${CURRENT_LOGFILE}" "err"
	fi
	return 0
}

function do_with_logging() {
	[[ ! -n "${DEST}" ]] && exit_with_error "DEST is not defined. Can't start logging."

	# @TODO: check we're not currently logging (eg: this has been called 2 times without exiting)
	export CURRENT_LOGGING_SECTION=${LOG_SECTION:-build}
	export CURRENT_LOGGING_DIR="${DEST}/${LOG_SUBPATH}"
	export CURRENT_LOGFILE="${CURRENT_LOGGING_DIR}/000.${CURRENT_LOGGING_SECTION}.log"
	mkdir -p "${CURRENT_LOGGING_DIR}"

	# We now execute whatever was passed as parameters, in some different conditions:
	# In both cases, writing to stderr will display to terminal.
	# So whatever is being called, should prevent rogue stuff writing to stderr.
	# this is mostly handled by redirecting stderr to stdout: 2>&1

	local prefix_sed_contents="[ ${CURRENT_LOGGING_SECTION} ]  "
	local prefix_sed_cmd="s/^/${prefix_sed_contents}/;"
	local FAILED=1
	if [[ "${SLOW_LOG}" == "yes" ]]; then
		# If showing log, use tee, so we log to file AND show the log. stderr will flow to screen.
		#echo "<START $1> Showing log for" "$@"
		# This is sick. Create a 3rd file descriptor sending it to sed. https://unix.stackexchange.com/questions/174849/redirecting-stdout-to-terminal-and-file-without-using-a-pipe
		exec 3> >(sed -e "${prefix_sed_cmd}") # tee -a "${CURRENT_LOGFILE}" |
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

	local padding=""
	local suffix=""
	[[ -n ${2} ]] && suffix="[\e[1;37m${2}\x1B[0m]"

	case "${3}" in
		err | error)
			echo -e "[\e[0;31m${padding}💥${padding}\x1B[0m] ${1} ${suffix}" >&2
			;;

		wrn | warn)
			echo -e "[\e[0;35m${padding}⚠️${padding} \x1B[0m] ${1} ${suffix}" >&2
			;;

		ext)
			echo -e "[\e[0;32m${padding}👽${padding}\x1B[0m] \e[1;32m${1}\x1B[0m ${suffix}" >&2
			;;

		info)
			echo -e "[\e[0;32m${padding}🌴${padding}\x1B[0m] ${1} ${suffix}" >&2
			;;

		*)
			echo -e "[\e[0;32m${padding}✨${padding}\x1B[0m] ${1} ${suffix}" >&2
			;;
	esac
}
