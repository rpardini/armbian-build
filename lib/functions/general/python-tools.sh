function prepare_pip_packages_for_python_tools() {
	declare -g PYTHON_TOOLS_PIP_PACKAGES_DONE="${PYTHON_TOOLS_PIP_PACKAGES_DONE:-no}"
	if [[ "${PYTHON_TOOLS_PIP_PACKAGES_DONE}" == "yes" ]]; then
		display_alert "Required Python packages" "already installed" "info"
		return 0
	fi

	# @TODO: virtualenv? system-wide for now
	display_alert "Installing required Python packages" "via pip3" "info"
	run_host_command_logged pip3 install unidiff GitPython unidecode

	return 0
}
