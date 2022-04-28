function extension_prepare_config__prepare_control_service() {
	display_alert "Adding CS" "${EXTENSION}" "info"
	export EXTRA_BSP_NAME="${EXTRA_BSP_NAME}-cs" # Unique bsp name for this extension, so things don't get mixed up later

	# Make sure we have the configs needed.
	[[ "${CONTROL_SERVICE_NAME}" == "" ]] && exit_with_error "Missing config CONTROL_SERVICE_NAME"
	[[ "${CONTROL_SERVICE_VERSION}" == "" ]] && exit_with_error "Missing config CONTROL_SERVICE_VERSION"
	[[ "${CONTROL_SERVICE_OWNER_SLASH_REPO}" == "" ]] && exit_with_error "Missing config CONTROL_SERVICE_OWNER_SLASH_REPO"
	[[ "${CONTROL_SERVICE_ENV_BASEURL}" == "" ]] && exit_with_error "Missing config CONTROL_SERVICE_ENV_BASEURL"
	[[ "${CONTROL_SERVICE_ENV_TOKEN}" == "" ]] && exit_with_error "Missing config CONTROL_SERVICE_ENV_TOKEN"
	[[ "${CONTROL_SERVICE_MEDIA_DEVICE_PATH}" == "" ]] && exit_with_error "Missing config CONTROL_SERVICE_MEDIA_DEVICE_PATH"

	# Derived values from config
	export CONTROL_SERVICE_BIN_FILE="${CONTROL_SERVICE_NAME}-${CONTROL_SERVICE_VERSION}-linux-${ARCH}"
	export CONTROL_SERVICE_BIN_URL="https://github.com/${CONTROL_SERVICE_OWNER_SLASH_REPO}/releases/download/${CONTROL_SERVICE_VERSION}/${CONTROL_SERVICE_BIN_FILE}"
	export CONTROL_SERVICE_CACHE_DIR="${SRC}/cache/control-service"
	export CONTROL_SERVICE_CACHED_CS_BIN_PATH="${CONTROL_SERVICE_CACHE_DIR}/${CONTROL_SERVICE_BIN_FILE}"
	declare -Agx CONTROL_SERVICE_ENV_VARS=(
		[MEDIA_PATH]="${CONTROL_SERVICE_MEDIA_DEVICE_PATH}"
		[BASEURL]="${CONTROL_SERVICE_ENV_BASEURL}"
		[TOKEN]="${CONTROL_SERVICE_ENV_TOKEN}"
		[SERVICE_VERSION]="${CONTROL_SERVICE_VERSION}"
		[FIRMWARE_VERSION]="${REVISION}"
	)

	# prepare a single key=value array with the envs
	declare -agx CONTROL_SERVICE_ENV_VARS_ARRAY=()
	for key in "${!CONTROL_SERVICE_ENV_VARS[@]}"; do
		CONTROL_SERVICE_ENV_VARS_ARRAY+=("${key}=${CONTROL_SERVICE_ENV_VARS[$key]@Q}")
	done
	# override the firmware version for this usage, so server knows this is running during firmware build.
	CONTROL_SERVICE_ENV_VARS_ARRAY+=("FIRMWARE_VERSION='${REVISION} at image build'")
	display_alert "CONTROL_SERVICE_ENV_VARS_ARRAY" "${CONTROL_SERVICE_ENV_VARS_ARRAY[*]}" "debug"
}

function fetch_sources_tools__fetch_control_service() {
	display_alert "Fetching CS bin" "${EXTENSION}" "info"

	# Make sure directory exists
	mkdir -p "${CONTROL_SERVICE_CACHE_DIR}"

	if [[ -f "${CONTROL_SERVICE_CACHED_CS_BIN_PATH}" ]]; then
		display_alert "Using cached CS bin" "${CONTROL_SERVICE_BIN_FILE}" "info"
	else
		# Lazy. GitHub Releases might require PAT to download from repo.
		display_alert "Go fetch" "${CONTROL_SERVICE_BIN_URL} into ${CONTROL_SERVICE_CACHE_DIR} file ${CONTROL_SERVICE_BIN_FILE}" "info"
		exit_with_error "Go fetch CS bin yourself, see instructions above"
	fi
}

