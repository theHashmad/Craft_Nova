*** Settings ***
Library     SSHLibrary
Library     String
Library     RequestsLibrary
Library     OperatingSystem
Library     DateTime
Library     Process
Resource    ../Keywords/Keyword_Codebeamer.robot
Resource    ../Configuration/CICD/CICD_Configuration.resource
Resource    ../Configuration/Codebeamer/Codebeamer_Configuration.resource
Resource    ../Keywords/Keyword_System.robot


*** Variables ***
${BASE_URL}                                             https://case.artifacts.medtronic.com/artifactory/crdn-generic-dev-local/aurora/builds/aurora-apps/${BRANCH}/
${OS_UPGRADE_BASE_URL}                                  https://case.artifacts.medtronic.com/artifactory/crdn-generic-dev-local/aurora/builds/aurora-os/${BRANCH}/
${DOWNLOAD_DIR}                                         temp_for_apps_deploy
${REMOTE_DIRECTORY}                                     /home/petalinux
${REMOTE_DIRECTORY_ARTIFACTS}                           ${REMOTE_DIRECTORY}/${DOWNLOAD_DIR}
${REMOTE_DIRECTORY_UPGRADE}                             /data/upgrade
${CONFIGS_PATH}                                         /etc/aurora
${CONFIG_FILE_NAME}                                     config.toml
${GRPC_Lib_DIR}                                         Common_Lib/G4_API/Core
${Generator_API}                                        GeneratorAPIClient.tar
${BUILD_INFO_FILE}                                      ${DOWNLOAD_DIR}/build_info.txt

${GRPC_FILE_PATH}                                       build-tools/tools/${Generator_API}
${AURORA_APPS_DEFAULT_FILE}                             /etc/default/aurora-apps
# List of file paths (relative to BASE_URL)
@{FILES}
...                                                     build-tools/tools/GeneratorAPIClient.tar
...                                                     apu-build-v2024.2-3.tar.gz
...                                                     rpu-sim-build.tar.gz
...                                                     build_info.txt

&{BINARIES}
# List of binary files paths (relative to BASE_URL)
...                                                     archiver=/usr/bin/archiver
...                                                     grpcserver=/usr/bin/grpcserver
...                                                     r5console=/usr/bin/r5console
...                                                     therapy_r5_0=/lib/firmware/therapy-sim-r5_0
...                                                     audio_service=/usr/bin/audio_service

*** Keywords ***
Download Specific Artifacts
    [Documentation]    Remove old files and download only the specified artifacts.
    [Tags]    internal
    [Arguments]    ${build_id}

    # Remove and recreate the directory
    Run Keyword And Ignore Error    Remove Directory    ${DOWNLOAD_DIR}    recursive=True
    Create Directory    ${DOWNLOAD_DIR}

    ${auth}=    Create List    ${api_user}    ${api_passwd}
    Create Session    artifactory    ${BASE_URL}${build_id}/    auth=${auth}    disable_warnings=1

    FOR    ${file_path}    IN    @{FILES}
        ${file_url}=    Set Variable    ${BASE_URL}${build_id}/${file_path}
        Download File    ${file_url}
    END

Download OS Upgrade Artifact
    [Documentation]    Downloads OS upgrade package for the specified OS ID, build ID, and platform.
    [Tags]    internal
    [Arguments]    ${os_id}=${UPGRADE_OS_ID}    ${build_id}=${BUILD_ID}    ${platform}=${PLATFORM}    ${os_version}=${OS_VERSION}    ${app_version}=${APP_VERSION}

    # Remove and recreate the directory
    Run Keyword And Ignore Error    Remove Directory    ${DOWNLOAD_DIR}    recursive=True
    Create Directory    ${DOWNLOAD_DIR}

    # Construct the OS upgrade filename
    ${filename}=    Set Variable    xilinx-${platform}-upgrade-aos-${os_version}.${os_id}-app-${app_version}.${build_id}.tar
    
    Log To Console    \nDownloading OS Upgrade Package:
    Log To Console    Platform: ${platform}
    Log To Console    OS Build ID: ${os_id}
    Log To Console    App Build ID: ${build_id}
    Log To Console    Filename: ${filename}
    
    # Construct the download URL
    ${file_url}=    Set Variable    ${OS_UPGRADE_BASE_URL}${os_id}/${filename}
    
    ${auth}=    Create List    ${api_user}    ${api_passwd}
    Create Session    artifactory    ${OS_UPGRADE_BASE_URL}${os_id}/    auth=${auth}    disable_warnings=1
    
    # Download the OS upgrade file
    Download File    ${file_url}
    
    Log    Successfully downloaded OS upgrade package: ${filename}

Extract And Copy OS Upgrade To Board
    [Documentation]    Copies OS upgrade directory to remote board and extracts tar to /data directory.
    [Tags]    internal
    [Arguments]    ${os_id}=${UPGRADE_OS_ID}    ${build_id}=${BUILD_ID}    ${platform}=${PLATFORM}    ${os_version}=${OS_VERSION}    ${app_version}=${APP_VERSION}

    # Construct the filename
    ${filename}=    Set Variable    xilinx-${platform}-upgrade-aos-${os_version}.${os_id}-app-${app_version}.${build_id}.tar
    
    Log To Console    \nCopying Download Directory to Board:
    Log To Console    Local directory: ${DOWNLOAD_DIR}
    Log To Console    Remote directory: ${REMOTE_DIRECTORY}
    
    # Copy entire download directory to board
    Copy Directory To Board    ${DOWNLOAD_DIR}    ${REMOTE_DIRECTORY}
    Log To Console    Directory copy completed successfully
    
    # Tar file is now at /home/petalinux/temp_for_apps_deploy/<filename>
    ${remote_tar_path}=    Set Variable    ${REMOTE_DIRECTORY}/${DOWNLOAD_DIR}/${filename}
    
    # Extract tar directly to /data
    Log To Console    Extracting tarball to /data...
    ${extract_cmd}=    Set Variable    tar -xf ${remote_tar_path} -C /data
    ${extract_output}=    Execute Command    ${extract_cmd}    sudo=True    sudo_password=${PASSWORD}
    Log    Extraction output: ${extract_output}
    Log To Console    Extraction completed
    
    # Run sync to ensure all data is written to disk
    Log To Console    Running sync...
    Execute Command    sync    sudo=True    sudo_password=${PASSWORD}
    Log To Console    Sync completed
    
    Log    Successfully copied and extracted OS upgrade package to /data

