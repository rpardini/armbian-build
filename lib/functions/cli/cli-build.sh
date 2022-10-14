function cli_standard_build_pre_run() {
	declare -g ARMBIAN_COMMAND_REQUIRE_BASIC_DEPS="yes" # Require prepare_host_basic to run before the command.

	# Super early handling. If no command and not root, become root by using sudo. Some exceptions apply.
	if [[ "${EUID}" == "0" ]]; then # we're already root. Either running as real root, or already sudo'ed.
		display_alert "Already running as root" "great" "debug"
	else
		# not root.
		# check if we're on Linux via uname. if not, refuse to do anything.
		if [[ "$(uname)" != "Linux" ]]; then
			display_alert "Not running on Linux" "refusing to run" "err"
			exit 1
		fi

		display_alert "This script requires root privileges" "trying to use sudo" "wrn"
		sudo --preserve-env "${SRC}/compile.sh" "${ARMBIAN_ORIGINAL_ARGV[@]}" # @TODO: relaunch done here!
		display_alert "AFTER SUDO!!!" "AFTER SUDO!!!" "warn"
	fi

}

function cli_standard_build_run() {
	# @TODO: then many other interesting possibilities like a REPL, which we lost somewhere along the way. docker-shell?

	# configuration etc - it initializes the extension manager
	prepare_and_config_main_build_single

	# Allow for custom user-invoked functions, or do the default build.
	if [[ -z $1 ]]; then
		main_default_build_single
	else
		# @TODO: rpardini: check this with extensions usage?
		eval "$@"
	fi
}
