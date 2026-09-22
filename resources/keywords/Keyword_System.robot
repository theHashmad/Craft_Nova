*** Settings ***
Library     SSHLibrary
Library     String
Library     OperatingSystem
Library     DateTime
Resource    ../Configuration/CICD/CICD_Configuration.resource
Resource    ../Keywords/Keyword_Common.robot
Resource    ../Keywords/Keyword_Deploy.robot


*** Keywords ***
Open Connection And Log In
    [Documentation]    Connecting and login for the Test Setup. Returns ID of opened connection.
    ...    Delegates to Check Board Online (which performs the full SSH connect + root elevation).
    ...    Retries up to ${retries} times with ${retry_delay} between attempts via Wait Until Keyword Succeeds.
    [Tags]    internal
    [Arguments]    ${alias}=${None}    ${retries}=3    ${retry_delay}=5s    ${login_delay}=10s
    ${id}=    Wait Until Keyword Succeeds    ${retries}x    ${retry_delay}
    ...    Check Board Online    alias=${alias}    login_delay=${login_delay}
    RETURN    ${id}

Execute Systemctl For Given Services
    [Documentation]    Execute systemctl for given services to start / stop / enable / disable / get status and return output
    [Tags]    internal
    [Arguments]    ${command}    ${services}
    ${output}=    Execute Command    systemctl ${command} ${services}    sudo=True    sudo_password=${PASSWORD}
    RETURN    ${output}

Write command and read output
    [Arguments]    @{arguments}    ${read_delay}=1.5
    ${arguments_arg}=    Catenate    @{arguments}
    Write    ${arguments_arg}
    ${output}=    Read   delay=${read_delay}
    RETURN    ${output}

Verify service is running
    [Tags]    40098=1    40097=1    39884=1    56731=1    96729=1
    [Arguments]    ${tmpServiceName}
    ${output}=    Execute Systemctl For Given Services    status    ${tmpServiceName}
    Should Contain    ${output}    Active: active (running)    msg=Setup verification failed: ${tmpServiceName} is not active.
    [Teardown]    Document Keyword Outcome    Confirmed ${tmpServiceName} was running successfully.

Verify service is not running
    [Arguments]    ${tmpServiceName}
    ${output}=    Execute Systemctl For Given Services    status    ${tmpServiceName}
    Should Contain     ${output}          Active: inactive (dead)    msg=Setup verification failed: ${tmpServiceName} is not inactive.

Verify service is running with configuration
    [Documentation]    To verify service is running and was started with config parameter
    [Tags]    internal
    [Arguments]    ${service}    ${binaryPath}    ${configPath}
    ${serviceStatus}=    Execute Systemctl For Given Services    status    ${service}
    Should Contain    ${serviceStatus}    active (running)
    Should Contain    ${serviceStatus}    ${binaryPath}
    Should Contain    ${serviceStatus}    --config=${configPath}

Execute Command and Validate Output
    [Tags]    40103=1    40101=1    40100=1,2,3,4,5    40099=1
    [Arguments]    ${tmpCommand}    ${expectedString}

    ${output}=    Execute Command    ${tmpCommand}
    Should Contain    ${output}    ${expectedString}
    [Teardown]    Document Keyword Outcome    Confirmed ${tmpCommand} was executed successfully.

Verify Aurora OS Release version
    [Tags]    56726=1
    ${output}=    Execute Command    system_info.sh
    ${result}=    Run Keyword And Ignore Error    Should Contain    ${output}    ${LATEST_AURORA_OS_VERSION}
    Run Keyword If    '${result[0]}' == 'FAIL'    Log To Console    \n \n[WARNING]\nInstalled version of Aurora OS is not the latest one.\n
    [Teardown]    Document Keyword Outcome    Confirmed system_info.sh was executed successfully.

Verify Aurora OS Distro
    [Tags]    56727=1
    ${output}=    Execute Command    system_info.sh
    ${aurora_os_line}=    Get Lines Containing String    ${output}    AURORA_OS_RELEASE
    ${aurora_os_read}=    Get Substring    ${aurora_os_line}    25    -1
    Log To Console And Report    ${aurora_os_read}
    Should Be True    ${aurora_os_read} >= 2790848

