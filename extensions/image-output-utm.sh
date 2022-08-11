enable_extension "image-output-qcow2"

#### *allow extensions to prepare their own config, after user config is done*
function extension_prepare_config__prepare_utm_config() {
	export UTM_VM_CPUS="${UTM_VM_CPUS:-4}"        # Number of CPUs
	export UTM_VM_RAM_GB="${UTM_VM_RAM_GB:-16}"   # RAM in Gigabytes
	export UTM_KEEP_QCOW2="${UTM_KEEP_QCOW2:-no}" # keep the qcow2 image after conversion to UTM
}

function user_config__metadata_cloud_config() {
	display_alert "Preparing UTM config" "${EXTENSION}" "info"
	export SERIALCON="ttyS0" # UTM's serial at ttyS0, for x86 @TODO: arm64? ttyAML0?
	display_alert "Prepared UTM config" "${EXTENSION}: SERIALCON: '${SERIALCON}'" "debug"
}

#### *custom post build hook*
function post_build_image__920_create_utm_plist() {
	local UTM_VM_NAME="${UTM_VM_NAME:-${version}}"            # The name of the VM when imported into Fusion/Player/Workstation; no spaces please
	local original_qcow2_image="${QCOW2_IMAGE_FILE}"          # Original from qcow2 output extension
	local temp_qcow2_image="${DESTIMG}/${version}_temp.qcow2" # shadow qcow2 for resize

	local base_utm_dirname="${UTM_VM_NAME}.utm"                      # directory for vmx format, name only
	local full_utm_dirname="${DESTIMG}/${base_utm_dirname}"          # directory for vmx format, full path
	local full_plist_filename="${full_utm_dirname}/config.plist"     # vmx in vmx format dir
	local base_file_rootdisk="${UTM_VM_NAME}-disk1-efi-rootfs.qcow2" # target temp vmdk (filename)
	local dir_file_rootdisk="${full_utm_dirname}/Data"
	local full_file_rootdisk="${dir_file_rootdisk}/${base_file_rootdisk}" # target temp vmdk (full path)
	local final_plist_zip_file="${DESTIMG}/${UTM_VM_NAME}.utm.zip"        # final vmx zip artifact - defaults to UEFI boot
	mkdir -p "${full_utm_dirname}" "${dir_file_rootdisk}"                 # pre-create it

	display_alert "Converting image to UTM VM format" "${EXTENSION}" "info"
	run_host_command_logged qemu-img create -f qcow2 -F qcow2 -b "${original_qcow2_image}" "${temp_qcow2_image}" # create a new, temporary, qcow2 with the original as backing image
	run_host_command_logged qemu-img resize "${temp_qcow2_image}" +92G                                           # resize the temporary
	run_host_command_logged qemu-img convert -f qcow2 -O qcow2 "${temp_qcow2_image}" "${full_file_rootdisk}"     # convert the big temp to vmdk
	run_host_command_logged rm -vf "${temp_qcow2_image}"                                                         # remove the temporary large qcow2, free space
	if [[ "${UTM_KEEP_QCOW2}" != "yes" ]]; then                                                                  # check if told to keep the qcow2 image
		display_alert "Discarding qcow2 image after" "conversion to UTM VM" "debug"                                 # debug
		run_host_command_logged rm -vf "${original_qcow2_image}"                                                    # remove the original qcow2, free space
	fi                                                                                                           # /check
	run_host_command_logged qemu-img info "${full_file_rootdisk}"                                                # show info

	display_alert "Creating config.plist file" "${EXTENSION}" "info"

	# @TODO: this is for UTM 4.x which is unreleased at this time
	cat <<- UTM_4X_CONFIG_PLIST > "${full_plist_filename}"
		<?xml version="1.0" encoding="UTF-8"?>
		<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
		<plist version="1.0">
		<dict>
			<key>Backend</key>
			<string>QEMU</string>
			<key>ConfigurationVersion</key>
			<integer>4</integer>
			<key>Display</key>
			<array/>
			<key>Drive</key>
			<array>
				<dict>
					<key>Identifier</key>
					<string>0</string>
					<key>ImageName</key>
					<string>${base_file_rootdisk}</string>
					<key>ImageType</key>
					<string>Disk</string>
					<key>Interface</key>
					<string>VirtIO</string>
				</dict>
			</array>
			<key>Information</key>
			<dict>
				<key>IconCustom</key>
				<false/>
				<key>Name</key>
				<string>${UTM_VM_NAME}</string>
			</dict>
			<key>Input</key>
			<dict>
				<key>MaximumUsbShare</key>
				<integer>0</integer>
				<key>UsbBusSupport</key>
				<string>Disabled</string>
				<key>UsbSharing</key>
				<true/>
			</dict>
			<key>Network</key>
			<array>
				<dict>
					<key>Hardware</key>
					<string>virtio-net-pci</string>
					<key>IsolateFromHost</key>
					<false/>
					<key>Mode</key>
					<string>Bridged</string>
					<key>PortForward</key>
					<array/>
				</dict>
			</array>
			<key>QEMU</key>
			<dict>
				<key>AdditionalArguments</key>
				<array/>
				<key>BalloonDevice</key>
				<true/>
				<key>DebugLog</key>
				<false/>
				<key>Hypervisor</key>
				<true/>
				<key>PS2Controller</key>
				<false/>
				<key>RNGDevice</key>
				<true/>
				<key>RTCLocalTime</key>
				<true/>
				<key>TPMDevice</key>
				<false/>
				<key>UEFIBoot</key>
				<true/>
			</dict>
			<key>Serial</key>
			<array>
				<dict>
					<key>Mode</key>
					<string>Terminal</string>
					<key>Target</key>
					<string>Auto</string>
					<key>Terminal</key>
					<dict>
						<key>BackgroundColor</key>
						<string>#000000</string>
						<key>Font</key>
						<string>Menlo-Regular</string>
						<key>FontSize</key>
						<integer>12</integer>
						<key>ForegroundColor</key>
						<string>#ffffff</string>
					</dict>
				</dict>
			</array>
			<key>Sharing</key>
			<dict>
				<key>ClipboardSharing</key>
				<true/>
				<key>DirectoryShareMode</key>
				<string>VirtFS</string>
				<key>DirectoryShareReadOnly</key>
				<true/>
			</dict>
			<key>Sound</key>
			<array/>
			<key>System</key>
			<dict>
				<key>Architecture</key>
				<string>x86_64</string>
				<key>CPU</key>
				<string>max</string>
				<key>CPUCount</key>
				<integer>${UTM_VM_CPUS}</integer>
				<key>CPUFlagsAdd</key>
				<array/>
				<key>CPUFlagsRemove</key>
				<array/>
				<key>ForceMulticore</key>
				<false/>
				<key>JITCacheSize</key>
				<integer>0</integer>
				<key>MemorySize</key>
				<integer>$((UTM_VM_RAM_GB * 1024))</integer>
				<key>Target</key>
				<string>q35</string>
			</dict>
		</dict>
		</plist>
	UTM_4X_CONFIG_PLIST

	# Now wrap the .vmx in a zip, with minimal compression. (release will .zst it later)
	display_alert "Zipping/storing UTM VM" "${EXTENSION}" "info"
	cd "${DESTIMG}" || false
	run_host_command_logged tree -h .
	run_host_command_logged zip -r -0 "${final_plist_zip_file}" "${base_utm_dirname}"/*
	cd - || false

	display_alert "Done, cleaning up" "${EXTENSION}" "info"
	rm -rf "${full_utm_dirname}"
}
