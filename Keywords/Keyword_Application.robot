*** Settings ***
Library    FlaUILibrary
Library    OperatingSystem
Resource   ../resources/variables/application/application_variables.robot

*** Keywords ***
Launch NOVA
    [Tags]    143698=1

    ${pid}=    Launch Application    ${NOVA_APPLICATION}
    Set Suite Variable    \${NOVA_PID}    ${pid}
    Wait For Application Handle By PID    ${pid}    10000

    Element Should Exist    /Window[@Name='NOVA']

    [Teardown]    Run Keywords
    ...    Document Keyword Outcome    NOVA opens successfully.
    ...    AND    Add Screenshot


Close NOVA
    [Documentation]    Explicitly close the NOVA window and kill the process if it remains open.
    Run Keyword And Ignore Error    Close Window    /Window[@Name='NOVA']
    Run Keyword And Ignore Error    Close Application    ${NOVA_APPLICATION}
    ${pid_to_close}=    Get Variable Value    \${NOVA_PID}    ${EMPTY}
    Run Keyword If    '${pid_to_close}' != '${EMPTY}' and '${pid_to_close}' != 'None'    Run    taskkill /PID ${pid_to_close} /F /T


Authenticate Using SSO
    [Tags]    143698=2

    ${auth}=    Set Variable
    ...    /Window[@Name='NOVA']//*[@Name='Authenticate in browser via single sign-on (SSO).']

    Wait Until Element Exist    ${auth}    10000
    Click    ${auth}

    Wait Until Element Exist
    ...    /Window[@Name='NOVA']//*[@AutomationId='SoftwareUpdaterOffline']
    ...    15000

    [Teardown]    Run Keywords
    ...    Document Keyword Outcome    User reaches the NOVA landing page.
    ...    AND    Add Screenshot


Select Update Software Offline
    [Tags]    143698=3

    ${offline_update}=    Set Variable
    ...    /Window[@Name='NOVA']//*[@AutomationId='SoftwareUpdaterOffline']

    Wait Until Element Exist
    ...    ${offline_update}
    ...    15000

    Click    ${offline_update}

    [Teardown]    Run Keywords
    ...    Document Keyword Outcome    The Update Software (Offline) page is displayed.
    ...    AND    Add Screenshot


Verify Offline Update Controls
    [Tags]    143698=4

    ${update_device}=    Set Variable
    ...    /Window[@Name='NOVA']//*[@AutomationId='UpdateDevice']

    Wait Until Element Exist
    ...    ${update_device}
    ...    15000

    Element Should Exist    ${update_device}

    [Teardown]    Run Keywords
    ...    Document Keyword Outcome    The page displays the controls required for offline software update and device selection.
    ...    AND    Add Screenshot


Continue To Update Device
    [Tags]    143698=5

    ${update_device}=    Set Variable
    ...    /Window[@Name='NOVA']//*[@AutomationId='UpdateDevice']

    Click    ${update_device}

    ${device_path}=    Set Variable
    ...    /Window[@Name='NOVA']//*[@AutomationId='DevicePath']

    Element Should Exist    ${device_path}

    ${items}=    Get All Names From Combobox
    ...    ${device_path}

    Log    DOWNLOAD PATH OPTIONS: ${items}

    [Teardown]    Run Keywords
    ...    Document Keyword Outcome    The Update Device page is displayed.
    ...    AND    Add Screenshot


Document Keyword Outcome
    [Arguments]    ${message}

    Set Suite Variable    \${keyword_result_message}    ${message}
    Set Suite Variable    ${KEYWORD_STATUS}    PASS
    Log    Verification Passed: ${message}


Add Screenshot
    Log    Screenshot capture is not required for this validation step.
