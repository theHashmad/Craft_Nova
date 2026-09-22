*** Settings ***
Library    Collections

*** Keywords ***
Log To Console And Report
    [Documentation]    Logs given `message` at specified `log_level` to log file and if `console` is set to True
    ...                it also logs `message` to console with INFO level. If global log_level is set to `DEBUG`, then
    ...                both logging actions take place, regardless of `console` value.
    [Arguments]    ${message}    ${level}=INFO    ${console}=${True}
    [Tags]    internal
    Log    ${message}    level=${level}

    IF    '${LOG_LEVEL}' != 'DEBUG'
        Run Keyword If    ${console}    Log To Console    ${message}
    ELSE
        Log To Console    ${message}
    END

Run With Recovery
    [Documentation]    Runs a keyword with retries. Retries 3 times with 5-second interval.
    [Tags]    internal
    [Arguments]    ${keyword_name}    @{args}
    Wait Until Keyword Succeeds    3x    5s    Run Keyword    ${keyword_name}    @{args}

Retry With Recovery
    [Documentation]    Retries ${keyword} up to ${retries} times. After each failure, ${recovery_keyword} is executed
    ...    before the next attempt instead of just waiting passively.
    ...    Pass arguments as Python lists: keyword_args=${{'['arg1', 'arg2']'}}  recovery_args=${{'['arg1']'}}
    [Tags]    internal
    [Arguments]    ${keyword}    ${recovery_keyword}    ${retries}=3    ${retry_delay}=5s    ${keyword_args}=${None}    ${recovery_args}=${None}
    ${kw_args}=     Run Keyword If    $keyword_args is None    Create List    ELSE    Set Variable    ${keyword_args}
    ${rec_args}=    Run Keyword If    $recovery_args is None    Create List    ELSE    Set Variable    ${recovery_args}
    FOR    ${attempt}    IN RANGE    1    ${retries} + 1
        TRY
            Run Keyword    ${keyword}    @{kw_args}
            RETURN
        EXCEPT    AS    ${error}
            Log    Attempt ${attempt} of ${retries} for '${keyword}' failed: ${error}    level=WARN    console=True
            IF    ${attempt} < ${retries}
                Log    Running recovery: '${recovery_keyword}'...    console=True
                Run Keyword And Ignore Error    Run Keyword    ${recovery_keyword}    @{rec_args}
                Sleep    ${retry_delay}
            END
        END
    END
    Fail    '${keyword}' still failing after ${retries} attempt(s).

Document Keyword Outcome
    [Documentation]    This keyword documents the outcome of a TRY block.
    [Tags]    internal
    [Arguments]    ${outcome}
    # ${KEYWORD_STATUS} holds status of the parent keyword if used in [Teardown] tag.
    IF    '${KEYWORD_STATUS}' == 'PASS'
        ${tmp_message}=    Set Variable    ${outcome}
    ELSE
        ${tmp_message}=    Set Variable    ${KEYWORD_MESSAGE}
    END
    VAR    ${keyword_result_message}=    ${tmp_message}    scope=GLOBAL

Get OS name
    [Documentation]    Returns OS name on which it is being run.
    [Tags]    internal
    ${system}=    Evaluate    platform.system()    platform

    RETURN    ${system}

Get Current User Home Directory
    [Documentation]    Returns path to current user home directory.
    [Tags]    internal
    ${home_path}=    Evaluate    pathlib.Path.home().as_posix()    pathlib

    RETURN    ${home_path}

Normalize file data value
    [Documentation]    It sanitizes data coming from CSV file. Its making sure that e.g. ${None} string is converted to python
    ...                *None* value.
    ...                ---
    ...                - *Date of Implementation:* 14-OCT-2025
    ...                - *Author:* Mateusz Rosiek
    ...                ---
    [Arguments]    ${value}
    [Tags]    internal

    ${result}=    Run Keyword If    '${value}' == '${None}'    Set Variable    ${None}
    ...    ELSE IF    '${value}' == '${True}'    Set Variable    ${True}
    ...    ELSE IF    '${value}' == '${EMPTY}'    Set Variable    ${EMPTY}
    ...    ELSE    Set Variable    ${value}
    RETURN    ${result}

