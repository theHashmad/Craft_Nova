*** Settings ***
Library     Collections
Library     CSVLibrary
Resource    ../Keywords/Keyword_Common_API.robot


*** Variables ***
${EVAL_FLOATING_POINTS}     2
&{catheter_topic_state}=
    ...    DISCONNECTED=kCatheterDisconnected
    ...    WAIT-FOR-CATHETER=kCatheterDisconnected
    ...    IN-SHEATH=kCatheterConnected
    ...    IN-VIVO-NORMAL=kCatheterConnected
    ...    IN-VIVO-ELEVATED=kCatheterConnected
    ...    EX-VIVO=kCatheterConnected
    ...    WAIT-FOR-REM=kCatheterConnected
    ...    STANDBY=kCatheterConnected
&{rem_topic_state}=
    ...    DISCONNECTED=kRemDisconnected
    ...    WAIT-FOR-CATHETER=kRemConnectedOnBody
    ...    IN-SHEATH=kRemConnectedOnBody
    ...    IN-VIVO-NORMAL=kRemConnectedOnBody
    ...    IN-VIVO-ELEVATED=kRemConnectedOnBody
    ...    EX-VIVO=kRemConnectedOnBody
    ...    WAIT-FOR-REM=kRemDisconnected
    ...    STANDBY=kRemConnectedOnBody


*** Keywords ***
Set Catheter State
    [Tags]    66647=3,7    66582=2,4,5    98718=8    99584=1
    [Arguments]    ${state}
    ${electrodes}=    Convert To List    0123
    ${config}=    GET State Configuration    ${state}
    ${cath_state}=    Get Cath State Value    ${catheter_topic_state}[${state}]
    ${grpc_temp_response}=    Send GRPC Request    Set Temperature
    ...    ${GRPC_SERVER}
    ...    ${config['TMP_STATUS']}    ${config['TMP']}
    ...    ${config['TMP_STATUS']}    ${config['TMP']}
    ...    ${config['TMP_STATUS']}    ${config['TMP']}
    ...    ${config['TMP_STATUS']}    ${config['TMP']}
    ${grpc_imp_response}=    Send GRPC Request    RF Instant Set    ${GRPC_SERVER}    ${electrodes}    ${config['IMP']}    ${config['PWR_ACCUR']}    ${config['PWR_DELAY']}
    Sleep    1
    ${grpc_success_temp}=    Run Keyword And Return Status
    ...    Should Be Equal As Integers
    ...    ${grpc_temp_response.status}
    ...    ${kSuccess}
    ${grpc_success_imp}=    Run Keyword And Return Status
    ...    Should Be Equal As Integers
    ...    ${grpc_imp_response.status}
    ...    ${kSuccess}
    ${notice}=    Get Notice For    kCatheter
    Should Be Equal As Strings    ${notice['catheterDataNotice']['state']}    ${cath_state}
    RETURN    ${grpc_success_temp}    ${grpc_success_imp}
    [Teardown]    Document Keyword Outcome    Verified that catheter is in ${catheter_topic_state}[${state}] state.
    
Set REM State
    [Tags]    66634=3    66582=1    98718=3    99584=2
    [Arguments]    ${state}
    ${config}=    GET State Configuration    ${state}
    ${grpc_response}=    Send GRPC Request    REM.Set Rem    ${GRPC_SERVER}    ${config['REM']}    0.0    kExternalLoad
    ${grpc_success}=    Run Keyword And Return Status
    ...    Should Be Equal As Integers
    ...    ${grpc_response.status}
    ...    ${kSuccess}
    ${notice}=    Get Notice For    kRem
    Should Be Equal As Strings    ${notice['remDataNotice']['magnitude']}    ${config['REM']}
    Should Be Equal As Strings    ${notice['remDataNotice']['phase']}    0.0
    RETURN    ${grpc_response}
    [Teardown]    Document Keyword Outcome    Verified that REM is in ${rem_topic_state}[${state}] state.

Set InVivoNormal State
    [Documentation]    Keyword to set InVivoNormal state
    ...                - *Date of Implementation:* 5-MAY-2026
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* Patient Circuit State Machine state: ``act_pc_state``
    [Tags]    69900=7    102359=1    102456=1    102393=1    66649=4    66650=1
    Sleep    1
    VAR    ${exp_pc_state}=    kPatientCircuitConnectedInVivoNormal
    Set REM State    IN-VIVO-NORMAL
    Set Catheter State    IN-VIVO-NORMAL
    Sleep    0.5
    ${notice}=    Get Notice For    kPatientCircuit
    VAR    ${act_pc_state}=    ${notice}[patientCircuitDataNotice][state]
    Should Be Equal    ${exp_pc_state}    ${act_pc_state}
    RETURN    ${act_pc_state}
    [Teardown]    Document Keyword Outcome    Verified that PatientCircuit is in InVivoNormal state.

Set InVivoElevated State
    [Documentation]    Keyword to set InVivoElevated state
    ...                - *Date of Implementation:* 5-MAY-2026
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* Patient Circuit State Machine state: ``act_pc_state``
    [Tags]    internal
    Sleep    1
    VAR    ${exp_pc_state}=    kPatientCircuitConnectedInVivoElevated
    Set REM State    IN-VIVO-ELEVATED
    Set Catheter State    IN-VIVO-ELEVATED
    Sleep    0.5
    ${notice}=    Get Notice For    kPatientCircuit
    VAR    ${act_pc_state}=    ${notice}[patientCircuitDataNotice][state]
    Should Be Equal    ${exp_pc_state}    ${act_pc_state}
    RETURN    ${act_pc_state}
    [Teardown]    Document Keyword Outcome    Verified that PatientCircuit is in InVivoElevated state.

