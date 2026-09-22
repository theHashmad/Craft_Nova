*** Settings ***
Library         Collections
Variables       ../Common_Lib/G4_API/Core/rem_api_pb2.py
Variables       ../Common_Lib/G4_API/Core/rem_api_pb2_grpc.py
Variables       ../Common_Lib/G4_API/Core/grpc_simulation_pb2.py
Variables       ../Common_Lib/G4_API/Core/grpc_simulation_pb2_grpc.py
Variables       ../Common_Lib/G4_API/Core/generator_subscription_pb2.py
Variables       ../Common_Lib/G4_API/Core/generator_subscription_pb2_grpc.py
Variables       ../Common_Lib/G4_API/Core/data_recorder_pb2.py
Variables       ../Common_Lib/G4_API/Core/data_recorder_pb2_grpc.py
Variables       ../Common_Lib/G4_API/Core/diagnostic_pb2.py
Variables       ../Common_Lib/G4_API/Core/diagnostic_pb2_grpc.py
Variables       ../Common_Lib/G4_API/Core/ablation_info_pb2.py
Variables       ../Common_Lib/G4_API/Core/ablation_info_pb2_grpc.py
Variables       ../Common_Lib/G4_API/Core/audio_pb2.py
Variables       ../Common_Lib/G4_API/Core/audio_pb2_grpc.py
Variables       ../Common_Lib/G4_API/Core/messages/common_pb2.py
Variables       ../Common_Lib/G4_API/Core/messages/common_pb2_grpc.py
Library         ../Common_Lib/G4_API/Wrappers/AblationInfo.py
Library         ../Common_Lib/G4_API/Wrappers/Audio.py
Library         ../Common_Lib/G4_API/Wrappers/DataRecorder.py
Library         ../Common_Lib/G4_API/Wrappers/Diagnostic.py
Library         ../Common_Lib/G4_API/Wrappers/REM.py
Library         ../Common_Lib/G4_API/Wrappers/RF.py
Library         ../Common_Lib/G4_API/Wrappers/Temperature.py
Library         ../Common_Lib/G4_API/Wrappers/Utility.py

Resource        ../Configuration/CICD/CICD_Configuration.resource
Library         ../Product_Configuration/States/Supported_States.py
Resource        Keyword_States_API.robot
Resource        Keyword_Display_Functional.robot
Library        ../Tools/Topic_Listener.py    ${GRPC_SERVER}
Library         ../Tools/HDD_PlayBack/HDDListener.py    server_address=${GRPC_SERVER}
Library        DateTime



*** Variables ***
${DATA_FILE_PATH}           Test_Data
${EVAL_FLOATING_POINTS}     3
${kSuccess}                 3
@{topics}                   kCatheter    kPatientCircuit    kRfChannelData    kDisplay    kRfControl    kRem


*** Keywords ***
Start Topic Listeners
    [Tags]    internal
    Start Topic Listener    @{topics}

Send GRPC Request
    [Tags]    internal
    [Arguments]    ${method}    ${server}    @{args}
    
    # Add retry logic for connection reset errors
    FOR    ${retry}    IN RANGE    5
        ${status}    ${response}=    Run Keyword And Ignore Error    ${method}    ${server}    @{args}
        
        # If successful, return immediately
        Return From Keyword If    '${status}' == 'PASS'    ${response}
        
        # Check if it's a connection reset error
        ${is_unavailable_error}=    Run Keyword And Return Status    
        ...    Should Contain    ${response}    StatusCode.UNAVAILABLE
        ${is_not_connected}=    Run Keyword And Return Status    
        ...    Should Contain    ${response}    ConnectionError
        ${is_connection_error}=    Evaluate    ${is_unavailable_error} or ${is_not_connected}
        ${is_reset_error}=    Run Keyword And Return Status    
        ...    Should Contain    ${response}    10054
        
        # If it's a connection reset, wait and retry
        Run Keyword If    ${is_connection_error} or ${is_reset_error}
        ...    Run Keywords
        ...    Log    Connection error detected, evicting stale channel and retrying in 5 seconds... (attempt ${retry + 1}/5)    WARN
        ...    AND    Evaluate    sys.modules.get('Common_Lib.G4_API.Wrappers.grpc_channel_manager').GrpcChannelManager.close_channel('${server}')    sys
        ...    AND    Sleep    5s
        ...    ELSE    Fail    ${response}    # Re-raise non-connection errors immediately
        
        # If this is the last retry, fail with the error
        Run Keyword If    ${retry} == 4    Fail    gRPC connection failed after 5 retries: ${response}
    END

    RETURN    ${response}

Listen To HDD Notices
    [Tags]    internal
    [Arguments]    ${server}
    ${resp_stream}=    Run Keyword    Listen To HDD    ${server}

    RETURN    ${resp_stream}

