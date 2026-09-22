*** Settings ***
Library     RequestsLibrary
Library     JSONLibrary
Library     Collections
Library     String
Resource    ../Configuration/CICD/CICD_Configuration.resource
Resource    ../Configuration/Codebeamer/Codebeamer_Configuration.resource
Library     OperatingSystem
Library     ../../Tools/StepResult.py


*** Variables ***
@{tmpCodeBeamerCreds}           ${cbUserName}    ${cbPwd}
@{tmpBodyTCBody}                @{EMPTY}
@{testCaseIds}                  @{EMPTY}
@{testCaseResult}               @{EMPTY}
@{testCaseStatus}               @{EMPTY}
@{testCaseMessage}              @{EMPTY}
@{tcList}                       @{EMPTY}
@{TCResults}                    @{EMPTY}
&{testCaseResultDict}           &{EMPTY}
&{testCaseStepResultDict}       &{EMPTY}
@{tmpTCResult}                  @{EMPTY}
&{codeBeamerResultEnum}         PASS=PASSED    FAIL=FAILED    Unknown=Not Run/Pending    NOT RUN=BLOCKED
&{bugList}                      &{EMPTY}
${openBug}                      ${EMPTY}


*** Keywords ***
Create Test Run in Codebeamer
    [Documentation]    High-level keyword to update CodeBeamer with test results.
    [Tags]    high    codebeamer
    ${suiteSetupStatus}=    Run Keyword And Return Status    Should Not Contain    ${SUITE_MESSAGE}    Suite setup failed
    IF    '${suiteSetupStatus}' == 'False'
        Log    \nALERT : SKIPPING CodeBeamer Test Run Creation as Suite Setup Failed.    console=Yes
        ${taskID}=    Create Task for Suite Setup Failure
        Create Result for Attachment    ${taskID}    ${EMPTY}    ${suiteSetupStatus}
        RETURN
    ELSE
        Log    \nSTARTING CodeBeamer Test Run Creation... \n\n    console=Yes
        IF    '${cbEnabled}'.lower() == 'true'
            IF    "${SuiteType}" == "datadriven"
                ${testCaseResultDict}=    Process Test Results for New DD
            ELSE
                ${testCaseResultDict}=    Set Variable    ${testCaseResultDict}
            END
            ${hasResults}=    Run Keyword And Return Status    Dictionary Should Not Be Empty    ${testCaseResultDict}
            IF    '${hasResults}' != 'True'
                ${testNameValue}=    Get Variable Value    ${TEST_NAME}    ${EMPTY}
                ${testStatusValue}=    Get Variable Value    ${TEST_STATUS}    ${EMPTY}
                ${testMessageValue}=    Get Variable Value    ${TEST_MESSAGE}    ${EMPTY}
                ${hasTestName}=    Run Keyword And Return Status    Should Not Be Empty    ${testNameValue}
                IF    '${hasTestName}' == 'True'
                    ${tmptestCaseID}=    Split String    ${testNameValue}    separator=:
                    ${hasTestCaseParts}=    Evaluate    len($tmptestCaseID) > 1
                    IF    ${hasTestCaseParts}
                        ${testCaseID}=    Set Variable    ${tmptestCaseID}[0]
                        ${tmpTCSteps}=    Create List
                        ${tmpCompletionMessage}=    Set Variable
                        ...    Test case result captured without step details. Test Status: ${testStatusValue}. Message: ${testMessageValue}
                        @{tmpTC}=    Create List    ${tmptestCaseID}[1]    ${testStatusValue}    ${tmpCompletionMessage}    0    ${tmpTCSteps}
                        Set To Dictionary    ${testCaseResultDict}    ${testCaseID}=${tmpTC}
                    ELSE
                        Log    Skipping fallback CodeBeamer result because TEST_NAME has no test-case ID separator: ${testNameValue}    console=Yes
                    END
                ELSE
                    Log    Skipping fallback CodeBeamer result because TEST_NAME is unavailable in suite teardown.    console=Yes
                END
            END
            Create CB Session
            Create Test Run Payload    ${testCaseResultDict}
            ${tmpTRResponse}    ${tmpTRID}=    Create Master Test Run    ${testCaseResultDict}
            ${runIdStatus}=    Run Keyword And Return Status    Should Not Be Equal    ${tmpTRID}    ${None}
            IF    '${runIdStatus}' == 'True'
                @{tmpHiddenRuns}=    Identify Internal Test Run Instances    ${tmpTRResponse}    ${testCaseResultDict}
                Update Test Step Results    ${tmpHiddenRuns}    ${testCaseResultDict}
                Update Test Run with Test Case Results and Close    ${tmpTRID}
                Create Result for Attachment    ${tmpTRID}    ${bugList}    ${suiteSetupStatus}
            ELSE
                Log    \nCodeBeamer Test Run creation did not return a valid run ID. The request likely failed because the configured CodeBeamer credentials or tracker permissions are invalid.    console=Yes
                Create Result for Attachment    NotApplicable    ${EMPTY}    ${suiteSetupStatus}
            END
        ELSE
            Log    \n-------------\n\nPOSTING TO CodeBeamer DISABLED FOR DEVELOPMENT / DEBUGING / ETC. \n\n    console=Yes
            Create Result for Attachment    NotApplicable    ${EMPTY}    ${suiteSetupStatus}
        END
    END

