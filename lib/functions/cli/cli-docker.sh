function cli_docker_pre_run() {
	if [[ "${DOCKERFILE_GENERATE_ONLY}" == "yes" ]]; then
		display_alert "Dockerfile generation only" "func cli_docker_pre_run" "debug"
		return 0
	fi

	# make sure we're not _ALREADY_ running under docker... otherwise eternal loop?
	if [[ "${ARMBIAN_RUNNING_IN_CONTAINER}" == "yes" ]]; then
		display_alert "wtf" "asking for docker... inside docker; turning to build command" "warn"
		# @TODO: wrong, what if we wanna run other stuff inside Docker? not build?
		ARMBIAN_CHANGE_COMMAND_TO="build"
	fi

}

function cli_docker_run() {
	LOG_SECTION="docker_cli_prepare" do_with_logging docker_cli_prepare

	if [[ "${DOCKERFILE_GENERATE_ONLY}" == "yes" ]]; then
		display_alert "Dockerfile generated" "exiting" "info"
		exit 0
	fi

	# Force showing logs here while bulding Dockerfile.
	SHOW_LOG=yes LOG_SECTION="docker_cli_build_dockerfile" do_with_logging docker_cli_build_dockerfile

	LOG_SECTION="docker_cli_prepare_launch" do_with_logging docker_cli_prepare_launch
	# @TODO: cleanup this. I want an array with original args, and the original configs, so I can change command and add params easily
	docker_cli_launch "${ARMBIAN_ORIGINAL_ARGV[@]}" "${ARMBIAN_DOCKER_RELAUNCH_EXTRA_ARGS[@]}" # @TODO: this "re-launches", docker case.
}