Disable And Stop Present Services
    [Documentation]    Disable and stop the present services as a prerequisite for changing the binary files.
    [Tags]    internal
    [Arguments]    ${services_string}
    Execute Systemctl For Given Services    status    ${services_string}
    Execute Systemctl For Given Services    disable    ${services_string}
    Execute Systemctl For Given Services    stop    ${services_string}

Delete Bins
    [Documentation]    Removes outdated binaries related to the specified services.
    [Tags]    internal
    [Arguments]    ${services}

    ${services_list}=    Evaluate    """${services}""".split(" ")

    IF    'therapy_sim.service' in @{services_list}
        Remove file with sudo    /usr/bin/r5console
        Remove file with sudo    /lib/firmware/therapy-sim-r5_0
        Remove file with sudo    ${CONFIGS_PATH}/therapy/${CONFIG_FILE_NAME}
    END

    IF    'generator-api.service' in @{services_list}
        Remove file with sudo    /usr/bin/grpcserv
        Remove file with sudo    ${CONFIGS_PATH}/generator-api/${CONFIG_FILE_NAME}
    END

    IF    'archiver.service' in @{services_list}
        Remove file with sudo    /usr/bin/archiver
        Remove file with sudo    ${CONFIGS_PATH}/archiver/${CONFIG_FILE_NAME}
        Remove file with sudo    /var/lib/archiver/therapy/therapy.db*
        Remove file with sudo    /var/lib/archiver/backup/therapy.db*
    END

    IF    'audio-service' in @{services_list}
        Remove file with sudo    /usr/bin/audio_service
        Remove file with sudo    ${CONFIGS_PATH}/audio_service/${CONFIG_FILE_NAME}
    END

    IF    'diagnostic' in @{services_list}
        Remove file with sudo    /lib/firmware/diagnostic-over-grpc
    END

Remove file with sudo
    [Documentation]    Remove given file with absolute path with sudo rights, then confirms successful removal.
    ...                - *Date of Implementation:* 15-04-2026
    ...                - *Author:* Pawel Dudek
    ...                - *Usage:* Provide file to be removed with absolute path. Used for binaries, configs or dependencies.
    ...                - *Returns:* N/A
    [Tags]    internal
    [Arguments]    ${given_file_absolute_path}
    Execute Command    rm -f ${given_file_absolute_path}    sudo=True    sudo_password=${PASSWORD}
    SSHLibrary.File Should Not Exist    ${given_file_absolute_path}

Copy Directory To Board
    [Documentation]    Copies a directory from the local machine to the target board.
    [Tags]    internal
    [Arguments]    ${local_dir}    ${remote_dir}

    # Normalize the provided local directory path
    ${local_dir}=    Normalize Path    ${local_dir}

    # Extract only the folder name
    ${folder_name}=    Evaluate    """${local_dir}""".rstrip("/").split("/")[-1]
    Log    ${folder_name}

    # Construct the full path on the remote board
    ${full_remote_path}=    Catenate    SEPARATOR=/    ${remote_dir}    ${folder_name}
    Log    ${full_remote_path}

    # # Delete existing directory
    Log    ${full_remote_path}
    Run Keyword And Ignore Error    Execute Command    rm -rf ${full_remote_path}    sudo=True    sudo_password=${PASSWORD}
    Execute Command    mkdir -p ${full_remote_path}

    # Copy the new directory
    Put Directory    ${local_dir}    ${remote_dir}
    Log    Copied directory ${local_dir} to ${remote_dir}

Reboot Board
    [Documentation]    Reboots the board and waits until it's back online.
    [Tags]    internal

    Execute Command    reboot    sudo=True    sudo_password=${PASSWORD}
    Wait Until Keyword Succeeds    10x    1s    Check Board Offline
    Sleep    20s
    Wait Until Keyword Succeeds    60x    2s    Check Board Online

Copy Library
    [Documentation]    Copies a directory from the local to the target board.
    [Tags]    internal
    [Arguments]    ${original_dir}    ${destination_dir}

    # Copy the new directory
    Copy File    ${original_dir}    ${destination_dir}
    Log    Copied ${original_dir} to ${destination_dir}

Extract Tar Files On Board
    [Documentation]    Extracts tar files on the target device to deploy new binaries.
    [Tags]    internal
    [Arguments]    ${tar_files}    ${remote_dir}

    # Ensure tar_files is correctly split into a list
    ${tar_files_list}=    Evaluate    """${tar_files}""".split(" ")

    FOR    ${tar_file}    IN    @{tar_files_list}
        ${extension}=    Evaluate    """${tar_file}""".split(".")[-1]

        IF    "${extension}" == "gz"
            ${command}=    Catenate    SEPARATOR=SPACE    tar -xvzf ${remote_dir}/${tar_file} -C ${remote_dir}
        ELSE
            ${command}=    Catenate    SEPARATOR=SPACE    tar -xvf ${remote_dir}/${tar_file} -C ${remote_dir}
        END

        Execute Command    ${command}    sudo=True    sudo_password=${PASSWORD}
        Log    Extracted ${tar_file} in ${remote_dir}
    END

