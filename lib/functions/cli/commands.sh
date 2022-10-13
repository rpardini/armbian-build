function armbian_register_commands() {
	# More than one command can map to the same handler. In that case, use ARMBIAN_COMMANDS_TO_VARS_DICT for specific vars.
	declare -g -A ARMBIAN_COMMANDS_TO_HANDLERS_DICT=(
		["docker"]="docker"        # thus requires cli_docker_pre_run and cli_docker_run
		["docker-purge"]="ocker"  # idem
		["dockerpurge"]="docker"   # idem
		["docker-shell"]="docker"  # idem
		["dockershell"]="docker"   # idem
		["vagrant"]="vagrant"      # thus requires cli_vagrant_pre_run and cli_vagrant_run
		["build"]="standard_build" # implemented in cli_standard_build_pre_run and cli_standard_build_run
		["undecided"]="undecided"  # implemented in cli_undecided_pre_run and cli_undecided_run - relaunches either build or docker
	)
	declare -g -A ARMBIAN_COMMANDS_TO_VARS_DICT=(
		["docker-purge"]="DOCKER_SUBCMD='purge'"
		["dockerpurge"]="DOCKER_SUBCMD='purge'"
		["docker-shell"]="DOCKER_SUBCMD='shell'"
		["dockershell"]="DOCKER_SUBCMD='shell'"
	)
}