Confirm build config
    [Documentation]    To confirm config provided with the build has correct content
    [Tags]    internal
    [Arguments]    ${configPath}    ${correctConfig}
    ${buildConfig}=    Execute Command    cat ${configPath}
    Should Be Equal    ${buildConfig}    ${correctConfig}

Check build config contains strings
    [Documentation]    To confirm config provided with the build has correct content string in it
    ...                - *Author:* Oliwia Maloch
    ...                - *Arguments:* ``configPath``, list of phrases to be checked ``correctConfigPhrases``
    ...                - *Returns* N/A
    [Tags]    internal
    [Arguments]    ${configPath}    @{correctConfigPhrases}
    ${buildConfig}=    Execute Command    cat ${configPath}
    FOR    ${phrase}    IN    @{correctConfigPhrases}
        Should Contain    ${buildConfig}    ${phrase}
    END

confirm audio device is null
    [Documentation]    to confirm correct audio device is set in audio config for KV/KR boards
    ...                - *Author:* Oliwia Maloch
    ...                - *Date of Implementation:* 27-Apr-2026
    ...                - *Returns* N/A
    [Tags]    internal
    Check Build Config Contains Strings    /etc/aurora/audio_service/config.toml    device = 'null'

Get length of log
    [Documentation]    Reading log and returning number of lines
    [Tags]    internal
    [Arguments]    ${logFileLocation}    ${logFile}
    ${files}=    SSHLibrary.List Files In Directory    ${logFileLocation}
    IF    '${logFile}' in ${files}
        ${log}=    Execute Command    cat ${logFileLocation}${logFile}
        ${logLenBefore}=    Get Line Count    ${log}
    ELSE
        ${logLenBefore}=    Set Variable    0
    END
    RETURN    ${logLenBefore}

Verify Log after startup
    [Documentation]    To verify if correct new entries have been added to log of service. For archiver only checking
    ...    first 2 because the rest are received from therapy
    [Tags]    internal
    [Arguments]    ${logFileLocation}    ${logFile}    ${correctLogEntries}
    SSHLibrary.File Should Exist    ${logFileLocation}${logFile}
    IF    $logFile == 'archiver_internal.txt'
        # verify correct entries are present
        ${log}=    Execute Command    cat ${logFileLocation}${logFile}
        @{linesToVerify}=    Split To Lines    ${log}    end=2
        Verify lines    ${linesToVerify}    ${correctLogEntries}
    ELSE
        # verify number of entries
        ${logLen}=    Get length of log    ${logFileLocation}    ${logFile}
        ${correctLen}=    Get Length    ${correctLogEntries}
        Should Be Equal
        ...    ${logLen}
        ...    ${correctLen}
        ...    msg=number of new entries (${logLen}) different then expected ${correctLen}
        # verify correct entries are present
        ${log}=    Execute Command    cat ${logFileLocation}${logFile}
        @{linesToVerify}=    Split To Lines    ${log}
        Verify lines    ${linesToVerify}    ${correctLogEntries}
    END

Verify log change
    [Documentation]    To verify log change - whether new and correct entries have been added
    [Tags]    internal
    [Arguments]    ${logFilePath}    ${logLenBefore}    ${correctLogEntries}
    # Get how many new log entries
    ${logAfter}=    Execute Command    cat ${logFilePath}
    ${logLenAfter}=    Get Line Count    ${logAfter}
    # Verify new entries
    ${linesAdded}=    Evaluate    ${logLenAfter} - ${logLenBefore}
    ${entriesLength}=    Get Length    ${correctLogEntries}
    Should Be Equal
    ...    ${linesAdded}
    ...    ${entriesLength}
    ...    msg=number of new entries (${linesAdded}) different then expected ${entriesLength}
    @{allLines}=    Split To Lines    ${logAfter}
    @{linesToVerify}=    Set Variable    @{allLines}[-${linesAdded}:]
    Verify lines    ${linesToVerify}    ${correctLogEntries}

Verify lines
    [Documentation]    To verify that multiline lines have expected entries
    [Tags]    internal
    [Arguments]    ${linesToVerify}    ${correctEntries}
    ${entriesLength}=    Get Length    ${correctEntries}
    # verify number of lines
    ${linesLength}=    Get Length    ${correctEntries}
    Should Be Equal    ${linesLength}    ${entriesLength}
    # verify content
    FOR    ${index}    IN RANGE    ${entriesLength}
        Should Contain    ${linesToVerify}[${index}]    ${correctEntries}[${index}]
    END