Get Epoch Timestamp
    [Tags]    internal
    [Arguments]    ${notice}
    [Documentation]    This keyword extracts the timestamp from the HDD notice and
    ...    converts it to epoch format for easier time calculations.
    ...  - *Date of Implementation:* 12-FEB-2026
    ...  - *Author:* Alireza Akhavian
    ...  - *Returns:* Epoch Timestamp
    ${t-timestamp_str}=    Get From Dictionary    ${notice}    timestamp
    ${timestamp_dt}=    Convert Date    ${t-timestamp_str}    datetime
    ${timestamp_epoch}=    Convert Date    ${timestamp_dt}    epoch
    RETURN    ${timestamp_epoch}

    [Teardown]    Document Keyword Outcome    Extracted epoch timestamp: ${timestamp_epoch} from notice timestamp: ${t-timestamp_str}

Get Host Epoch Timestamp
    [Tags]    internal
    [Documentation]    Retrieves the current UTC time from the target host via timedatectl
    ...    and converts it to epoch format matching the notice timestamp format.
    ...  - *Date of Implementation:* 10-MAR-2026
    ...  - *Author:* Alireza Akhavian
    ...  - *Returns:* Epoch Timestamp of host current UTC time
    ${timedatectl_output}=    Execute Command    timedatectl
    ${utc_line}=    Get Lines Containing String    ${timedatectl_output}    Universal time
    ${utc_str}=    Should Match Regexp    ${utc_line}    \\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}
    ${t-host}=    Convert Date    ${utc_str}    epoch
    RETURN    ${t-host}

Synchronized Sleep
    [Tags]    internal
    [Arguments]    ${t-ref}    ${sleep_time}
    [Documentation]    Sleeps the remaining time needed so that exactly ${sleep_time} seconds have passed
    ...    since the reference epoch timestamp ${t-ref} (from the target host).
    ...  - *Date of Implementation:* 10-MAR-2026
    ...  - *Author:* Alireza Akhavian
    ...  - *Returns:* None
    ${t-now}=    Get Host Epoch Timestamp
    ${remaining}=    Evaluate    max(0.0, ${t-ref} + ${sleep_time} - ${t-now})
    Sleep    ${remaining}

Verify Electrodes Set Power
    [Tags]    internal
    [Arguments]    ${data_notice}    ${expected_powers}
    [Documentation]    ...    This keyword verifies the SET power values for each electrode
    ...    in the RF Channel Data Notice against the expected powers.
    ...  - *Date of Implementation:* 12-FEB-2026
    ...  - *Author:* Alireza Akhavian
    ...  - *Returns:* None

    ${power_count}=    Get Length    ${expected_powers}
    Should Be Equal As Integers    4    ${power_count}    msg=Number of expected powers must match number of electrodes in the notice.
    ${act_powers}=    Get From Dictionary    ${data_notice}    powerSetpoints

    FOR    ${index}    IN RANGE    4
        ${expected_power}=    Get From List    ${expected_powers}    ${index}
        ${act_power}=    Get From List    ${act_powers}    ${index}
        Should Be Equal    ${act_power}    ${expected_power}    type=auto
    END

    [Teardown]    Document Keyword Outcome    Verified power values for electrodes: ${expected_powers}

Wait And Verify Set Power At Target Time
    [Tags]    102359=4,5,6,7,8,9    102456=4,7    102393=4,6,7,12,14,15
    [Arguments]    ${t-0}    ${target_seconds}      @{expected_powers}
    [Documentation]    Wait and verify set power at the target time on specified electrodes
    ...  - *Date of Implementation:* 12-FEB-2026
    ...  - *Author:* Alireza Akhavian
    ...  - *Returns:* None

    WHILE    True
        ${topic_res}=    Stream Notices For    kRfChannelData
        IF  ${topic_res} is not None
            ${current_notice}=    Get From Dictionary    ${topic_res}    rfChannelDataNotice
            ${t-current}=    Get Epoch Timestamp    ${current_notice}
            ${time_elapsed}=    Evaluate    math.floor(${t-current} - ${t-0})    modules=math
            IF    ${time_elapsed} == ${target_seconds}
                ${reminder}=    Evaluate    round(${t-current} - ${t-0} - ${target_seconds}, 4)
                Log    Power verification at t+${target_seconds}s (timestamp: ${t-current}, elapsed: ${time_elapsed}s)
                Verify Electrodes Set Power    ${current_notice}   ${expected_powers}
                BREAK
            ELSE IF     ${time_elapsed} >= ${target_seconds} + 1
                Log To Console    time elapsed: ${time_elapsed}s. target time: ${target_seconds}s. Power verification failed.
                Fail    Power verification at t+${target_seconds}s failed. Expected time reached but power not verified.
            END
        END
        Sleep    0.01s    # Sleep briefly to avoid busy waiting
    END

    [Teardown]    Document Keyword Outcome    Verified power set values at ${target_seconds}s after RF Event: ${expected_powers}