Create Result for Attachment
    [Arguments]    ${tmpTRID}    ${bugList}    ${SSFailure}=False
    # [Setup]    Remove File    path=${CURDIR}/../Reports/results.txt
    Log    ${bugList}
    ${isBugListEmpty}=    Run Keyword And Return Status    Should Be Empty    ${bugList}
    ${newBugList}=    Set Variable    ${EMPTY}
    IF    "${isBugListEmpty}" == "True"
        Log    Bug List Empty
    ELSE
        FOR    ${key}    ${value}    IN    &{bugList}
        ${newBugList}=    Catenate    ${newBugList}    ${key}:${value}|
        END
    END
    ${fileContent}=    Run Keyword If     "${isBugListEmpty}" == "True" and "${SSFailure}" == "True"    Set Variable    \n${SUITE_NAME},${tmpTRID},${SUITE_STATUS}    ELSE IF    "${isBugListEmpty}" == "True" and "${SSFailure}" == "False"    Set Variable    \n${SUITE_NAME},${tmpTRID},${SUITE_STATUS}-SS    ELSE    Set Variable    \n${SUITE_NAME},${tmpTRID},${SUITE_STATUS},${newBugList}
    Append To File    path=${CURDIR}/../Reports/RF/results.txt    content=${fileContent}
 
Create Task for Suite Setup Failure
    [Tags]    internal    codebeamer    reporting    p1
    ${newMsg}=    Split String    ${SUITE_MESSAGE}    separator=\n
    ${taskName}=    Set Variable    ${newMsg}[1]
    ${taskDescription}=    Set Variable    Suite Setup for suite ${SUITE_NAME} has failed. Hence skipping test case execution and CodeBeamer Test Run creation.\n\nPlease refer to the logs for more details.\n\n${SUITE_MESSAGE}\n\n Pipeline ID: ${PipelineID} \n CI Job ID: ${CI_JOB_ID}
    ${tmpTaskBody}=    Create Dictionary    name=${taskName}    description=${taskDescription}
    Log    ${tmpTaskBody}
    Create CB Session
    ${createTaskOut}=    POST On Session
    ...    url=https://crdn.codebeamer.com/rest/v3/trackers/261780/items
    ...    alias=cb
    ...    json=${tmpTaskBody}
    ...    expected_status=200
    ...    msg=Task creation failed..check logs for further debugging
    Log    ${createTaskOut.json()}
    ${taskID}=    Get Value From Json    ${createTaskOut.json()}    $..id
    Log    \n\nNew Task for failure Analysis : ${taskID}[0]    console=Yes
    RETURN    ${taskID}[0]

Process Test Results for New DD
    [Tags]    internal    codebeamer    reporting    p1
    ${totalTC}=    Get Length    ${tmpStepResult}
    Log    Total Test Cases in Suite : ${totalTC}    console=False
    ${totalStepCount}=    Evaluate    ${totalTC} * ${TotalSteps}
    Log    Total Steps in Suite : ${totalStepCount}    console=False
    ${tmpFinalStepResult}=    Create List
    ${tsIndex}=    Set Variable    1
    Log    Initial Step Result List : ${tmpStepResult}    console=False

    WHILE    ${tsIndex} < ${totalStepCount+1}
        FOR    ${tmpStepResult-item}    IN    @{tmpStepResult}
            IF    ${tmpStepResult-item} == []
                ${StepDict}=    Create Dictionary    Step-${tsIndex}=FAIL|0000-00-00T00:00:00|"FAIL"
                Log    ${StepDict}    console=False
                Append To List    ${tmpFinalStepResult}    ${StepDict}
                ${tsIndex}=    Evaluate    ${tsIndex} + 1
            ELSE
                FOR    ${step}    IN    @{tmpStepResult-item}
                    Log    ${step}    console=False
                    ${StepDict}=    Create Dictionary    Step-${tsIndex}=${step}
                    Log    ${StepDict}    console=False
                    Append To List    ${tmpFinalStepResult}    ${StepDict}
                    ${tsIndex}=    Evaluate    ${tsIndex} + 1
                END
            END
        END
    END
    Log    \n\nFinal Step Result List : ${tmpFinalStepResult}    console=False
    ${tmpName}=    Split String    ${dataTCName}    separator=:
    ${tmpCompletionMessage}=    Set Result Conclusion Message    ${tmpFinalStepResult}    ${totalStepCount}
    @{tmpDDResult}=    Create List
    ...    ${tmpName}[1]
    ...    ${SUITE_STATUS}
    ...    ${tmpCompletionMessage}
    ...    ${0}
    ...    ${tmpFinalStepResult}
    &{testCaseResultDict}=    Create Dictionary    ${tmpName}[0]=${tmpDDResult}
    RETURN    ${testCaseResultDict}

Format Test Results for Data Driven Tests
    [Documentation]    Keyword to create test results dictionary for data driven tests to be used in CodeBeamer Test Run creation.
    [Tags]    internal    codebeamer    reporting    p1
    # Log To Console    ${dataTCName}
    ${tmpName}=    Split String    ${dataTCName}    separator=:
    @{tmpDDResult}=    Create List    ${tmpName}[1]    ${SUITE_STATUS}    ${SUITE_MESSAGE}    ${0}    ${tmpStepResult}
    &{testCaseResultDict}=    Create Dictionary    ${tmpName}[0]=${tmpDDResult}
    Log    ${testCaseResultDict}
    RETURN    ${testCaseResultDict}

Set Result Conclusion Message
    [Documentation]    Keyword to create conclusion message for test case result based on step results.
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${stepResult}    ${stepCount}
    ${resultStr}=    Catenate    ${stepResult}
    ${totalFaild}=    Get Count    ${resultStr}    FAIL|
    ${totalNotRun}=    Get Count    ${resultStr}    NOT RUN|
    ${passCount}=    Get Count    ${resultStr}    PASS|
    IF    '${SUITE_STATUS}'=='FAIL'
        ${tmpCompletionMessage}=    Set Variable
        ...    Test Case Execution Failed. Total Steps:${stepCount}, Passed Steps:${passCount}, Failed Steps:${totalFaild}, Not Run Steps:${totalNotRun}. For more details, please refer to the Test Automation Execution Log File.
    ELSE
        ${tmpCompletionMessage}=    Set Variable
        ...    All steps executed successfully.Total Steps:${stepCount}, Passed Steps:${passCount}, Failed Steps:${totalFaild}, Not Run Steps:${totalNotRun}
    END
    RETURN    ${tmpCompletionMessage}