Calculate Days Difference
    [Documentation]    Calculates difference in days between two dates. It accepts dates in format "YYYY MM DD".
    ...    - *Date of Implementation:* 03-03-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:*    \${diff_days}=    Calculate Days Difference    2026 02 15    2026 02 16
    ...    - *Returns:*    Number of days between date1 and date2. If date2 is earlier than date1, it returns negative value.
    [Tags]    internal
    [Arguments]    ${date1}    ${date2}
    ${date1_obj}=    Evaluate    datetime.date(*(time.strptime("${date1}", "%Y %m %d")[0:3]))   modules=datetime,time
    ${date2_obj}=    Evaluate    datetime.date(*(time.strptime("${date2}", "%Y %m %d")[0:3]))   modules=datetime,time
    ${difference}=    Evaluate    ($date2_obj - $date1_obj).days

    RETURN    ${difference}

Validate Date Argument
    [Documentation]    Validates that date is provided in format YYYY MM DD and is a real calendar date.
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:*    Validate Date Argument    2026 02 45
    [Tags]    internal
    [Arguments]    ${date}

    Should Match Regexp
    ...    ${date}
    ...    ^\\d{4}\\s\\d{2}\\s\\d{2}$
    ...    msg=Fail, Invalid date format '${date}'. Expected format: YYYY MM DD.

    TRY
        Evaluate    time.strptime("${date}", "%Y %m %d")    modules=time
    EXCEPT    AS    ${err}
        Fail    msg=Fail, Invalid calendar date '${date}'. Expected a real date in format YYYY MM DD. Details: ${err}
    END

Verify Dictionary Contains Keys
    [Documentation]    Base keyword. Verifies that the given dictionary contains all specified keys.
    ...    - *Date of Implementation:* 13-03-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:*    Accepts a path as a list of keys to traverse, then checks final keys.
    ...                  - `dictionary`    Any dictionary to check
    ...                  - `expected_keys` List of keys expected to exist in the dictionary
    ...    - *Returns:*    N/A
    [Tags]    internal
    [Arguments]    ${dictionary}    @{expected_keys}

    Should Not Be Empty    ${dictionary}    msg=Fail, Dictionary is empty.
    FOR    ${key}    IN    @{expected_keys}
        Dictionary Should Contain Key    ${dictionary}    ${key}
        ...    msg=Fail, '${key}' not found in ${dictionary}.
    END
    [Teardown]    Document Keyword Outcome    Verification Passed: Dictionary (${dictionary}) contained expected keys (${expected_keys}).

Verify Dictionary Key Has Value
    [Documentation]    Verifies that a specific key in a given dictionary has the expected value.
    ...    - *Date of Implementation:* 13-03-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:*    Accepts a path as a list of keys to traverse, then checks final keys.
    ...                  Arguments:
    ...                  - `dictionary`      The dictionary to check
    ...                  - `target_key`      The key to check
    ...                  - `expected_value`  The expected value for the target key
    ...    - *Returns:*  N/A
    [Tags]    internal
    [Arguments]    ${dictionary}    ${target_key}    ${expected_value}

    Dictionary Should Contain Key    ${dictionary}    ${target_key}
    ...    msg=Fail, '${target_key}' not found in dictionary.
    ${actual_value}=    Get From Dictionary    ${dictionary}    ${target_key}
    Should Be Equal    ${actual_value}    ${expected_value}
    ...    msg=Fail, For key '${target_key}' expected value was '${expected_value}' but got '${actual_value}'.
    [Teardown]    Document Keyword Outcome    Verification Passed: Dictionary key '${target_key}' had expected value '${expected_value}' in dictionary (${dictionary}).
    