Evaluate HDD Fields
    [Tags]    internal
    [Arguments]    ${method}    ${properties}    ${electrode}    ${hdd_res}    ${exp_status}    ${exp_value}
    ${exp_value}=    Convert To Number    ${exp_value}    ${EVAL_FLOATING_POINTS}

    # Use Get From Dictionary to extract objects list
    # Extract top-level RF properties
    ${property_dict}=    Get From Dictionary    ${hdd_res}    ${properties}

    # Check electrode property ( value and status) for each electrode
    ${property}=    Get From List    ${property_dict}    ${electrode}
    ${property_value}=    Get From Dictionary    ${property}    value
    ${act_prop_status}=    Get From Dictionary    ${property}    status
    ${act_prop_value}=    Convert To Number    ${property_value}    ${EVAL_FLOATING_POINTS}

    Log    Verify ${method} values for electrode #${electrode} using HDD Fields
    Should Be Equal    ${exp_value}    ${act_prop_value}    type=auto

    Log    Verify ${method} status for electrode #${electrode} using HDD Fields
    Should Be Equal    ${act_prop_status}    ${act_prop_status}    type=auto

Evaluate RFDataNotice
    [Tags]    robot:continue-on-failure    internal
    [Arguments]
    ...    ${method}
    ...    ${electrode}
    ...    ${topic_res}
    ...    ${exp_status}
    ...    ${exp_power_accuracy}
    ...    ${exp_impedance}
    ...    ${SKIP_TEST}
    ${exp_power_accuracy}=    Convert To Number    ${exp_power_accuracy}    ${EVAL_FLOATING_POINTS}
    ${exp_impedance}=    Convert To Number    ${exp_impedance}    ${EVAL_FLOATING_POINTS}

    ${actual_result_all_channels}=    Get From Dictionary    ${topic_res}    rfChannelDataNotice

    # Check impedance for each electrode
    ${impedances}=    Get From Dictionary    ${actual_result_all_channels}    impedances
    ${impedance}=    Get From List    ${impedances}    ${electrode}
    ${impedance_value}=    Get From Dictionary    ${impedance}    value
    ${act_rf_status}=    Get From Dictionary    ${impedance}    status
    ${act_impedance}=    Convert To Number    ${impedance_value}    ${EVAL_FLOATING_POINTS}
    Log    Verify Impedance Value for electrode #${electrode}
    Should Be Equal    ${exp_impedance}    ${act_impedance}    type=auto

    Log    Verify Impedance Status Value for electrode #${electrode}
    Should Be Equal    ${exp_status}    ${act_rf_status}    type=auto

    # ${SKIP_TEST} used here as a variable not a RF Keyword
    IF    ${SKIP_TEST}    RETURN

    # Check power for each electrode
    ${powers}=    Get From Dictionary    ${actual_result_all_channels}    powers
    ${power}=    Get From List    ${powers}    ${electrode}
    ${power_value}=    Get From Dictionary    ${power}    value
    ${act_power}=    Convert To Number    ${power_value}    ${EVAL_FLOATING_POINTS}
    Log    Verify Power Value for electrode #${electrode}
    Should Be Equal    ${exp_power_accuracy}    ${act_power}    type=auto

    # Check sequential impedance for each electrode
    ${seqImpedances}=    Get From Dictionary    ${actual_result_all_channels}    seqImpedances
    ${seqImpedance}=    Get From List    ${seqImpedances}    ${electrode}
    ${seqImpedance_value}=    Get From Dictionary    ${seqImpedance}    value
    ${act_seqImpedance}=    Convert To Number    ${seqImpedance_value}    ${EVAL_FLOATING_POINTS}
    Log    Verify Sequential Impedance Value for electrode #${electrode}
    Should Be Equal    ${exp_impedance}    ${act_seqImpedance}    type=auto

Send RF Instant Set Request
    [Tags]    internal
    [Arguments]    ${electrodes}    ${newImpedance}    ${newPowerAccuracy}    ${newPowerDelay}
    ${grpc_response}=    Send GRPC Request
    ...    RF Instant Set
    ...    ${GRPC_SERVER}
    ...    ${electrodes}
    ...    ${newImpedance}
    ...    ${newPowerAccuracy}
    ...    ${newPowerDelay}
    ${grpc_success}=    Run Keyword And Return Status
    ...    Should Be Equal As Strings
    ...    ${grpc_response.status}
    ...    ${kSuccess}

    RETURN    ${grpc_success}