Create Test Run Payload
    [Documentation]    Keyword to create payload for creating Test Run in CodeBeamer with test cases and their results.
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${testCaseResultDict}
    Log    \n\nCreating payload for TestRun creation in CodeBeamer...    console=Yes
    Log    ${testCaseResultDict}
    ${tcListLength}=    Get Length    ${tcList}
    IF    ${tcListLength} == 0
        FOR    ${key}    ${value}    IN    &{testCaseResultDict}
            ${resultLength}=    Get Length    ${value}
            IF    ${resultLength} == 5
                ${tmpTRunBody}=    Create Dictionary    id=${key}    name=${value}[0]    type=TrackerItemReference
                Append To List    ${tcList}    ${tmpTRunBody}
            ELSE
                Log    Skipping malformed CodeBeamer result for test case ${key}: ${value}    console=Yes
            END
        END
    END
    FOR    ${key}    ${value}    IN    &{testCaseResultDict}
        ${resultLength}=    Get Length    ${value}
        Continue For Loop If    ${resultLength} != 5
        ${tmpTRunBody}=    Create Dictionary    id=${key}    name=${value}[0]    type=TrackerItemReference
        ${tmpResult}=    Get From Dictionary    ${codeBeamerResultEnum}    ${value}[1]
        ${testCaseResult}=    Create Dictionary
        ...    testCaseReference=${tmpTRunBody}
        ...    result=${tmpResult}
        ...    conclusion=${value}[2]
        ...    runTime=${value}[3]
        Log    ${testCaseResult}
        Set Suite Variable    ${testCaseResult}
        Append To List    ${tmpTCResult}    ${testCaseResult}
        Log    ${value}
        IF    "${tmpResult}"=="FAILED"
            ${bugList}=    Create Defect List    ${key}    ${value}
            ${tmpBugRef}=    Create Dictionary    id=${bugList}[${key}]
            @{tmpBugRefList}=    Create List    ${tmpBugRef}
            Set To Dictionary    ${testCaseResult}    reportedBugReferences=${tmpBugRefList}
        ELSE
            ${bugList}=    Set Variable    ${None}
        END
        Log    ${bugList}
    END

Associate Custom Report Link To Test Run
    [Documentation]    Keyword to associate custom report links to the main test run instance in CodeBeamer.
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${hiddenRun}    ${PipelineID}    ${testCaseID}
    ${reportURL}=    Set Variable    https://code.mdtcreate.com/crdn/-/aurora/artf/-/jobs/${CI_JOB_ID}/artifacts/Reports/CustomReports/${testCaseID}.html
    ${tmpFromDict}=    Create Dictionary    id=${hiddenRun}    type=TrackerItemReference
    ${tmpRelationType}=    Create Dictionary    id=4    name=related
    ${ReportAssociationBody}=    Create Dictionary
    ...    name=Automation Test Report
    ...    description=Custom Report Link for Automation Test Run-${hiddenRun}
    ...    descriptionFormat=PlainText
    ...    url=${reportURL}
    ...    from=${tmpFromDict}
    ...    type=${tmpRelationType}
    Log    ${ReportAssociationBody}  
    ${tmpJSON}=    Convert Json To String    ${ReportAssociationBody}
    Log    ${tmpJSON}
    ${ReportAssociationResponse}=    Run Keyword And Ignore Error
    ...    POST On Session
    ...    url=https://crdn.codebeamer.com/rest/v3/associations
    ...    alias=cb
    ...    json=${ReportAssociationBody}
    ...    expected_status=200
    ...    msg=TestRun-Report Association creation failed..check logs for further debugging
    Log    ${ReportAssociationResponse}

Upload Custom Report To Test Run
    [Documentation]    Upload the locally generated custom HTML report to a CodeBeamer test-run item.
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${testRunID}    ${testCaseID}
    ${reportPath}=    Set Variable    ${OUTPUTDIR}${/}CustomReports${/}${testCaseID}.html
    File Should Exist    ${reportPath}
    ${reportFile}=    Create Zip Attachment    ${reportPath}    ${testCaseID}.zip
    &{uploadFiles}=    Create Dictionary    attachments=${reportFile}
    ${uploadResponse}=    POST On Session
    ...    url=https://crdn.codebeamer.com/api/v3/items/${testRunID}/attachments
    ...    alias=cb
    ...    files=${uploadFiles}
    ...    expected_status=200
    ...    msg=Uploading custom report ${reportPath} to TestRun ${testRunID} failed
    ${uploadedAttachments}=    Set Variable    ${uploadResponse.json()}
    Should Not Be Empty    ${uploadedAttachments}
    Log    Uploaded local custom report ${reportPath} to TestRun ${testRunID}.    console=Yes
    RETURN    ${uploadResponse}

