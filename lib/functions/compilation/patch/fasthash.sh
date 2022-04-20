function report_fashtash_should_execute() {
	report_fasthash "$@"
	# @TODO: if fasthash only, return 1
	return 0
}

function report_fasthash() {
	declare -gAx fasthash_commit=(
		[type]="${1}"
		[obj]="${2}"
		[desc]="${3}"
	)
	display_alert "report_fasthash" "${fasthash_context[type]}: ${fasthash_context[desc]}" "fasthash"

	return 0
}

# commit the fasthash_commit stored above.
function mark_fasthash_done() {
	display_alert "mark_fasthash_done" "$*" "fasthash"
	[[ "${PATCHES_TO_GIT}" != "yes" ]] && return 0 # do nothing unless explicitly enabled

	# if no fasthash_context, do nothing
	declare -gi fasthash_initialized
	if [[ ${fasthash_initialized} -lt 1 ]]; then
		display_alert "mark_fasthash_done when not initialized, ignoring" "$*" "fasthash"
		return 0
	fi

	fasthash_commit[mtime]="${1}"
	regular_git add .
	#  -m "${fasthash_commit[desc]}"
	GIT_COMMITTER_NAME="commiter ${fasthash_context[current_branch]}" \
		GIT_COMMITTER_EMAIL="${MAINTAINERMAIL}" \
		GIT_COMMITTER_DATE="$(format_mtime_to_git_date "${fasthash_commit[mtime]}")" \
		regular_git commit --author "author ${fasthash_context[current_branch]} <${MAINTAINERMAIL}>" --file=<(
		cat <<- COMMIT_MSG
			${fasthash_commit[desc]}

			${fasthash_commit[type]} ${fasthash_commit[obj]}
			date: ${fasthash_commit[mtime]}
			pre_patch_version: ${fasthash_context[pre_patch_version]}
		COMMIT_MSG
	)
	return 0
}

function mark_fasthash_failed() {
	display_alert "mark_fasthash_failed" "$*" "fasthash"
	unset fasthash_commit
	return 0
}

function initialize_fasthash() {
	display_alert "initialize_fasthash" "$*" "fasthash"
	declare -gi fasthash_initialized=1
	# Should note the passed parameters.
	declare -gAx fasthash_context=(
		[type]="${1}"
		[base_git_hash]="${2}"     # might be empty during fast hash.
		[pre_patch_version]="${3}" # might be empty
		[work_dir]="${4}"          # might be empty
	)
	# derived
	fasthash_context[base_branch]="${fasthash_context[type]}-${ARMBIAN_BUILD_UUID}"

	# initialize the list of hashes
	declare -gax fast_hash_list=()

	# Then create a new git branch in cwd, from HEAD.
	regular_git checkout -b "${fasthash_context[base_branch]}"
}

function fasthash_branch() {
	fasthash_context[current_branch]="${1}"
	display_alert "fasthash_branch" "$*" "fasthash"
	regular_git checkout -b "${fasthash_context[current_branch]}-${ARMBIAN_BUILD_UUID}"
}

function finish_fasthash() {
	display_alert "finish_fasthash" "$*" "fasthash"
	declare -gi fasthash_initialized=0
	return 0
}

function fasthash_debug() {
	if [[ "${SHOW_FASTHASH}" != "yes" ]]; then
		return 0
	fi
	display_alert "fasthash_debug" "$*" "fasthash"
	find . -type f -printf "'%T@ %p\\n'" |
		grep -v -e "\.ko" -e "\.o" -e "\.cmd" -e "\.mod" -e "\.a" -e "\.tmp" -e "\.dtb" -e ".scr" -e "\.\/debian" |
		sort -n | tail -n 10
}

function get_file_modification_time() { # @TODO: This is almost always called from a subshell. No use throwing errors?
	local -i file_date
	if [[ ! -f "${1}" ]]; then
		exit_with_error "Can't get modification time of nonexisting file" "${1}"
		return 1
	fi
	# YYYYMMDDhhmm.ss - it is NOT a valid integer, but is what 'touch' wants for its "-t" parameter
	# YYYYMMDDhhmmss - IS a valid integer and we can do math to it. 'touch' code will format it later
	file_date=$(date +%Y%m%d%H%M%S -r "${1}")
	display_alert "Read modification date for file" "${1} - ${file_date}" "timestamp"
	echo -n "${file_date}"
	return 0
}

function get_dir_modification_time() {
	local -i file_date
	if [[ ! -d "${1}" ]]; then
		exit_with_error "Can't get modification time of nonexisting dir" "${1}"
		return 1
	fi
	# YYYYMMDDhhmm.ss - it is NOT a valid integer, but is what 'touch' wants for its "-t" parameter
	# YYYYMMDDhhmmss - IS a valid integer and we can do math to it. 'touch' code will format it later
	file_date=$(date +%Y%m%d%H%M%S -r "${1}")
	display_alert "Read modification date for DIRECTORY" "${1} - ${file_date}" "timestamp"
	echo -n "${file_date}"
	return 0
}

# This is for simple "set without thinking" usage, date preservation is done directly by process_patch_file
function set_files_modification_time() {
	local -i mtime="${1}"
	local formatted_mtime
	shift
	display_alert "Setting date ${mtime}" "${*} (no newer check)" "timestamp"
	formatted_mtime="${mtime:0:12}.${mtime:12}"
	touch --no-create -m -t "${formatted_mtime}" "${@}"
}

function format_mtime_to_git_date() {
	echo -n "${1:0:4}-${1:4:2}-${1:6:2} ${1:8:2}:${1:10:2}:${1:12:2}"
}