Verify Nested Dict Contains Keys
    [Documentation]    Recursively verifies nested dictionary structure.
    ...    - *Date of Implementation:* 13-03-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:*    Accepts a path as a list of keys to traverse, then checks final keys.
    ...                  Arguments:
    ...                  - `dictionary`    The starting dictionary
    ...                  - `key_path`      List of keys to traverse down the nesting (e.g. ['level1', 'level2'])
    ...                  - `expected_keys` Keys expected to exist at the final nested level
    ...    - *Returns:*    Final dict which contains expected keys, useful for further validation if needed.
    [Tags]    internal
    [Arguments]    ${dictionary}    ${key_path}    @{expected_keys}

    Should Not Be Empty    ${dictionary}    msg=Fail, Dictionary is empty.
    ${current_dict}=    Set Variable    ${dictionary}

    FOR    ${path_key}    IN    @{key_path}
        Dictionary Should Contain Key    ${current_dict}    ${path_key}
        ...    msg=Fail, '${path_key}' not found while traversing path.
        ${current_dict}=    Get From Dictionary    ${current_dict}    ${path_key}
        Should Not Be Empty    ${current_dict}
        ...    msg=Fail, Value at '${path_key}' is empty or not a dictionary.
    END

    Verify Dictionary Contains Keys    ${current_dict}    @{expected_keys}

    RETURN    ${current_dict}
    [Teardown]    Document Keyword Outcome    Verification Passed: Nested dictionary contained expected keys (${expected_keys} at path: ${key_path}. Final dict: ${current_dict}.

Verify Nested Dict Key Has Value
    [Documentation]    Traverses a nested dictionary structure using a key path and verifies
    ...    that the target key at the final level has the expected value.
    ...    - *Date of Implementation:* 13-03-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:*    Accepts a path as a list of keys to traverse, then checks the value of the target key.
    ...                  Arguments:
    ...                  - `dictionary`      The starting dictionary
    ...                  - `key_path`        List of keys to traverse down the nesting (e.g. ['level1', 'level2'])
    ...                  - `target_key`      The key to check at the final nested level
    ...                  - `expected_value`  The expected value for the target key
    ...    - *Returns:*    Final dict which contains expected keys, useful for further validation if needed.
    [Tags]    internal
    [Arguments]    ${dictionary}    ${key_path}    ${target_key}    ${expected_value}

    ${nested_dict}=    Verify Nested Dict Contains Keys    ${dictionary}    ${key_path}    ${target_key}
    ${actual_value}=    Get From Dictionary    ${nested_dict}    ${target_key}
    Should Be Equal    ${actual_value}    ${expected_value}
    ...    msg=Fail, '${target_key}' expected '${expected_value}' but got '${actual_value}'.

    [Teardown]    Document Keyword Outcome    Verification Passed: Nested dictionary key '${target_key}' had expected value '${expected_value}' at path: ${key_path}. Final dict: ${nested_dict}.

Verify Container Length
    [Documentation]    Verifies that the given container has the expected length.
    ...    Works with any container type: list, dictionary, string, etc.
    ...    - *Date of Implementation:* 13-03-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:*
    ...                  - `container`        The container to check (list, dict, string, etc.)
    ...                  - `expected_length`  The expected length of the container
    ...    - *Returns:*  N/A
    [Tags]    109040=4,5
    [Arguments]    ${container}    ${expected_length}

    ${actual_length}=    Get Length    ${container}
    Should Be Equal As Integers    ${actual_length}    ${expected_length}
    ...    msg=Fail, Expected length '${expected_length}' but got '${actual_length}' for container: ${container}.
    [Teardown]    Document Keyword Outcome    Verification Passed: Container (${container}) had expected length: ${expected_length}.

Wait sec
    [Documentation]
    ...    - *Date of Implementation:* 21-Apr-2026
    ...    - *Author:* Oliwia Maloch
    ...    - *Arguments:* ``seconds`` sec
    ...    - *Returns:*  N/A
    [Tags]    99584=10
    [Arguments]    ${seconds}
    Sleep    ${seconds}
    [Teardown]    Document Keyword Outcome    Verified that ${seconds} sec have passed.