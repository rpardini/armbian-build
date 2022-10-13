function cli_docker_pre_run() {
	display_alert "Docker!" "func cli_docker_pre_run" "warn"

	# make sure we're not _ALREADY_ running under docker... otherwise eternal loop?
	if [[ "${ARMBIAN_RUNNING_IN_CONTAINER}" == "yes" ]]; then
		display_alert "wtf" "asking for docker... inside docker; turning to build command" "warn"
		ARMBIAN_CHANGE_COMMAND_TO="build"
	fi

}

function cli_docker_run() {
	display_alert "Docker!" "func cli_docker_run" "warn"

	LOG_SECTION="docker_cli_prepare" do_with_logging docker_cli_prepare

	if [[ "${DOCKERFILE_GENERATE_ONLY}" == "yes" ]]; then
		display_alert "Dockerfile generated" "exiting" "info"
		exit 0
	fi

	# Force showing logs here while bulding Dockerfile.
	SHOW_LOG=yes LOG_SECTION="docker_cli_build_dockerfile" do_with_logging docker_cli_build_dockerfile
	
	LOG_SECTION="docker_cli_prepare_launch" do_with_logging docker_cli_prepare_launch
	docker_cli_launch "${ARMBIAN_ORIGINAL_ARGV[@]}" # this might include "docker" again...
}