Send RF Gradual Set Request
    [Tags]    internal
    [Arguments]
    ...    ${electrodes}
    ...    ${newImpedance}
    ...    ${newPowerAccuracy}
    ...    ${newPowerDelay}
    ...    ${impedanceProfile}
    ...    ${PowerAccuracyProfile}
    ...    ${PowerDelayProfile}
    ${grpc_response}=    Send GRPC Request
    ...    RF Gradual Set
    ...    ${GRPC_SERVER}
    ...    ${electrodes}
    ...    ${newImpedance}
    ...    ${newPowerAccuracy}
    ...    ${newPowerDelay}
    ...    ${impedanceProfile}
    ...    ${PowerAccuracyProfile}
    ...    ${PowerDelayProfile}
    ${grpc_success}=    Run Keyword And Return Status
    ...    Should Be Equal As Strings
    ...    ${grpc_response.status}
    ...    ${kSuccess}

    RETURN    ${grpc_success}

Send REM Set Request
    [Tags]    internal
    [Arguments]    ${magnitude}    ${phase}    ${load}

    ${grpc_response}=    Send GRPC Request    REM.Set Rem    ${GRPC_SERVER}    ${magnitude}    ${phase}    ${load}
    ${grpc_success}=    Run Keyword And Return Status
    ...    Should Be Equal As Strings
    ...    ${grpc_response.status}
    ...    ${kSuccess}

    RETURN    ${grpc_success}

Send Temperature Set Request
    [Tags]    internal
    [Arguments]
    ...    ${StatusChan_0}
    ...    ${TempChan_0}
    ...    ${StatusChan_1}
    ...    ${TempChan_1}
    ...    ${StatusChan_2}
    ...    ${TempChan_2}
    ...    ${StatusChan_3}
    ...    ${TempChan_3}

    ${grpc_response}=    Send GRPC Request
    ...    Set Temperature
    ...    ${GRPC_SERVER}
    ...    ${StatusChan_0}
    ...    ${TempChan_0}
    ...    ${StatusChan_1}
    ...    ${TempChan_1}
    ...    ${StatusChan_2}
    ...    ${TempChan_2}
    ...    ${StatusChan_3}
    ...    ${TempChan_3}
    ${grpc_success}=    Run Keyword And Return Status
    ...    Should Be Equal As Strings
    ...    ${grpc_response.status}
    ...    ${kSuccess}

    RETURN    ${grpc_success}

Check if Therapy in expected state
    [Documentation]    Keyword to check if generator is in expected state
    ...                - *Date of Implementation:* 1-OCT-2025
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* Generator State Machine state: ``genState``
    [Tags]    69900=2,5,8,11,14    66647=2,4,6,8    66634=2,4    66582=3,6    66102=1,4    66649=2,5    66650=2,5    99584=5,9,12    99197=2
    [Arguments]    ${GRPC_SERVER}    ${exp_genState}
    ${hdd_res}=    Listen To HDD Notices    ${GRPC_SERVER}
    ${genState}=    Get From Dictionary    ${hdd_res}    generatorState
    Should Be Equal    ${exp_genState}    ${genState}    type=auto    msg=Generator state ${genState} does not match expected state ${exp_genState}.
    RETURN    ${genState}
    [Teardown]    Document Keyword Outcome    Verified that Generator is in ${exp_genState} state.

Check if REM in expected state
    [Documentation]    Keyword to check if REM is in expected state
    ...                - *Date of Implementation:* 12-FEB-2026
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* REM State Machine state: ``REMstate``
    [Tags]    98718=1,4
    [Arguments]    ${GRPC_SERVER}    ${exp_REMstate}
    ${hdd_res}=    Listen To HDD Notices    ${GRPC_SERVER}
    ${REMstate}=    Get From Dictionary    ${hdd_res}    remStatus
    Should Be Equal    ${exp_REMstate}    ${REMstate}    type=auto    msg=REM state ${REMstate} does not match expected state ${exp_REMstate}.
    RETURN    ${REMstate}
    [Teardown]    Document Keyword Outcome    Verified that Generator is in ${exp_REMstate} state.

Check if Catheter in expected state
    [Documentation]    Keyword to check if Catheter is in expected state
    ...                - *Date of Implementation:* 12-FEB-2026
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* Catheter State Machine state: ``CathState``
    [Tags]    98718=6,9
    [Arguments]    ${GRPC_SERVER}    ${exp_CathState}
    ${hdd_res}=    Listen To HDD Notices    ${GRPC_SERVER}
    ${CathState}=    Get From Dictionary    ${hdd_res}    cathState
    Should Be Equal    ${exp_CathState}    ${CathState}    type=auto    msg=Catheter state ${CathState} does not match expected state ${exp_CathState}.
    RETURN    ${CathState}
    [Teardown]    Document Keyword Outcome    Verified that Catheter is in ${exp_CathState} state.