Run service with config
    [Documentation]    Run given service with config and returns output
    [Tags]    internal
    [Arguments]    ${binaryName}    ${configName}    ${optionalRunLocation}=    ${optionalConfigLocation}=
    IF    $optionalRunLocation != ${None}    Write    cd ${optionalRunLocation}
    ${not_used}=    Read    delay=1.5
    Write    ${binaryName} --config=${optionalConfigLocation}${configName}
    ${output}=    Read    delay=1.5
    RETURN    ${output}

Run service without config
    [Documentation]    Run given service without config and returns output
    [Tags]    internal
    [Arguments]    ${binaryName}
    ${output}=    Execute Command    ${binaryName}
    RETURN    ${output}

Reconnect
    [Documentation]    Just close ssh connection and open again
    [Tags]    internal
    Close All Connections
    Open Connection And Log In


Set System Time To UTC
    [Documentation]    Disable NTP, get current UTC time, and set it on host using timedatectl
    [Tags]    internal
    ${disable_ntp}=    Execute Command    timedatectl set-ntp false    sudo=True    sudo_password=${PASSWORD}
    ${current_time}=    Get Current Date    time_zone=UTC    result_format=%Y-%m-%d %H:%M:%S
    ${output}=    Execute Command    timedatectl set-time "${current_time}"    sudo=True    sudo_password=${PASSWORD}
    RETURN    ${output}


Create defect for deployment or health check failure
    [Documentation]   Create defect in Codebeamer for deployment or health check failure
    [Tags]    deployment defect
    IF  '${SUITE STATUS}' == 'FAIL' and '${cbEnabled}'.lower() == 'true'
        ${deployOrHealth}=    Set Variable If
        ...    'TS AuroraOS Initial Health Check' in '${SUITE NAME}'    Health check failed after deployment
        ...    'Aurora Apps Dwnld Deploy' in '${SUITE NAME}'    Deployment failed
        ${tmpBugDetected}=    Create Dictionary
        ...    fieldId=10000
        ...    name=Found In Build
        ...    value=${BUILD_ID}
        ...    type=TextFieldValue
        ${bugDetectedList}=    Create List    ${tmpBugDetected}
        ${tmpBugPriority}=    Create Dictionary
        ...    id=2
        ...    name=High
        ...    type=ChoiceOptionReference
        ${tmpBugSeverity}=    Create Dictionary
        ...    id=2
        ...    name=Critical
        ...    type=ChoiceOptionReference
        ${tempBugSeverityList}=    Create List    ${tmpBugSeverity}
        ${tmpBugDetails}=    Create Dictionary
        ...    name=[Automation-Bug]: Deployment Failure Detected!
        ...    description=${deployOrHealth} for Pipeline: ${PipelineID}; Build: ${BUILD_ID}. Please investigate the issue.
        ...    customFields=${bugDetectedList}
        ...    priority=${tmpBugPriority}
        ...    severities=${tempBugSeverityList}
        Create CB Session
        ${bugCreation}=    POST On Session
        ...    url=https://crdn.codebeamer.com/rest/v3/trackers/330137/items
        ...    alias=cb
        ...    json=${tmpBugDetails}
        ...    expected_status=200
        ...    msg=Try bug creation
        ${bugID}=    Get Value From Json    ${bugCreation.json()}    $..id
        Log    \n\nBug Created: ${bugID}[0]    console=Yes
    END


Verify expected text is present in given service config
    [Documentation]    Keyword to check that given service config contains expected text
    ...                - *Date of Implementation:* 20-02-2026
    ...                - *Author:* Pawel Dudek
    ...                - *Usage:* Provide expected text and service name as arguments
    ...                - *Returns:* N/A
    [Tags]    98833=1
    [Arguments]    ${expected_text}    ${given_service}

    ${output}=    Execute Command    cat /etc/aurora/${given_service}/config.toml
    Should Contain    ${output}    ${expected_text}    msg=Expected text: "${expected_text}" not found in config of ${given_service}.

    [Teardown]    Document Keyword Outcome    Verified that config of ${given_service} contains ${expected_text}


