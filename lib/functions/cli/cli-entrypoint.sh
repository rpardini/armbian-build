function cli_entrypoint() {
	# array, readonly, global, for future reference, "exported" to shutup shellcheck
	declare -rg -x -a ARMBIAN_ORIGINAL_ARGV=("${@}")

	if [[ "${ARMBIAN_ENABLE_CALL_TRACING}" == "yes" ]]; then
		set -T # inherit return/debug traps
		mkdir -p "${SRC}"/output/call-traces
		echo -n "" > "${SRC}"/output/call-traces/calls.txt
		trap 'echo "${BASH_LINENO[@]}|${BASH_SOURCE[@]}|${FUNCNAME[@]}" >> ${SRC}/output/call-traces/calls.txt ;' RETURN
	fi

	# Process the command line, separating params (XX=YY) from non-params arguments.
	# That way they can be set in any order.
	declare -A -g ARMBIAN_PARSED_CMDLINE_PARAMS=() # A dict of PARAM=VALUE
	declare -a -g ARMBIAN_NON_PARAM_ARGS=()        # An array of all non-param arguments
	parse_cmdline_params "${@}"                    # which fills the above vars.

	# Now load the key=value pairs from cmdline into environment, before loading config or executing commands.
	# This will be done _again_ later, to make sure cmdline params override config et al.
	apply_cmdline_params_to_env "early" # which uses ARMBIAN_PARSED_CMDLINE_PARAMS
	# From here on, no more ${1} or stuff. We've parsed it all into ARMBIAN_PARSED_CMDLINE_PARAMS or ARMBIAN_NON_PARAM_ARGS and ARMBIAN_COMMAND.

	# Decide what we're gonna do. We've a few hardcoded, 1st-argument "commands".
	declare -A ARMBIAN_COMMANDS_TO_HANDLERS_DICT=(
		["docker"]="DOCKER_SUBCMD='docker' cli_handle_docker"
		["docker-purge"]="DOCKER_SUBCMD='purge' cli_handle_docker"
		["dockerpurge"]="DOCKER_SUBCMD='purge' cli_handle_docker"
		["docker-shell"]="DOCKER_SUBCMD='shell' cli_handle_docker"
		["dockershell"]="DOCKER_SUBCMD='shell' cli_handle_docker"
		["vagrant"]="cli_handle_vagrant"
	)

	# Check if the first non-param arg is a known command.
	local ARMBIAN_FIRST_NON_PARAM="${ARMBIAN_NON_PARAM_ARGS[0]}"
	display_alert "ARMBIAN_FIRST_NON_PARAM" "${ARMBIAN_FIRST_NON_PARAM}" "debug"

	declare ARMBIAN_HAS_COMMAND="no"

	declare ARMBIAN_COMMAND=""
	declare ARMBIAN_HAS_FIRST_NON_PARAM="no"
	if [[ "x${ARMBIAN_FIRST_NON_PARAM}x" != "xx" ]]; then
		declare ARMBIAN_COMMAND="${ARMBIAN_COMMANDS_TO_HANDLERS_DICT["${ARMBIAN_FIRST_NON_PARAM}"]}"
		display_alert "Found a first non-param argument" "${ARMBIAN_COMMAND}" "debug"
		declare -r ARMBIAN_HAS_FIRST_NON_PARAM="yes"
	fi

	if [[ "x${ARMBIAN_COMMAND}x" != "xx" ]]; then
		display_alert "Found command in" "ARMBIAN_COMMAND: ${ARMBIAN_COMMAND}" "debug"
		declare -r ARMBIAN_COMMAND="${ARMBIAN_COMMAND}"
		declare -r ARMBIAN_HAS_COMMAND="yes"
		# 'shift' the non-param array, since we've taken the command from it.
		ARMBIAN_NON_PARAM_ARGS=("${ARMBIAN_NON_PARAM_ARGS[@]:1}")
	else
		declare -r ARMBIAN_COMMAND=""
		declare -r ARMBIAN_HAS_COMMAND="no"
		display_alert "No command found in" "ARMBIAN_FIRST_NON_PARAM: ${ARMBIAN_FIRST_NON_PARAM}" "debug"
	fi

	# Super early handling. If no command and not root, become root by using sudo. Some exceptions apply.
	if [[ "${EUID}" == "0" ]]; then # we're already root. Either running as real root, or already sudo'ed.
		display_alert "Already running as root" "great" "debug"
	elif [[ "${ARMBIAN_HAS_COMMAND}" == "yes" ]]; then # If we've a command, don't check for root, let each command handler decide.
		display_alert "Not running as root, but we've a command" "great" "debug"
	elif [[ "${CONFIG_DEFS_ONLY}" == "yes" ]]; then                 # this var is set in the ENVIRONMENT, not as parameter.
		display_alert "No sudo for" "env CONFIG_DEFS_ONLY=yes" "debug" # not really building in this case, just gathering meta-data.
	else
		# non, command, default build, not root.
		# check if we're on Linux via uname. if not, refuse to do anything.
		if [[ "$(uname)" != "Linux" ]]; then
			display_alert "Not running on Linux" "refusing to run" "err"
			exit 1
		fi

		display_alert "This script requires root privileges" "trying to use sudo" "wrn"
		sudo --preserve-env "${SRC}/compile.sh" "${ARMBIAN_ORIGINAL_ARGV[@]}"
		display_alert "AFTER SUDO!!!" "AFTER SUDO!!!" "warn"
	fi

	# Create userpatches directory if not exists.
	mkdir -p "${SRC}"/userpatches


	# Check if the (newly-shifted, possibly) ${1} refers to a configfile in userpatches.
	if [[ -z "${CONFIG}" && -n "$1" && -f "${SRC}/userpatches/config-$1.conf" ]]; then
		CONFIG="userpatches/config-$1.conf" # here `docker` does its magic pt 1
		shift
	fi

	# using default if custom not found
	if [[ -z "${CONFIG}" && -f "${SRC}/userpatches/config-default.conf" ]]; then
		CONFIG="userpatches/config-default.conf"
	fi

	# Check that the config file specified actually exists, and bail if not.
	CONFIG_FILE="$(realpath "${CONFIG}")"
	if [[ ! -f "${CONFIG_FILE}" ]]; then
		display_alert "Config file does not exist" "${CONFIG}" "error"
		exit 254
	fi

	# Get the directory name of the config, and use it as DEST if it contains an "output" folder. @TODO: Why?
	CONFIG_PATH=$(dirname "${CONFIG_FILE}")

	# DEST is the main output dir.
	declare DEST="${SRC}/output"
	if [ -d "$CONFIG_PATH/output" ]; then
		DEST="${CONFIG_PATH}/output"
	fi
	display_alert "Output directory DEST:" "${DEST}" "debug"

	# set unique mounting directory for this build.
	# basic deps, which include "uuidgen", will be installed _after_ this, so we gotta tolerate it not being there yet.
	declare -g ARMBIAN_BUILD_UUID
	if [[ -f /usr/bin/uuidgen ]]; then
		ARMBIAN_BUILD_UUID="$(uuidgen)"
	else
		display_alert "uuidgen not found" "uuidgen not installed yet" "info"
		ARMBIAN_BUILD_UUID="no-uuidgen-yet-${RANDOM}-$((1 + $RANDOM % 10))$((1 + $RANDOM % 10))$((1 + $RANDOM % 10))$((1 + $RANDOM % 10))"
	fi
	display_alert "Build UUID:" "${ARMBIAN_BUILD_UUID}" "debug"

	# Super-global variables, used everywhere. The directories are NOT _created_ here, since this very early stage.
	export WORKDIR="${SRC}/.tmp/work-${ARMBIAN_BUILD_UUID}"                         # WORKDIR at this stage. It will become TMPDIR later. It has special significance to `mktemp` and others!
	export SDCARD="${SRC}/.tmp/rootfs-${ARMBIAN_BUILD_UUID}"                        # SDCARD (which is NOT an sdcard, but will be, maybe, one day) is where we work the rootfs before final imaging. "rootfs" stage.
	export MOUNT="${SRC}/.tmp/mount-${ARMBIAN_BUILD_UUID}"                          # MOUNT ("mounted on the loop") is the mounted root on final image (via loop). "image" stage
	export EXTENSION_MANAGER_TMP_DIR="${SRC}/.tmp/extensions-${ARMBIAN_BUILD_UUID}" # EXTENSION_MANAGER_TMP_DIR used to store extension-composed functions
	export DESTIMG="${SRC}/.tmp/image-${ARMBIAN_BUILD_UUID}"                        # DESTIMG is where the backing image (raw, huge, sparse file) is kept (not the final destination)
	export LOGDIR="${SRC}/.tmp/logs-${ARMBIAN_BUILD_UUID}"                          # Will be initialized very soon, literally, below.

	LOG_SECTION=entrypoint start_logging_section     # This creates LOGDIR.
	add_cleanup_handler trap_handler_cleanup_logging # cleanup handler for logs; it rolls it up from LOGDIR into DEST/logs

	if [ "${OFFLINE_WORK}" == "yes" ]; then
		display_alert "* " "You are working offline!"
		display_alert "* " "Sources, time and host will not be checked"
	else
		# check and install the basic utilities.
		LOG_SECTION="prepare_host_basic" do_with_logging prepare_host_basic # This includes the 'docker' case.
	fi

	# Source the extensions manager library at this point, before sourcing the config.
	# This allows early calls to enable_extension(), but initialization proper is done later.
	# shellcheck source=lib/extensions.sh
	source "${SRC}"/lib/extensions.sh

	# This actually sources/executes the config file.
	display_alert "Using config file" "${CONFIG_FILE}" "info"
	pushd "${CONFIG_PATH}" > /dev/null || exit
	# shellcheck source=/dev/null
	source "${CONFIG_FILE}" # @TODO: in the docker case this is the 'bingo': this config re-execs compile.sh with "$@" that has already had 'docker' shifted from $1; it also errors out so never returns? not sure
	popd > /dev/null || exit

	# @TODO, why?
	[[ -z "${USERPATCHES_PATH}" ]] && USERPATCHES_PATH="${CONFIG_PATH}"

	# Apply the params received from the command line _again_ after running the config.
	# This ensures that params take precedence over stuff possibly defined in the config.
	apply_cmdline_params_to_env "after config" # which uses ARMBIAN_PARSED_CMDLINE_PARAMS

	# @TODO: actually execute the command here.
	exit_with_error "This is the end of the line, folks."

	##
	## Main entrypoint.
	##

	# reset completely after sourcing config file
	#set -o pipefail  # trace ERR through pipes - will be enabled "soon"
	#set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable - one day will be enabled
	set -o errtrace # trace ERR through - enabled
	set -o errexit  ## set -e : exit the script if any statement returns a non-true return value - enabled

	# requirements, hostdeps, etc; publishes metadata
	# Prepare the list of host dependencies.
	if [[ "${REQUIREMENTS_DEFS_ONLY}" == "yes" ]]; then
		declare -a -g host_dependencies=()
		early_prepare_host_dependencies # tests itself for REQUIREMENTS_DEFS_ONLY=yes too
		install_host_dependencies "for REQUIREMENTS_DEFS_ONLY=yes"
		# @TODO: maybe also toolchains?
		# @TODO: maybe also some gitballs?

		display_alert "Done with" "REQUIREMENTS_DEFS_ONLY" "cachehit"
		exit 0
	fi

	# configuration etc - it initializes the extension manager
	do_capturing_defs prepare_and_config_main_build_single # this sets CAPTURED_VARS

	if [[ "${CONFIG_DEFS_ONLY}" == "yes" ]]; then
		echo "${CAPTURED_VARS}" # to stdout!
	else
		unset CAPTURED_VARS
		# Allow for custom user-invoked functions, or do the default build.
		if [[ -z $1 ]]; then
			main_default_build_single
		else
			# @TODO: rpardini: check this with extensions usage?
			eval "$@"
		fi
	fi

	# Build done, run the cleanup handlers explicitly.
	# This zeroes out the list of cleanups, so it's not done again when the main script exits normally and trap = 0 runs.
	run_cleanup_handlers
}