Check If Display In Expected State
    [Documentation]    Keyword to check if Display is in expected state
    ...                - *Date of Implementation:* 23-JAN-2026
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* Display State Machine state: ``act_displ_state``
    [Tags]    69900=3,6,9,12,15    66102=2,5
    [Arguments]    ${exp_state}
    ${exp_displ_state}=    Get Displ State Value    ${exp_state}
    ${notice}=    Get Notice For    kDisplay
    VAR    ${act_displ_state}=    ${notice}[displayStatusNotice][state]
    Should Be Equal As Integers    ${exp_displ_state}    ${act_displ_state}    msg=wrong display state (expected ${exp_state} != actual ${act_displ_state})
    RETURN    ${act_displ_state}
    [Teardown]    Document Keyword Outcome    Verified that Display is in ${exp_state} state.

Check if RF in expected state
    [Documentation]    Keyword to check if RF State Machine is in expected state
    ...                - *Date of Implementation:* 16-Apr-2026
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* RF State Machine state: ``RfState``
    [Tags]    99584=4,8,11
    [Arguments]    ${GRPC_SERVER}    ${exp_RfState}
    ${hdd_res}=    Listen To HDD Notices    ${GRPC_SERVER}
    ${RfState}=    Get From Dictionary    ${hdd_res}    rfState
    Should Be Equal    ${exp_RfState}    ${RfState}    type=auto
    RETURN    ${RfState}
    [Teardown]    Document Keyword Outcome    Verified that RF is in ${exp_RfState} state.

Check if TOOR Status as expected
    [Documentation]    Keyword to check if TOOR have expected statuses for each electrode
    ...                - *Date of Implementation:* 8-Apr-2026
    ...                - *Author:* Oliwia Maloch
    ...                - *Usage* list ``exp_toors`` eg.: kNoToor    kNoToor    kNoToor    kNoToor
    ...                - *Returns* Generator State Machine TOOR statuses for all electrodes: ``act_toors``
    [Tags]    internal
    [Arguments]    ${GRPC_SERVER}    @{exp_toors}
    ${hdd_res}=    Listen To HDD Notices    ${GRPC_SERVER}
    ${act_toors}=    Get From Dictionary    ${hdd_res}    toorStatuses
    Should Be Equal    ${exp_toors}    ${act_toors}    type=auto
    RETURN    ${act_toors}
    [Teardown]    Document Keyword Outcome    Verified that TOOR statuses are as expected: ${act_toors}

Get electrode toggle status after toggling via RfControl topic
    [Documentation]    Keyword to check if if electrode was toggled via RfControlTopic
    ...                - *Date of Implementation:* 1-OCT-2025
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* electrode toggle state True/False: ``toggle_state``; RfControlTopic state: ``act_rfc_state``
    [Tags]    internal
    [Arguments]    ${electrode}
    Sleep    1
    VAR    &{electrodes}=    D1=0    2=1    3=2    P4=3
    VAR    ${toggle_index}=    ${electrodes}[${electrode}]
    VAR    ${exp_rfc_state}=    True
    ${toggle_state}=    Get Electrode Object Toggle Status After Toggling    ${electrode}
    ${notice}=    Get Notice For    kRfControl
    VAR    ${act_rfc_state}=    ${notice}[electrodeToggleNotice][electrodesToggled]
    VAR    ${act_rfc_state_index}=    ${act_rfc_state}[${toggle_index}]
    Should Be Equal    ${exp_rfc_state}    ${act_rfc_state_index}    type=auto
    RETURN    ${toggle_state}    ${act_rfc_state}

HDD Field Should Be Equal
    [Documentation]    Reads HDD data and verifies that the value
    ...    at requested property equals the expected value.
    [Tags]    internal
    [Arguments]    ${property}    ${expected_value}

    ${hdd_res}=    Listen To HDD Notices    ${GRPC_SERVER}
    Should Not Be Empty    ${hdd_res}    msg=No HDD data received.

    ${actual_value}=    Get From Dictionary    ${hdd_res}    ${property}
    Should Be Equal    ${actual_value}    ${expected_value}    type=auto
    ...    msg=HDD data had value '${actual_value}' at path ${property}, expected '${expected_value}'.

    RETURN    ${hdd_res}

Wait Until HDD Field Equals
    [Documentation]    Waits until a HDD data contains the expected value at the requested path.
    ...    Returns the matching HDD notice.
    ...    - *Date of Implementation:* 08-05-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Returns* HDD notice that contains expected value at the requested path: ``hdd_entry``
    [Tags]    59212=3,7,11,15    59337=4,10,16,22,28,34,40,46
    [Arguments]    ${property}    ${expected_value}    ${timeout}=15s    ${retry_interval}=50ms

    ${hdd_entry}=    Wait Until Keyword Succeeds
    ...    ${timeout}
    ...    ${retry_interval}
    ...    HDD Field Should Be Equal
    ...    ${property}
    ...    ${expected_value}

    RETURN    ${hdd_entry}
    [Teardown]    Run Keywords    Document Keyword Outcome    Verified that HDD field '${property}' equals expected value '${expected_value}' within ${timeout}.    AND    Add Screenshot

