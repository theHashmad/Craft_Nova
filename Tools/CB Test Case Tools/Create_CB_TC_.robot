*** Settings ***
Library         RequestsLibrary
Library         JSONLibrary
Library         Collections
Library         String
Library         OperatingSystem
Library         SSHLibrary
Library         ExcelSage

Suite Setup     Copy File    TS_Template.robot    ${RFFileName}


*** Variables ***
@{tmpCodeBeamerCreds}           craft-runner    craft-runner
@{tmpBodyTCBody}                @{EMPTY}
@{testCaseIds}                  @{EMPTY}
@{testCaseResult}               @{EMPTY}
@{testCaseStatus}               @{EMPTY}
@{testCaseMessage}              @{EMPTY}
@{tcList}                       @{EMPTY}
&{testCaseResultDict}           &{EMPTY}
&{testCaseStepResultDict}       &{EMPTY}
@{tmpTCResult}                  @{EMPTY}
&{codeBeamerResultEnum}         PASS=PASSED    FAIL=FAILED    Unknown=Not Run/Pending    NOT RUN=BLOCKED
${testConfigName}               ${EMPTY}
&{bugList}                      &{EMPTY}
${openBug}                      ${EMPTY}
${tmpParamTCName}               ${EMPTY}
@{resultList}                   @{EMPTY}
@{resultList1}                  @{EMPTY}
${keywordStatusMessage}         ${EMPTY}
${testCaseFilePath}             TD-66649.xlsx
@{stepColumns}                  C    D
${previousTestName}             ${EMPTY}
${previousTestDesc}             ${EMPTY}
${testCaseDict}                 ${EMPTY}
${RFFileName}                   ${CURDIR}/${testCaseFilePath}.robot
${createRFFile}                 False


*** Test Cases ***
Create New DD Test Case in CodeBeamer
    [Documentation]    Test case to create a new test case in CodeBeamer.
    [Tags]    datadriven    codebeamer
    @{testStepsList}=    Create List
    @{testCaseList}=    Create List
    &{testCaseDict}=    Create Dictionary
    ${tmpExcel}=    Open Workbook    ${CURDIR}/${testCaseFilePath}.xlsx
    ${tmpTestData}=    Fetch Sheet Data    Data    ignore_empty_rows=True    output_format=dict
    Log    \n\nThe Test Data fetched from Excel is: ${tmpTestData}
    ${totalTCs}=    Get Length    ${tmpTestData}
    Log    \n\nThe Total Test Cases to be created are: ${totalTCs}
    ${tmpTestSteps}=    Fetch Sheet Data    Steps    ignore_empty_rows=True    output_format=list
    ${tmpTCName}=    Get Cell Value    A2    Steps
    ${tmpTCDesc}=    Get Cell Value    B2    Steps
    Log    \n\nThe Test Steps fetched from Excel are: ${tmpTestSteps}
    FOR    ${tmpDataRow}    IN    @{tmpTestData}
        Log    \n\nThe Test Data Row is: ${tmpDataRow}
        Remove From Dictionary    ${tmpDataRow}    ${None}
        FOR    ${tmpTCRow}    IN    @{tmpTestSteps}
            ${tmpAction}=    Set Variable    ${tmpTCRow}[2]
            ${tmpExpected}=    Set Variable    ${tmpTCRow}[3]
            FOR    ${key}    ${value}    IN    &{tmpDataRow}
                Log    \n\nThe Test Case Row is: ${tmpTCRow}
                ${value}=    Convert To String    ${value}
                ${statusAction}=    Run Keyword And Return Status    Should Contain    ${tmpAction}    ${key}
                IF    '${statusAction}' == 'True'
                    ${tmpAction}=    Replace String    ${tmpAction}    ${key}    ${value}
                ELSE
                    ${tmpAction}=    Set Variable    ${tmpAction}
                END
                IF    '${statusAction}' == 'True'
                    ${tmpAction}=    Replace String    ${tmpAction}    "{"    "\~\{"
                ELSE
                    ${tmpAction}=    Set Variable    ${tmpAction}
                END
                ${statusExpected}=    Run Keyword And Return Status    Should Contain    ${tmpExpected}    ${key}
                IF    '${statusExpected}' == 'True'
                    ${tmpExpected}=    Replace String    ${tmpExpected}    ${key}    ${value}
                ELSE
                    ${tmpExpected}=    Set Variable    ${tmpExpected}
                END
                Log    \n\nThe Action after replacement is: ${tmpAction}    console=False
                Log    \n\nThe Expected after replacement is: ${tmpExpected}    console=False
            END
            ${testStepActionDict}=    Create Dictionary
            ...    fieldId=1000001
            ...    name=Action
            ...    value=${tmpAction}
            ...    type=WikiTextFieldValue
            ${testStepExpectedDict}=    Create Dictionary
            ...    fieldId=1000002
            ...    name=Expected result
            ...    value=${tmpExpected}
            ...    type=WikiTextFieldValue
            ${testCriticalDict}=    Create Dictionary
            ...    fieldId=1000003
            ...    name=Critical
            ...    value=false
            ...    type=BoolFieldValue
            @{testStepBlock}=    Create List    ${testStepActionDict}    ${testStepExpectedDict}    ${testCriticalDict}
            ${lentgth}=    Get Length    ${testStepsList}
            Append To List    ${testStepsList}    ${testStepBlock}
            Log    \n\nThe Test Steps List is: ${testStepsList}    console=False
        END
        Append To List    ${testCaseList}    ${testStepsList}
    END
    Log    \n\nThe Test Steps List is: ${testCaseList}[0]    console=False
    Create CB Session
    ${newTC}=    Create New Test Case    ${testCaseList}[0]    ${tmpTCName}    ${tmpTCDesc}
    Log    \n\nThe New Test Case created in CodeBeamer is: ${newTC}    console=True
    Find And Replace    ${tmpTCName}    ${newTC}:${tmpTCName}    Steps
    IF    '${createRFFile}'=='True'    Create RF Test Suite Template
    Close Workbook

