function cli_artifact_pre_run() {
	initialize_artifact "${WHAT:-"kernel"}"
	# Run the pre run adapter
	artifact_cli_adapter_pre_run
}

function cli_artifact_run() {
	: "${chosen_artifact:?chosen_artifact is not set}"
	: "${chosen_artifact_impl:?chosen_artifact_impl is not set}"

	display_alert "artifact" "${chosen_artifact}" "debug"
	display_alert "artifact" "${chosen_artifact} :: ${chosen_artifact_impl}()" "debug"
	artifact_cli_adapter_config_prep # only if in cli.

	# When run in GHA, assume we're checking/updating the remote cache only.
	# Local cache is ignored, and if found, it's not unpacked, either from local or remote.
	# If remote cache is found, does nothing.
	declare default_update_remote_only="no"
	if [[ "${CI}" == "true" ]] && [[ "${GITHUB_ACTIONS}" == "true" ]]; then
		display_alert "Running in GitHub Actions, assuming we're updating remote cache only" "GHA remote-only" "info"
		default_update_remote_only="yes"
	fi

	declare skip_unpack_if_found_in_caches="${skip_unpack_if_found_in_caches:-"${default_update_remote_only}"}"
	declare ignore_local_cache="${ignore_local_cache:-"${default_update_remote_only}"}"
	declare deploy_to_remote="${deploy_to_remote:-"${default_update_remote_only}"}"

	# If OCI_TARGET_BASE is explicitly set, ignore local, skip if found in remote, and deploy to remote after build.
	if [[ -n "${OCI_TARGET_BASE}" ]]; then
		skip_unpack_if_found_in_caches="yes"
		ignore_local_cache="yes"
		deploy_to_remote="yes"
	fi

	do_with_default_build obtain_complete_artifact # @TODO: < /dev/null -- but what about kernel configure?
}