Create Defect List
    [Documentation]    Keyword to get the list of defects created during the test run.
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${key}    ${value}
    Log     ${value}
    Log     ${value}[2]
    Log     ${value}[-1]
    @{errorStrings}=    Create List
    IF    ${value}[-1] == []
        Append To List   ${errorStrings}    ${value}[2]
    ELSE
        FOR    ${newErrorString}    IN    @{value}[-1]
            Log    New Error String: ${newErrorString}
            ${tmpErrorString}=    Get Dictionary Values    ${newErrorString}
            ${tmpErrorString}=    Split String    ${tmpErrorString}[0]    separator=|
            IF  'FAIL' in ${tmpErrorString} 
                ${tmpErrorString}=    Set Variable    ${tmpErrorString}[-1]
                Append To List    ${errorStrings}    ${tmpErrorString}
            ELSE
            Continue For Loop
            END
        END      
    END
    Log   ${errorStrings}    console=False
   
    ${associatedItems}=    GET On Session
    ...    url=https://crdn.codebeamer.com/rest/items/${key}/relations
    ...    alias=${cbsession}
    ${associationID}=    Get Value From Json    ${associatedItems.json()}    $..keyAndId
    ${bugIDList}=    Get Matches    ${associationID}    *DEFECT-*
    ${checkDefectsAssociated}=    Run Keyword And Return Status    Should Not Be Empty    ${bugIDList}
    IF    "${checkDefectsAssociated}" == "True"
        ${existingActiveBug}=    Set Variable    ${EMPTY}
        FOR    ${bug}    IN    @{bugIDList}
            ${tmpDefectKeyString}=    Set Variable If    'AUTODEFECT' in '${bug}'    AUTODEFECT-    DEFECT-
            ${bugID}=    Strip String    ${bug}    characters=${tmpDefectKeyString}
            ${bugDetails}=    GET On Session
            ...    url=https://crdn.codebeamer.com/rest/items/${bugID}
            ...    alias=${cbsession}
            ${bugStatus}=    Get Value From Json    ${bugDetails.json()}    $..status
 
#### NEW BUG IDENTIFICATION LOGIC            
           
            ${bugDescription}=    Get Value From Json    ${bugDetails.json()}    $..description
            Log    \nExisting Bug Details: ID: ${bugID}, Status: ${bugStatus[0]} , Description: ${bugDescription}[0]    console=False
            # ${newErrorStringsList}=    Set Variable    @{value}[-1]
           
            ${exactActiveBug}=    Run Keyword And Return Status    Should Contain Any    ${bugDescription}[0]    @{errorStrings}
            ${bugState}=    Get From Dictionary    ${bugStatus[0]}    name
 
            IF    "${bugState}"=="Closed"
                ${existingActiveBug}=    Set Variable    False
            ELSE
                ${existingActiveBug}=    Set Variable    True
            END
 
            IF    "${existingActiveBug}"=="True" and "${exactActiveBug}"=="True"
                ${openBug}=    Set Variable    ${bugID}
                Exit For Loop
            END
        END
        Log    ${existingActiveBug}
        IF    "${existingActiveBug}"=="True" and "${exactActiveBug}"=="True"
            Log    \nSkipping Bug Creation as existing Active Bug(s) exists : ${openBug}    console=True
            Set To Dictionary    ${bugList}    ${key}    ${openBug}
        ELSE
            ${tmpBugDetected}=    Create Dictionary
            ...    fieldId=10000
            ...    name=Found In Build
            ...    value=${BUILD_ID}
            ...    type=TextFieldValue
            ${bugDetectedList}=    Create List    ${tmpBugDetected}
            ${tmpBugPriority}=    Create Dictionary
            ...    id=3
            ...    name=Normal
            ...    type=ChoiceOptionReference
            ${tmpBugSeverity}=    Create Dictionary
            ...    id=4
            ...    name=Minor
            ...    type=ChoiceOptionReference
            ${tempBugSeverityList}=    Create List    ${tmpBugSeverity}
            ${clean_conclusion}=    Strip Image Markup    ${value}[2]
            ${clean_step_logs}=    Strip Image Markup    ${value}[4]
            ${tmpBugDetails}=    Create Dictionary
            ...    name=[Automation-Bug]: Bug for TC ${key}:${value}[0]
            ...    description=Test Case ${key} Failed! pipeline ID:${PipelineID} Error Message : ${clean_conclusion}. \n Step Logs : ${clean_step_logs}.\nRefer to detailed Logs for more details.
            ...    customFields=${bugDetectedList}
            ...    priority=${tmpBugPriority}
            ...    severities=${tempBugSeverityList}
            ${bugCreation}=    POST On Session
            ...    url=https://crdn.codebeamer.com/rest/v3/trackers/330137/items
            ...    alias=cb
            ...    json=${tmpBugDetails}
            ...    expected_status=200
            ...    msg=Try bug creation
            ${bugID}=    Get Value From Json    ${bugCreation.json()}    $..id
            Log    \n\nBug Created: ${bugID}[0]    console=Yes
            Set To Dictionary    ${bugList}    ${key}    ${bugID}[0]
            Attach Screenshot To Bug    ${bugID}[0]    ${value}[4]
        END
    ELSE
        ${tmpBugDetected}=    Create Dictionary
        ...    fieldId=10000
        ...    name=Found In Build
        ...    value=${BUILD_ID}
        ...    type=TextFieldValue
        ${bugDetectedList}=    Create List    ${tmpBugDetected}
        ${tmpBugPriority}=    Create Dictionary
            ...    id=3
            ...    name=Normal
            ...    type=ChoiceOptionReference
        ${tmpBugSeverity}=    Create Dictionary
            ...    id=4
            ...    name=Minor
            ...    type=ChoiceOptionReference
        ${tempBugSeverityList}=    Create List    ${tmpBugSeverity}
        ${clean_conclusion}=    Strip Image Markup    ${value}[2]
        ${clean_step_logs}=    Strip Image Markup    ${value}[4]
        ${tmpBugDetails}=    Create Dictionary
        ...    name=[Automation-Bug]: Bug for TC ${key}:${value}[0]
        ...    description=Test Case ${key} Failed! pipeline ID:${PipelineID} Error Message : ${clean_conclusion}. \n Step Logs : ${clean_step_logs}.\nRefer to detailed Logs for more details.
        ...    customFields=${bugDetectedList}
        ...    priority=${tmpBugPriority}
        ...    severities=${tempBugSeverityList}
        ${bugCreation}=    POST On Session
        ...    url=https://crdn.codebeamer.com/rest/v3/trackers/330137/items
        ...    alias=cb
        ...    json=${tmpBugDetails}
        ...    expected_status=200
        ...    msg=Try bug creation
        ${bugID}=    Get Value From Json    ${bugCreation.json()}    $..id
        Log    \n\nBug Created: ${bugID}[0]    console=Yes
        Set To Dictionary    ${bugList}    ${key}    ${bugID}[0]
        Attach Screenshot To Bug    ${bugID}[0]    ${value}[4]
    END
    RETURN    ${bugList}
 