Backup original config of service
    [Documentation]    Keyword moving original config of given service to be able to restore it after test execution.
    ...                - *Date of Implementation:* 20-02-2026
    ...                - *Author:* Pawel Dudek
    ...                - *Usage:* provide service name
    ...                - *Returns:* N/A
    [Tags]    internal
    [Arguments]    ${given_service}

    Execute Command    mkdir /home/petalinux/original_${given_service}_config/
    Execute Command    mv /etc/aurora/${given_service}/config.toml /home/petalinux/original_${given_service}_config/    sudo=True    sudo_password=${PASSWORD}


Restore original config of service
    [Documentation]    Keyword restoring config of given service from backup and clearing after it.
    ...                - *Date of Implementation:* 18-02-2026
    ...                - *Author:* Pawel Dudek
    ...                - *Usage:* provide service name
    ...                - *Returns:* N/A
    [Tags]    internal
    [Arguments]    ${given_service}

    Execute Command    rm /etc/aurora/${given_service}/config.toml    sudo=True    sudo_password=${PASSWORD}
    Execute Command    mv /home/petalinux/original_${given_service}_config/config.toml /etc/aurora/${given_service}/    sudo=True    sudo_password=${PASSWORD}
    Execute Command    rmdir /home/petalinux/original_${given_service}_config/
    Directory Should Not Exist    /home/petalinux/original_${given_service}_config/


Copy config of given service without selected line
    [Documentation]    Creates a copy of service's config and save it in /home/petalinux for future use.
    ...                - *Date of Implementation:* 27-02-2026
    ...                - *Author:* Pawel Dudek
    ...                - *Usage:* Provide service name and the exact line to remove (including newline if needed)
    ...                - *Returns:* N/A
    [Tags]    internal
    [Arguments]    ${service}    ${line_to_remove}
    ${config_txt}=    Execute Command    cat /etc/aurora/${service}/config.toml
    ${filtered}=    Remove String    ${config_txt}    ${line_to_remove}
    Execute Command    echo "${filtered}" > modified_config.toml


Replace original config with modified version
    [Documentation]   Replaces original config of service with modified version saved in /home/petalinux. This is needed for testing how service is working without specific line in config.
    [Tags]    internal
    [Arguments]    ${service}
    Backup original config of service    ${service}
    Execute Command    mv modified_config.toml /etc/aurora/${service}/config.toml    sudo=True    sudo_password=${PASSWORD}


Remove storage path from archiver config
    [Documentation]    Creates modified version of archiver's config needed for test and replaces original config with it.
    ...                Also creates a backup of original config for future restoration after test execution.
    ...                - *Date of Implementation:* 27-02-2026
    ...                - *Author:* Pawel Dudek
    ...                - *Usage:* No input, just execution of other keywords
    ...                - *Returns:* N/A
    [Tags]     98833=2
    Copy config of given service without selected line    archiver    storage.path = '/var/lib/archiver/therapy/'\n
    Replace original config with modified version    archiver

    [Teardown]    Document Keyword Outcome    Successfully substituted original config of archiver with modified version without storage path


Restart services
    [Documentation]    Restart services.
    [Tags]     98833=3
    [Arguments]    ${services_string}

    Execute Systemctl For Given Services    restart    ${services_string}

    # Convert the services string into a list for iteration in status checks
    ${services_list}=    Evaluate    """${services_string}""".split(" ")

    # Iterate through each service to verify it is active and enabled
    FOR    ${service}    IN    @{services_list}
        ${status_output}=    Execute Systemctl For Given Services    status    ${service}
        Should Contain    ${status_output}    Active: active    msg=Service ${service} is not active after restart.
        Should Contain    ${status_output}    enabled;    msg=Service ${service} is not enabled after restart.
    END

    [Teardown]    Document Keyword Outcome    Services from input list (${services_string}) were restarted successfully and their status is active and enabled.