Extract Library
    [Documentation]    Extracts tar files on the target device
    [Tags]    internal
    [Arguments]    ${path}    ${tar_file}

    ${normalized_path}=    Normalize Path    ${path}
    ${target_file}=    Join Path    ${normalized_path}    ${tar_file}

    ${command}=    Catenate    SEPARATOR=SPACE    tar -xvf ${target_file} -C ${normalized_path}
    ${rc}    ${output}=    Run And Return Rc And Output    ${command}
    Log    ${output}
    Should Be Equal As Integers    ${rc}    0    msg=tar extraction failed (rc=${rc}): ${output}
    Log    Extracted ${tar_file}
    ${py_files}=    OperatingSystem.List Files In Directory    ${normalized_path}    *.py    absolute=${True}
    Log    Python files in ${normalized_path}:\n${py_files}
    ${messages_path}=    Join Path    ${normalized_path}    messages
    ${msg_py_files}=    OperatingSystem.List Files In Directory    ${messages_path}    *.py    absolute=${True}
    Log    Python files in ${messages_path}:\n${msg_py_files}

Copy Extracted Bins And Remove Temp Directory
    [Documentation]    Copies extracted binaries to their designated locations.
    [Tags]    internal
    [Arguments]    ${services}
    ${services_list}=    Evaluate    """${services}""".split(" ")

    IF    'therapy_sim.service' in @{services_list}
        Copy File With Sudo    ${REMOTE_DIRECTORY_ARTIFACTS}/r5console/r5console    /usr/bin/r5console
        Copy File With Sudo    ${REMOTE_DIRECTORY_ARTIFACTS}/therapy/therapy-sim-r5_0    /lib/firmware/therapy-sim-r5_0
        Copy File With Sudo    ${REMOTE_DIRECTORY_ARTIFACTS}/therapy/config/${CONFIG_FILE_NAME}    ${CONFIGS_PATH}/therapy/${CONFIG_FILE_NAME}
    END

    IF    'generator-api.service' in @{services_list}
        Copy File With Sudo    ${REMOTE_DIRECTORY_ARTIFACTS}/generator_api/grpcserver    /usr/bin/grpcserver
        Copy File With Sudo    ${REMOTE_DIRECTORY_ARTIFACTS}/generator_api/config/${CONFIG_FILE_NAME}    ${CONFIGS_PATH}/generator-api/${CONFIG_FILE_NAME}
    END

    IF    'archiver.service' in @{services_list}
        Copy File With Sudo    ${REMOTE_DIRECTORY_ARTIFACTS}/archiver/archiver    /usr/bin/archiver
        Copy File With Sudo    ${REMOTE_DIRECTORY_ARTIFACTS}/archiver/config/${CONFIG_FILE_NAME}    ${CONFIGS_PATH}/archiver/${CONFIG_FILE_NAME}
        Copy File With Sudo    ${REMOTE_DIRECTORY_ARTIFACTS}/archiver/storage/therapy.db    /var/lib/archiver/therapy/therapy.db
        Copy File With Sudo    ${REMOTE_DIRECTORY_ARTIFACTS}/archiver/storage/therapy.db    /var/lib/archiver/backup/therapy.db
        Execute Command        chmod 0644 /var/lib/archiver/therapy/therapy.db    sudo=True    sudo_password=${PASSWORD}
        Execute Command        chmod 0444 /var/lib/archiver/backup/therapy.db    sudo=True    sudo_password=${PASSWORD}
    END

    IF    'audio-service.service' in @{services_list}
        Copy File With Sudo    ${REMOTE_DIRECTORY_ARTIFACTS}/audio_service/audio_service    /usr/bin/audio_service
        Copy File With Sudo    ${REMOTE_DIRECTORY_ARTIFACTS}/audio_service/config/${CONFIG_FILE_NAME}    ${CONFIGS_PATH}/audio_service/${CONFIG_FILE_NAME}
    END

    IF    'diagnostic' in @{services_list}
        Copy File With Sudo    ${REMOTE_DIRECTORY_ARTIFACTS}/diagnostic/diagnostic-over-grpc    /lib/firmware/diagnostic-over-grpc
    END

    # Delete temp directory on target board
    Execute Command    rm -f ${DOWNLOAD_DIR}/*
    Execute Command    rmdir ${DOWNLOAD_DIR}/

Run System Upgrade
    [Documentation]    Executes the system upgrade script with the specified upgrade directory.
    [Tags]    internal

    Log To Console    \nRunning System Upgrade:
    Log To Console    Upgrade directory: ${REMOTE_DIRECTORY_UPGRADE}

   
    ${cmd}=    Set Variable    system_upgrade.sh -u -d ${REMOTE_DIRECTORY_UPGRADE}/
    
    Log    Executing command: ${cmd}
    ${output}=    Execute Command    ${cmd}    sudo=True    sudo_password=${PASSWORD}    return_stdout=True    return_stderr=True    return_rc=True
    
    Log    Command output:\n${output}[0]
    Log    Command stderr:\n${output}[1]
    Log    Command return code: ${output}[2]
    
    Should Be Equal As Integers    ${output}[2]    0    msg=System upgrade failed with return code ${output}[2]. Error: ${output}[1]
    
    # Check for error indicators in output
    Should Not Contain    ${output}[0]    ERROR    ignore_case=True    msg=System upgrade output contains ERROR
    Should Not Contain    ${output}[0]    FAILED    ignore_case=True    msg=System upgrade output contains FAILED
    
    Log To Console    System upgrade command executed successfully
    
    RETURN    ${output}[0]

Power Cycle Host
    [Documentation]    Power cycles the host using DLI power switch via REST API.
    ...    Requires POWER_USER and POWER_PASSWORD to be configured.
    [Tags]    internal
    [Arguments]    ${outlet_index}=7    ${switch_ip}=${POWER_SWITCH_IP}       ${power_off_sleep}=10

    # Convert outlet index to 0-based (server side expects 0-based indexing)
    ${server_outlet_index}=    Evaluate    ${outlet_index} - 1

    Log To Console    \nPower Cycling Host:
    Log To Console    Switch IP: ${switch_ip}
    Log To Console    Outlet index (user): ${outlet_index}
    Log To Console    Outlet index (server): ${server_outlet_index}
    Log To Console    Power off duration: ${power_off_sleep}s
    
    # Turn OFF the outlet
    Log To Console    Turning outlet OFF...
    ${cmd_off}=    Set Variable    curl --fail --silent --show-error --digest -u "${POWER_USER}:${POWER_PASSWORD}" -X PUT -H "X-CSRF: x" --data "value=false" "http://${switch_ip}/restapi/relay/outlets/${server_outlet_index}/state/"
    ${result_off}=    Run Process    ${cmd_off}    shell=True
    Should Be Equal As Integers    ${result_off.rc}    0    msg=Failed to turn outlet OFF. ${result_off.stderr}
    
    # Sleep with power off
    Log To Console    Sleeping for ${power_off_sleep}s with DUT powered off...
    Sleep    ${power_off_sleep}s
    
    # Turn ON the outlet
    Log To Console    Turning outlet ON...
    ${cmd_on}=    Set Variable    curl --fail --silent --show-error --digest -u "${POWER_USER}:${POWER_PASSWORD}" -X PUT -H "X-CSRF: x" --data "value=true" "http://${switch_ip}/restapi/relay/outlets/${server_outlet_index}/state/"
    ${result_on}=    Run Process    ${cmd_on}    shell=True
    Should Be Equal As Integers    ${result_on.rc}    0    msg=Failed to turn outlet ON. ${result_on.stderr}
    
    Log To Console    Power cycle completed successfully

Verify OS Upgraded Version
    [Documentation]    Verifies that the Aurora OS version after upgrade matches the expected
    [Tags]    internal
    ${output}=    Execute Command    system_info.sh
    ${result}=    Should Contain    ${output}    AURORA_OS_RELEASE="${OS_VERSION}.${UPGRADE_OS_ID}"
    [Teardown]    Document Keyword Outcome    Verified OS upgraded by checking system_info.

Copy file with sudo
    [Documentation]    Copies given file with absolute path with sudo rights, then confirms successful copying.
    ...                - *Date of Implementation:* 15-04-2026
    ...                - *Author:* Pawel Dudek
    ...                - *Usage:* Provide file to be copied with absolute path. Used for binaries, configs or dependencies.
    ...                - *Returns:* N/A
    [Tags]    internal
    [Arguments]    ${given_file_absolute_path}    ${target_location}
    Execute Command
    ...    cp ${given_file_absolute_path} ${target_location}
    ...    sudo=True
    ...    sudo_password=${PASSWORD}
    SSHLibrary.File Should Exist    ${target_location}

Enable And Start Updated Services
    [Documentation]    Enable and start the updated services.
    [Tags]    internal
    [Arguments]    ${services_string}

    Execute Systemctl For Given Services    status    ${services_string}
    Execute Systemctl For Given Services    enable    ${services_string}
    Execute Systemctl For Given Services    start    ${services_string}

    # Convert the services string into a list for iteration in status checks
    ${services_list}=    Evaluate    """${services_string}""".split(" ")

    # Iterate through each service to verify it is active and enabled
    FOR    ${service}    IN    @{services_list}
        # ${status_output}=    Check Service Status    ${service}
        ${status_output}=    Execute Systemctl For Given Services    status    ${service}
        Should Contain    ${status_output}    Active: active
        Should Contain    ${status_output}    enabled;
    END

Reset Board and Services
    [Documentation]    Restart the board and services.
    [Tags]    109051=7
    Reboot Board
    Run With Recovery
    ...    Enable And Start Updated Services
    ...    archiver.service generator-api.service therapy_sim.service display.service audio-service.service
    [Teardown]    Document Keyword Outcome    Verified board was rebooted successfully and services are up and running again: archiver, generator-api, therapy_sim, display, audio-service.

Clean Downloaded Artifacts
    [Documentation]    Remove the downloaded artifacts from local
    [Tags]    internal
    Run Keyword And Ignore Error    Remove Directory    ${DOWNLOAD_DIR}    recursive=True

Download File
    [Documentation]    Download a file and save it in the specified directory.
    [Tags]    internal
    [Arguments]    ${file_url}

    ${file_name}=    Evaluate    os.path.basename("${file_url}")    modules=os
    ${destination}=    Set Variable    ${DOWNLOAD_DIR}/${file_name}

    Log    Downloading ${file_url} ...

    ${response}=    Get On Session    artifactory    ${file_url}    stream=True

    Should Be Equal As Strings    ${response.status_code}    200
    Create Binary File    ${destination}    ${response.content}
    Log    Downloaded: ${destination}

Check Board Offline
    [Documentation]    Verifies if the board has gone offline.
    [Tags]    internal
    ${status}=    Run Keyword And Ignore Error    Execute Command    echo "Checking if board is offline"
    ${error_message}=    Set Variable    ${status}[1]
    Log    Checking offline status: ${error_message}
    Should Contain    ${error_message}    SSH session not active

Check Board Online
    [Documentation]    Checks if the board has come back online. Opens an SSH connection, elevates to root and verifies the prompt.
    ...    Accepts optional ${alias} and ${login_delay} so it can be reused by Open Connection And Log In.
    [Tags]    internal
    [Arguments]    ${alias}=${None}    ${login_delay}=10s
    Run Keyword And Ignore Error    Close Connection
    ${id}=    Open Connection    ${HOST}    prompt=$    timeout=15s    alias=${alias}
    Login    ${USERNAME}    ${PASSWORD}    delay=${login_delay}
    Write    sudo su -
    Set Client Configuration    prompt=#
    ${output}=    Read Until Prompt
    Should Contain    ${output}    root@
    Should End With    ${output}    :~#
    RETURN    ${id}

Download Grpc Libraries
    [Documentation]    Remove old files and download Grpc Lib
    [Tags]    internal
    [Arguments]    ${build_id}
    # Remove and recreate the directory
    Run Keyword And Ignore Error    Remove Directory    ${DOWNLOAD_DIR}    recursive=True
    Create Directory    ${DOWNLOAD_DIR}

    ${auth}=    Create List    ${api_user}    ${api_passwd}
    Create Session    artifactory    ${BASE_URL}${build_id}/    auth=${auth}    disable_warnings=1

    ${file_url}=    Set Variable    ${BASE_URL}${build_id}/${GRPC_FILE_PATH}
    Download File    ${file_url}

Verify Software Versions
    [Documentation]    Verifies that deployed binaries contain the expected software version string and the parsed version string from build_info.txt.
    [Tags]    internal
    [Arguments]    ${build_id}    ${binaries}
    ${expected_version}=    Set Variable    ${build_id}

    Log    Verifying expected version string: ${expected_version}
    Log    Verifying parsed version string: ${PARSED_VERSION_STRING}

    FOR    ${name}    ${path}    IN    &{binaries}
        ${output}=    Execute Command    strings ${path} | grep "Software Version" || echo ""
        Log    ${name} - version string found: ${output}

        Should Contain
        ...    ${output}
        ...    ${expected_version}
        ...    msg=ERROR: ${name} version mismatch! Found: ${output}, expected: ${expected_version}
        Should Contain
        ...    ${output}
        ...    ${PARSED_VERSION_STRING}
        ...    msg=ERROR: ${name} missing parsed version string! Found: ${output}, expected: ${PARSED_VERSION_STRING}
    END

Parse And Log Build Info
    [Documentation]    Parses the build_info.txt file and logs its contents to the Robot log and report.
    [Tags]    internal
    [Arguments]    ${build_info_path}

    Log To Console    \n
    ${exists}=    Run Keyword And Return Status    OperatingSystem.File Should Exist    ${build_info_path}
    IF    not ${exists}    Fail    File not found

    ${lines}=    OperatingSystem.Get File    ${build_info_path}
    ${lines}=    Split String    ${lines}    \n

    # Init defaults
    Set Global Variable    ${SW_VER_PREFIX}    NONE
    Set Global Variable    ${BUILD_ID_PARSED}    NONE

    FOR    ${line}    IN    @{lines}
        ${stripped}=    Strip String    ${line}
        IF    '${stripped}' and not '${stripped}'.startswith('#')
            Log To Console And Report    ${stripped}
        END

        IF    '${stripped}'.startswith('AURORA_APPS_SOFTWARE_VERSION=')
            Set Global Variable    ${SW_VER_PREFIX}    ${stripped.split('=')[1].strip('"')}
        END

        IF    '${stripped}'.startswith('AURORA_APPS_BUILD_ID=')
            Set Global Variable    ${BUILD_ID_PARSED}    ${stripped.split('=')[1].strip('"')}
        END
    END

    # Check that values were found
    IF    '${SW_VER_PREFIX}' == 'NONE'
        Fail    Software version not found in build_info.txt
    END
    IF    '${BUILD_ID_PARSED}' == 'NONE'
        Fail    Build ID not found in build_info.txt
    END

    # Build expected version string and compare to input
    ${EXPECTED_VERSION}=    Set Variable    ${SW_VER_PREFIX}.${BUILD_ID}
    ${PARSED_VERSION}=    Set Variable    ${SW_VER_PREFIX}.${BUILD_ID_PARSED}

    # Validate parsed build ID matches passed build ID
    Should Be Equal
    ...    ${BUILD_ID_PARSED}
    ...    ${BUILD_ID}
    ...    msg=Build ID mismatch: parsed=${BUILD_ID_PARSED}, expected=${BUILD_ID}
    # Set full software version string for later use in verification
    ${PARSED_VERSION_STRING}=    Set Variable    Software Version: ${PARSED_VERSION}
    Set Global Variable    ${PARSED_VERSION_STRING}    ${PARSED_VERSION_STRING}
    Log    Parsed version string set to: ${PARSED_VERSION_STRING}

Remove All Display Images Except
    [Documentation]    Removes all display images from the board except the one matching the specified tag to free up space.
    ...                - *Date of Implementation:* 14-05-2026
    ...                - *Author:* Mateusz Rosiek
    [Tags]    internal
    [Arguments]    ${tag}
    ${available_images}=    Execute Command    podman images -a    sudo=True    sudo_password=${PASSWORD}
    Log    Available images before cleaning: ${available_images}
    ${images_to_remove_all_info}=    Execute Command    podman images --filter=reference!="*:${tag}"    sudo=True    sudo_password=${PASSWORD}
    Log    Images to remove (not matching tag ${tag}): ${images_to_remove_all_info}
    ${images_to_remove}=    Execute Command    podman images --filter=reference!="*:${tag}" -q    sudo=True    sudo_password=${PASSWORD}
    # Process the output to get a clean list of image IDs separated by space to be consumed by podman rmi command
    ${lines}=    Split String    ${images_to_remove}    \n
    ${lines}=    Evaluate    [x.strip() for x in $lines if x.strip()]
    ${space_separated}=    Evaluate    " ".join($lines)
    Log    ${space_separated}
    IF    '${space_separated}'
        Execute Command    podman rmi ${space_separated}    sudo=True    sudo_password=${PASSWORD}
    ELSE
        Log    No images to remove... skipping removal.
    END
    ${available_images}=    Execute Command    podman images -a    sudo=True    sudo_password=${PASSWORD}
    Log    Available images after cleaning: ${available_images}

Update Display App And Verify Tag
    [Documentation]    Updates the display container and confirms DISPLAY_TAG reflects the new value.
    [Tags]    internal
    [Arguments]    ${new_tag}    ${artifact_user}    ${artifact_token}
    ${old_tag}=    Get Display Tag From Default Apps File
    Log    Old DISPLAY_TAG: ${old_tag}
    Log    New DISPLAY_TAG: ${new_tag}

    IF    '${old_tag}' != '${new_tag}'
        # safely stop display service before deleting image which is already used. It will be deleted after the update.
        Execute Systemctl For Given Services    stop    display.service
        # make sure to remove old display images to free up space before update (in case state of the board is such that
        # old images weren't removed, e.g. due to failed update or manual changes)
        Remove All Display Images Except    ${new_tag}
        Update Display Image From Artifactory    ${new_tag}    ${artifact_user}    ${artifact_token}
        Verify Display Tag Matches    ${new_tag}
    ELSE
        Log    Skipping update: DISPLAY_TAG already set to ${new_tag}.
    END
    # make sure to remove old display image to free up space (the one which was updated is now obsolete or any other stale images
    # which was downloaded manually in the meantime, e.g. for testing purposes)
    Remove All Display Images Except    ${new_tag}

Get Display Tag From Default Apps File
    [Documentation]    Extracts and returns the DISPLAY_TAG value from the system info file (${AURORA_APPS_DEFAULT_FILE}).
    [Tags]    internal
    ${output}=    Execute Command    grep '^DISPLAY_TAG=' ${AURORA_APPS_DEFAULT_FILE}
    ${tag}=    Replace String    ${output}    DISPLAY_TAG=    ${EMPTY}
    RETURN    ${tag}

Update Display Image From Artifactory
    [Documentation]    Executes update_display.sh and waits for confirmation messages.
    [Tags]    internal
    [Arguments]    ${tag}    ${user}    ${token}    ${timeout}=240s
    ${cmd}=    Set Variable    update_display.sh -c ${tag} -u ${user} -t ${token}
    ${start_time}=    Get Current Date
    Write    ${cmd}
    ${conn}=    Get Connection
    ${default_timeout}=    Set Variable    ${conn.timeout}
    Set Client Configuration    timeout=${timeout}
    ${output}=    Read Until    Restarting display...
    ${end_time}=    Get Current Date
    ${elapsed}=    Subtract Date From Date    ${end_time}    ${start_time}
    ${elapsed_msg}=    Set Variable    Update Display Image From Artifactory took ${elapsed} seconds (tag: ${tag})
    Log    ${elapsed_msg}    WARN
    Set Client Configuration    timeout=${default_timeout}
    Log    ${output}
    Should Contain    ${output}    Login Succeeded!
    Should Contain    ${output}    Restarting display...

Verify Display Tag Matches
    [Tags]    internal
    [Arguments]    ${expected_tag}
    ${actual_tag}=    Get Display Tag From Default Apps File
    Log    Fetched DISPLAY_TAG: ${actual_tag}
    Should Be Equal    ${actual_tag}    ${expected_tag}

Get Services Requiring Update
    [Documentation]    Checks each service binary on the board against the new build ID.
    ...    Returns a space-separated string of service names whose on-board version does not
    ...    match ${build_id}. Services with missing or unreadable binaries are always included.
    ...    Sets the global variable ${SERVICES_TO_UPDATE} for downstream tasks.
    [Tags]    internal
    [Arguments]    ${services}    ${build_id}

    # Map each .service name to its primary binary path on the board
    &{SERVICE_BINARY_MAP}=    Create Dictionary
    ...    archiver.service=/usr/bin/archiver
    ...    generator-api.service=/usr/bin/grpcserver
    ...    therapy_sim.service=/lib/firmware/therapy-sim-r5_0
    ...    audio-service.service=/usr/bin/audio_service

    ${services_list}=    Evaluate    """${services}""".split()
    ${to_update}=    Create List

    FOR    ${service}    IN    @{services_list}
        ${binary}=    Get From Dictionary    ${SERVICE_BINARY_MAP}    ${service}    default=${EMPTY}

        IF    '${binary}' == '${EMPTY}'
            Log    No binary mapping for '${service}' — including in update list    WARN
            Append To List    ${to_update}    ${service}
            CONTINUE
        END

        ${result}=    Run Keyword And Ignore Error
        ...    Execute Command
        ...    strings ${binary} | grep "Software Version" || echo ""
        ${status}=    Set Variable    ${result}[0]
        ${output}=    Set Variable    ${result}[1]

        IF    '${status}' != 'PASS' or '${build_id}' not in '${output}'
            Log    ${service}: on-board version does not include '${build_id}' (found: ${output}) — scheduling update
            Append To List    ${to_update}    ${service}
        ELSE
            Log    ${service}: already at version '${build_id}' — skipping
            Log To Console    ${service}: up to date (${build_id})
        END
    END

    ${services_str}=    Evaluate    " ".join($to_update)
    Set Global Variable    ${SERVICES_TO_UPDATE}    ${services_str}
    Log To Console    Services requiring update: ${services_str}
    RETURN    ${services_str}

Get And Log System Info
    [Documentation]    Runs system_info.sh and logs every line.
    [Tags]    internal
    ${result}=    Run Keyword And Ignore Error
    ...    Execute Command
    ...    system_info.sh
    ...    return_stderr=True
    ...    sudo=True
    ...    sudo_password=${PASSWORD}
    ${output}=    Set Variable    ${result}[1]
    ${is_list}=    Evaluate    isinstance(${output}, list)
    IF    ${is_list}
        ${output_str}=    Evaluate    '\\n'.join(${output})
    ELSE
        ${output_str}=    Set Variable    ${output}
    END
    ${lines}=    Split String    ${output_str}    \n
    FOR    ${line}    IN    @{lines}
        Log To Console    ${line}
        Log    ${line}
    END

Update Audio Device Config
    [Documentation]    Updates the device parameter in the audio service config file to 'null' if not already set.
    [Tags]    internal

    ${config_path}=    Set Variable    /etc/aurora/audio_service/config.toml

    # Read the current config file
    ${current_content}=    Execute Command    cat ${config_path}    sudo=True    sudo_password=${PASSWORD}
    Log    Current config content:\n${current_content}

    # Check if device is already set to 'null'
    ${is_already_null}=    Run Keyword And Return Status    Should Contain    ${current_content}    device = 'null'

    IF    ${is_already_null}
        Log    Audio device is already set to 'null'. No changes needed.
    ELSE
        # Use sed to replace any device line with null (matches any device value)
        Execute Command    sed -i "s/device = '[^']*'/device = 'null'/g" ${config_path}    sudo=True    sudo_password=${PASSWORD}

        # Verify the change
        ${verify_content}=    Execute Command    cat ${config_path}    sudo=True    sudo_password=${PASSWORD}
        Should Contain    ${verify_content}    device = 'null'
        Log    Successfully updated audio device to 'null'
    END

Update Log Level Config
    [Documentation]    Updates the log_level parameter in all service config files to the specified value.
    ...    If the log level is invalid or set to default, no changes are made.
    [Tags]    internal
    [Arguments]    ${new_log_level}

    # Normalize input to lowercase
    ${new_log_level}=    Convert To Lower Case    ${new_log_level}

    # Log the chosen level at the beginning
    Log    Target log level: ${new_log_level}
    Log To Console    \nTarget log level: ${new_log_level}

    # Define valid log levels
    ${valid_levels}=    Create List    trace    debug    info    warning    error    critical    off    warn    err

    # Check if log level is valid
    ${is_valid}=    Run Keyword And Return Status    Should Contain    ${valid_levels}    ${new_log_level}

    IF    '${new_log_level}' == 'default'
        Log    Default log level - skipping config update.
        Log To Console    Default log level - skipping config update.
        RETURN
    END

    IF    not ${is_valid}
        Fail    Invalid log level '${new_log_level}'. Valid levels are: trace, debug, info, warning, error, critical, off, warn, err, default
    END


    # Define all service config paths
    @{config_paths}=    Create List
    ...    /etc/aurora/archiver/config.toml
    ...    /etc/aurora/audio_service/config.toml
    ...    /etc/aurora/display/config.toml
    ...    /etc/aurora/generator-api/config.toml
    ...    /etc/aurora/therapy/config.toml

    FOR    ${config_path}    IN    @{config_paths}
        # Check if file exists
        ${exists}=    Run Keyword And Return Status    SSHLibrary.File Should Exist    ${config_path}

        IF    ${exists}
            # Read current content
            ${current_content}=    Execute Command    cat ${config_path}    sudo=True    sudo_password=${PASSWORD}
            Log    Current config for ${config_path}:\n${current_content}

            # Extract current log level using regex
            ${current_log_level}=    Set Variable    UNKNOWN
            ${matches}=    Get Regexp Matches    ${current_content}    log_level = '([^']*)'    1
            IF    ${matches}
                ${current_log_level}=    Set Variable    ${matches}[0]
            END

            # Check if log_level is already set to the desired value
            IF    '${current_log_level}' == '${new_log_level}'
                Log    Log level in ${config_path} is already set to '${new_log_level}'. No changes needed.
                Log To Console    Log level in ${config_path} is already set to '${new_log_level}'. No changes needed.
            ELSE
                # Update log_level using sed
                Execute Command
                ...    sed -i "s/log_level = '[^']*'/log_level = '${new_log_level}'/g" ${config_path}
                ...    sudo=True
                ...    sudo_password=${PASSWORD}

                # Verify the change
                ${verify_content}=    Execute Command    cat ${config_path}    sudo=True    sudo_password=${PASSWORD}
                Should Contain    ${verify_content}    log_level = '${new_log_level}'
                Log    Successfully updated log_level in ${config_path}: '${current_log_level}' → '${new_log_level}'
                Log To Console    ✓ ${config_path}: '${current_log_level}' → '${new_log_level}'
            END
        ELSE
            Log    Warning: Config file ${config_path} does not exist. Skipping.
            Log To Console     Warning: Config file ${config_path} does not exist. Skipping.
        END
    END

Detect Upgrading Boot Image
    [Documentation]    Queries the next boot image using imgsel.sh -q, extracts the image letter (A or B) from the last line, and sets it as a global variable.
    [Tags]    internal
    
    Log To Console    \nSetting Next Boot Image:
    
    # Query the next boot image
    ${query_output}=    Execute Command    imgsel.sh -q    sudo=True    sudo_password=${PASSWORD}
    Log    imgsel.sh -q output:\n${query_output}
    
    Log To Console    ${query_output}
    
    # Parse output: last line format is "<current_image> <next_boot>", e.g., "B A"
    ${lines}=    Split String    ${query_output}    \n
    ${last_line}=    Set Variable    ${lines}[-1]
    ${last_line_stripped}=    Strip String    ${last_line}
    
    # Split last line by whitespace and get second element (next boot image)
    ${parts}=    Split String    ${last_line_stripped}
    ${next_image}=    Set Variable    ${parts}[1]
    
    Log To Console    Detected next boot image: ${next_image}
    Set Global Variable    ${NEXT_BOOT_IMAGE}    ${next_image}
    
    RETURN    ${next_image}

Commit Boot Image
    [Documentation]    Commits the specified boot image as the default using imgsel.sh -c.
    [Tags]    internal
    [Arguments]    ${image}
    
    Log To Console    \nCommitting Boot Image ${image}:
    
    # Commit the specified image as default boot image
    ${commit_output}=    Execute Command    imgsel.sh -c ${image}    sudo=True    sudo_password=${PASSWORD}    return_stdout=True    return_stderr=True    return_rc=True
    
    Log    Commit command output:\n${commit_output}[0]
    Log    Commit command stderr:\n${commit_output}[1]
    Log    Commit command return code: ${commit_output}[2]
    
    Should Be Equal As Integers    ${commit_output}[2]    0    msg=Failed to commit boot image ${image}. Return code: ${commit_output}[2], Error: ${commit_output}[1]
    
    Log To Console    Successfully committed image ${image} as default boot image
    
    RETURN    ${commit_output}[0]

Pull Logs From Remote
    [Documentation]    Automated keyword for extracting logs from the remote host to a local logs directory.
    [Arguments]        ${host}    ${username}    ${password}
    ${timestamp}=      Get Current Date    result_format=%d-%m-%Y_%H-%M-%S
    ${local_dir}=      Set Variable    logs/${timestamp}
    Create Directory   ${local_dir}
    Open Connection    ${host}
    Login    ${username}    ${password}

    ${ls_result}=    Execute Command    find /var/log/ -maxdepth 1 -type f    sudo=True    sudo_password=${password}
    ${log_files}=    Split String    ${ls_result}    \n

    Execute Command    mkdir -p /home/petalinux/tmp    sudo=True    sudo_password=${password}
    
    FOR    ${file}    IN    @{log_files}
        Continue For Loop If    '${file}' == ''
        ${tmp_path}=    Set Variable    /home/petalinux/tmp/${file.split('/')[-1]}
        # Copy file to /home/petalinux/tmp with sudo
        Execute Command    cp ${file} ${tmp_path}    sudo=True    sudo_password=${password}
        Execute Command    chmod 644 ${tmp_path}    sudo=True    sudo_password=${password}
        ${basename}=    Evaluate    os.path.basename("${file}")    modules=os
        SSHLibrary.Get File    ${tmp_path}    ${local_dir}/${basename}
        # Clean up temp file
        Execute Command    rm -f ${tmp_path}    sudo=True    sudo_password=${password}
    END
    ${journal}=    Execute Command    journalctl -r    sudo=True    sudo_password=${password}
    Create File    ${local_dir}/journalctl.txt    ${journal}
    Close Connection
    RETURN    ${local_dir}



Refresh Archiver Database
    [Documentation]    Stops the archiver service, copies the backup database to the therapy folder,
    ...    sets correct permissions, and restarts the archiver service.
    ...  - *Date of Implementation:* 16-APR-2026
    ...  - *Author:* Mina Bikhit
    [Tags]    internal

    # Step 1: Stop the archiver service
    Log    \nStep 1: Stopping archiver service...
    Execute Systemctl For Given Services    stop    archiver.service

    # Step 2: Remove old therapy database
    Log    Step 2: Removing old therapy database...
    Execute Command    rm -f /var/lib/archiver/therapy/therapy.db*    sudo=True    sudo_password=${PASSWORD}

    # Step 3: Copy backup database to therapy folder and set permissions
    Log    Step 3: Copying backup database to therapy folder...
    Execute Command    mkdir -p /var/lib/archiver/therapy    sudo=True    sudo_password=${PASSWORD}
    Execute Command    cp /var/lib/archiver/backup/therapy.db /var/lib/archiver/therapy/therapy.db    sudo=True    sudo_password=${PASSWORD}
    Execute Command    chmod 0644 /var/lib/archiver/therapy/therapy.db    sudo=True    sudo_password=${PASSWORD}
    SSHLibrary.File Should Exist    /var/lib/archiver/therapy/therapy.db

    # Step 4: Restart the archiver service
    Log    Step 4: Restarting archiver service...
    Execute Systemctl For Given Services    start    archiver.service

    # Step 5: Verify archiver is running
    ${status_output}=    Execute Systemctl For Given Services    status    archiver.service
    Should Contain    ${status_output}    Active: active    msg=Archiver service failed to start after database refresh
    Log    Archiver service is running with refreshed database.




Pull Therapy DB From Board
    [Documentation]    Pull therapy.db from the board to the local machine for inspection.
    ...    Copies the file via sudo to a temp location accessible by the SSH user,
    ...    then downloads it locally with a timestamp suffix.
    ...  - *Date of Implementation:* 08-MAY-2026
    ...  - *Author:* Mina Bikhit
    ...  - *Usage:*
    ...  -    ``local_dest`` – Local destination directory (default: ${CURDIR}${/}artifacts)
    ...  -    ``remote_path`` – Path to therapy.db on the board (default: /var/lib/archiver/therapy/therapy.db)
    ...  - *Returns:* Local file path of the downloaded therapy.db
    [Tags]    internal
    [Arguments]    ${local_dest}=${EXECDIR}${/}artifacts    ${remote_path}=/var/lib/archiver/therapy/therapy.db

    # Verify file exists on board
    SSHLibrary.File Should Exist    ${remote_path}

    # Copy to temp location accessible without sudo
    ${tmp_path}=    Set Variable    /home/petalinux/tmp/therapy.db
    Execute Command    mkdir -p /home/petalinux/tmp    sudo=True    sudo_password=${PASSWORD}
    Execute Command    cp ${remote_path} ${tmp_path}    sudo=True    sudo_password=${PASSWORD}
    Execute Command    chmod 644 ${tmp_path}    sudo=True    sudo_password=${PASSWORD}

    # Download to local machine
    Create Directory    ${local_dest}
    ${timestamp}=    Get Current Date    result_format=%Y%m%d_%H%M%S
    ${local_file}=    Set Variable    ${local_dest}${/}therapy_${timestamp}.db
    SSHLibrary.Get File    ${tmp_path}    ${local_file}

    # Clean up temp file
    Execute Command    rm -f ${tmp_path}    sudo=True    sudo_password=${PASSWORD}

    Log    Downloaded therapy.db to: ${local_file}
    RETURN    ${local_file}