Attach Screenshot To Bug
    [Documentation]    Attaches a screenshot embedded in step results to a CodeBeamer bug item.
    ...    Extracts the base64 image from ${step_logs} and uploads it as a multipart attachment.
    ...    Silently skips if no image is found.
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${bug_id}    ${step_logs}
    ${image_data}=    Extract Image For Upload    ${step_logs}
    IF    $image_data is not None
        ${tmpUploadContent}=    Create Dictionary    attachments=${image_data}
        Run Keyword And Ignore Error
        ...    POST On Session
        ...    url=https://crdn.codebeamer.com/api/v3/items/${bug_id}/attachments
        ...    alias=cb
        ...    files=${tmpUploadContent}
        ...    expected_status=200
        ...    msg=Screenshot attachment upload to bug ${bug_id} failed
        Log    Screenshot attached to bug ${bug_id}    console=Yes
    END

Create CB Session
    [Documentation]    Keyword to create a session with CodeBeamer server.
    [Tags]    internal    codebeamer    reporting    p1
    ${cbsession}=    Create Session
    ...    cb
    ...    https://crdn.codebeamer.com
    ...    auth=${tmpCodeBeamerCreds}
    ...    disable_warnings=1
    Set Suite Variable    ${cbsession}

Create Master Test Run
    [Documentation]    Keyword to create Test Run in codebeamer with list of Test Cases that are being executed. This is used as a Suite Teardown keyword to update the results for individual test cases and finally update the test run instance and close it.
    [Tags]    internal    codebeamer    reporting    p1    teardown
    [Arguments]    ${testCaseResultDict}
    ${tcRunNameObj}=    Create Dictionary    name=${cbTestRunName}
    ${finalTestRunBody}=    Create Dictionary    testCaseIds=@{tcList}    testRunModel=${tcRunNameObj}
    Log    ${finalTestRunBody}
    Log    \n\nCreating a new TestRun instance in CodeBeamer with executed TestCases added...    console=Yes
    ${createTestRunStatus}    ${createTestRunOut}=    Run Keyword And Ignore Error
    ...    POST On Session
    ...    url=https://crdn.codebeamer.com/rest/v3/trackers/261965/testruns
    ...    alias=cb
    ...    json=${finalTestRunBody}
    ...    expected_status=200
    ...    msg=TestRun creation failed..check logs for further debugging
    IF    '${createTestRunStatus}' == 'PASS'
        ${createRunResponseText}=    Set Variable    ${createTestRunOut.json()}
        Log    ${createRunResponseText}
        ${runIdList}=    Run Keyword And Ignore Error    Get Value From Json    ${createRunResponseText}    $..id
        IF    '${runIdList}[0]' == 'PASS'
            ${testRunID}=    Set Variable    ${runIdList}[1]
            Log    \n\nThe TestRun instance created is: ${testRunID}[0]    console=Yes
            Update Test Config Information    ${cbTestRunName}    ${testRunID}[0]
            RETURN    ${createTestRunOut}    ${testRunID}[0]
        ELSE
            Log    \nCodeBeamer Test Run request returned no run ID. Check the configured credentials and tracker permissions.    console=Yes
            RETURN    ${createTestRunOut}    ${None}
        END
    ELSE
        Log    \nCodeBeamer Test Run request failed before creation. This usually means the configured credentials are invalid or the user lacks permissions for tracker 261965.    console=Yes
        Log    ${createTestRunOut}    console=Yes
        RETURN    ${None}    ${None}
    END

Identify Internal Test Run Instances
    [Documentation]    Keyword to identify hidden test run instances created as children of the main test run instance in CodeBeamer.
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${createTestRunOut}    ${testCaseResultDict}
    ${HiddentestRuns}=    Get Value From Json    ${createTestRunOut.json()}    $..children
    Log    \n\nThe Hidden TestRun instances created are: ${HiddentestRuns}
    RETURN    ${HiddentestRuns}

Update Test Step Results
    [Documentation]    Keyword to update individual test step results for a test case in CodeBeamer.
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${HiddentestRuns}    ${testCaseResultDict}
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
        &{TCStepResultSet}=    Create Dictionary
        ${tmpCBResult1}=    Get From Dictionary    ${testCaseResultDict}    ${testCaseID}
        ${tmpCBResult2}=    Set Variable    @{tmpCBResult1}[4]
        ${listStatus}=    Get Length    ${tmpCBResult2}
        Set Suite Variable    ${testLogFileMessage}    ${EMPTY}
        IF    "${listStatus}" != "0"
            IF    "${listStatus}" == "1"
                Log Dictionary    ${tmpCBResult2}
                ${key}=    Get Dictionary Keys    ${tmpCBResult2}
                ${value}=    Get From Dictionary    ${tmpCBResult2}    ${key}[0]
                Set To Dictionary    ${TCStepResultSet}    ${key}[0]    ${value}
            ELSE
                FOR    ${step}    IN    @{tmpCBResult2}
                    FOR    ${key}    ${value}    IN    &{step}
                        Set To Dictionary    ${TCStepResultSet}    ${key}    ${value}
                    END
                END
            END
        END
        Log Dictionary    ${TCStepResultSet}
        ${stepResultStatus}=    Get Length    ${TCStepResultSet}
        Continue For Loop If    "${stepResultStatus}"=="${0}"
        ${tmpRunName}=    Get Value From Json    ${hiddenTestRunResponse.json()}    $..name
        ${hiddenTestRunName}=    Set Variable    ${tmpRunName}[0]
        ${actualResultObject}=    Get Value From Json    ${hiddenTestRunResponse.json()}    $..customFields
        FOR    ${resultObject}    IN    @{actualResultObject}
            FOR    ${tmpOnject}    IN    @{resultObject}
                ${fieldID}=    Get From Dictionary    ${tmpOnject}    fieldId
                ${resultList}=    Create List
                IF    "${fieldID}" == "2000000"
                    ${tmpTCStepResults}=    Get From Dictionary    ${tmpOnject}    values
                    Log    ${tmpTCStepResults}
                    ${testStepsCount}=    Get Length    ${tmpTCStepResults}
                    FOR    ${tmpStepResultCounter}    IN RANGE    ${0}    ${testStepsCount}
                        ${tmpStepResultList}=    Create List