function pre_customize_image__038_control_service_add() {
	display_alert "Adding CS to target image" "${EXTENSION}" "info"
	run_host_command_logged cp -pv "${CONTROL_SERVICE_CACHED_CS_BIN_PATH}" "${SDCARD}/usr/local/bin/${CONTROL_SERVICE_BIN_FILE}"
	chroot_sdcard chown -v -R vlc:vlc "/usr/local/bin/${CONTROL_SERVICE_BIN_FILE}"

	display_alert "Configuring CS EnvironmentFile" "${EXTENSION}" "info"
	echo "" > "${SDCARD}/etc/default/${CONTROL_SERVICE_NAME}"
	for key in "${!CONTROL_SERVICE_ENV_VARS[@]}"; do
		echo "${key}=${CONTROL_SERVICE_ENV_VARS[$key]@Q}" >> "${SDCARD}/etc/default/${CONTROL_SERVICE_NAME}"
	done
	run_host_command_logged cat "${SDCARD}/etc/default/${CONTROL_SERVICE_NAME}"

	display_alert "Adding CS systemd service" "${EXTENSION}" "info"
	cat <<- EOD > "${SDCARD}/usr/lib/systemd/system/${CONTROL_SERVICE_NAME}.service"
		[Unit]
		Description=${CONTROL_SERVICE_NAME}
		After=early-autoconfig.service bluetooth.service network.target
		Requires=early-autoconfig.service bluetooth.service network.target
		StartLimitIntervalSec=0

		[Service]
		User=vlc
		Group=vlc
		SyslogIdentifier=${CONTROL_SERVICE_NAME}
		EnvironmentFile=/etc/default/${CONTROL_SERVICE_NAME}
		ExecStart=/usr/local/bin/${CONTROL_SERVICE_BIN_FILE}
		Restart=always

		[Install]
		WantedBy=multi-user.target
	EOD
	chroot_sdcard systemctl enable ${CONTROL_SERVICE_NAME}.service
}

# Hack, add media to /media from the host.
function pre_customize_image__039_add_media_via_control_service() {
	local host_src="${SRC}/cache/media-cs"
	local device_dest="${CONTROL_SERVICE_MEDIA_DEVICE_PATH}"

	if [[ "${host_src}" == "" ]] && [[ "${device_dest}" == "" ]]; then
		display_alert "CS: no media found" "Set CONTROL_SERVICE_MEDIA_DEVICE_PATH" "warn"
		return 0
	fi

	# First, add from host cached media.
	mkdir -p "${SDCARD}${device_dest}"
	if [[ -d "${host_src}" ]]; then
		display_alert "Adding media from host's ${host_src}" "${EXTENSION}" "info"
		run_host_command_logged cp -rvp "${host_src}"/* "${SDCARD}${device_dest}"/
	else
		display_alert "Missing media at host's ${host_src}" "${EXTENSION}" "warn"
		# make sure host cache exists
		mkdir -p "${host_src}"
	fi

	display_alert "Making media folder owned by vlc" "${EXTENSION}" "info"
	chroot_sdcard chown -v -R vlc:vlc "${device_dest}"

	# Then run the control service to fetch updates, so baked image has fresh catalog at time of build.
	display_alert "Running CS to fetch media" "${EXTENSION}" "info"
	chroot_sdcard "${CONTROL_SERVICE_ENV_VARS_ARRAY[@]}" "/usr/local/bin/${CONTROL_SERVICE_BIN_FILE}" --one-shot-sync

	display_alert "Syncing media back to host cache" "${EXTENSION}" "info"
	run_host_command_logged rsync -av "${SDCARD}${device_dest}"/* "${host_src}"/

	# Once done, sync back to the host, so we can use it in the next build.
	display_alert "Syncing media to host" "${EXTENSION}" "info"
}