Start Ablation
    [Documentation]    Keyword to start ablation if therapy is in TherapyReady state
    ...                - *Date of Implementation:* 12-FEB-2026
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* N/A
    [Tags]    69900=10    102359=2    102456=2    102393=2,10    99584=7    99197=1    59212=2,6,10,14    59337=2,8,14,20,26,32,38,44
    Check If Therapy In expected State    ${GRPC_SERVER}    kGeneratorTherapyReady
    Send RF Button Request    ${GRPC_SERVER}
    [Teardown]    Document Keyword Outcome    Verified that ablation started.

Stop Ablation
    [Documentation]    Keyword to stop ablation if therapy is in TherapyAblate state
    ...                - *Date of Implementation:* 12-FEB-2026
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* N/A
    [Tags]    69900=13    102359=10    102393=8,16    102456=8
    Check If Therapy In expected State    ${GRPC_SERVER}    kGeneratorTherapyAblate
    Sleep    1s    # Add a sleep to make sure we are in ablation state before sending stop command, to avoid potential race condition.
    Send RF Button Request    ${GRPC_SERVER}
    [Teardown]    Document Keyword Outcome    Verified that ablation stopped.

Start RF Timer
    [Documentation]    Start RF Timer and return the start timestamp
    ...  - *Date of Implementation:* 12-FEB-2026
    ...  - *Author:* Alireza Akhavian
    ...  - *Returns:* ${t-0} Epoch Timestamp when RF started
    [Tags]    102359=3    102456=3    102393=3,11
    WHILE    True
        ${topic_res}=    Stream Notices For    kRfChannelData
        ${current_notice}=    Get From Dictionary    ${topic_res}    rfChannelDataNotice
        ${state}=    Get From Dictionary    ${current_notice}    state
        IF    '${state}' == 'kRfAblate'
             ${t-0}=    Get Epoch Timestamp    ${current_notice}
             RETURN    ${t-0}
        END
    END

    [Teardown]    Document Keyword Outcome    Verified Timer started at RF Start.

Set Temperatures And Get Notice Timestamp
    [Tags]    102456=5,6    102393=5,9,13    60463=4
    [Arguments]
    ...    ${TempChan_0}
    ...    ${TempChan_1}
    ...    ${TempChan_2}
    ...    ${TempChan_3}
    [Documentation]    Send temperature set request with specified values for each channel
    ...    and return the epoch timestamp of the first catheter notice that reflects the updated values.
    ...  - *Date of Implementation:* 12-FEB-2026
    ...  - *Author:* Alireza Akhavian
    ...  - *Returns:* ${t-1} Epoch Timestamp of the notice with updated temperatures

    Send Temperature Set Request
    ...    kSuccess    ${TempChan_0}
    ...    kSuccess    ${TempChan_1}
    ...    kSuccess    ${TempChan_2}
    ...    kSuccess    ${TempChan_3}

    # Build expected values list for loop comparison
    @{expected_temps}=    Create List    ${TempChan_0}    ${TempChan_1}    ${TempChan_2}    ${TempChan_3}

    WHILE    True
        ${topic_res}=    Stream Notices For    kCatheter
        IF    ${topic_res} is not None
            ${cath_notice}=    Get From Dictionary    ${topic_res}    catheterDataNotice
            ${raw_temps}=      Get From Dictionary    ${cath_notice}    rawTemperatures
            ${all_match}=    Evaluate    all(float(ch['value']) == float(exp) for ch, exp in zip($raw_temps, $expected_temps))
            IF    ${all_match}
                ${t-1}=    Get Epoch Timestamp    ${cath_notice}
                RETURN    ${t-1}
            END
        END
    END

    [Teardown]    Document Keyword Outcome    Verified Temperature Set Request sent with values: ${TempChan_0}, ${TempChan_1}, ${TempChan_2}, ${TempChan_3}.


Check PatientCircuitDataNotice fields for existence
    [Documentation]    Checks for the existence of expected fields in the PatientCircuitDataNotice and returns the
    ...    dictionary containing those fields for further validation if needed.
    ...  - *Date of Implementation:* 25-MAR-2026
    ...  - *Author:* Mateusz Rosiek
    ...  - *Usage:* Make sure that before calling this keyword, kPatientCircuit notices are being listened to.
    ...  - *Returns:* PatientCircuitDataNotice dictionary
    [Tags]    109040=3
    [Arguments]    @{expected_fields}
    ${pc_notice}=    Get Notice For    kPatientCircuit
    ${path}=    Create List    patientCircuitDataNotice
    ${target_dict}=    Verify Nested Dict Contains Keys    ${pc_notice}    ${path}    @{expected_fields}
    RETURN    ${target_dict}
    [Teardown]    Document Keyword Outcome    Verification Passed: PatientCircuitDataNotice contained the expected fields.

##################################################################################
########################## Audio Service Keywords ################################
##################################################################################

