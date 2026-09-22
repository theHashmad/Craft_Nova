*** Settings ***
Library     RequestsLibrary
Library     JSONLibrary
Library     Collections
Library     String
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
&{testCaseResultDict}           &{EMPTY}
&{testCaseStepResultDict}       &{EMPTY}
@{tmpTCResult}                  @{EMPTY}
&{codeBeamerResultEnum}         PASS=PASSED    FAIL=FAILED    Unknown=Not Run/Pending    NOT RUN=BLOCKED
&{bugList}                      &{EMPTY}
${openBug}                      ${EMPTY}


*** Keywords ***
# Placeholder: canonical content is maintained under resources/keywords/Keyword_Codebeamer.robot
# This duplicate was restored to revert previous consolidation changes.