####### Try invalid keys
                        ${tmpCBResultKeyStatus}=    Run Keyword And Return Status
                        ...    Dictionary Should Contain Key
                        ...    ${TCStepResultSet}
                        ...    Step-${tmpStepResultCounter+1}
                        IF    "${tmpCBResultKeyStatus}" == "True"
                            ${tmpCBResult}=    Get From Dictionary
                            ...    ${TCStepResultSet}
                            ...    Step-${tmpStepResultCounter+1}
                            ${splitResult}=    Split String    ${tmpCBResult}    separator=|
                            ${translatedStepResult}=    Get From Dictionary
                            ...    ${codeBeamerResultEnum}
                            ...    ${splitResult}[0]
                            ${timeStamp}=    Strip String    ${splitResult}[1]
                        ELSE
                            ${tmpStepTime}=    Get Time    format=YYYY-MM-DDThh:mm:ss
                            ${splitStepTime}=    Replace String    ${tmpStepTime}    ${SPACE}    T
                            ${tmpCBResult}=    Set Variable    Unknown|${splitStepTime}
                            ${splitResult}=    Split String    ${tmpCBResult}    separator=|
                            ${translatedStepResult}=    Get From Dictionary
                            ...    ${codeBeamerResultEnum}
                            ...    ${splitResult}[0]
                            ${timeStamp}=    Strip String    ${splitResult}[1]
                        END
### TRY String
                        IF    "${translatedStepResult}"=="FAILED"
                            ${stepconclusion}=    Set Variable    ${splitResult}[2]
                            ${actualResultString}=    Set Variable
                            ...    Step-${tmpStepResultCounter+1}: ${stepconclusion}.${testLogFileMessage}
                        ELSE IF    "${translatedStepResult}"=="Not Run/Pending"
                            ${actualResultString}=    Set Variable
                            ...    Step-${tmpStepResultCounter+1}: Test Step Not updated with results as Keyword mapping details missing.${testLogFileMessage}
                        ELSE IF    "${translatedStepResult}"=="BLOCKED"
                            ${actualResultString}=    Set Variable
                            ...    Step-${tmpStepResultCounter+1}: Test Step Blocked due to previous step failure.${testLogFileMessage}
                        ELSE
                            ${actualResultString}=    Set Variable
                            ...    Step-${tmpStepResultCounter+1}: ${splitResult}[2]${testLogFileMessage}
                        END

                        ${tmpStepActualResultBody}=    Create Dictionary
                        ...    fieldId=2000004
                        ...    name=Actual result
                        ...    value=${actualResultString}
                        ...    type=WikiTextFieldValue
                        ${tmpStepResultBody}=    Create Dictionary
                        ...    fieldId=2000005
                        ...    name=Result
                        ...    value=${translatedStepResult}
                        ...    type=TextFieldValue
                        ${tmpStepRunByDetails}=    Create Dictionary
                        ...    id=121
                        ...    name=craft-runner
                        ...    type=UserReference
                        ...    email=karvec2@medtronic.com
                        ${tmpStepRunByList}=    Create List    ${tmpStepRunByDetails}
                        ${tmpSharedFieldNames}=    Create List
                        ${tmpStepRunByBody}=    Create Dictionary
                        ...    fieldId=2000006
                        ...    name=Run by
                        ...    values=${tmpStepRunByList}
                        ...    type=ChoiceFieldValue
                        ...    sharedFieldNames=${tmpSharedFieldNames}
                        ${tmpStepRunAtBody}=    Create Dictionary
                        ...    fieldId=2000007
                        ...    name=Run at
                        ...    value=${timeStamp}.000
                        ...    type=DateFieldValue
                        ...    sharedFieldNames=${tmpSharedFieldNames}
                        Append To List
                        ...    ${tmpTCStepResults}[${tmpStepResultCounter}]
                        ...    ${tmpStepActualResultBody}
                        ...    ${tmpStepResultBody}
                        ...    ${tmpStepRunByBody}
                        ...    ${tmpStepRunAtBody}
                        Append To List    ${resultList}    ${tmpTCStepResults}[${tmpStepResultCounter}]
                    END
                    Log    ${resultList}
                END
            END
            ${tmpExp}=    Catenate    ${resultList}
            ${customFieldUpdateBody}=    Create Dictionary
            ...    fieldId=${fieldID}
            ...    name=Test Step Results
            ...    values=${resultList}
            ...    type=TableFieldValue
            ${customFieldList}=    Create List    ${customFieldUpdateBody}
        END
        ${hiddenTestRunUpdateBody}=    Create Dictionary
        ...    id=${hiddenTestRunID}
        ...    name=${hiddenTestRunName}
        ...    customFields=${customFieldList}
        Log    ${hiddenTestRunUpdateBody}
        ${tmpUpdateTestStepUpdateResponse}=    PUT On Session
        ...    url=https://crdn.codebeamer.com/rest/v3/items/${hiddenRun}[id]
        ...    alias=cb
        ...    json=${hiddenTestRunUpdateBody}
        ...    expected_status=200
        ...    msg=Updating TestRun ${hiddenTestRunID} with Test Step Results Failed..check logs for further debugging
        # Associate Bug to Test Run    ${hiddenRun}    ${bugList}    ${testCaseID}
        IF    "${CI_JOB_ID}" == "NotApplicable"
            Upload Custom Report To Test Run    ${hiddenRun}[id]    ${testCaseID}
        ELSE
            Associate Custom Report Link To Test Run    ${hiddenRun}[id]    ${PipelineID}    ${testCaseID}
        END
        Update Test Config Information    ${hiddenTestRunName}    ${hiddenTestRunID}
    END

