*** Settings ***
Library     RequestsLibrary
Library     JSONLibrary
Library     Collections
Library     String
Library     OperatingSystem
Library     SSHLibrary


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


*** Test Cases ***
Convert Parameterized TC to Test Steps
    [Documentation]    Convert Parameterized TC to Test Steps
    [Tags]    param
    [Setup]    Remove File    Converted_TC_List.txt
    Log    Test case to convert parameterized TC to test steps
    &{oldNewTCMap}=    Create Dictionary
    ${tmpMasterTCList}=    Create List    47603
    # ...    66649
    # ...    66587    61673    59343    58328    58327    58274    58273    58014    57675    57660    54024    52406    49964    47603    44629    42737
    FOR    ${tmpList}    IN    @{tmpMasterTCList}
        ${tc}=    Create List    ${tmpList}
        Log    \n\nConverting Old TC ID: ${tmpList} to New TC with Test Steps...    console=True
        ${tmpNewID}=    Create New Test Cases in Codebeamer    ${tc}
        Set To Dictionary    ${oldNewTCMap}    ${tmpList}    ${tmpNewID}
        Log    \n\nOld TC ID: ${tmpList} / New TC ID: ${tmpNewID}    console=True
    END
    Log    \n\nList of All Converted TC: ${oldNewTCMap}


*** Keywords ***
Create New Test Cases in Codebeamer
    [Documentation]    High-level keyword to update CodeBeamer with test results.
    [Tags]    high    codebeamer
    [Arguments]    ${testCaseResultList}
    Create CB Session
    ${tmpTRResponse}    ${tmpTRID}=    Create Master Test Run    ${testCaseResultList}
    @{tmpHiddenRuns}=    Identify Param Internal Test Run Instances    ${tmpTRResponse}    ${testCaseResultDict}
    ${tcSteps}=    Get Param Test Steps    ${tmpHiddenRuns}    ${testCaseResultDict}
    ${totalSteps}=    Get Length    ${tcSteps}
    ${masterPayload}=    Create List
    ${tmpPay}=    Set Variable    ${EMPTY}
    FOR    ${index}    ${tcpayload}    IN ENUMERATE    @{tcSteps}
        Log    \n\n${tcpayload}
        FOR    ${key}    IN    @{tcpayload}
            Append To List    ${masterPayload}    ${key}
        END
        Log    ${masterPayload}
    END
    ${newID}=    Create New Test Case    ${masterPayload}
    RETURN    ${newID}

Create Test Run Payload
    [Documentation]    Keyword to create payload for creating Test Run in CodeBeamer with test cases and their results.
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${testCaseListDict}
    Log    \n\nCreating payload for TestRun creation in CodeBeamer...
    FOR    ${key}    IN    @{testCaseListDict}
        ${tmpTRunBody}=    Create Dictionary    id=${key}    type=TrackerItemReference
        Append To List    ${tcList}    ${tmpTRunBody}
    END

Create CB Session
    [Documentation]    Keyword to create a session with CodeBeamer server.
    [Tags]    internal    codebeamer    reporting    p1
    ${cbsession}=    Create Session
    ...    cb
    ...    https://crdn.codebeamer.com
    ...    auth=${tmpCodeBeamerCreds}
    ...    disable_warnings=1
    Set Global Variable    ${cbsession}

Create Master Test Run
    [Documentation]    Keyword to create Test Run in codebeamer with list of Test Cases that are being executed. This is used as a Suite Teardown keyword to update the results for individual test cases and finally update the test run instance and close it.
    [Tags]    internal    codebeamer    reporting    p1    teardown
    [Arguments]    ${testCaseList}
    FOR    ${key}    IN    @{testCaseList}
        ${tmpTRunBody}=    Create Dictionary    id=${key}    type=TrackerItemReference
        Append To List    ${tcList}    ${tmpTRunBody}
    END
    ${tcRunNameObj}=    Create Dictionary    name=TC_Convert_${SUITE NAME}
    ${finalTestRunBody}=    Create Dictionary    testCaseIds=@{tcList}    testRunModel=${tcRunNameObj}
    Log    ${finalTestRunBody}
    Log    \n\nCreating a new TestRun instance in CodeBeamer with executed TestCases added...
    ${createTestRunOut}=    POST On Session
    ...    url=https://crdn.codebeamer.com/rest/v3/trackers/19971/testruns
    ...    alias=cb
    ...    json=${finalTestRunBody}
    ...    expected_status=200
    ...    msg=TestRun creation failed..check logs for further debugging
    Log    ${createTestRunOut.json()}
    ${testRunID}=    Get Value From Json    ${createTestRunOut.json()}    $..id
    Log    \n\nThe TestRun instance created is: ${testRunID}[0]
    # Update Test Config Information    CRAFT_${SUITE NAME}    ${testRunID}[0]
    RETURN    ${createTestRunOut}    ${testRunID}[0]

