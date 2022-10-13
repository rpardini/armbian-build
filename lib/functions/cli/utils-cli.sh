# This is called like this:
#	declare -A -g ARMBIAN_PARSED_CMDLINE_PARAMS=()
#	declare -a -g ARMBIAN_NON_PARAM_ARGS=()
#	parse_cmdline_params "${@}" # which fills the vars above, being global.
function parse_cmdline_params() {
	declare -A -g ARMBIAN_PARSED_CMDLINE_PARAMS=()
	declare -a -g ARMBIAN_NON_PARAM_ARGS=()

	while [[ "x${1}x" != "xx" ]]; do # @TODO, incorrect, I just wanna parse them ALL.
		if [[ "${1}" == *=* ]]; then    # it's a param.
			local param_name param_value param_value_desc
			param_name=${1%%=*}
			param_value=${1##*=}
			param_value_desc="${param_value:-(empty)}"
			ARMBIAN_PARSED_CMDLINE_PARAMS["${param_name}"]="${param_value}"
			shift
			display_alert "Command line: parsed parameter '$param_name' to" "${param_value_desc}" "debug"
		else # not a param, store it in the non-param array for later usage
			local non_param_value="${1}"
			local non_param_value_desc="${non_param_value:-(empty)}"
			display_alert "Command line: storing non-param argument" "${non_param_value_desc}" "debug"
			ARMBIAN_NON_PARAM_ARGS+=("${non_param_value}")
			shift
		fi
	done
}

# This can be called early on, or later after having sourced the config. Show what is happening.
# This is called:
# apply_cmdline_params_to_env "reason" # reads from global ARMBIAN_PARSED_CMDLINE_PARAMS
function apply_cmdline_params_to_env() {
	declare -A -g ARMBIAN_PARSED_CMDLINE_PARAMS # Hopefully this has values
	declare __my_reason="${1}"
	shift

	# Loop over the dictionary and apply the values to the environment.
	for param_name in "${!ARMBIAN_PARSED_CMDLINE_PARAMS[@]}"; do
		local param_value param_value_desc current_env_value
		# get the current value from the environment
		current_env_value="${!param_name}"
		current_env_value_desc="${current_env_value:-(empty)}"
		# get the new value from the dictionary
		param_value="${ARMBIAN_PARSED_CMDLINE_PARAMS[${param_name}]}"
		param_value_desc="${param_value:-(empty)}"

		# Compare, log, and apply.
		if [[ "${current_env_value}" != "${param_value}" ]]; then
			display_alert "Command line: '${__my_reason}': applying '$param_name', changing '${current_env_value_desc}' to" "${param_value_desc}" "info"
			# use `declare -g` to make it global, we're in a function.
			eval "declare -g $param_name=\"$param_value\""
		else
			display_alert "Command line: '${__my_reason}': '$param_name' already set to" "${current_env_value_desc}" "debug"
		fi
	done
}