###################################################################

Associate Bug to Test Run
    [Documentation]    Keyword to associate bugs created during the test run to the main test run instance in CodeBeamer.
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${hiddenRun}    ${bugList}    ${testCaseID}
    ${bugListStatus}=    Run Keyword And Return Status    Should Not Be Empty    ${bugList}
    IF    "${bugListStatus}"=="False"
        Log    "No bugs found for the test case"
    ELSE
        ${getBugID}=    Get From Dictionary    ${bugList}    ${testCaseID}
        ${tmpFromDict}=    Create Dictionary    id=${getBugID}    type=TrackerItemReference
        ${tmpToDict}=    Create Dictionary    id=${hiddenRun}[id]    type=TrackerItemReference
        ${tmpToTCDict}=    Create Dictionary    id=${testCaseID}    type=TrackerItemReference
        ${tmpRelationType}=    Create Dictionary    id=1    name=related
        ${tmpTCRelationType}=    Create Dictionary    id=1    name=child
        ${TRassociationBody}=    Create Dictionary
        ...    name=Automation Bug
        ...    description=Bug Reported from Automation Test Run-${hiddenRun}[id]
        ...    descriptionFormat=PlainText
        ...    from=${tmpFromDict}
        ...    to=${tmpToDict}
        ...    type=${tmpRelationType}
        ...    propagatingSuspects=true
        ...    biDirectionalPropagation=true
        ...    propagatingDependencies=true
        ${TCassociationBody}=    Create Dictionary
        ...    name=Automation Bug
        ...    description=Bug Reported from Automation Test Run-${hiddenRun}[id]
        ...    descriptionFormat=PlainText
        ...    from=${tmpFromDict}
        ...    to=${tmpToTCDict}
        ...    type=${tmpTCRelationType}
        ...    propagatingSuspects=true
        ...    biDirectionalPropagation=true
        ...    propagatingDependencies=true
        ${tmpBugTRAssocitationReponse}=    Run Keyword And Ignore Error
        ...    POST On Session
        ...    url=https://crdn.codebeamer.com/rest/v3/associations
        ...    alias=cb
        ...    json=${TRassociationBody}
        ...    expected_status=200
        ...    msg=TestRun-Bug Association creation failed..check logs for further debugging
        ${tmpBugTRAssocitationReponse}=    Run Keyword And Ignore Error
        ...    POST On Session
        ...    url=https://crdn.codebeamer.com/rest/v3/associations
        ...    alias=cb
        ...    json=${TCassociationBody}
        ...    expected_status=200
        ...    msg=TestRun-Bug Association creation failed..check logs for further debugging
    END

Update Test Config Information
    [Documentation]    Keyword to update the Test Run instance created in CodeBeamer with Test
    [Tags]    internal    codebeamer    reporting    p1
    [Arguments]    ${tmpSuiteName}    ${tmpRunID}
    ${testConfigs}=    GET On Session    url=https://crdn.codebeamer.com/rest/v3/trackers/261904/items/    alias=cb
    @{testConfig}=    Get Value From Json    ${testConfigs.json()}    $..name
    ${testConfigIndex}=    Get Index From List    ${testConfig}    ${testConfigName}
    ${testConfigID}=    Get Value From Json    ${testConfigs.json()}    $.itemRefs.[${testConfigIndex}].id
    ${tmpPropogate}=    Create Dictionary    suspectPropagation=DO_NOT_PROPAGATE
    ${refData}=    Create Dictionary    referenceData=${tmpPropogate}
    Log    ${refData}
    ${tmpPlatformBody}=    Create Dictionary
    ...    id=${testConfigID}[0]
    ...    name=${testConfigName}
    ...    type=TrackerItemReference
    ...    angularIcon=settings
    ...    iconColor=#00a85d
    ...    propagateSuspects=false
    ...    trackerKey=TESTCONF
    ...    trackerTypeId=16
    ...    uri=/item/${testConfigID}[0]
    ...    referenceData=${tmpPropogate}
    ${tmpPlatformList}=    Create List    ${tmpPlatformBody}
    ${tmpSharedField}=    Create List
    ${tmpBuildNumberID}=    Create Dictionary
    ...    fieldId=10003
    ...    name=AuroraApps_Build_Number
    ...    value=${BUILD_ID}
    ...    sharedFieldNames=${tmpSharedField}
    ...    type=TextFieldValue
    ${tmpExecutionID}=    Create Dictionary
    ...    fieldId=10005
    ...    name=PipelineID
    ...    value=${PipelineID}
    ...    sharedFieldNames=${tmpSharedField}
    ...    type=TextFieldValue
    ${tmpCustomFieldList}=    Create List    ${tmpBuildNumberID}    ${tmpExecutionID}
    ${tmpStepRunByDetails}=    Create Dictionary
    ...    id=121
    ...    name=craft-runner
    ...    type=UserReference
    ...    email=karvec2@medtronic.com

    ${tmpPlatformsBody}=    Create Dictionary
    ...    name=${tmpSuiteName}
    ...    platforms=${tmpPlatformList}
    ...    customFields=${tmpCustomFieldList}
    Log    ${tmpPlatformsBody}
    ${tmpUpdateTestConfigResponse}=    PUT On Session
    ...    url=https://crdn.codebeamer.com/rest/v3/items/${tmpRunID}
    ...    alias=cb
    ...    json=${tmpPlatformsBody}
    ...    expected_status=200
    ...    msg=Updating TestRun ${tmpRunID} with Test Configuration and Build Number failed..check logs for further debugging