Identify Internal Test Run Instances
    [Documentation]    Keyword to identify hidden test run instances created as children of the main test run instance in CodeBeamer.
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${createTestRunOut}    ${testCaseResultDict}
    ${HiddentestRuns}=    Get Value From Json    ${createTestRunOut.json()}    $..children

    RETURN    ${HiddentestRuns}

Identify Param Internal Test Run Instances
    [Documentation]    Keyword to identify hidden test run instances created as children of the main test run instance in CodeBeamer.
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${createTestRunOut}    ${testCaseResultDict}
    ${HiddentestRuns}=    Get Value From Json    ${createTestRunOut.json()}    $..children
    Log    \n\nThe Hidden TestRun instances created are: ${HiddentestRuns}
    ${tmpChildRunID}=    Set Variable    @{HiddentestRuns}[0]
    ${hiddenTestRunResponse}=    GET On Session
    ...    url=https://crdn.codebeamer.com/rest/v3/items/${tmpChildRunID}[id]
    ...    alias=${cbsession}
    ${DDRunIDs}=    Get Value From Json    ${hiddenTestRunResponse.json()}    $..children
    Log    \n\nThe Child TestRun instances created are: ${DDRunIDs}
    ${HiddentestRuns}=    Set Variable    ${DDRunIDs}
    RETURN    ${HiddentestRuns}

Get Param Test Steps
    [Documentation]    Keyword to update individual test step results for a test case in CodeBeamer.
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${HiddentestRuns}    ${testCaseResultDict}
    # @{resultList}=    Create List
    FOR    ${hiddenRun}    IN    @{HiddentestRuns}[0]
        Log    ${hiddenRun}
        Log    ${hiddenRun}[id]
        ${hiddenTestRunResponse}=    GET On Session
        ...    url=https://crdn.codebeamer.com/rest/v3/items/${hiddenRun}[id]
        ...    alias=cb
        Log    ${hiddenTestRunResponse.json()}
        ${tmpRunID}=    Get Value From Json    ${hiddenTestRunResponse.json()}    $..id
        ${hiddenTestRunID}=    Set Variable    ${tmpRunID}[0]
        ${testCaseID}=    Set Variable    ${tmpRunID}[5]
        ${testCaseID}=    Convert To String    ${testCaseID}
        ${actualResultObject}=    Get Value From Json    ${hiddenTestRunResponse.json()}    $..customFields
        ${tmpStepBlock}=    Create List    ${EMPTY}
        FOR    ${resultObject}    IN    @{actualResultObject}
            FOR    ${tmpOnject}    IN    @{resultObject}
                Log    ${tmpOnject}
                ${fieldID}=    Get From Dictionary    ${tmpOnject}    fieldId
                IF    "${fieldID}" == "2000000"
                    ${tmpTCStepResults}=    Get From Dictionary    ${tmpOnject}    values
                    Log    ${tmpTCStepResults}
                    ${testStepsCount}=    Get Length    ${tmpTCStepResults}
                    Log    ${testStepsCount}
                    ${tmpStepString}=    Convert Json To String    ${tmpTCStepResults}
                    ${tmpIDStr}=    Replace String Using Regexp    ${tmpStepString}    (\\d)(\\d\{\6\}\)    1\\2
                    Log    ${tmpIDStr}
                    # ${tmpIDStr}=    Replace String    ${tmpIDStr}    '    "
                    ${tmpStepJson}=    Convert String To Json    ${tmpIDStr}

                    Log    \n\n\n FRESH BLOCK : \n${tmpStepJson}
                    ${lengthCheck}=    Get Length    ${tmpStepJson}
                    Log    \n\n\n Length Check : \n${lengthCheck}
                    Set List Value    ${tmpStepBlock}    ${0}    ${tmpStepJson}
                    Log    \n\n\n${tmpStepBlock}[0]
                    Append To List    ${resultList}    ${tmpStepBlock}[0]
                    Log    \n\n\n FINAL RESULT LIST : \n${resultList}[0]
                ELSE IF    "${fieldID}" == "1000000"
                    ${tmpTCBlock}=    Get From Dictionary    ${tmpOnject}    values
                    ${tmpTCName}=    Get Value From Json    ${tmpTCBlock}    $..name
                    Log    ${tmpTCName}
                    ${tmpParamTCName}=    Set Variable    ${tmpTCName}[1]
                    Set Suite Variable    ${tmpParamTCName}
                END
            END
        END
    END
    Log    ${resultList}
    RETURN    ${resultList}

Create New Test Case
    [Documentation]    Keyword to create a new Test Case in CodeBeamer with the name and steps provided.
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${testCaseSteps}
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
    ...    name=CRAFT-${tmpParamTCName}
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