Verify new data are being added to file
    [Documentation]    Check new lines are added to given file, e.g. hdd.csv.
    ...                - *Date of Implementation:* 20-02-2026
    ...                - *Author:* Pawel Dudek
    ...                - *Usage:* Provide a path to file
    ...                - *Returns:* N/A
    [Tags]     98833=4    60463=2
    [Arguments]    ${file}

    ${line_count_1st}=    Execute Command    wc -l ${file}
    ${line_count_2nd}=    Execute Command    wc -l ${file}
    ${count_1st}=    Convert To Integer    ${line_count_1st.split()[0]}
    ${count_2nd}=    Convert To Integer    ${line_count_2nd.split()[0]}
    Should Be True    ${count_2nd} > ${count_1st}    msg=No new data added to ${file}. Line count did not increase.

    [Teardown]    Document Keyword Outcome    New data are being added to ${file}

Check header of hdd file
    [Documentation]    Check first line of hdd.csv file is a header and contains all required data in correct order.
    ...                - *Date of Implementation:* 24-02-2026
    ...                - *Author:* Pawel Dudek
    ...                - *Usage:* No inout, just run
    ...                - *Returns:* N/A
    [Tags]     60463=1

    ${output}=    Execute Command    head -1 /var/lib/archiver/therapy/hdd.csv
    Remove File    ${CURDIR}/hdd_temp.csv
    Create File    ${CURDIR}/hdd_temp.csv    ${output}
    ${actual_header}=    Read Csv As List    ${CURDIR}/hdd_temp.csv    ,
    ${expected_header}=    Read Csv As List    ${CURDIR}/../Test_Data/Resources/hdd_expected_header.csv    ,
    Should Be Equal    ${actual_header}    ${expected_header}    msg=Header of hdd.csv file is different than expected.

    [Teardown]    Document Keyword Outcome    It has been confirmed that the header of the hdd.csv file is correct.

Read current value from hdd csv
    [Documentation]    Reads last line of hdd.csv file and return value in given column.
    ...                from column with given index.
    ...                - *Date of Implementation:* 24-02-2026
    ...                - *Author:* Pawel Dudek
    ...                - *Usage:* Provide name of column to read value from.
    ...                - *Returns:* Latest value from given column in hdd.csv file.
    [Tags]     60463=3
    [Arguments]    ${column_to_read}

    Remove File       ${CURDIR}/hdd_temp.csv
    ${output}=        Execute Command    head -1 /var/lib/archiver/therapy/hdd.csv
    Create File       ${CURDIR}/hdd_temp.csv    ${output}\n
    ${output}=        Execute Command    tail -1 /var/lib/archiver/therapy/hdd.csv
    Append To File    ${CURDIR}/hdd_temp.csv    ${output}

    ${hdd_header}=    Read Csv As List    ${CURDIR}/hdd_temp.csv    ,
    ${column_index}=     Get Index From List    ${hdd_header}[0]    ${column_to_read}
    ${value_to_return}=    Get From List    ${hdd_header}[1]    ${column_index}

    RETURN    ${value_to_return}


Verify value in hdd csv changed after sending grpc request
    [Documentation]    Check that values changed after sending gRPC request, comparing them before and after sending the request.
    ...                - *Date of Implementation:* 24-02-2026
    ...                - *Author:* Pawel Dudek
    ...                - *Usage:* Provide value from before and data allowing to read current value in hdd.csv file.
    ...                - *Returns:* N/A
    [Tags]     60463=5
    [Arguments]    ${current_value_before}    ${column_to_read}    ${expected_value}

    ${current_value_after}    Read current value from hdd csv    ${column_to_read}
    Should Not Be Equal    ${current_value_before}    ${current_value_after}    msg=Value in hdd.csv file did not change after sending gRPC request.
    Should Be Equal As Numbers    ${current_value_after}    ${expected_value}        msg=Value in hdd.csv file changed after sending gRPC request, but is different then expected.

    [Teardown]    Document Keyword Outcome    Verify that ${column_to_read} changed after sending GRPC request.

Remove hdd temp csv
    [Documentation]    Remove hdd_temp.csv, to be run from teardown of tests using hdd_temp.csv for storing temporary data from hdd.csv file.
    ...                - *Date of Implementation:* 02-03-2026
    ...                - *Author:* Pawel Dudek
    ...                - *Usage:* No input, just run
    ...                - *Returns:* N/A
    [Tags]     internal

    Remove File       ${CURDIR}/hdd_temp.csv