Send Audio Increase Volume Request
    [Documentation]    - *Arguments:* ``group``: kTherapy/kAlerts/kConnection, ``increase_value``: 0-100
    ...                - *Returns:* command was executed - ``grpc_success`` pass/fail
    [Tags]    internal
    [Arguments]    ${group}    ${increase_value}
    ${response}=    Send GRPC Request
    ...    Increase Volume
    ...    ${GRPC_SERVER}
    ...    ${increase_value}
    ...    ${group}
    ${grpc_success}=    Run Keyword And Return Status
    ...    Should Be Equal As Strings
    ...    ${response.status}
    ...    ${kSuccess}

    RETURN    ${grpc_success}

Send Audio Decrease Volume Request
    [Documentation]    - *Arguments:* ``group``: kTherapy/kAlerts/kConnection, ``decrease_value``: 0-100
    ...                - *Returns:* command was executed - ``grpc_success`` pass/fail
    [Tags]    internal
    [Arguments]    ${group}    ${decrease_value}
    ${response}=    Send GRPC Request
    ...    Decrease Volume
    ...    ${GRPC_SERVER}
    ...    ${decrease_value}
    ...    ${group}
    ${grpc_success}=    Run Keyword And Return Status
    ...    Should Be Equal As Strings
    ...    ${response.status}
    ...    ${kSuccess}

    RETURN    ${grpc_success}

Get Audio Current Volume Level
    [Documentation]    - *Arguments:* ``group``: kTherapy/kAlerts/kConnection
    ...                - *Returns:* current volume ``level``: 0-100
    [Tags]    internal
    [Arguments]    ${group}
    ${response}=    Send GRPC Request
    ...    Increase Volume
    ...    ${GRPC_SERVER}
    ...    0
    ...    ${group}
    ${level}=    Set Variable    ${response.updated_value}

    RETURN    ${level}

Check if current audio volume level for group like expected
    [Documentation]    Keyword for checking if current volume for given audio group is like expected.
    ...                - *Date of Implementation:* 17-Dec-2025
    ...                - *Author:* Oliwia Maloch
    ...                - *Arguments:* ``group``: kTherapy/kAlerts/kConnection, ``exp_vol_lvl``: 0-100
    ...                - *Returns:* N/A
    [Arguments]    ${group}    ${exp_vol_lvl}
    [Tags]    88752=2,3,4,6,8,9,10,12,14,15,16,18    109051=4,5,6,8,9,10    81975=2,4,6
    ${actual_vol}=    Get Audio Current Volume Level    ${group}
    Should Be Equal As Numbers    ${exp_vol_lvl}    ${actual_vol}
    ...    msg=Fail, wrong volume for group ${group}. Expected: ${exp_vol_lvl}, Actual: ${actual_vol}
    [Teardown]    Document Keyword Outcome    Verified ${group} sound volume is ${exp_vol_lvl}%.

Send Audio Set Volume Request
    [Documentation]    Set absolute volume level for a specific audio group: kTherapy, kAlerts, kConnection
    ...                - *Arguments:* ``group``: kTherapy/kAlerts/kConnection, ``volume``: 0-100
    [Tags]    88752=1,5,7,11,13,17    109051=1,2,3    81975=1,3,5
    [Arguments]    ${group}    ${volume}
    ${response}=    Send GRPC Request
    ...    Set Volume
    ...    ${GRPC_SERVER}
    ...    ${volume}
    ...    ${group}
    ${grpc_success}=    Run Keyword And Return Status
    ...    Should Be Equal As Strings
    ...    ${response.status}
    ...    ${kSuccess}
    Should Be True    ${grpc_success}    msg=Failed to set volume to ${volume}% for group ${group}
    RETURN    ${grpc_success}
    [Teardown]    Document Keyword Outcome    Verified audio group ${group} volume was set to ${volume}%.

Send Audio Set Volume Request And Get Response
    [Documentation]    Set volume for a specific audio group: kTherapy, kAlerts, kConnection and return full response (for error checking)
    ...                - *Arguments:* ``group``: kTherapy/kAlerts/kConnection, ``volume``: 0-100
    [Tags]    internal
    [Arguments]    ${group}    ${volume}
    ${response}=    Send GRPC Request
    ...    Set Volume
    ...    ${GRPC_SERVER}
    ...    ${volume}
    ...    ${group}
    RETURN    ${response}

Send Audio Increase Volume And Get Response
    [Documentation]    Increase volume and return full response with previous/updated values
    ...                - *Arguments:* ``group``: kTherapy/kAlerts/kConnection, ``increase_value``: 0-100
    [Tags]    internal
    [Arguments]    ${group}    ${increase_value}
    ${response}=    Send GRPC Request
    ...    Increase Volume
    ...    ${GRPC_SERVER}
    ...    ${increase_value}
    ...    ${group}
    RETURN    ${response}

