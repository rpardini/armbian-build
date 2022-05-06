# Config
export DEBUG_PACKAGE_LISTS=false

# PACKAGE_LIST_RM is unreliable due to sed bizarreness. Do it forcibly.
function remove_packages_everywhere() {
	local old_DEBOOTSTRAP_LIST="${DEBOOTSTRAP_LIST}"
	local old_PACKAGE_LIST_ADDITIONAL="${PACKAGE_LIST_ADDITIONAL}"
	local old_PACKAGE_LIST="${PACKAGE_LIST}"
	# shellcheck disable=SC2068 # please expand
	for one_pkg in ${@}; do
		local one_pkg_to_remove_with_spaces_around_it=" ${one_pkg} " # with a space
		# @TODO: using PACKAGE_LIST_RM causes errors at do_main_configuration() main-config.sh:384 which needs to be rewritten
		#export PACKAGE_LIST_RM="${PACKAGE_LIST_RM}${one_pkg_to_remove_with_spaces_around_it}"                     # This does not really work.
		#export PACKAGE_LIST_BOARD_REMOVE="${PACKAGE_LIST_BOARD_REMOVE}${one_pkg_to_remove_with_spaces_around_it}" # This will cause it to be apt-removed if installed.
		# add a space...
		export DEBOOTSTRAP_LIST=" ${DEBOOTSTRAP_LIST} "
		export PACKAGE_LIST_ADDITIONAL=" ${PACKAGE_LIST_ADDITIONAL} "
		export PACKAGE_LIST=" ${PACKAGE_LIST} "
		# no quotes, let it expand. spaces are significant.
		export DEBOOTSTRAP_LIST=${DEBOOTSTRAP_LIST//${one_pkg_to_remove_with_spaces_around_it}/ }
		export PACKAGE_LIST_ADDITIONAL=${PACKAGE_LIST_ADDITIONAL//${one_pkg_to_remove_with_spaces_around_it}/ }
		export PACKAGE_LIST=${PACKAGE_LIST//${one_pkg_to_remove_with_spaces_around_it}/ }
	done

	#display_alert "remove_packages_everywhere: done: removed:" "$*" "debug"
	#display_alert "remove_packages_everywhere: done: DEBOOTSTRAP_LIST: before:" "${old_DEBOOTSTRAP_LIST}" "debug"
	#display_alert "remove_packages_everywhere: done: DEBOOTSTRAP_LIST: after:" "${DEBOOTSTRAP_LIST}" "debug"
	#display_alert "remove_packages_everywhere: done: PACKAGE_LIST_ADDITIONAL: before:" "${old_PACKAGE_LIST_ADDITIONAL}" "debug"
	#display_alert "remove_packages_everywhere: done: PACKAGE_LIST_ADDITIONAL: after:" "${PACKAGE_LIST_ADDITIONAL}" "debug"
	#display_alert "remove_packages_everywhere: done: PACKAGE_LIST: before:" "${old_PACKAGE_LIST}" "debug"
	#display_alert "remove_packages_everywhere: done: PACKAGE_LIST: after:" "${PACKAGE_LIST}" "debug"
}

user_config__200_debug_package_lists_early() {
	[[ "${DEBUG_PACKAGE_LISTS}" != "false" ]] && display_alert "Package list DEBOOTSTRAP_LIST          (early)" "${DEBOOTSTRAP_LIST}" "info"
	[[ "${DEBUG_PACKAGE_LISTS}" != "false" ]] && display_alert "Package list PACKAGE_LIST              (early)" "${PACKAGE_LIST}" "info"
	[[ "${DEBUG_PACKAGE_LISTS}" != "false" ]] && display_alert "Package list PACKAGE_LIST_ADDITIONAL   (early)" "${PACKAGE_LIST_ADDITIONAL}" "info"
	[[ "${DEBUG_PACKAGE_LISTS}" != "false" ]] && display_alert "Package list PACKAGE_LIST_FAMILY       (early)" "${PACKAGE_LIST_FAMILY}" "info"
	[[ "${DEBUG_PACKAGE_LISTS}" != "false" ]] && display_alert "Package list PACKAGE_LIST_BOARD_REMOVE (early)" "${PACKAGE_LIST_BOARD_REMOVE}" "info"
	[[ "${DEBUG_PACKAGE_LISTS}" != "false" ]] && display_alert "Package list PACKAGE_LIST_RM           (early)" "${PACKAGE_LIST_RM}" "info"
	[[ "${DEBUG_PACKAGE_LISTS}" != "false" ]] && display_alert "Package list PACKAGE_LIST_EXCLUDE      (early)" "${PACKAGE_LIST_EXCLUDE}" "info"
	return 0 # shortcircuits above, so force exit with success
}

user_config_post_aggregate_packages__800_debug_package_lists_after_aggregation() {
	# Show lists:
	[[ "${DEBUG_PACKAGE_LISTS}" != "false" ]] && display_alert "Package list DEBOOTSTRAP_LIST          (super-final)) " "${DEBOOTSTRAP_LIST}" "info"
	[[ "${DEBUG_PACKAGE_LISTS}" != "false" ]] && display_alert "Package list PACKAGE_LIST              (super-final)) " "${PACKAGE_LIST}" "info"
	[[ "${DEBUG_PACKAGE_LISTS}" != "false" ]] && display_alert "Package list PACKAGE_LIST_BOARD_REMOVE (super-final)) " "${PACKAGE_LIST_BOARD_REMOVE}" "info"
	return 0 # shortcircuits above, so force exit with success
}