Create Normal Test Cases in CodeBeamer
    [Tags]    normal    codebeamer
    @{testStepsList}=    Create List
    @{masterTestList}=    Create List
    @{tcIndexList}=    Create List
    ${tmpExcel}=    Open Workbook    ${CURDIR}/${testCaseFilePath}.xlsx
    ${totalRows}=    Get Row Count    sheet_name=Steps
    FOR    ${index}    IN RANGE    ${1}    ${totalRows + 1}
        @{testCaseList}=    Create List
        ${name}=    Get Cell Value    A${index+1}    Steps
        ${desc}=    Get Cell Value    B${index+1}    Steps
        IF    '${name}'!='${None}'
            ${previousTestName}=    Set Variable    ${name}
        ELSE
            ${previousTestName}=    Set Variable    ${previousTestName}
        END
        IF    '${desc}'!='${None}'
            ${previousTestDesc}=    Set Variable    ${desc}
        ELSE
            ${previousTestDesc}=    Set Variable    ${previousTestDesc}
        END
        IF    '${name}'=='${previousTestName}'
            ${testStepsList}=    Create List
        ELSE
            ${testStepsList}=    Set Variable    ${testStepsList}
        END
        ${action}=    Get Cell Value    C${index+1}    Steps
        ${expected}=    Get Cell Value    D${index+1}    Steps
        ${action}=    Replace String Using Regexp    ${action}    [\r\n]+    ${EMPTY}
        ${expected}=    Replace String Using Regexp    ${expected}    [\r\n]+    ${EMPTY}
        ${testStepActionDict}=    Create Dictionary
        ...    fieldId=1000001
        ...    name=Action
        ...    value=${action}
        ...    type=WikiTextFieldValue
        ${testStepExpectedDict}=    Create Dictionary
        ...    fieldId=1000002
        ...    name=Expected result
        ...    value=${expected}
        ...    type=WikiTextFieldValue
        ${testCriticalDict}=    Create Dictionary
        ...    fieldId=1000003
        ...    name=Critical
        ...    value=false
        ...    type=BoolFieldValue
        @{testStepBlock}=    Create List    ${testStepActionDict}    ${testStepExpectedDict}    ${testCriticalDict}
        Append To List    ${testStepsList}    ${testStepBlock}
        Log    \n\nThe Test Steps List is: ${testStepsList}    console=False
        IF    '${name}'!='${None}'
            ${testCaseDict}=    Create Dictionary    name=${name}    description=${desc}    steps=${testStepsList}
        ELSE
            ${testCaseDict}=    Set To Dictionary    ${testCaseDict}    steps=${testStepsList}
        END
        Log    \n\nThe Test Case Dictionary is: ${testCaseDict}    console=False
        IF    '${name}'!='${None}'
            Append To List    ${testCaseList}    ${testCaseDict}
        END
        IF    '${name}'!='${None}'
            Append To List    ${masterTestList}    ${testCaseList}
        END
    END

    Log    \n\nThe Test Case List is: ${masterTestList}    console=False
    ${totalBlocks}=    Get Length    ${masterTestList}
    Log    \n\nThe Total Test Case Blocks to be created are: ${totalBlocks}    console=False
    FOR    ${tcdata}    IN    @{masterTestList}
        ${tmpName}=    Get From Dictionary    ${tcdata}[0]    name
        ${tmpDesc}=    Get From Dictionary    ${tcdata}[0]    description
        ${tmpSteps}=    Get From Dictionary    ${tcdata}[0]    steps
        Create CB Session
        ${newTC}=    Create New Test Case    ${tmpSteps}    ${tmpName}    ${tmpDesc}
        Log    \n\nThe New Test Case created in CodeBeamer is: ${newTC} with name: ${tmpName}    console=False
        Find And Replace    ${tmpName}    ${newTC}:${tmpName}    Steps
    END
    IF    '${createRFFile}'=='True'    Create RF Test Suite Template
    Close Workbook

Create RF Test Suite Template
    [Tags]    normal-rf    internal    try    datadriven-rf
    Open Workbook    ${CURDIR}/${testCaseFilePath}.xlsx
    Create RF Test Suite Template