Set inSheath State
    [Documentation]    Keyword to set inSheath state
    ...                - *Date of Implementation:* 1-OCT-2025
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* Patient Circuit State Machine state: ``act_pc_state``
    [Tags]    69900=4   66647=1,5     66634=1    66102=3    66649=1    66650=4
    Sleep    1
    VAR    ${exp_pc_state}=    kPatientCircuitConnectedInSheath
    Set REM State    IN-SHEATH
    Set Catheter State    IN-SHEATH
    Sleep    0.5
    ${notice}=    Get Notice For    kPatientCircuit
    VAR    ${act_pc_state}    ${notice['patientCircuitDataNotice']['state']}
    Should Be Equal    ${exp_pc_state}    ${act_pc_state}
    RETURN    ${act_pc_state}
    [Teardown]    Document Keyword Outcome    Verified that PatientCircuit is in InSheath state.

Set ExVivo State
    [Documentation]    Keyword to set ExVivo state
    ...                - *Date of Implementation:* 1-OCT-2025
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* Patient Circuit State Machine state: ``act_pc_state``
    [Tags]    internal
    Sleep    1
    VAR    ${exp_pc_state}=    kPatientCircuitConnectedExVivo
    Set REM State    EX-VIVO
    Set Catheter State    EX-VIVO
    ${notice}=    Get Notice For    kPatientCircuit
    VAR    ${act_pc_state}=    ${notice}[patientCircuitDataNotice][state]
    Should Be Equal    ${exp_pc_state}    ${act_pc_state}
    RETURN    ${act_pc_state}

Set Standby state
    [Documentation]    Keyword to set Standby state
    ...                - *Date of Implementation:* 12-FEB-2026
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* Generator State Machine state: ``state``
    [Tags]    109040=2
    Set REM State    STANDBY
    Set Catheter State    STANDBY
    ${state}=    Check If Therapy In expected State    ${GRPC_SERVER}    kGeneratorStandby
    RETURN    ${state}
    [Teardown]    Document Keyword Outcome    Verification Passed: Generator was in Standby state.

Set Disconnected state
    [Documentation]    Keyword to set Disconnected state
    ...                - *Date of Implementation:* 1-OCT-2025
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* N/A
    [Tags]    69900=1    109040=1
    Set REM State    DISCONNECTED
    Set Catheter State    DISCONNECTED
    [Teardown]    Document Keyword Outcome    Verified that PatientCircuit is in Disconnected state.

Set WaitForCatheter state
    [Documentation]    Keyword to set WaitForCatheter state
    ...                - *Date of Implementation:* 6-OCT-2025
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* Patient Circuit State Machine state: ``act_pc_state``
    [Tags]    internal
    Sleep    1
    VAR    ${exp_pc_state}=    kPatientCircuitWaitForCatheter
    Set REM State    WAIT-FOR-CATHETER
    Set Catheter State    WAIT-FOR-CATHETER
    ${notice}=    Get Notice For    kPatientCircuit
    VAR    ${act_pc_state}=    ${notice}[patientCircuitDataNotice][state]
    Should Be Equal    ${exp_pc_state}    ${act_pc_state}
    RETURN    ${act_pc_state}

Set WaitForRem state
    [Documentation]    Keyword to set WaitForRem state
    ...                - *Date of Implementation:* 23-JAN-2026
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* Patient Circuit State Machine state: ``act_pc_state``
    [Tags]    internal
    Sleep    1
    VAR    ${exp_pc_state}=    kPatientCircuitWaitForRem
    Set REM State    WAIT-FOR-REM
    Set Catheter State    WAIT-FOR-REM
    ${notice}=    Get Notice For    kPatientCircuit
    VAR    ${act_pc_state}=    ${notice}[patientCircuitDataNotice][state]
    Should Be Equal    ${exp_pc_state}    ${act_pc_state}
    RETURN    ${act_pc_state}

Set TherapyAblate State
    [Documentation]    Keyword to set TherapyAblate state
    ...                - *Date of Implementation:* 12-FEB-2026
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* Generator State Machine state: ``state``
    [Tags]    internal
    ${ablation_status}=    Run Keyword And Return Status    Start Ablation
    IF    '${ablation_status}'=='False'
        Set InVivoNormal State
        Start Ablation
    END
    Sleep    5
    ${state}=    Check If Therapy In expected State    ${GRPC_SERVER}    kGeneratorTherapyAblate
    RETURN    ${state}

Set TherapyStopped State
    [Documentation]    Keyword to set TherapyStopped state
    ...                - *Date of Implementation:* 12-FEB-2026
    ...                - *Author:* Oliwia Maloch
    ...                - *Returns* Generator State Machine state: ``state``
    [Tags]    internal
    ${ablation_status}=    Run Keyword And Return Status    Stop Ablation
    IF    '${ablation_status}'=='False'
        Set TherapyAblate State
        Stop Ablation
    END
    Sleep    5
    ${state}=    Check If Therapy In expected State    ${GRPC_SERVER}    kGeneratorTherapyStopped
    RETURN    ${state}

Test Setup for Display and API
    [Documentation]    Open display, check python information, get test start time, validate application, go to case screen
    [Tags]    internal
    Open display
    Set Disconnected State
    Check If Therapy In expected State    ${GRPC_SERVER}    kGeneratorStandby
    Set InVivoNormal State
    Check If Therapy In expected State    ${GRPC_SERVER}    kGeneratorTherapyReady