Send Audio Decrease Volume And Get Response
    [Documentation]    Decrease volume and return full response with previous/updated values
    ...                - *Arguments:* ``group``: kTherapy/kAlerts/kConnection, ``decrease_value``: 0-100
    [Tags]    internal
    [Arguments]    ${group}    ${decrease_value}
    ${response}=    Send GRPC Request
    ...    Decrease Volume
    ...    ${GRPC_SERVER}
    ...    ${decrease_value}
    ...    ${group}
    RETURN    ${response}

Set default vol lvl for all groups
    [Documentation]    Set default volume level for all groups
    [Tags]    internal
    Send Audio Set Volume Request    kTherapy    50
    Send Audio Set Volume Request    kAlerts    50
    Send Audio Set Volume Request    kConnection    50
    [Teardown]    Document Keyword Outcome    Verified that volume is set to default for all audio groups.

##################################################################################
########################## END OF Audio Service Keywords #########################
##################################################################################

##################################################################################
########################## Case Management Keywords ##############################
##################################################################################

Send Open Case Request
    [Documentation]    Open a new case on the generator and return the case info.
    ...  - *Date of Implementation:* 15-APR-2026
    ...  - *Author:* Mina Bikhit
    ...  - *Returns:* Case info (id, name, timestamp) from the opened case
    [Tags]    internal
    [Arguments]    ${case_name}
    ${grpc_response}=    Send GRPC Request
    ...    Open Case
    ...    ${GRPC_SERVER}
    ...    ${case_name}
    ${case_info}=    Set Variable    ${grpc_response.case_info}
    RETURN    ${case_info}

Send Close Case Request
    [Documentation]    Close an existing case on the generator.
    ...  - *Date of Implementation:* 15-APR-2026
    ...  - *Author:* Mina Bikhit
    ...  - *Returns:* gRPC response
    [Tags]    internal
    [Arguments]    ${case_id}=${None}
    ${grpc_response}=    Run Keyword If    $case_id is not None
    ...    Send GRPC Request    Close Case    ${GRPC_SERVER}    ${case_id}
    ...    ELSE
    ...    Send GRPC Request    Close Case    ${GRPC_SERVER}
    RETURN    ${grpc_response}

Send Get Current Case Info Request
    [Documentation]    Get information about the currently open case.
    ...  - *Date of Implementation:* 15-APR-2026
    ...  - *Author:* Mina Bikhit
    ...  - *Returns:* Case info (id, name, timestamp) of the current case
    [Tags]    internal
    ${grpc_response}=    Send GRPC Request
    ...    Get Current Case Info
    ...    ${GRPC_SERVER}
    ${case_info}=    Set Variable    ${grpc_response.case_info}
    RETURN    ${case_info}

Create Multiple Case Reports
    [Documentation]    Open and close a specified number of cases to populate the reports screen.
    ...    Each iteration opens a case with a generated name, then immediately closes it.
    ...  - *Date of Implementation:* 15-APR-2026
    ...  - *Author:* Mina Bikhit
    ...  - *Arguments:*
    ...  -    ``number_of_cases`` – The number of cases to create (open + close).
    ...  -    ``case_name_prefix`` – Optional prefix for case names (default: ``AutoCase``).
    ...  - *Returns:* List of case info objects created
    [Tags]    internal
    [Arguments]    ${number_of_cases}    ${case_name_prefix}=AutoCase
    ${number_of_cases}=    Convert To Integer    ${number_of_cases}

    # Close any pre-existing open case before creating new ones
    # ID of 0 or 4294967295 (0xFFFFFFFF) means no case is open
    ${status}    ${current_case}=    Run Keyword And Ignore Error    Send Get Current Case Info Request
    IF    '${status}' == 'PASS'
        IF    ${current_case.id} > 0 and ${current_case.id} != 4294967295
            Log    Closing pre-existing open case (ID=${current_case.id}) before creating new cases.    WARN
            Send Close Case Request
        END
    END

    @{created_cases}=    Create List
    FOR    ${index}    IN RANGE    ${number_of_cases}
        ${case_name}=    Set Variable    ${case_name_prefix}_${index + 1}
        Send Open Case Request    ${case_name}
        Sleep    3s    reason=Wait for archiver to process the opened case
        ${result}=    Send Get Current Case Info Request
        Log To Console    Opened case ${index + 1}/${number_of_cases}: ID=${result.id}, Name=${result.name}
        Append To List    ${created_cases}    ${result}
        Send Close Case Request    ${result.id}
        Log To Console    Closed case ${index + 1}/${number_of_cases}: ID=${result.id}
    END
    RETURN    ${created_cases}
    [Teardown]    Document Keyword Outcome    Created and closed ${number_of_cases} case(s) with prefix '${case_name_prefix}'

##################################################################################
########################## END OF Case Management Keywords #######################
##################################################################################


