*** Variables ***
@{tmpBodyTCBody}            @{EMPTY}
@{testCaseIds}              @{EMPTY}
@{testCaseResult}           @{EMPTY}
@{testCaseStatus}           @{EMPTY}
@{testCaseMessage}          @{EMPTY}
@{tcList}                   @{EMPTY}
&{testCaseResultDict}       &{EMPTY}
@{tmpTCResult}              @{EMPTY}
&{codeBeamerResultEnum}     PASS=PASSED    FAIL=FAILED
${testConfigName}           sr-lab-kv260-craft1    # this is the default value for test config name used in codebeamer integration, the acutal values should be passed from command line or CI pipeline

${cbUserName}               craft-runner
${cbPwd}                    craft-runner
${cbEnabled}                true    # false / true - to disable posting to codebeamer, usefulwhen developing or debugging etc.
${cbTestRunName}            "CRAFT_NOVA_${SUITE NAME}"
@{tmpCodeBeamerCreds}       ${cbUserName}    ${cbPwd}

