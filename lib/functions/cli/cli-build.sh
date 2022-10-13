function cli_standard_build_pre_run() {
	display_alert "Build!" "func cli_standard_build_pre_run" "warn"

	# @TODO: move to the cli pre handler; allow it to change the command to run, or re-launch compile.sh.
	# Super early handling. If no command and not root, become root by using sudo. Some exceptions apply.
	if [[ "${EUID}" == "0" ]]; then # we're already root. Either running as real root, or already sudo'ed.
		display_alert "Already running as root" "great" "debug"
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

}

function cli_standard_build_run() {
	display_alert "Build!" "ACTUAL BUILD WILL RUN!" "warn"

	# @TODO: So gigantic contention point here about logging the basic deps installation.
	if [ "${OFFLINE_WORK}" == "yes" ]; then
		display_alert "* " "You are working offline!"
		display_alert "* " "Sources, time and host will not be checked"
	else
		# check and install the basic utilities;
		# @TODO: maybe only if _pre_run asked we to? We don't wanna do this on Darwin, for example.
		LOG_SECTION="prepare_host_basic" do_with_logging prepare_host_basic # This includes the 'docker' case.
	fi

	##
	## Main entrypoint.
	##
	# @TODO: of course, split install-deps, dump-config from this.
	# @TODO: then many other interesting possibilities like a REPL, which we lost somewhere along the way. docker-shell?

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


	#display_alert "Build!" "ACTUAL BUILD WILL ERROR OUT!" "warn"
	#this_will_error_out


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

}
