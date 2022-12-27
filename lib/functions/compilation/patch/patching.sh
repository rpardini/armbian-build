#!/usr/bin/env bash

# process_patch_file <file> <description>
#
# parameters:
# <file>: path to patch file
# <status>: additional status text
#
process_patch_file() {
	local patch="${1}"
	local status="${2}"
	local -i patch_date
	local relative_patch="${patch##"${SRC}"/}" # ${FOO##prefix} remove prefix from FOO

	# detect and remove files which patch will create
	lsdiff -s --strip=1 "${patch}" | grep '^+' | awk '{print $2}' | xargs -I % sh -c 'rm -f %'

	# shellcheck disable=SC2015 # noted, thanks. I need to handle exit code here.
	patch --batch -p1 -N --input="${patch}" --quiet --reject-file=- && { # "-" discards rejects
		display_alert "* $status ${relative_patch}" "" "info"
	} || {
		display_alert "* $status ${relative_patch}" "failed" "wrn"
		[[ $EXIT_PATCHING_ERROR == yes ]] && exit_with_error "Aborting due to" "EXIT_PATCHING_ERROR"
	}

	return 0 # short-circuit above, avoid exiting with error
}

userpatch_create() {
	display_alert "@TODO" "@TODO armbian-next" "warn"
	# create commit to start from clean source
	git add .
	git -c user.name='Armbian User' -c user.email='user@example.org' commit -q -m "Cleaning working copy"

	mkdir -p "${DEST}/patch"
	local patch="$DEST/patch/$1-$LINUXFAMILY-$BRANCH.patch"

	# apply previous user debug mode created patches
	if [[ -f $patch ]]; then
		display_alert "Applying existing $1 patch" "$patch" "wrn" && patch --batch --silent -p1 -N < "${patch}"
		# read title of a patch in case Git is configured
		if [[ -n $(git config user.email) ]]; then
			COMMIT_MESSAGE=$(cat "${patch}" | grep Subject | sed -n -e '0,/PATCH/s/.*PATCH]//p' | xargs)
			display_alert "Patch name extracted" "$COMMIT_MESSAGE" "wrn"
		fi
	fi

	# prompt to alter source
	display_alert "Make your changes in this directory:" "$(pwd)" "wrn"
	display_alert "Press <Enter> after you are done" "waiting" "wrn"
	read -r < /dev/tty
	tput cuu1
	git add .
	# create patch out of changes
	if ! git diff-index --quiet --cached HEAD; then
		# If Git is configured, create proper patch and ask for a name
		if [[ -n $(git config user.email) ]]; then
			display_alert "Add / change patch name" "$COMMIT_MESSAGE" "wrn"
			read -e -p "Patch description: " -i "$COMMIT_MESSAGE" COMMIT_MESSAGE
			[[ -z "$COMMIT_MESSAGE" ]] && COMMIT_MESSAGE="Patching something"
			git commit -s -m "$COMMIT_MESSAGE"
			git format-patch -1 HEAD --stdout --signature="Created with Armbian build tools https://github.com/armbian/build" > "${patch}"
			PATCHFILE=$(git format-patch -1 HEAD)
			rm $PATCHFILE # delete the actual file
			# create a symlink to have a nice name ready
			find $DEST/patch/ -type l -delete # delete any existing
			ln -sf $patch $DEST/patch/$PATCHFILE
		else
			git diff --staged > "${patch}"
		fi
		display_alert "You will find your patch here:" "$patch" "info"
	else
		display_alert "No changes found, skipping patch creation" "" "wrn"
	fi
	git reset --soft HEAD~
	for i in {3..1..1}; do echo -n "$i." && sleep 1; done
}