Update Test Run with Test Case Results and Close
    [Documentation]    Keyword to update the Test Run instance created in CodeBeamer with results for individual test cases and close the Test Run instance.
    [Tags]    internal    codebeamer    reporting    p1    teardown
    [Arguments]    ${testRunID}
    sleep    5s    reason=Waiting for Test Run in CodeBeamer to be active before updating results..
    # Log    ${bugList}
    # ${bugIDs}=    Get Dictionary Values    ${bugList}
    # ${reportedBugRef}=    Create List
    # FOR    ${bugID}    IN    @{bugIDs}
    #    ${tmpBugRef}=    Create Dictionary    id=${bugID}
    #    Append To List    ${reportedBugRef}    ${tmpBugRef}
    # END
    # ${tmpBugRefStruct}=    Create Dictionary    reportedBugReferences=${reportedBugRef}
    # Append To List    ${tmpTCResult}    ${tmpBugRefStruct}
    ${tmpTCResultBodyFinal}=    Create Dictionary    updateRequestModels=${tmpTCResult}    parentResultPropagation=true
    Log    ${tmpTCResultBodyFinal}
    Log    \n\nUpdating ${testRunID} TestRun instance with results for individual test cases...    console=Yes
    ${tmpUpdateTRunResponse}=    PUT On Session
    ...    url=https://crdn.codebeamer.com/rest/v3/testruns/${testRunID}
    ...    alias=cb
    ...    json=${tmpTCResultBodyFinal}
    ...    expected_status=200
    ...    msg=Updating TestRun ${testRunID} with results failed..check logs for further debugging
    Log    \n\nThe TestRun instance ${testRunID} updated with TC results and Closed    console=Yes
    Log    https://crdn.codebeamer.com/issue/${testRunID}    html=True    console=False
    ${SUITE NAME}=    Catenate    ${SUITE NAME}    https://crdn.codebeamer.com/issue/${testRunID}
    IF    "${CI_JOB_ID}" == "NotApplicable"
        FOR    ${tcResult}    IN    @{tmpTCResult}
            Upload Custom Report To Test Run    ${testRunID}    ${tcResult}[testCaseReference][id]
        END
    ELSE
        FOR    ${tcResult}    IN    @{tmpTCResult}
        Associate Custom Report Link To Test Run    ${testRunID}    ${PipelineID}    ${tcResult}[testCaseReference][id]    
        END
    END

Get Test Start Time
    [Tags]    teardown
    ${start_time}=    Get Time    format=epoch
    Set Suite Variable    ${start_time}

Get Total Test Cases
    [Documentation]    Keyword to get the total number of test cases from the CSV file.
    [Tags]    internal    datadriven
    @{totalTests}=    Get Variable Value    @{DataDriver_DATA_LIST}
    ${totalTCs}=    Get Length    ${totalTests}
    Log    \n\nThe Total Test Cases to be created are: ${totalTCs}    console=True
    Set Suite Variable    ${totalTCs}

Collect Test Result
    [Tags]    teardown
    IF    '${cbEnabled}'.lower() == 'true'
        ${end_time}=    Get Time    format=epoch
        ${duration}=    Evaluate    ${end_time}-${start_time}
        ${tmptestCaseID}=    Split String    ${TEST_NAME}    separator=:
        ${testCaseID}=    Set Variable    ${tmptestCaseID}[0]
        Log    ${TCResults}
        # Log To Console    ${SuiteType}
        IF    "${SuiteType}" == "datadriven"
            Log    \nSkip Processing Data Driven TC Results here...    console=False
        ELSE
            @{tmpTCSteps}=    Create List
            IF    ${TCResults}
                FOR    ${result}    IN    @{TCResults}
                    IF    "${result}[0]"=="${testCaseID}"
                        Append To List    ${tmpTCSteps}    ${result}[1]
                    END
                END
                Log List    ${tmpTCSteps}
                ${resultStr}=    Catenate    ${TCResults}
                ${stepCount}=    Get Length    ${TCResults}
                ${totalFaild}=    Get Count    ${resultStr}    FAIL|
                ${totalNotRun}=    Get Count    ${resultStr}    NOT RUN|
                ${passCount}=    Get Count    ${resultStr}    PASS|
                IF    '${TEST_STATUS}'=='FAIL'
                    ${tmpCompletionMessage}=    Set Variable
                    ...    Test Case Execution Failed: ${Test Message}. Total Steps:${stepCount}, Passed Steps:${passCount}, Failed Steps:${totalFaild}, Not Run Steps:${totalNotRun}. Please refer to Test Automation Log Files for more details.
                ELSE
                    ${tmpCompletionMessage}=    Set Variable
                    ...    All steps executed successfully.Total Steps:${stepCount}, Passed Steps:${passCount}, Failed Steps:${totalFaild}, Not Run Steps:${totalNotRun}
                END
            ELSE
                ${tmpCompletionMessage}=    Set Variable
                ...    Test Setup Failed: ${Test Message}. No Test Steps executed. Check logs for more details.
            END

            @{tmpTC}=    Create List
            ...    ${tmptestCaseID}[1]
            ...    ${TEST STATUS}
            ...    ${tmpCompletionMessage}
            ...    ${duration}
            ...    ${tmpTCSteps}
            Set To Dictionary    ${testCaseResultDict}    ${testCaseID}=${tmpTC}
            Log    \n\nAdded ${TEST NAME} status and result in master suite execution list    console=Yes
            Log Dictionary    ${testCaseResultDict}
            Log
            ...    \n\nAdded ${TEST NAME} and its Test Step status and results in master suite execution list
            ...    console=Yes
        END
    ELSE
        Log    \nCollect Test Result skipped because posting to CodeBeamer is disabled.    console=Yes
    END