*** Keywords ***
Create CB Session
    [Documentation]    Keyword to create a session with CodeBeamer server.
    [Tags]    internal    codebeamer    reporting    p1
    ${cbsession}=    Create Session
    ...    cb
    ...    https://crdn.codebeamer.com
    ...    auth=${tmpCodeBeamerCreds}
    ...    disable_warnings=1
    Set Global Variable    ${cbsession}

Create New Test Case
    [Documentation]    Keyword to create a new Test Case in CodeBeamer with the name and steps provided.
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${testCaseSteps}    ${tmpParamTCName}=${None}    ${tmpTCDesc}=${None}
    Log    \n\n\n\n${testCaseSteps}
    ${tmpPriority}=    Create Dictionary    id=3    name=Medium    type=ChoiceOptionReference
    ${tmpStatus}=    Create Dictionary    id=1    name=New    type=ChoiceOptionReference
    ${tmpTCBlock}=    Create Dictionary
    ...    fieldId=1000000
    ...    name="Test Steps"
    ...    type=TableFieldValue
    ...    values=${testCaseSteps}
    ${tmpTCBlockList}=    Create List    ${tmpTCBlock}
    ${tmpTCBody}=    Create Dictionary
    ...    name=${tmpParamTCName}
    ...    description=${tmpTCDesc}
    ...    priority=${tmpPriority}
    ...    status=${tmpStatus}
    ...    customFields=${tmpTCBlockList}
    ${tcCreateResponse}=    POST On Session
    ...    url=https://crdn.codebeamer.com/rest/v3/trackers/19968/items
    ...    alias=cb
    ...    json=${tmpTCBody}
    ...    expected_status=200
    ...    msg=Try Test Case creation
    ${tmpNewTCID}=    Get Value From Json    ${tcCreateResponse.json()}    $..id
    Log    \n\nTest Case Created: ${tmpNewTCID}[0] with name: ${tmpParamTCName}
    RETURN    ${tmpNewTCID}[0]

Create RF Test Suite Template
    [Tags]    normal    internal
    @{testStepsList}=    Create List
    @{masterTestList}=    Create List
    @{tcIndexList}=    Create List
    ${totalRows}=    Get Row Count    sheet_name=Steps    ignore_empty_rows=True
    FOR    ${index}    IN RANGE    ${1}    ${totalRows + 1}
        @{testCaseList}=    Create List
        ${name}=    Get Cell Value    A${index+1}    Steps
        IF    '${name}'!='${None}'
            ${tcID}=    Split String    ${name}    separator=:
        ELSE
            ${tcID}=    Set Variable    ${None}
        END
        ${desc}=    Get Cell Value    B${index+1}    Steps
        IF    '${name}'!='${None}'
            ${previousTestName}=    Set Variable    ${name}
        ELSE
            ${previousTestName}=    Set Variable    ${previousTestName}
        END
        IF    '${desc}'!='${None}'
            ${previousTestDesc}=    Set Variable    ${desc}
        ELSE
            ${previousTestDesc}=    Set Variable    ${previousTestDesc}
        END
        IF    '${name}'=='${previousTestName}'
            ${testStepsList}=    Create List
        ELSE
            ${testStepsList}=    Set Variable    ${testStepsList}
        END
        IF    '${name}'!='${None}'
            Append To File    ${RFFileName}    \n\n${name}\n
        END
        # Run Keyword If    '${name}'!='${None}'    Append To File    ${RFFileName}    \n\nXXXXX:${name}\n
        IF    '${name}'!='${None}'
            Append To File    ${RFFileName}    \t[Documentation]\tSample Test Case Through Script. Goal:${desc}\n
        END
        IF    '${name}'!='${None}'
            Append To File
            ...    ${RFFileName}
            ...    ...\t\t- ``Date Of Implementation : <DD-MMM-YYYY> / Author : <Tester Name>``\n
        END
        IF    '${name}'!='${None}'
            Append To File    ${RFFileName}    ...\t\t- ``Last Updated : <DD-MMM-YYYY> / Updated By : <Tester Name>``\n
        END
        IF    '${name}'!='${None}'
            Append To File
            ...    ${RFFileName}
            ...    ...\t\t- ``Test Case ID : [https://crdn.codebeamer.com/item/${tcID[0]} | ${tcID[0]}] / User Story ID : [https://crdn.codebeamer.com/item/<USID> | <USID>]``\n
        END
        IF    '${name}'!='${None}'
            Append To File    ${RFFileName}    ...\t\t| Test Steps:\n
        END
        ${action}=    Get Cell Value    C${index+1}    Steps
        ${expected}=    Get Cell Value    D${index+1}    Steps
        ${action}=    Replace String Using Regexp    ${action}    [\r\n]+    ${EMPTY}
        ${expected}=    Replace String Using Regexp    ${expected}    [\r\n]+    ${EMPTY}
        Append To File    ${RFFileName}    ...\t\t- ``${action}`` : ``${expected}``\n
    END
