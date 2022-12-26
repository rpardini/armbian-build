function kernel_drivers_create_patches() {
	declare version="$1"
	declare kernel_work_dir="$2"
	declare kernel_git_revision="$3"

	# grab the date of the kernel kernel_git_revision into kernel_driver_commit_date, which will be used to commit later
	declare kernel_driver_commit_date
	kernel_driver_commit_date=$(git -C "$kernel_work_dir" show -s --format=%ci "$kernel_git_revision")
	display_alert "Kernel driver commit date" "$kernel_driver_commit_date" "warn"

	display_alert "Preparing patches for drivers" "version: ${version} kernel_work_dir: ${kernel_work_dir}" "info"

	kernel_drivers_prepare_harness "$@"
}

function kernel_drivers_prepare_harness() {
	declare version="${1}"
	declare kernel_work_dir="${2}"
	declare kernel_git_revision="$3"
	declare -I version kernel_work_dir kernel_driver_commit_date # outer scope variables

	declare -a drivers=(
		driver_rtl8152_rtl8153
		driver_rtl8189ES
		driver_rtl8189FS
		driver_rtl8192EU
		driver_rtl8811_rtl8812_rtl8814_rtl8821
		driver_xradio_xr819
		driver_rtl8811CU_rtl8821C
		driver_rtl8188EU_rtl8188ETV
		driver_rtl88x2bu
		driver_rtl88x2cs
		driver_rtl8822cs_bt
		driver_rtl8723DS
		driver_rtl8723DU
		driver_rtl8822BS
	)

	declare target_patch_dir="patch/kernel-drivers/${LINUXFAMILY}-${KERNEL_MAJOR_MINOR}"
	mkdir -p "${SRC}/${target_patch_dir}"

	declare tmp_target_dir="${WORKDIR}/kernel-drivers/${LINUXFAMILY}-${KERNEL_MAJOR_MINOR}"
	[[ -d "${tmp_target_dir}" ]] && run_host_command_logged rm -rf "${tmp_target_dir}" # zero it out if exists; it won't.
	mkdir -p "${tmp_target_dir}"

	# start the counter
	declare driver_counter=0

	# change cwd to the kernel working dir
	cd "${kernel_work_dir}" || exit_with_error "Failed to change directory to ${kernel_work_dir}"

	#run_host_command_logged git status
	run_host_command_logged git reset --hard "${kernel_git_revision}"
	# git: remove tracked files, but not those in .gitignore
	run_host_command_logged git clean -fd # no -x here

	for driver in "${drivers[@]}"; do
		# increment the counter
		driver_counter=$((driver_counter + 1))
		# prepare a string with the counter, padded with up to 4 zeroes
		declare driver_counter_string
		driver_counter_string=$(printf "%04d" "$driver_counter")

		display_alert "Preparing driver" "${driver}" "info"

		# reset variables used by each driver
		declare version="${1}"
		declare kernel_work_dir="${2}"
		declare kernel_git_revision="$3"
		# for compatibility with `master`-based code
		declare kerneldir="${kernel_work_dir}"
		declare EXTRAWIFI="yes" # forced! @TODO not really?

		# change cwd to the kernel working dir
		cd "${kernel_work_dir}" || exit_with_error "Failed to change directory to ${kernel_work_dir}"

		# invoke the driver (@TODO: in a subshell?)
		"${driver}"

		# recover from possible cwd changes in the driver code
		cd "${kernel_work_dir}" || exit_with_error "Failed to change directory to ${kernel_work_dir}"

		# calculate the target patch file name
		declare target_patch_file="${SRC}/${target_patch_dir}/${driver_counter_string}-${driver}.patch"
		#run_host_command_logged git status

		# git: check if there are modifications
		if [[ -n "$(git status --porcelain)" ]]; then
			display_alert "Driver" "'${driver}' has modifications" "exporting patch into ${target_patch_dir}/${driver}.patch" "info"
			declare tmp_patch_file="${tmp_target_dir}/${driver_counter_string}-${driver}.patch"

			export_changes_as_patch_via_git_format_patch # takes 41s
			#export_changes_as_patch_via_git_diff        # takes 38s

			# move the patch file to the target location if it's not the same contents
			if ! cmp -s "${tmp_patch_file}" "${target_patch_file}"; then
				display_alert "Driver" "'${driver}' patch file has changed" "moving to ${target_patch_dir}/${driver}.patch" "info"

				# show a colored diff between them
				#diff -u "${target_patch_file}" "${tmp_patch_file}" || true

				run_host_command_logged mv -v "${tmp_patch_file}" "${target_patch_file}"
			else
				display_alert "Driver" "'${driver}' patch is the same as the one in ${target_patch_file}" "skipping" "info"
			fi

		else
			# if the target patch exits, remove it.
			if [[ -f "${target_patch_file}" ]]; then
				display_alert "Driver" "'${driver}' has applied no modifications, removing existing..." "info"
				run_host_command_logged rm -fv "${target_patch_file}"
			else
				display_alert "Driver" "'${driver}' has applied no modifications, skipping" "info"
			fi

		fi

	done

}

function export_changes_as_patch_via_git_format_patch() {
	# git: add all modifications
	run_host_command_logged git add . "&>/dev/null"

	# git: commit the changes
	declare -a commit_params=(
		-m "driver: ${driver}"
		--date="${kernel_driver_commit_date}"
		--author="${MAINTAINER} <${MAINTAINERMAIL}>"
	)
	GIT_COMMITTER_NAME="${MAINTAINER}" GIT_COMMITTER_EMAIL="${MAINTAINERMAIL}" git commit "${commit_params[@]}" &> /dev/null

	# export the commit as a patch; first to a temporary file, then move it to the target location if they're not the same
	declare formatpatch_params=(
		"-1" "--stdout"
		"--unified=3"    # force 3 lines of diff context
		"--keep-subject" # do not add a prefix to the subject "[PATCH] "
		# "--add-header=Organization: Armbian"  # add a header to the patch (ugly, changes the header)
		"--no-encode-email-headers" # do not encode email headers
		'--signature' "Armbian generated patch from driver ${driver} for kernel ${version} and family ${LINUXFAMILY}"
		'--stat=120'            # 'wider' stat output; default is 80
		'--stat-graph-width=10' # shorten the diffgraph graph part, it's too long
		"--zero-commit"         # Output an all-zero hash in each patch’s From header instead of the hash of the commit.
	)
	git format-patch "${formatpatch_params[@]}" > "${tmp_patch_file}"
}

function export_changes_as_patch_via_git_diff() {
	# use git to export the working copy's changes as a patch. include newly added files
	run_host_command_logged git add -N . "&>/dev/null"
	git diff --unified=3 > "${tmp_patch_file}"
}
