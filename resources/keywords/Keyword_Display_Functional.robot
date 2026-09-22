*** Settings ***
Resource    ../Keywords/Keyword_Display.robot


*** Keywords ***

##################################################################################
########################## Case Screen Keywords ##################################
##################################################################################
    
Get electrode object toggle status after toggling
    [Documentation]    Keyword to toggle on electrode on display
    ...                - *Date of Implementation:* 18-NOV-2025
    ...                - *Author:* Oliwia Maloch
    ...                - *Arguments:* electrode to be toggled: ``electrode``
    ...                - *Returns* toggle state True/False: ``toggle_state``
    [Tags]    internal
    [Arguments]    ${electrode}
    VAR    ${toggle_state}=    False
    ${status_before}=    Element Should Be Visible    ${turnedOff_electrode_${electrode}}
    Click Element    ${electrode${electrode}_Electrode}
    ${status_after}=    Element Should Be Visible    ${turnedOff_electrode_${electrode}}
    Should Not Be Equal    ${status_before}    ${status_after}    msg=Fail, Electrode ${electrode} not toggled
    VAR    ${toggle_state}=    True
    RETURN    ${toggle_state}

Enable electrode
    [Documentation]    Keyword to enable given electrode on display
    ...                - *Date of Implementation:* 18-NOV-2025
    ...                - *Author:* Oliwia Maloch
    ...                - *Arguments:* electrode to be enabled: ``electrode``
    ...                - *Returns* N/A
    [Tags]    internal
    [Arguments]    ${electrode}
    ${status_before}=    Element Should Be Visible    ${turnedOff_electrode_${electrode}}
    IF    ${status_before} == True
        Click Element    ${electrode${electrode}_Electrode}
        ${status_after}=    Element Should Be Visible    ${turnedOff_electrode_${electrode}}
        Should Not Be Equal    ${status_before}    ${status_after}    msg=Fail, Electrode ${electrode} not clicked
    END

Disable electrode
    [Documentation]    Keyword to disable given electrode on display
    ...                - *Date of Implementation:* 18-NOV-2025
    ...                - *Author:* Oliwia Maloch
    ...                - *Arguments:* electrode to be disabled: ``electrode``
    ...                - *Returns* N/A
    [Tags]    internal
    [Arguments]    ${electrode}
    ${status_before}=    Element Should Be Visible    ${turnedOff_electrode_${electrode}}
    IF    ${status_before} == False
        Click Element    ${electrode${electrode}_Electrode}
        ${status_after}=    Element Should Be Visible    ${turnedOff_electrode_${electrode}}
        Should Not Be Equal    ${status_before}    ${status_after}    msg=Fail, Electrode ${electrode} not clicked
    END
    RETURN    disabled

Enable electrodes
    [Documentation]    Keyword to enable given electrodes on display
    ...                - *Date of Implementation:* 18-NOV-2025
    ...                - *Author:* Oliwia Maloch
    ...                - *Arguments:* list of electrodes to be enabled: list ``electrodes``
    ...                - *Returns* N/A
    [Tags]    66649=3    66650=3    99584=6    59212=1
    [Arguments]    @{electrodes}
    FOR    ${electrode}    IN    @{electrodes}
        Enable Electrode    ${electrode}
    END
    [Teardown]    Document Keyword Outcome    Verified that electrodes [@{electrodes}] were enabled.

Disable electrodes
    [Documentation]    Keyword to enable given electrodes on display
    ...                - *Date of Implementation:* 18-NOV-2025
    ...                - *Author:* Oliwia Maloch
    ...                - *Arguments:* list of electrodes to be disabled: list ``electrodes``
    ...                - *Returns* N/A
    [Tags]    internal
    [Arguments]    @{electrodes}
    FOR    ${electrode}    IN    @{electrodes}
        Disable Electrode    ${electrode}
    END

Set electrodes statuses
    [Documentation]    Keyword to enable/disable given electrodes on display
    ...                - *Date of Implementation:* 18-NOV-2025
    ...                - *Author:* Oliwia Maloch
    ...                - *Arguments:* dict of electrodes and their expected statuses: dict ``exp_electrodes_states``, eg. {D1=enabled    2=disabled    3=enabled    P4=disabled}
    ...                - *Returns:* dict of electrodes and their statuses after setting expected statuses: ``act_electrodes_states``, eg. {D1=enabled    2=disabled    3=enabled    P4=disabled}
    [Tags]    59212=5,9,13    59337=1,7,13,19,25,31,37,43
    [Arguments]    &{exp_electrodes_states}
    VAR    &{act_electrodes_states}=
    FOR    ${electrode}    ${el_status}    IN    &{exp_electrodes_states}
        IF    '${el_status.lower()}'=='enabled'
            Enable Electrode    ${electrode}
            Set To Dictionary    ${act_electrodes_states}    ${electrode}=${el_status}
        ELSE IF    '${el_status.lower()}'=='disabled'
            Disable Electrode    ${electrode}
            Set To Dictionary    ${act_electrodes_states}    ${electrode}=${el_status}
        ELSE
            Fail    Fail, wrong arguments given. Status can take given values: enabled/disabled
        END
    END
    RETURN    ${act_electrodes_states}
    [Teardown]    Run Keywords    Document Keyword Outcome    Verified that electrodes were set to following statuses: &{act_electrodes_states}.    AND    Add Screenshot

Check if ablation time as expected
    [Documentation]    Keyword to check if ablation timers shows expected time value
    ...                - *Date of Implementation:* 16-Apr-2026
    ...                - *Author:* Oliwia Maloch
    [Tags]    99584=13
    [Arguments]    ${exp_time}
    ${current_ablation_time}=    Get Text    ${timer_panel_time_digits}
    Should Be Equal As Numbers    ${current_ablation_time}    ${exp_time}    msg='Fail, ablation time ${current_ablation_time}s does not equal expected ${exp_time}s'
    [Teardown]    Document Keyword Outcome    Verified that ablation timer shows ${current_ablation_time} sec.
    
Check If Total Ablation Counter Shows Expected Value
    [Documentation]    Keyword to check if total ablation counter shows expected number of counts
    ...                - *Date of Implementation:* 07-05-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* `exp_count` argument is the expected number of counts shown on the Total Ablation Counter on the Case Screen.
    [Tags]    59212=4,8,12,16    59337=6,12,18,24,30,36,42,48
    [Arguments]    ${exp_count}
    ${current_count}=    Get Text    ${rlPanel_AblationCount}
    Should Be Equal As Numbers    ${current_count}    ${exp_count}    msg='Fail, Total Ablation Counter shows ${current_count} counts, expected ${exp_count} counts.'
    [Teardown]    Run Keywords    Document Keyword Outcome    Verified that Total Ablation Counter shows ${current_count} counts.    AND    Add Screenshot

Check If R/L Counter Shows Expected Value
    [Documentation]    Keyword to check if R/L counter shows expected number of counts
    ...                - *Date of Implementation:* 07-05-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* `exp_count` argument is the expected number of counts shown on the Total Ablation Counter on the Case Screen.
    ...                `tag` argument can take the following values: `R`, `L`, based on which counter the verification will be performed.
    [Tags]    59212=4,8,12,16    59337=5,11,17,23,29,35,41,47
    [Arguments]    ${tag}    ${exp_count}
    IF    '${tag}'.upper() == 'R'
        ${counter_element}=    Set Variable    ${rlPanel_AblationCountRight}
    ELSE IF    '${tag}'.upper() == 'L'
        ${counter_element}=    Set Variable    ${rlPanel_AblationCountLeft}
    ELSE
        Fail    Fail, wrong argument given for tag. Tag can take following values: R or L
    END

    ${current_count}=    Get Text    ${counter_element}
    Should Be Equal As Numbers    ${current_count}    ${exp_count}    msg='Fail, ${tag} counter shows ${current_count} counts, expected ${exp_count} counts.'
    [Teardown]    Run Keywords    Document Keyword Outcome    Verified that ${tag} counter shows ${current_count} counts.    AND    Add Screenshot

Verify Run Number
    [Documentation]    Verifies that the run counter element is visible, its ``currentRunCount`` property
    ...                equals the expected value, and verifies the displayed text.
    ...                For the first run, the text should be "Run 1". For subsequent runs, the text
    ...                should equal the run number.
    ...                - *Date of Implementation:* 20-05-2026
    ...                - *Author:* Mina Bikhit
    [Tags]    58334=1,5,7
    [Arguments]    ${expected_value}
    Verify Element Is Visible    ${runNumberText}
    Verify Element Property Should Be    ${runNumberText}    currentRunCount    ${expected_value}
    IF    '${expected_value}' == '1'
        Verify Element Property Should Be    ${runNumberText}    text    Run 1
    ELSE
        Verify Element Property Should Be    ${runNumberText}    text    ${expected_value}
    END
    [Teardown]    Document Keyword Outcome    Verified run counter is ${expected_value}.


Select R Button
    [Documentation]    Select R tag button and verify that state of R and L buttons is correct after R button selection.
    ...                - *Date of Implementation:* 18-05-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* N/A
    ...                - *Returns:* N/A
    [Tags]    59801=2
    VAR    ${verification_msg}     State of R and L buttons was correct with following properties after R button selection:
    Click Element    ${right_button_tag}

    ${key_right_bg_h}=    Set Variable    buttons_bg_color_highlighted
    ${button_right_bg_color}=    Get Color    ${right_button}
    Should Be Equal
    ...    ${RL_BTN_COLORS}[${key_right_bg_h}]
    ...    ${button_right_bg_color}
    ...    msg=Verification Failed: Actual highlighted right button background color: ${button_right_bg_color} is not matching expected highlighted right button background color: ${RL_BTN_COLORS}[${key_right_bg_h}] (color name: ${RL_BTN_COLORS_NAMES}[${key_right_bg_h}])
    ...    values=False
    VAR    ${verification_msg}    ${verification_msg} R button highlighted background color: ${button_right_bg_color} (color name: ${RL_BTN_COLORS_NAMES}[${key_right_bg_h}]),

    ${key_left_bg}=    Set Variable    buttons_bg_color
    ${button_left_bg_color}=    Get Color    ${left_button}
    Should Be Equal
    ...    ${RL_BTN_COLORS}[${key_left_bg}]
    ...    ${button_left_bg_color}
    ...    msg=Verification Failed: Actual left button background color: ${button_left_bg_color} is not matching expected left button background color: ${RL_BTN_COLORS}[${key_left_bg}] (color name: ${RL_BTN_COLORS_NAMES}[${key_left_bg}])
    ...    values=False
    VAR    ${verification_msg}    ${verification_msg} L button background color: ${button_left_bg_color} (color name: ${RL_BTN_COLORS_NAMES}[${key_left_bg}]),

    ${key_right_text_h}=    Set Variable    buttons_text_color_highlighted
    ${button_right_text_color}=    Get Color    ${right_button_text}
    Should Be Equal
    ...    ${RL_BTN_COLORS}[${key_right_text_h}]
    ...    ${button_right_text_color}
    ...    msg=Verification Failed: Actual highlighted right button text color: ${button_right_text_color} is not matching expected highlighted right button text color: ${RL_BTN_COLORS}[${key_right_text_h}] (color name: ${RL_BTN_COLORS_NAMES}[${key_right_text_h}])
    ...    values=False
    VAR    ${verification_msg}    ${verification_msg} R button highlighted text color: ${button_right_text_color} (color name: ${RL_BTN_COLORS_NAMES}[${key_right_text_h}]),
    ${key_left_text}=    Set Variable    buttons_text_color
    ${button_left_text_color}=    Get Color    ${left_button_text}
    Should Be Equal
    ...    ${RL_BTN_COLORS}[${key_left_text}]
    ...    ${button_left_text_color}
    ...    msg=Verification Failed: Actual left button text color: ${button_left_text_color} is not matching expected left button text color: ${RL_BTN_COLORS}[${key_left_text}] (color name: ${RL_BTN_COLORS_NAMES}[${key_left_text}])
    ...    values=False
    VAR    ${verification_msg}    ${verification_msg} L button text color: ${button_left_text_color} (color name: ${RL_BTN_COLORS_NAMES}[${key_left_text}]),
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: ${verification_msg}    AND    Add Screenshot

Select L Button
    [Documentation]    Select L tag button and verify that state of R and L buttons is correct after L button selection.
    ...                - *Date of Implementation:* 18-05-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* N/A
    ...                - *Returns:* N/A
    [Tags]    59801=3
    VAR    ${verification_msg}     State of R and L buttons was correct with following properties after L button selection:
    Click Element    ${left_button_tag}

    ${key_right_bg}=    Set Variable    buttons_bg_color
    ${button_right_bg_color}=    Get Color    ${right_button}
    Should Be Equal
    ...    ${RL_BTN_COLORS}[${key_right_bg}]
    ...    ${button_right_bg_color}
    ...    msg=Verification Failed: Actual right button background color: ${button_right_bg_color} is not matching expected right button background color: ${RL_BTN_COLORS}[${key_right_bg}] (color name: ${RL_BTN_COLORS_NAMES}[${key_right_bg}])
    ...    values=False
    VAR    ${verification_msg}    ${verification_msg} R button background color: ${button_right_bg_color} (color name: ${RL_BTN_COLORS_NAMES}[${key_right_bg}]),

    ${key_left_bg_h}=    Set Variable    buttons_bg_color_highlighted
    ${button_left_bg_color}=    Get Color    ${left_button}
    Should Be Equal
    ...    ${RL_BTN_COLORS}[${key_left_bg_h}]
    ...    ${button_left_bg_color}
    ...    msg=Verification Failed: Actual highlighted left button background color: ${button_left_bg_color} is not matching expected highlighted left button background color: ${RL_BTN_COLORS}[${key_left_bg_h}] (color name: ${RL_BTN_COLORS_NAMES}[${key_left_bg_h}])
    ...    values=False
    VAR    ${verification_msg}    ${verification_msg} L button highlighted background color: ${button_left_bg_color} (color name: ${RL_BTN_COLORS_NAMES}[${key_left_bg_h}]),

    ${key_right_text}=    Set Variable    buttons_text_color
    ${button_right_text_color}=    Get Color    ${right_button_text}
    Should Be Equal
    ...    ${RL_BTN_COLORS}[${key_right_text}]
    ...    ${button_right_text_color}
    ...    msg=Verification Failed: Actual right button text color: ${button_right_text_color} is not matching expected right button text color: ${RL_BTN_COLORS}[${key_right_text}] (color name: ${RL_BTN_COLORS_NAMES}[${key_right_text}])
    ...    values=False
    VAR    ${verification_msg}    ${verification_msg} R button text color: ${button_right_text_color} (color name: ${RL_BTN_COLORS_NAMES}[${key_right_text}]),

    ${key_left_text_h}=    Set Variable    buttons_text_color_highlighted
    ${button_left_text_color}=    Get Color    ${left_button_text}
    Should Be Equal
    ...    ${RL_BTN_COLORS}[${key_left_text_h}]
    ...    ${button_left_text_color}
    ...    msg=Verification Failed: Actual highlighted left button text color: ${button_left_text_color} is not matching expected highlighted left button text color: ${RL_BTN_COLORS}[${key_left_text_h}] (color name: ${RL_BTN_COLORS_NAMES}[${key_left_text_h}])
    ...    values=False
    VAR    ${verification_msg}    ${verification_msg} L button highlighted text color: ${button_left_text_color} (color name: ${RL_BTN_COLORS_NAMES}[${key_left_text_h}]),
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: ${verification_msg}    AND    Add Screenshot

Select R/L Button
    [Documentation]    Select R or L tag button based on the given argument and verify that state of R and L buttons is correct after the selection.
    ...                Useful for datadriven testing where we can choose which button to click.
    ...                - *Date of Implementation:* 20-05-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* `tag` argument can take the following values: `R`, `L`, based on which button selection will be performed.
    [Tags]    59337=3,9,15,21,27,33,39,45
    [Arguments]    ${tag}

    IF    '${tag}'.upper() == 'R'
        Select R Button
    ELSE IF    '${tag}'.upper() == 'L'
        Select L Button
    ELSE
        Fail    Fail, wrong argument given for tag. Tag can take following values: R or L
    END

    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: ${tag} button selection successful and state of R and L buttons is correct.    AND    Add Screenshot


##################################################################################
########################## END OF Case Screen Keywords ###########################
##################################################################################

Open menu
    [Documentation]    Opens the hamburger menu on the Header if it is not already open.
    [Tags]    91981=1
    VAR    ${verification_msg}
    ${menu_visible}=    Element Should Be Visible    ${hamburger_menu}
    Should Be True    ${menu_visible}    msg=Fail, Hamburger menu not visible.
    ${is_open}=    Get Property    ${hamburger_menu}    isOpen
    IF    not ${is_open}    Click Element    ${hamburger_menu}
    VAR    ${verification_msg}=    Hamburger menu was opened successfully.
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: ${verification_msg}    AND    Add Screenshot

Close menu
    [Documentation]    Closes the hamburger menu on the Header if it is open.
    [Tags]    internal
    ${menu_visible}=    Element Should Be Visible    ${hamburger_menu}
    Should Be True    ${menu_visible}    msg=Fail, Hamburger menu not visible.
    ${is_open}=    Get Property    ${hamburger_menu}    isOpen
    IF    ${is_open}    Click Element    ${hamburger_menu}

Select Option From Menu
    [Documentation]    Selects the specified option from the hamburger menu.
    ...    - *Date of Implementation:* 04-03-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:* `option` argument can take the following values: `brightness`, `volume`, `settings`,  `report`, `help`.
    [Tags]    internal
    [Arguments]    ${option}
    Click Element    ${menu_${option}_option}
    VAR    ${verification_msg}    ${option.capitalize()} option was selected from the hamburger menu successfully.
    [Teardown]    Run Keywords    Document Keyword Outcome    ${verification_msg}    AND    Add Screenshot

##################################################################################
########################## Settings Screen Keywords ################################
##################################################################################

Navigate to settings page
    [Documentation]    Navigates to the Settings page from the main menu.
    ...    It verifies also: language option with default English, time option
    [Tags]    95974=1    97775=1
    Open Menu
    Select Option From Menu    settings
    ${res}=    Element Should Be Visible    ${settingsScreen}
    Should Be True    ${res}    msg=Fail, Navigation to Settings page failed. Settings screen not visible.
    ${timer_picker}=    Element Should Be Visible    ${general_settings_time_box}
    Should Be True    ${timer_picker}    msg=Fail, Timer settings not visible.
    ${language_menu}=    Element Should Be Visible    ${general_settings_language_box}
    Should Be True    ${language_menu}    msg=Fail, Language settings not visible.
    ${default_language}=    Set Variable    English (English)
    ${current_language}=    Get Currently Set Language
    Should Be Equal
    ...    ${default_language}    ${current_language}
    ...    msg=Current language: ${current_language} does not match default: ${default_language}

    [Teardown]    Run Keywords    Document Keyword Outcome    The Timer and Language options are visible   AND    Add Screenshot

Open general settings tab
    [Documentation]    Opens the General Settings tab on the Settings page.
    ...                - *Date of Implementation:* 20-02-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* Opens the General Settings tab on the Settings page and verifies that it is opened successfully.
    [Tags]    97827=1    97820=1    97821=1    97819=1    101463=1
    ${res}=    Element Should Be Visible    ${settingsScreen}
    Should Be True    ${res}    msg=Fail, Settings page not visible.
    Click Element    ${settings_tab_bar_gen_btn}
    ${tab_name}=    Get Property    ${settings_tab_bar}    currentItem.text
    Should Be Equal As Strings    ${tab_name}    General    msg=Fail, General Settings tab not opened.

    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: Navigated to General Settings tab successfully.    AND    Add Screenshot

Open advanced settings tab
    [Documentation]    Opens the Advanced Settings tab on the Settings page.
    [Tags]    97827=20
    ${res}=    Element Should Be Visible    ${settingsScreen}
    Should Be True    ${res}    msg=Fail, Settings page not visible.
    Click Element    ${settings_tab_bar_adv_btn}    20    20
    ${tab_name}=    Get Property    ${settings_tab_bar}    currentItem.text
    Should Be Equal As Strings    ${tab_name}    Advanced    msg=Fail, Advanced Settings tab not opened.

    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: Navigated to Advanced Settings tab successfully.    AND    Add Screenshot

Open Settings Tab
    [Documentation]    Navigates to the specified subpage in the Settings screen.
    ...    - *Date of Implementation:* 04-02-2026
    [Tags]    internal
    [Arguments]    ${subpage}
    IF    '${subpage}' == 'General'
        Open General Settings Tab
    ELSE IF    '${subpage}' == 'Advanced'
        Open Advanced Settings Tab
    END

Toggle Between Settings Tabs
    [Documentation]    Toggles between the General and Advanced tabs within the Settings screen.
    [Tags]    internal
    ${res}=    Element Should Be Visible    ${settingsScreen}
    Should Be True    ${res}    msg=Fail, Settings page not visible.
    ${tab_name}=    Get Property    ${settings_tab_bar}    currentItem.text

    IF    '${tab_name}' == 'General'
        Click Element    ${settings_tab_bar_adv_btn}    20    20
        ${new_tab_name}=    Get Property    ${settings_tab_bar}    currentItem.text
        Should Be Equal As Strings    ${new_tab_name}    Advanced    msg=Fail, Advanced Settings tab not opened.
    ELSE IF    '${tab_name}' == 'Advanced'
        Click Element    ${settings_tab_bar_gen_btn}
        ${new_tab_name}=    Get Property    ${settings_tab_bar}    currentItem.text
        Should Be Equal As Strings    ${new_tab_name}    General    msg=Fail, General Settings tab not opened.
    END

Open date picker
    [Documentation]    Opens the date picker component in the General Settings tab on the Settings Screen.
    [Tags]    98893=1,5,10,15,19,23,27    101463=2
    ${res}=    Element Should Be Visible    ${general_settings_date_box}
    Should Be True    ${res}    msg=Fail, date box is not visible.

    ${is_expanded}=    Get Property    ${general_settings_date_box}    listOpen
    ${is_expanded}=    Convert To Boolean    ${is_expanded}
    IF    not ${is_expanded}
        Click Element    ${general_settings_current_date_item}
    END
    ${is_expanded}=    Get Property    ${general_settings_date_box}    listOpen
    Should Be True    ${is_expanded}    msg=Fail, The expanding of the date picker failed.
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: The date picker expanded successfully.    AND    Add Screenshot

Close date picker
    [Documentation]    Closes the date picker component in the General Settings tab on the Settings Screen.
    [Tags]    internal
    ${res}=    Element Should Be Visible    ${general_settings_date_box}
    Should Be True    ${res}    msg=Fail, date box is not visible.

    ${is_expanded}=    Get Property    ${general_settings_date_box}    listOpen
    ${is_expanded}=    Convert To Boolean    ${is_expanded}
    IF    ${is_expanded}    Click On Screen Background Area
    ${is_expanded}=    Get Property    ${general_settings_date_box}    listOpen
    ${is_expanded}=    Convert To Boolean    ${is_expanded}
    Should Not Be True    ${is_expanded}    msg=Fail, The collapsing of the date picker failed.

Open Language Dropdown
    [Documentation]    Opens the language dropdown menu in the General Settings tab on the Settings Screen.
    [Tags]    97775=2
    ${res}=    Element Should Be Visible    ${general_settings_language_box}
    Should Be True    ${res}    msg=Fail, Language box is not visible.

    ${is_expanded}=    Get Property    ${general_settings_language_box}    listOpen
    ${is_expanded}=    Convert To Boolean    ${is_expanded}
    IF    not ${is_expanded}
        Click Element    ${general_settings_language_current_item_box}
    END
    ${is_expanded}=    Get Property    ${general_settings_language_box}    listOpen
    Should Be True    ${is_expanded}    msg=Fail, The expanding of the language dropdown failed.

    [Teardown]    Run Keywords    Document Keyword Outcome    The language dropdown opened successfully and verifications passed
    ...    AND    Add Screenshot

Close Language Dropdown
    [Documentation]    Closes the language dropdown menu in the General Settings tab on the Settings Screen.
    [Tags]    97775=21
    ${res}=    Element Should Be Visible    ${general_settings_language_box}
    Should Be True    ${res}    msg=Fail, Language box is not visible.
    ${is_expanded}=    Get Property    ${general_settings_language_box}    listOpen
    ${is_expanded}=    Convert To Boolean    ${is_expanded}
    IF    ${is_expanded}    Click On Screen Background Area
    ${is_expanded}=    Get Property    ${general_settings_language_box}    listOpen
    ${is_expanded}=    Convert To Boolean    ${is_expanded}
    Should Not Be True    ${is_expanded}    msg=Fail, The collapsing of the language dropdown failed.
    [Teardown]    Run Keywords    Document Keyword Outcome    The language dropdown closed successfully and verifications passed
    ...    AND    Add Screenshot

Select Next Language On Settings Page
    [Documentation]    Selects the next language from opened language dropdown menu, verifies the change and modification indicator.
    ...    Returns the old language and the new language as text.
    [Tags]    97827=2,5
    VAR    ${verification_msg}

    ${old_language}=    Get Currently Set Language
    Open Language Dropdown
    Select Next Item In List View    ${general_settings_language_list_view}

    ${new_language}=    Get Currently Set Language
    Should Not Be Equal    ${old_language}    ${new_language}    msg=Fail, Language not changed after selecting next language from the dropdown.
    ${status}    ${message}=    Check Modification Indicator For The Given Setting On Settings Page    language setting    ${modification_indicator_color}
    Should Be True    ${status}    msg=Fail, Modification indicator for language setting not displayed after changing the language.
    VAR    ${verification_msg}    Selected next language successfully. New selected language was ${new_language} and ${message}.
    RETURN    ${verification_msg}    ${old_language}    ${new_language}
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: ${verification_msg}    AND    Add Screenshot

Select Previous Language On Settings Page
    [Documentation]    Selects the previous language from the language dropdown menu.
    ...    Returns the old language and the new language as text.
    [Tags]    internal
    ${old_language}=    Get Currently Set Language
    Open Language Dropdown
    Select Previous Item In List View    ${general_settings_language_list_view}
    ${new_language}=    Get Currently Set Language
    Should Not Be Equal    ${old_language}    ${new_language}    msg=Fail, Language not changed after selecting previous language from the dropdown.
    RETURN    ${old_language}    ${new_language}

Select language
    [Documentation]    Selects a specific language from the language dropdown menu on the Settings Screen.
    ...    Supported ``language`` values are: English, Danish, Dutch, French, German, Greek, Italian,
    ...    Latvian, Norwegian, Portuguese, Russian, Spanish and Swedish.
    [Tags]    internal
    [Arguments]    ${language}
    @{languages_names}=    Get Dictionary Keys    ${SUPPORTED_LANGUAGES}
    Should Contain    ${languages_names}    ${language}    msg=Fail, Language ${language} not supported.

    ${res}=    Element Should Be Visible    ${settingsScreen}
    Should Be True    ${res}    msg=Fail, Settings page not visible.
    ${tab_name}=    Get Property    ${settings_tab_bar}    currentItem.text
    Should Be Equal As Strings    ${tab_name}    General    msg=Fail, General Settings tab not opened.

    ${language_to_select}=    Get From Dictionary    ${SUPPORTED_LANGUAGES}    ${language}
    Select Item In List View By Text    ${general_settings_language_list_view}    ${language_to_select}

Get Currently Set Language
    [Documentation]    Retrieves the currently selected language from the language dropdown menu on the Settings Screen.
    [Tags]    internal
    ${res}=    Element Should Be Visible    ${general_settings_language_current_item_text}
    Should Be True    ${res}    msg=Fail, current language text object is not visible.
    ${current_language}=    Get Text    ${general_settings_language_current_item_text}
    RETURN    ${current_language}

Get Currently Set Date
    [Documentation]    Retrieves the currently selected date from the date picker component on the Settings Screen.
    [Tags]    internal
    ${res}=    Element Should Be Visible    ${general_settings_current_date_text}
    Should Be True    ${res}    msg=Fail, current date text is not visible.
    ${current_date}=    Get Text    ${general_settings_current_date_text}
    RETURN    ${current_date}

Add days to current date
    [Documentation]    Adds a specified number of days to the currently selected date in the date picker component on the Settings Screen.
    ...    The `days_to_add` argument specifies the number of days to add.
    ...    Returns the new selected date as a string from date text field.
    ...    If ``days_to_add`` is negative, it subtracts days from the current date.
    [Tags]    internal
    [Arguments]    ${days_to_add}
    ${current_date_text}=    Get Currently Set Date
    Open Date Picker
    ${date_box_obj}=    Get Object Reference    ${general_settings_date_box}    True
    ${current_date_obj}=    Evaluate    $date_box_obj.currentDate
    ${new_date_obj}=    Evaluate    $current_date_obj.addDays(${days_to_add})

    # make interaction view dayViewObject by calling dateClicked method to set new date
    ${day_view_obj}=    Get Object Reference    ${general_settings_calendar_day_view}    True
    Evaluate    $day_view_obj.dateClicked($new_date_obj)

    Close Date Picker
    ${date_after_change_text}=    Get Currently Set Date

    Should Not Contain
    ...    ${date_after_change_text}
    ...    ${current_date_text}
    ...    msg=Fail, Date not changed after adding ${days_to_add} days.
    RETURN    ${date_after_change_text}

Open time picker
    [Documentation]    Opens the time picker component in the General Settings tab on the Settings Screen.
    [Tags]    95974=2    101463=28
    ${res}=    Element Should Be Visible    ${general_settings_timer_component}
    IF    not $res    Click Element    ${general_settings_time_box_item}
    ${res}=    Element Should Be Visible    ${general_settings_timer_component}
    Should Be True
    ...    ${res}
    ...    msg=Fail, The expanding of the time picker failed. The expanded time picker is not visible.

    [Teardown]    Run Keywords    Document Keyword Outcome    The time picker expanded - passed    AND    Add Screenshot

Close time picker
    [Documentation]    Closes the time picker component in the General Settings tab on the Settings Screen.
    [Tags]    95974=10
    ${res}=    Element Should Be Visible    ${general_settings_timer_component}
    IF    $res
        Click On Screen Background Area
        ${res}=    Element Should Be Visible    ${general_settings_timer_component}
    END
    Should Not Be True
    ...    ${res}
    ...    msg=Fail, The collapsing of the time picker failed. The time picker is still visible.

    [Teardown]    Run Keywords    Document Keyword Outcome    The time picker collapsed - passed    AND    Add Screenshot

Get And Convert Time
    [Documentation]    Retrieves the time from the given time element and converts it to an integer.
    ...    ``object_real_name``: The locator of the time element to retrieve the time from. Locator is the
    ...    symbolic name defined in the object repository.
    [Tags]    internal
    [Arguments]    ${object_real_name}
    ${time_text}=    Get Text    ${object_real_name}
    ${time_text}=    Replace String    ${time_text}    00    0
    ${time_int}=    Convert To Integer    ${time_text}
    RETURN    ${time_int}

Get Currently Set Time
    [Documentation]    Retrieves the currently set time from the time picker component on the Settings Screen.
    [Tags]    internal
    ${res}=    Element Should Be Visible    ${settingsScreen}
    Should Be True    ${res}    msg=Fail, Settings page not visible.
    ${tab_name}=    Get Property    ${settings_tab_bar}    currentItem.text
    Should Be Equal As Strings    ${tab_name}    General    msg=Fail, General Settings tab not opened.

    ${res}=    Element Should Be Visible    ${general_settings_time_text}
    Should Be True    ${res}    msg=Fail, Timer text box is not visible.
    ${current_time}=    Get Text    ${general_settings_time_text}
    RETURN    ${current_time}

Increase Time By One Minute
    [Documentation]    Increase time by one minute
    [Tags]    95974=5
    ${res}=    Element Should Be Visible    ${general_settings_timer_component}
    Should Be True
    ...    ${res}
    ...    msg=Fail, Time picker component is not visible. Cannot increase time. Please open time picker first.

    ${current_minute}=    Get And Convert Time    ${general_settings_label_minute}
    Click Element    ${general_settings_spin_min_up}
    ${increased_minute}=    Get And Convert Time    ${general_settings_label_minute}

    IF    ${current_minute} == 59
        ${expected_minute}=    Set Variable    0
    ELSE
        ${expected_minute}=    Evaluate    ${current_minute} + 1
    END
    Should Be Equal As Integers
    ...    ${increased_minute}    ${expected_minute}
    ...    msg=Increased minute by one: ${increased_minute} is not matching expected: ${expected_minute}
    ...    values=False

    [Teardown]    Run Keywords    Document Keyword Outcome    The timer increased by one minute and verifications passed    AND    Add Screenshot

Get Currently Set Default View
    [Documentation]    Retrieves the currently selected default view from the Advanced Settings tab on the Settings Screen.
    ...    It returns both the text of the selected option and the locator of the selected option.
    [Tags]    internal
    ${default_view_options}=    Create List
    ...    ${electrode_stability_only_setting}
    ...    ${electrode_stability_and_impedance_setting}
    FOR    ${option}    IN    @{default_view_options}
        ${is_visible}=    Element Should Be Visible    ${option}
        Should Be True    ${is_visible}    msg=Fail, Default View option ${option} not visible.
        ${is_selected}=    Get Property    ${option}    checked
        ${is_selected}=    Convert To Boolean    ${is_selected}
        IF    ${is_selected}
            ${selected_option}=    Set Variable    ${option}
            BREAK
        ELSE
            ${selected_option}=    Set Variable    ${EMPTY}
        END
    END
    ${option_text}=    Get Text    ${selected_option}

    RETURN    ${option_text}    ${selected_option}

Toggle Default View Setting On Settings Page
    [Documentation]    Toggles the Default View setting in the Advanced Settings tab on the Settings Screen.
    ...    If the current setting is "Electrode Stability Only", it switches to "Electrode Stability and Impedance", and vice versa.
    [Tags]    internal
    ${previous_setting_text}    ${setting_real_name}=    Get Currently Set Default View
    ${status}=    Run Keyword And Return Status
    ...    Dictionaries Should Be Equal
    ...    ${setting_real_name}
    ...    ${electrode_stability_only_setting}
    IF    ${status}
        Click Element    ${electrode_stability_and_impedance_setting}
    END
    IF    not ${status}    Click Element    ${electrode_stability_only_setting}
    ${current_setting_text}    ${_}=    Get Currently Set Default View
    Should Not Be Equal
    ...    ${previous_setting_text}
    ...    ${current_setting_text}
    ...    msg=Fail, Toggling Default View setting failed.

Toggle Display Measure Impedance Value Setting
    [Documentation]    Toggles the Display Measured Impedance Values setting in the Advanced Settings tab on the Settings screen.
    ...    If the setting is currently enabled, it disables it, and vice versa.
    [Tags]    internal
    ${default_view_option_text}    ${_}=    Get Currently Set Default View
    Should Contain
    ...    ${default_view_option_text}
    ...    stability and impedance
    ...    msg=Fail, Display Measured Impedance Values setting is only available when Default View is set to "Electrode Stability and Impedance".

    ${is_visible}=    Element Should Be Visible    ${display_impedance_setting}
    Should Be True    ${is_visible}    msg=Fail, Display Measured Impedance Values setting is not visible.

    ${is_checked}=    Get Property    ${display_impedance_setting}    checked
    ${is_checked}=    Convert To Boolean    ${is_checked}
    Click Element    ${display_impedance_setting}
    # Verify that the setting has been toggled
    ${new_is_checked}=    Get Property    ${display_impedance_setting}    checked
    ${new_is_checked}=    Convert To Boolean    ${new_is_checked}
    Should Not Be Equal
    ...    ${is_checked}
    ...    ${new_is_checked}
    ...    msg=Fail, Toggling Display Measured Impedance Values setting failed.

Get Display Measure Impedance Value Setting
    [Documentation]    Retrieves the current setting for displaying measured impedance values from the Advanced Settings tab on Settings screen.
    ...    It returns ``True`` if the setting is enabled, ``False`` otherwise.
    [Tags]    internal
    ${is_visible}=    Element Should Be Visible    ${display_impedance_setting}
    Should Be True    ${is_visible}    msg=Fail, Display Measured Impedance Values setting not visible.

    ${is_checked}=    Get Property    ${display_impedance_setting}    checked    False
    ${is_checked}=    Convert To Boolean    ${is_checked}

    RETURN    ${is_checked}

Toggle Laterality Tagging Setting
    [Documentation]    Toggles the Laterality setting in the Advanced Settings tab on the Settings Screen and verifies if change took place.
    ...    If the setting is currently enabled, it disables it, and vice versa.
    ...    Returns the previous setting and the new setting as boolean values.
    [Tags]    97827=33,36
    ${current_setting}=    Get Laterality Tagging Setting
    Click Element    ${select_r_or_l_kidney_setting}
    # Verify that the setting has been toggled
    ${new_value}=    Get Laterality Tagging Setting
    Should Not Be Equal    ${current_setting}    ${new_value}    msg=Fail, Toggling Laterality setting failed.

    RETURN    ${current_setting}    ${new_value}
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: Toggled Laterality Tagging setting successfully. Value before: ${current_setting}, after change: ${new_value}.    AND    Add Screenshot

Get Laterality Tagging Setting
    [Documentation]    Retrieves the current setting for laterality tagging from the Advanced Settings tab on the Settings Screen.
    ...    It returns ``True`` if the setting is enabled, ``False`` otherwise.
    [Tags]    internal
    ${is_visible}=    Element Should Be Visible    ${select_r_or_l_kidney_setting}
    Should Be True    ${is_visible}    msg=Fail, Laterality setting not visible.

    ${is_checked}=    Get Property    ${select_r_or_l_kidney_setting}    checked
    ${is_checked}=    Convert To Boolean    ${is_checked}

    RETURN    ${is_checked}

Get Current Value Of Given Setting
    [Documentation]    Retrieves the current value of a specified setting in the Settings screen.
    ...    ``setting``: Name of the setting from General Settings tab whose value is to be retrieved.
    ...    Allowed values for ``setting`` are: 'language setting', 'date setting', 'time setting',
    ...    'default view setting', 'display impedance', 'laterality tagging'.
    [Tags]    internal
    [Arguments]    ${setting}
    IF    '${setting}' == 'language setting'
        ${setting_value}=    Get Currently Set Language
    ELSE IF    '${setting}' == 'date setting'
        ${setting_value}=    Get Currently Set Date
    ELSE IF    '${setting}' == 'time setting'
        ${setting_value}=    Get Currently Set Time
    ELSE IF    '${setting}' == 'default view setting'
        ${setting_value}    ${_}=    Get Currently Set Default View
    ELSE IF    '${setting}' == 'display impedance setting'
        ${setting_value}=    Get Display Measure Impedance Value Setting
    ELSE IF    '${setting}' == 'laterality tagging setting'
        ${setting_value}=    Get Laterality Tagging Setting
    END
    # stringify the returned value
    ${setting_value}=    Convert To String    ${setting_value}

    RETURN    ${setting_value}

Check Modification Indicator For The Given Setting On Settings Page
    [Documentation]    Checks if the modification indicator is displayed for the specified setting on the Settings Screen.
    ...    - *Date of Implementation:* 04-02-2026
    [Tags]    internal
    [Arguments]    ${setting}    ${modification_color}
    ${status}=    Set Variable    False
    ${message}=    Set Variable    Modification indicator for ${setting} not detected.
    ${message_ok}=    Set Variable
    ...    Modification indicator for ${setting} detected. Border color (${modification_color}) and first character being asterisk are correct.

    IF    '${setting}' == 'language setting'
        ${language}=    Get Currently Set Language
        ${first_char}=    Get Substring    ${language}    0    1
        ${color_check}=    Element Attribute Value Should Be
        ...    ${general_settings_language_current_item_box}
        ...    border.color.name
        ...    ${modification_color}
        IF    '${first_char}' == '*' and ${color_check}
            VAR    ${status}=    True
            VAR    ${message}=    ${message_ok}
        END
    ELSE IF    '${setting}' == 'date setting'
        ${date}=    Get Currently Set Date
        ${first_char}=    Get Substring    ${date}    0    1
        ${color_check}=    Element Attribute Value Should Be
        ...    ${general_settings_current_date_item}
        ...    border.color.name
        ...    ${modification_color}
        IF    '${first_char}' == '*' and ${color_check}
            VAR    ${status}=    True
            VAR    ${message}=    ${message_ok}
        END
    ELSE IF    '${setting}' == 'time setting'
        ${time}=    Get Currently Set Time
        ${first_char}=    Get Substring    ${time}    0    1
        ${color_check}=    Element Attribute Value Should Be
        ...    ${general_settings_time_box_item}
        ...    border.color.name
        ...    ${modification_color}
        IF    '${first_char}' == '*' and ${color_check}
            VAR    ${status}=    True
            VAR    ${message}=    ${message_ok}
        END
    ELSE IF    '${setting}' == 'default view setting'
        ${ind_1}=    Element Should Be Visible    ${electrode_stability_only_modification_indicator}
        ${ind_2}=    Element Should Be Visible    ${electrode_stability_and_impedance_modification_indicator}
        IF    ${ind_1} and ${ind_2}
            VAR    ${status}=    True
            VAR    ${message}=    Modification indicator for ${setting} detected.
        END
    ELSE IF    '${setting}' == 'display impedance setting'
        ${res}=    Element Should Be Visible    ${display_impedance_modification_indicator}
        IF    ${res}
            VAR    ${status}=    True
            VAR    ${message}=    Modification indicator for ${setting} detected.
        END
    ELSE IF    '${setting}' == 'laterality tagging setting'
        ${res}=    Element Should Be Visible    ${select_r_or_l_kidney_modification_indicator}
        IF    ${res}
            VAR    ${status}=    True
            VAR    ${message}=    Modification indicator for ${setting} detected.
        END
    END

    RETURN    ${status}    ${message}

Modify ${setting} On The ${subpage} Subpage
    [Documentation]    Modifies a specified setting on a given subpage within the Settings screen.
    ...    ``subpage``: The subpage within the Settings screen where the setting is located. Allowed values are 'General' and 'Advanced'.
    ...    ``setting``: The specific setting to be modified. Supported settings include:
    ...    For 'General' subpage: 'language setting', 'date setting', 'time setting'.
    ...    For 'Advanced' subpage: 'default view setting', 'display impedance setting', 'laterality tagging setting'.
    ...    Returns the old and new values of the modified setting.
    [Tags]    internal
    IF    '${subpage}' == 'General'
        IF    '${setting}' == 'language setting'
            ${_}    ${old_value}    ${new_value}=    Select Next Language On Settings page
        ELSE IF    '${setting}' == 'date setting'
            ${old_value}=    Get Currently Set Date
            ${new_value}=    Add Days To Current Date    -1
        ELSE IF    '${setting}' == 'time setting'
            ${old_value}=    Get Currently Set Time
            Open Time Picker
            Increase Time By One Hour
            Close Time Picker
            ${new_value}=    Get Currently Set Time
        END
    ELSE IF    '${subpage}' == 'Advanced'
        IF    '${setting}' == 'default view setting'
            ${old_value}    ${_}=    Get Currently Set Default View
            Toggle Default View Setting On Settings Page
            ${new_value}    ${_}=    Get Currently Set Default View
        ELSE IF    '${setting}' == 'display impedance setting'
            Click Element    ${electrode_stability_and_impedance_setting}
            ${old_value}=    Get Display Measure Impedance Value Setting
            Toggle Display Measure Impedance Value Setting
            ${new_value}=    Get Display Measure Impedance Value Setting
        ELSE IF    '${setting}' == 'laterality tagging setting'
            ${old_value}    ${new_value}=    Toggle Laterality Tagging Setting
        END
    END
    RETURN    ${old_value}    ${new_value}

Select Keep Editing Option from Unsaved Changes Dialog
    [Documentation]    Selects the keep editing option from the Unsaved Changes confirmation dialog and verifies if it disappeared.
    ...                - *Date of Implementation:* 20-02-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* N/A
    [Tags]    97820=4,7    97821=4,7    97819=4,7

    Click Element    ${confirmation_dialog_cancel_btn}
    Wait For Element To Be Invisible    ${confirmation_dialog}    2000
    ${res}=    Element Should Not Be Visible    ${confirmation_dialog}
    Should Be True    ${res}    msg=Discard confirmation dialog was still visible after selection of keep editing option.
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: Keep editing option was selected and confirmation dialog disappeared.   AND    Add Screenshot

Select Discard Option On Settings Page
    [Documentation]    Selects the discard option on Settings Page and verifies if confirmation dialog appears depending on
    ...                `expect_confirmation_dialog` argument.
    ...                - *Date of Implementation:* 20-02-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* `expect_confirmation_dialog` parameter is a boolean which specifies whether confirmation
    ...                dialog is expected to appear after clicking the discard button on settings page.
    ...                If `expect_confirmation_dialog` is set to `True`, the keyword verifies that the confirmation dialog
    ...                is visible. If set to `False`, it verifies that the confirmation dialog is not visible and user
    ...                navigated back successfully.
    ...                Example:
    ...                Select Discard Option On Settings Page    expect_confirmation_dialog=False
    [Tags]    97827=3,9,15,22,28,34    97820=6    97821=6    97819=6
    [Arguments]    ${expect_confirmation_dialog}=True
    VAR    ${verification_msg}
    Click Element    ${settings_cancel_btn}
    IF    ${expect_confirmation_dialog}
        ${res}=    Element Should Be Visible    ${confirmation_dialog}
        Should Be True    ${res}    msg=Discard confirmation dialog was not displayed upon clicking discard button.
        VAR    ${verification_msg}    Discard confirmation dialog was displayed after clicking discard button.
    ELSE
        ${res}=    Element Should Not Be Visible    ${confirmation_dialog}
        Should Be True    ${res}    msg=Discard confirmation dialog was displayed after clicking discard button.
        VAR    ${verification_msg}    Navigated back successfully and discard confirmation dialog was not displayed after clicking discard button.
    END

    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: ${verification_msg}    AND    Add Screenshot

Select Discard Option from Unsaved Changes Dialog and verify retention of previous settings
    [Documentation]    Selects the discard option from the Unsaved Changes confirmation dialog and verifies that the previous setting value is retained.
    ...    This keyword clicks the confirmation dialog's discard button, waits for the dialog to disappear, and optionally navigates back to the settings page if triggered by the Back button.
    ...    It then retrieves the value of the specified setting and asserts that it matches the value before changes were made.
    ...    Used to ensure that discarding changes reverts the setting to its original value.
    ...
    ...    =Arguments=
    ...    | ${settings_before_changes} | The value of the setting before any changes were made. |
    ...    | ${setting}                | The name of the setting to verify (e.g. 'language setting', 'date setting', 'time setting',
    ...    'default view setting', 'display impedance', 'laterality tagging'). |
    ...    | ${trigger_source}         | The source that triggered the discard action (e.g. 'Back button', 'Discard button in General Subpage'). |
    ...    | ${settings_subpage}=General | (Optional) The subpage in the settings screen where the setting is located. Defaults to 'General'. |

    [Tags]    97827=4,7,10,13,16,19,23,26,29,32,35,38
    [Arguments]    ${settings_before_changes}    ${setting}    ${trigger_source}    ${settings_subpage}=General
    Click Element    ${confirmation_dialog_ok_btn}
    Wait For Element To Be Invisible    ${confirmation_dialog}    2000
    ${res}=    Element Should Not Be Visible    ${confirmation_dialog}
    Should Be True    ${res}    msg=Discard confirmation dialog was still visible after discarding changes.

    ${res}=    Run Keyword And Return Status    Should Contain    ${trigger_source}    Back button
    IF    $res
        Navigate To Settings Page
        Open Settings Tab    ${settings_subpage}
    END
    ${settings_after_discarding}=    Get Current Value Of Given Setting    ${setting}
    IF    '${setting}' == 'time setting'
        @{settings_after_discarding}=    Split String    ${settings_after_discarding}    :
        # Check hour only, as minutes may vary due to execution time
        ${settings_after_discarding}=    Set Variable    ${settings_after_discarding}[0]
    END
    # Clean up any unwanted characters - asterisk at the beginning
    ${settings_after_discarding}=    Replace String    ${settings_after_discarding}    *    ${EMPTY}    count=1

    Should Be Equal
    ...    ${settings_before_changes}
    ...    ${settings_after_discarding}
    ...    msg=Settings were not reverted to the initial values. Changes were not discarded properly. Settings before changes: ${settings_before_changes}, Settings after discarding changes: ${settings_after_discarding}.
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: Settings for ${setting} before changes: ${settings_before_changes} were equal to settings after changes ${settings_after_discarding} when discard operation was performed with ${trigger_source} as the source of the action.    AND    Add Screenshot

Select Back Button on Header
    [Documentation]    Selects the back button from the Header and verifies if confirmation dialog appears depending on
    ...                `expect_confirmation_dialog` argument.
    ...                - *Date of Implementation:* 20-02-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* `expect_confirmation_dialog` parameter is a boolean which specifies whether confirmation
    ...                dialog is expected to appear after clicking the back button. If `expect_confirmation_dialog` is
    ...                set to `True`, the keyword verifies that the confirmation dialog is visible. If set to `False`,
    ...                it verifies that the confirmation dialog is not displayed and navigation back was successful.
    ...                Example:
    ...                Select Back Button on Header    expect_confirmation_dialog=False
    [Tags]    97827=6,12,18,25,31,37    97820=3,10    97821=3,10    97819=3,10    101463=30
    [Arguments]    ${expect_confirmation_dialog}=True
    VAR    ${verification_msg}
    Click Element    ${back_header_btn}
    IF    ${expect_confirmation_dialog}
        ${res}=    Element Should Be Visible    ${confirmation_dialog}
        Should Be True    ${res}    msg=Discard confirmation dialog was not displayed upon clicking Back button.
        VAR    ${verification_msg}    Discard confirmation dialog was displayed after clicking Back button.
    ELSE
        ${res}=    Element Should Not Be Visible    ${confirmation_dialog}
        Should Be True    ${res}    msg=Discard confirmation dialog was displayed upon clicking Back
        VAR    ${verification_msg}    Navigated Back successfully and discard confirmation dialog was not displayed after clicking Back button.
    END
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: ${verification_msg}.    AND    Add Screenshot

Select previous day in Date Picker on Settings page
    [Documentation]    Selects the previous day in the Date Picker on the Settings Screen and verifies if new date is different from previous one.
    [Tags]    97827=8,11
    ${current_date}=    Get Currently Set Date
    ${new_date_raw}=    Add Days To Current Date    -1
    ${new_date}=    Replace String    ${new_date_raw}    *    ${EMPTY}    count=1
    Should Not Be Equal
    ...    ${new_date}
    ...    ${current_date}
    ...    msg=Date selection did not change after selecting previous day.
    Should Not Be Equal    ${new_date}    ${current_date}    msg=Date selection did not change after selecting an earlier day.
    VAR    ${verify_string_1}    Selected earlier day successfully. New selected date was ${new_date}.

    # verify modification indicator
    ${status}    ${msg}=    Check Modification Indicator For The Given Setting On Settings Page    date setting    ${modification_indicator_color}
    Should Be True    ${status}    msg=${msg}
    VAR    ${verify_string_2}    Modification indicator for date setting was displayed correctly after changing the date.
    VAR    ${verification_message}=    ${verify_string_1} ${verify_string_2}

    RETURN    ${verification_message}    ${current_date}    ${new_date_raw}
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: ${verification_message}    AND    Add Screenshot

Restore Date To The Original Date
    [Documentation]    Restores the date to the previous state by setting the original date and verifies if value was
    ...    reverted and modification indicator disappeared.
    ...    - *Date of Implementation:* 19-02-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:* This keyword is used to revert the date setting to its original value after it has
    ...    been changed, and to verify that the modification indicator is no longer visible. It takes the original date
    ...    as an argument, sets it back in the date picker, and then checks that the displayed date matches the original
    ...    date and that the modification indicator has disappeared.
    ...    - *Returns:* A verification message confirming that the date was successfully reverted and the
    ...    modification indicator is no longer visible, along with the restored date value.
    [Arguments]    ${original_date}
    [Tags]    internal
    VAR    ${verification_msg}
    ${currently_set_date}=    Get Currently Set Date
    ${currently_set_date}=    Replace String    ${currently_set_date}    *    ${EMPTY}
    ${original_date}=    Replace String    ${original_date}    *    ${EMPTY}
    ${diff_days}=    Calculate Days Difference    ${currently_set_date}    ${original_date}
    Add Days To Current Date    ${diff_days}
    ${restored_date}=    Get Currently Set Date
    ${result}    ${message}=    Check Modification Indicator For The Given Setting On Settings Page    date setting    ${modification_indicator_color}
    Should Not Be True    ${result}    msg=Modification indicator is still visible after reverting date to original value.
    VAR    ${verify_string_1}    Modification indicator for date setting was not displayed after reverting date to original value.
    Should Be Equal    ${original_date}    ${restored_date}    msg=Date was not reverted to the original date. Original date: ${original_date}, current date after reverting: ${restored_date}.
    VAR    ${verification_msg}    Date was reverted to the original date successfully. Current date is now: ${restored_date}. ${verify_string_1}
    RETURN    ${verification_msg}    ${restored_date}

Change electrode preview settings on settings page
    [Documentation]    Changes the electrode preview settings on settings page.
    [Tags]    97827=21,24
    ${previous_option_text}    ${obj_real_name}=    Get Currently Set Default View
    Toggle Default View Setting On Settings Page
    ${current_option_text}    ${obj_real_name}=    Get Currently Set Default View
    Should Not Be Equal As Strings
    ...    ${previous_option_text}
    ...    ${current_option_text}
    ...    msg=Electrode preview option text did not change after toggling it.
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: Changed electrode preview settings successfully. New state was ${current_option_text}.    AND    Add Screenshot

Change electrode preview settings via toggle option on settings page
    [Documentation]    Changes the electrode preview settings via toggle option.
    [Tags]    97827=27,30
    ${previous_value}=    Get Display Measure Impedance Value Setting
    Toggle Display Measure Impedance Value Setting
    ${current_value}=    Get Display Measure Impedance Value Setting
    Should Not Be Equal
    ...    ${previous_value}
    ...    ${current_value}
    ...    msg=Display Impedance value setting did not change after toggling it.
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: Changed electrode preview settings via toggle option successfully. Value before: ${previous_value}, after change: ${current_value}.    AND    Add Screenshot

Change Given Setting On The Given Subpage On Settings Page
    [Documentation]    Modifies the specified setting on the given subpage and verifies if modification indicator was visible.
    ...    It returns the old value and the new value of the setting for further verification steps.
    [Tags]    97824=1,3,5,7,9,11,13,15,17,19,21,23
    [Arguments]    ${setting}    ${subpage}    ${modification_indicator_color}
    Open Settings Tab    ${subpage}
    ${old_value}    ${new_value}=    Modify ${setting} On The ${subpage} Subpage

    # stringify new and old values for proper comparison in verification step
    ${old_value}=    Convert To String    ${old_value}
    ${new_value}=    Convert To String    ${new_value}
    ${result}    ${message}=    Check Modification Indicator For The Given Setting On Settings Page
    ...    ${setting}
    ...    ${modification_indicator_color}
    IF    not ${result}    Fail    msg=${message}
    RETURN    ${old_value}    ${new_value}    ${setting}
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: Modified setting ${setting} on ${subpage} subpage successfully and ${message}.    AND    Add Screenshot

Save Changes By Given Save Method On The Settings Page
    [Documentation]    Saves changes on the Settings screen using the specified save method.
    [Tags]    97824=2,4,6,8,10,12,14,16,18,20,22,24    98893=4,9,14,18,22,26,30    101463=4,17
    [Arguments]    ${old_value}    ${setting}    ${subpage}    ${save_method}
    IF    '${save_method}' == 'save button'
        Click Element    ${settings_ok_btn}
    ELSE IF    '${save_method}' == 'switching pages'
        # Toggle two times to return to the original subpage
        Toggle Between Settings Tabs
        Toggle Between Settings Tabs
    END
    ${new_value}=    Get Current Value Of Given Setting    ${setting}
    Should Not Be Equal As Strings
    ...    ${old_value}
    ...    ${new_value}
    ...    msg=Settings changes were not saved properly using ${save_method}. Value before saving: ${old_value}, value after saving: ${new_value} for ${setting} in ${subpage} subpage.
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: Saving changes for ${setting} in ${subpage} settings subpage by ${save_method} was successful. Value before saving: ${old_value}, value after saving: ${new_value}.    AND    Add Screenshot

Decrease Time By One Minute
    [Documentation]    Decrease time by one minute
    ...                - *Date of Implementation:* 09-02-2026
    ...                - *Author:* Valentyn Karpiuk
    ...                - *Usage:* Reduces the time by one minute using the corresponding button
    [Tags]    95974=6
    ${res}=    Element Should Be Visible    ${general_settings_timer_component}
    Should Be True    ${res}    msg=Fail, Time picker component is not visible. Cannot decrease time. Please open time picker first.

    ${current_minute}=    Get And Convert Time    ${general_settings_label_minute}
    Click Element    ${general_settings_spin_min_down}
    ${decreased_minute}=    Get And Convert Time    ${general_settings_label_minute}

    IF   ${current_minute} == 0
        ${expected_minute}=    Set Variable    59
    ELSE
        ${expected_minute}=    Evaluate    ${current_minute} - 1
    END
    Should Be Equal As Integers
    ...    ${decreased_minute}    ${expected_minute}
    ...    msg=Decreased minute by one: ${decreased_minute} is not matching expected: ${expected_minute}
    ...    values=False
    [Teardown]    Run Keywords    Document Keyword Outcome    The timer decreased by one minute and verifications passed    AND    Add Screenshot

Increase Time By One Hour
    [Documentation]    Increase time by one hour
    ...                - *Date of Implementation:* 09-02-2026
    ...                - *Author:* Valentyn Karpiuk
    ...                - *Usage:* Increases the time by one hour using the corresponding button
    [Tags]    95974=3    97827=14,17
    ${res}=    Element Should Be Visible    ${general_settings_timer_component}
    Should Be True    ${res}    msg=Fail, Time picker component is not visible. Cannot increase time. Please open time picker first.

    ${current_hour}=    Get And Convert Time    ${general_settings_label_hour}
    Click Element    ${general_settings_spin_hour_up}
    ${increased_hour}=    Get And Convert Time    ${general_settings_label_hour}

    IF   ${current_hour} == 23
        ${expected_hour}=    Set Variable    0
    ELSE
        ${expected_hour}=    Evaluate    ${current_hour} + 1
    END
    Should Be Equal As Integers
    ...    ${increased_hour}    ${expected_hour}
    ...    msg=Decreased hour by one: ${increased_hour} is not matching expected: ${expected_hour}
    ...    values=False

    [Teardown]    Run Keywords    Document Keyword Outcome    The timer increased by one hour and verifications passed    AND    Add Screenshot

Decrease Time By One Hour
    [Documentation]    Decrease time by one hour
    ...                - *Date of Implementation:* 09-02-2026
    ...                - *Author:* Valentyn Karpiuk
    ...                - *Usage:* Reduces the time by one hour using the corresponding button
    [Tags]    95974=4
    ${res}=    Element Should Be Visible    ${general_settings_timer_component}
    Should Be True    ${res}    msg=Fail, Time picker component is not visible. Cannot decrease time. Please open time picker first.

    ${current_hour}=    Get And Convert Time    ${general_settings_label_hour}
    Click Element    ${general_settings_spin_hour_down}
    ${decreased_hour}=    Get And Convert Time    ${general_settings_label_hour}

    IF   ${current_hour} == 0
        ${expected_hour}=    Set Variable    23
    ELSE
        ${expected_hour}=    Evaluate    ${current_hour} - 1
    END
    Should Be Equal As Integers
    ...    ${decreased_hour}    ${expected_hour}
    ...    msg=Decreased hour by one: ${decreased_hour} is not matching expected: ${expected_hour}
    ...    values=False
    [Teardown]    Run Keywords    Document Keyword Outcome    The timer decreased by one hour and verifications passed    AND    Add Screenshot

Set Timer Hours By Clicking
    [Documentation]    Set hours by clicking
    ...                - *Date of Implementation:* 09-02-2026
    ...                - *Author:* Valentyn Karpiuk
    ...                - *Usage:* Uses the given button locator to adjust and set the timer to the specified hour value
    [Tags]    internal
    [Arguments]    ${set_hour}    ${button_locator}
    ${current_hour}=    Get And Convert Time    ${general_settings_label_hour}
    ${counter}=    Set Variable    0
    WHILE    ${current_hour} != ${set_hour}
        Click Element    ${button_locator}
        ${current_hour}=    Get And Convert Time    ${general_settings_label_hour}
        ${counter}=    Evaluate    ${counter} + 1
        Run Keyword If    ${counter} > 24    Fail    Too many attempts to set hour!
    END
    Should Be Equal
    ...    ${set_hour}    ${current_hour}
    ...    msg=Verification Failed: hour not set correctly. Expected: ${set_hour}, got: ${current_hour}

Set Timer Hours Optimally
    [Documentation]    Set hours optimally
    ...                - *Date of Implementation:* 09-02-2026
    ...                - *Author:* Valentyn Karpiuk
    ...                - *Usage:* Calculate the distance upwards (up) and downwards (down), assuming the values wrap around cyclically.
    [Tags]    internal
    [Arguments]    ${set_hour}
    ${set_hour}=    Convert To Integer    ${set_hour}
    ${current_hour}=    Get And Convert Time    ${general_settings_label_hour}
    ${up_distance}=    Evaluate    (${set_hour} - ${current_hour}) % 24
    ${down_distance}=    Evaluate    (${current_hour} - ${set_hour}) % 24
    Run Keyword If    ${up_distance} <= ${down_distance}
    ...    Set Timer Hours By Clicking    ${set_hour}    ${general_settings_spin_hour_up}
    ...    ELSE
    ...    Set Timer Hours By Clicking    ${set_hour}    ${general_settings_spin_hour_down}

Set Timer Minutes By Clicking
    [Documentation]    Set minutes by clicking
    ...                - *Date of Implementation:* 09-02-2026
    ...                - *Author:* Valentyn Karpiuk
    ...                - *Usage:* Uses the given button locator to adjust and set the timer to the specified minute value
    [Tags]    internal
    [Arguments]    ${set_minute}    ${button_locator}
    ${current_minute}=    Get And Convert Time    ${general_settings_label_minute}
    ${counter}=    Set Variable    0
    WHILE    ${current_minute} != ${set_minute}
        Click Element    ${button_locator}
        ${current_minute}=    Get And Convert Time    ${general_settings_label_minute}
        ${counter}=    Evaluate    ${counter} + 1
        Run Keyword If    ${counter} > 60    Fail    Too many attempts to set minute!
    END
    Should Be Equal
    ...    ${set_minute}    ${current_minute}
    ...    msg=Verification Failed: Minute not set correctly. Expected: ${set_minute}, got: ${current_minute}

Set Timer Minutes Optimally
    [Documentation]    Set minutes optimally
    ...                - *Date of Implementation:* 09-02-2026
    ...                - *Author:* Valentyn Karpiuk
    ...                - *Usage:* Calculate the distance upwards (up) and downwards (down), assuming the values wrap around cyclically.
    [Tags]
    [Arguments]    ${set_minute}
    ${set_minute}=    Convert To Integer    ${set_minute}
    ${current_minute}=    Get And Convert Time    ${general_settings_label_minute}
    ${up_distance}=    Evaluate    (${set_minute} - ${current_minute}) % 60
    ${down_distance}=    Evaluate    (${current_minute} - ${set_minute}) % 60

    Run Keyword If    ${up_distance} <= ${down_distance}
    ...    Set Timer Minutes By Clicking    ${set_minute}    ${general_settings_spin_min_up}
    ...    ELSE
    ...    Set Timer Minutes By Clicking    ${set_minute}    ${general_settings_spin_min_down}

Set Time
    [Documentation]    Set hours and minutes
    ...                - *Date of Implementation:* 09-02-2026
    ...                - *Author:* Valentyn Karpiuk
    ...                - *Usage:* Optimally sets the time to the specified hours and minutes,
    ...                adjusting values only if they differ from the current time. Example: Set Time 13  00
    [Tags]    101463=29
    [Arguments]    ${hours}    ${minutes}
    ${current_hours}=    Get And Convert Time    ${general_settings_label_hour}
    ${current_minutes}=    Get And Convert Time    ${general_settings_label_minute}
    ${hours_int}=    Convert To Integer    ${hours}
    ${minutes_int}=    Convert To Integer    ${minutes}

    IF   ${current_hours} == ${hours_int} and ${current_minutes} == ${minutes_int}
        Log To Console    The hours and minutes are already set to ${hours}:${minutes}
    ELSE
        Set Timer Hours Optimally    ${hours}
        Set Timer Minutes Optimally    ${minutes}
    END
    ${new_hours}=    Get And Convert Time    ${general_settings_label_hour}
    ${new_minutes}=    Get And Convert Time    ${general_settings_label_minute}
    Should Be Equal    [${new_hours}, ${new_minutes}]    [${hours_int}, ${minutes_int}]
    ...    msg=Verification Failed: Minutes and hours not set correctly. Expected: ${hours_int} : ${minutes_int}, got: ${new_hours} : ${new_minutes}
    [Teardown]    Run Keywords    Document Keyword Outcome    Time was set to ${hours}:${minutes} successfully and verifications passed.    AND    Add Screenshot

Select Down Arrow Button
    [Documentation]    Move the scroll bar button from top to bottom by clicking the down arrow button
    ...                - *Date of Implementation:* 09-02-2026
    ...                - *Author:* Valentyn Karpiuk
    ...                - *Usage:* Moves the scroll bar button downward by clicking the down arrow and verifies the movement.
    [Tags]    97775=19
    Open Language Dropdown
    ${previous_location}=    Get Property    ${general_settings_language_scroll_bar_button}    y
    IF    ${previous_location} == 180
        Log To Console   Scroll bar button is already at the bottom and cannot be moved further down.
    ...            INFO    msg=Scroll bar button is already at the bottom and cannot be moved further down.
    ELSE
        Click Element    ${general_settings_language_down_button_image}
        ${current_location}=    Get Property    ${general_settings_language_scroll_bar_button}    y
        Should Be True    ${previous_location} < ${current_location}    msg=The scroll bar button does not move down after clicking down arrow button.
    END

    [Teardown]    Run Keywords    Document Keyword Outcome    Moved the scroll bar button from top to bottom by clicking the down arrow button successfully and verifications passed
    ...    AND    Add Screenshot

Select Up Arrow Button
    [Documentation]    Move the scroll bar button from bottom to top by clicking the up arrow button
    ...                - *Date of Implementation:* 09-02-2026
    ...                - *Author:* Valentyn Karpiuk
    ...                - *Usage:* Moves the scroll bar button upward by clicking the up arrow and verifies the movement.
    [Tags]    97775=18
    Open Language Dropdown
    ${previous_location}=    Get Property    ${general_settings_language_scroll_bar_button}    y
    IF    ${previous_location} == 45
        Log To Console    Scroll bar button is already at the top and cannot be moved further up.
    ...        INFO    msg=Scroll bar button is already at the top and cannot be moved further up.
    ELSE
        Click Element    ${general_settings_language_up_button_image}
        ${current_location}=    Get Property    ${general_settings_language_scroll_bar_button}    y
        Should Be True    ${previous_location} > ${current_location}    msg=The scroll bar button does not move up after clicking up arrow button.
    END

        [Teardown]    Run Keywords    Document Keyword Outcome    Moved the scroll bar button from bottom to top by clicking the up arrow button successfully and verifications passed
    ...    AND    Add Screenshot

Click Navigation Button In Date Picker
    [Documentation]    Clicks the specified navigation button in date picker and optionally verifies if the header text changed accordingly to the expected behavior.
    ...                - *Date of Implementation:* 27-04-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* ``navigation_direction`` parameter specifies the direction of navigation, either 'forward' or 'backward'. 
    ...                ``button_type`` parameter specifies whether to click the normal navigation buttons (next/previous month) or the fast navigation buttons (jump forward/backward).
    ...                ``verify_view`` is a boolean parameter that determines whether to verify the change in header text after navigation.
    ...                ``view_should_change`` is a boolean parameter that specifies whether change in header text is expected after navigation.
    ...                - *Returns:* N/A
    [Tags]    101463=9,10,12,14,22,23,25,27
    [Arguments]    ${navigation_direction}    ${button_type}=normal    ${verify_view}=True    ${view_should_change}=True
    VAR    ${verification_msg}
    ${current_view}=    Get Property    ${general_settings_current_date_drop_down}    viewMode    False
    ${header_text_before}=    Date Picker Get Header Text
    IF    '${navigation_direction}' == 'forward'
        IF    '${button_type}' == 'normal'
            Click Element    ${general_settings_calendar_next_btn}
        ELSE IF    '${button_type}' == 'fast'
            Click Element   ${general_settings_calendar_jump_forward_btn}
        END
    ELSE IF    '${navigation_direction}' == 'backward'
        IF    '${button_type}' == 'normal'
            Click Element    ${general_settings_calendar_prev_btn}
        ELSE IF    '${button_type}' == 'fast'
            Click Element    ${general_settings_calendar_jump_back_btn}
        END
    ELSE
        Fail    msg=Invalid navigation direction: ${navigation_direction}. Expected 'forward' or 'backward'.
    END

    IF    ${verify_view}
        ${header_text_after}=    Date Picker Get Header Text
        IF    ${view_should_change}
            Should Not Be Equal As Strings    ${header_text_before}    ${header_text_after}    msg=Header text did not change after navigation, but it was expected to change.
            VAR    ${verification_msg}    Header text changed as expected. Current view: ${current_view}, header text before: ${header_text_before}, header text after: ${header_text_after}.
        ELSE
            Should Be Equal As Strings    ${header_text_before}    ${header_text_after}    msg=Header text changed after navigation, but it was expected to remain the same.
            VAR    ${verification_msg}    Header text did not change, which is expected behavior. Current view: ${current_view}, header text before: ${header_text_before}, header text after: ${header_text_after}.
        END
    ELSE
        VAR    ${verification_msg}    ${navigation_direction.capitalize()} navigation in date picker performed.
    END
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: ${verification_msg}    AND    Add Screenshot

Select View In Date Picker
    [Documentation]    Selects the date picker view on the settings page and verifies that it is displayed.
    ...                - *Date of Implementation:* 31-03-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* Clicks on date picker header to open desired view and verifies that the view is displayed.
    ...                `view` parameter specifies the view to be selected, e.g. 'day', 'month' or 'year'.
    [Tags]    98893=6,11    101463=7,11,13,15,20,24,26
    [Arguments]    ${view}
    FOR    ${_}    IN RANGE    3
        ${current_view}=    Get Property    ${general_settings_current_date_drop_down}    viewMode    False
        ${view}=    Convert To Lower Case    ${view}
        ${res}=    Run Keyword And Return Status    Should Be Equal As Strings    ${view}    ${current_view}
        IF    ${res}
            RETURN
        ELSE
            Click Element    ${general_settings_calendar_month_year_btn}
        END
    END
    Fail    msg=Failed to open ${view} view in date picker after multiple attempts.

    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: Successfully opened ${view} view in date picker.    AND    Add Screenshot

Select View And Verify Selected Date Is Displayed In Date Picker
    [Documentation]    Navigates to the specified view and verifies that the selected date is displayed correctly.
    ...    - *Date of Implementation:* 28-04-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:* Scrolls view in date picker to desired ``view_name`` and checks if ``expected_date`` is selected.
    ...    - *Returns:* N/A
    [Tags]    101463=5,6,18,19
    [Arguments]    ${view_name}    ${expected_date}
    Select View In Date Picker    ${view_name}
    ${displayed_date_info}=    Date Picker Get Data Of Currently Selected Delegate
    Should Be Equal As Strings    ${displayed_date_info}[text]    ${expected_date}    msg=Displayed date does not match the expected date in the ${view_name} view.
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: The selected date is displayed correctly in ${view_name} view of date picker. Displayed date: ${displayed_date_info}[text], Expected date: ${expected_date}.    AND    Add Screenshot


Scroll Year View Until Year Is In Range In Date Picker
    [Documentation]    Scrolls year view in date picker until the specified year is in range.
    ...                - *Date of Implementation:* 08-04-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* Scrolls year view in date picker until the specified year is in range. 
    ...                `year` parameter specifies the year to be found in the year view.
    [Tags]    internal
    [Arguments]    ${year}
    VAR    ${verification_msg}
    # input validation
    ${res}=    Evaluate    ${DATE_PICKER_MIN_YEAR_RANGE} <= ${year} <= ${DATE_PICKER_MAX_YEAR_RANGE}
    Should Be True    ${res}    msg=Invalid year ${year} provided for scrolling. Year must be between ${DATE_PICKER_MIN_YEAR_RANGE} and ${DATE_PICKER_MAX_YEAR_RANGE}.
    
    ${current_start_year_range}=    Get Property    ${general_settings_calendar_year_view}    startYear
    ${year_difference}=    Evaluate    ${year} - ${current_start_year_range}
    ${year_diff_abs}=    Evaluate    abs(${year_difference})
    ${is_diff_positive}=    Evaluate    ${year_difference} > 0
    IF    ${year} >= ${current_start_year_range} and ${year} < ${current_start_year_range} + ${DATE_PICKER_MAX_YEARS_VIEW}
        VAR    ${verification_msg}    Year ${year} was already in range in year view of date picker. Current start year range: ${current_start_year_range}.
        RETURN
    END
    
    VAR    ${safe_counter}=    ${0}
    WHILE    ${True}
        IF    ${is_diff_positive}
            Click Element    ${general_settings_calendar_next_btn}
        ELSE
            Click Element    ${general_settings_calendar_prev_btn}
        END
        ${current_start_year_range}=    Get Property    ${general_settings_calendar_year_view}    startYear
        IF    ${year} >= ${current_start_year_range} and ${year} < ${current_start_year_range} + ${DATE_PICKER_MAX_YEARS_VIEW}
            BREAK
        ELSE
            # below should result in 11
            ${max_year_span}=    Evaluate    int((((${DATE_PICKER_MAX_YEAR_RANGE} - ${DATE_PICKER_MIN_YEAR_RANGE}) + 1) / ${DATE_PICKER_MAX_YEARS_VIEW}))
            IF    ${safe_counter} >= ${max_year_span} + 1
                Fail    msg=Exceeded maximum number of scrolls while trying to find year ${year} in year view of date picker. Current start year range after scrolling: ${current_start_year_range}.
            ELSE
                ${safe_counter}=    Evaluate   ${safe_counter} + ${1} 
                CONTINUE
            END
        END
    END
    ${current_start_year_range}=    Get Property    ${general_settings_calendar_year_view}    startYear
    ${year_difference}=    Evaluate    ${year} - ${current_start_year_range}
    ${year_diff_abs}=    Evaluate    abs(${year_difference})
    IF    ${year_diff_abs} >= ${DATE_PICKER_MAX_YEARS_VIEW}
        BuiltIn.Fail    msg=Failed to scroll year view in date picker to the range containing year ${year}. Current start year range after scrolling: ${current_start_year_range}.
    ELSE
        VAR    ${verification_msg}    Scrolled year view in date picker until year ${year} was in range successfully. Current start year range after scrolling: ${current_start_year_range}.
    END
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: ${verification_msg}    AND    Add Screenshot


Select Item In Date Picker
    [Documentation]    Internal helper: selects an item (day, month or year) in the date picker by text
    ...    and verifies the selection changed.
    ...    - *Date of Implementation:* 08-04-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:* This keyword is used to select a specific item (day, month, or year) in the date picker based on the provided text.
    ...    ``item_type``: type of item to select. Allowed values: 'day', 'month', 'year'.
    ...    ``item_text``: the text to click (e.g. '15', 'March', '1994').
    ...    ``day_filter_mode`` is used to specify if we want to click only days from current month or also days from previous/next month which are visible in calendar.
    ...    Possible values for ``day_filter_mode`` are: ``current_month_only``, ``all``, ``beyond_current_month_only``.
    ...    - *Returns:* Verification status, Verification message, selected item text before clicking, selected item text after clicking for further verification if needed.
    [Tags]    internal
    [Arguments]    ${item_type}    ${item_text}    ${day_filter_mode}=current_month_only
    VAR    ${verification_msg}
    ${delegate_before}=    Date Picker Get Data Of Currently Selected Delegate
    VAR    ${text_before}=    ${delegate_before}[text]

    IF    '${item_type}' == 'day'
        Date Picker Click Day By Text    ${item_text}    ${day_filter_mode}
    ELSE IF    '${item_type}' == 'month'
        Date Picker Click Month By Text    ${item_text}
    ELSE IF    '${item_type}' == 'year'
        Scroll Year View Until Year Is In Range In Date Picker    ${item_text}
        Date Picker Click Year By Text    ${item_text}
    ELSE
        Fail    msg=Invalid item_type '${item_type}'. Allowed values: 'day', 'month', 'year'.
    END

    ${delegate_after}=    Date Picker Get Data Of Currently Selected Delegate
    VAR    ${text_after}=    ${delegate_after}[text]
    
    IF    '${text_before}' == '${item_text}'
        Log    The ${item_type} ${item_text} was already selected in date picker.
        VAR    ${verification_msg}    The ${item_type} ${item_text} was already selected in date picker.
        VAR    ${verification_result}    ${True}
    ELSE
        VAR    ${fail_msg}    Selected ${item_type} in date picker did not change after clicking on a ${item_type}. 
        ...    Selected ${item_type} delegate before clicking: ${text_before}, after clicking: ${text_after}.
        ${res}=    Run Keyword And Return Status    Should Not Be Equal As Strings    ${text_before}    ${text_after}    msg=${fail_msg}
        IF    ${res}
            ${verification_msg}    Set Variable    Selected ${item_type} in date picker was changed successfully.
            ...    Selected ${item_type} before clicking: ${text_before}, ${item_type} after clicking: ${text_after}.
            VAR    ${verification_result}    ${True}
        ELSE
            VAR    ${verification_msg}    ${fail_msg}
            VAR    ${verification_result}    ${False}
        END
            
    END
    RETURN    ${verification_result}    ${verification_msg}    ${text_before}    ${text_after}

Select Day In Date Picker
    [Documentation]    Selects the day in date picker on settings page and optionally verifies that the selected day is correct.
    ...                - *Date of Implementation:* 01-04-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* `day` parameter specifies the day to be selected in date picker.
    ...                ``day_filter_mode`` is used to specify if we want to click only days from current month or also days from previous/next month which are visible in calendar.
    ...                Possible values for ``day_filter_mode`` are: ``current_month_only``, ``all``, ``beyond_current_month_only``.
    ...                By default ``day_filter_mode`` is set to ``current_month_only``.
    ...               ``verify_selection``: boolean specifying whether to verify that the selection changed after clicking on the day. Default value is True.
    ...               ``selection_should_change``: boolean specifying whether selection was expected to happen.
    ...                - *Returns:* Verification message, day before change, day after change.
    [Tags]    101463=8,21
    [Arguments]    ${day}    ${day_filter_mode}=current_month_only    ${verify_selection}=True    ${selection_should_change}=True
    VAR    ${verification_msg}
    ${verification_status}    ${verification_msg}    ${day_before_text}    ${day_after_text}=
    ...    Select Item In Date Picker       day    ${day}    ${day_filter_mode}
    IF    ${verify_selection}
        IF    ${selection_should_change}
            Should Be True    ${verification_status}    msg=${verification_msg}
        ELSE
            Should Not Be True    ${verification_status}    msg=Selection did happen but it should not to.
        END
    ELSE
        VAR    ${verification_msg}    Day ${day} was clicked in date picker.
    END
    RETURN    ${verification_msg}    ${day_before_text}    ${day_after_text}
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: ${verification_msg}    AND    Add Screenshot

Select Date Other Than Currently Selected In Date Picker
    [Documentation]    Selects a date other than currently selected in date picker on settings page and verifies that the selected day is correct.
    ...                - *Date of Implementation:* 13-04-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* This keyword selects a different day than currently selected in date picker and verifies that the selected day has changed.
    ...                For days and years, it selects the previous day/year, for months it selects the next month.
    ...                `date_type` parameter specifies the type of date item to be selected, possible values 'day', 'month', 'year'.
    [Tags]    98893=2,7,12
    [Arguments]    ${date_type}
    VAR    ${verification_msg}
    # Capture current selected day
    ${selected_before}=    Date Picker Get Data Of Currently Selected Delegate
    ${selected_before_text}=    Set Variable    ${selected_before}[text]
    # this should be the same as selected_before
    IF    '${date_type}' == 'year'
        ${saved_date}=       Date Picker Get Data Of Currently Saved Delegate    year
    ELSE
        ${saved_date}=       Date Picker Get Data Of Currently Saved Delegate    date
    END
    ${saved_date_text}=    Set Variable    ${saved_date}[text]

    # Pick another day than currently selected
    IF    '${date_type}' == 'day'
        ${current_day_int}=    Convert To Integer    ${selected_before_text}
        IF    ${current_day_int} == ${1}
            ${target_date}=    Set Variable    2
        ELSE
            ${target_date}=    Evaluate    ${current_day_int} - 1
        END
        Select Day In Date Picker    ${target_date}
    ELSE IF    '${date_type}' == 'month'
        ${month_num}=    Evaluate    list(calendar.month_abbr).index($selected_before_text)    modules=calendar
        ${next_month_num}=    Evaluate    (${month_num} % 12) + 1
        ${target_date}=    Evaluate    calendar.month_abbr[${next_month_num}]    modules=calendar
        Select Month In Date Picker    ${target_date}
    ELSE IF    '${date_type}' == 'year'
        ${current_year_int}=    Convert To Integer    ${selected_before_text}
        IF    ${current_year_int} == ${DATE_PICKER_MIN_YEAR_RANGE}
            ${res}=    Evaluate    ${DATE_PICKER_MIN_YEAR_RANGE} + 1
            ${target_date}=    Set Variable    ${res}
        ELSE
            ${target_date}=    Evaluate    ${current_year_int} - 1
        END
        Select Year In Date Picker    ${target_date}
    END

    ${selected_after}=    Date Picker Get Data Of Currently Selected Delegate
    ${selected_after_text}=    Set Variable    ${selected_after}[text]
    
    Should Not Be Equal As Strings    ${selected_before_text}    ${selected_after_text}    msg=Selected date in date picker did not change after selecting a different date. Selected date before clicking: ${selected_before_text}, selected date after clicking: ${selected_after_text}.
    Should Not Be Equal As Strings    ${saved_date_text}    ${selected_after_text}    msg=Selected date in date picker did not change after selecting a different date. Selected date before clicking: ${saved_date_text}, selected date after clicking: ${selected_after_text}.
    
    Should Be True    ${saved_date}[visible]    msg=Saved date delegate is not visible.
    Should Be True    ${selected_after}[visible]    msg=Selected date delegate is not visible after selecting a different date.
    
    VAR    ${verification_msg}    Selected a different ${date_type} in date picker successfully. Selected ${date_type} before clicking: ${selected_before_text}, selected ${date_type} after clicking: ${selected_after_text}. Selected date and saved date were visible.
    RETURN    ${verification_msg}    ${selected_before_text}    ${selected_after_text}
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: ${verification_msg}   AND    Add Screenshot
    
Select Month In Date Picker
    [Documentation]    Selects the month in date picker on settings page and optionally verifies that the selected month is correct.
    ...                - *Date of Implementation:* 02-04-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* `month` parameter specifies the month to be selected in date picker.
    ...                ``verify_selection_changed``: boolean specifying whether to verify that the selection changed after clicking on the day. Default value is True.
    ...                - *Returns:* Verification message, month before change, month after change.
    [Tags]    internal
    [Arguments]    ${month}    ${verify_selection_changed}=True
    VAR    ${verification_msg}
    ${verification_status}    ${verification_msg}    ${month_before_text}    ${month_after_text}=
    ...    Select Item In Date Picker       month    ${month}
    IF    ${verify_selection_changed}
        Should Be True    ${verification_status}    msg=${verification_msg}
    ELSE
        VAR    ${verification_msg}    Month ${month} was clicked in date picker.
    END
    RETURN    ${verification_msg}    ${month_before_text}    ${month_after_text}
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: ${verification_msg}    AND    Add Screenshot

Select Year In Date Picker
    [Documentation]    Selects the year in date picker on settings page and optionally verifies that the selected year is correct.
    ...                - *Date of Implementation:* 02-04-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* `year` parameter specifies the year to be selected in date picker.
    ...                ``verify_selection_changed``: boolean specifying whether to verify that the selection changed after clicking on the day. Default value is True.
    ...                - *Returns:* Verification message, year before change, year after change.
    [Tags]    internal
    [Arguments]    ${year}    ${verify_selection_changed}=True
    VAR    ${verification_msg}
    ${verification_status}    ${verification_msg}    ${year_before_text}    ${year_after_text}=
    ...    Select Item In Date Picker       year    ${year}
    IF    ${verify_selection_changed}
        Should Be True    ${verification_status}    msg=${verification_msg}
    ELSE
        VAR    ${verification_msg}    Year ${year} was clicked in date picker.
    END
    RETURN    ${verification_msg}    ${year_before_text}    ${year_after_text}
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: ${verification_msg}    AND    Add Screenshot

Select Date In Date Picker
    [Documentation]    Selects the date in date picker on settings page and verifies that the selected date is correct.
    ...                - *Date of Implementation:* 02-04-2026
    ...                - *Author:* Mateusz Rosiek
    ...                - *Usage:* Selects the date in date picker by selecting year, month and day and verifies that the selected date is correct.
    ...                ``date`` parameter is expected to be in format 'YYYY MM DD', e.g. '1994 02 15'.
    ...                ``day_filter_mode`` is used to specify if we want to click only days from current month or also days from previous/next month which are visible in calendar.
    ...                Possible values for ``day_filter_mode`` are: ``current_month_only``, ``all``, ``beyond_current_month_only``.
    ...                By default ``day_filter_mode`` is set to ``current_month_only``.
    [Tags]    98893=16,20,24,28    101463=3,16
    [Arguments]    ${date}    ${day_filter_mode}=current_month_only
    VAR    ${verification_msg}
    Validate Date Argument    ${date}
    ${year}    ${month}    ${day}=    Split String    ${date}    separator=${SPACE}
    ${month}=    Convert To Integer    ${month}
    ${day}=    Convert To Integer    ${day}

    Select View In Date Picker    year
    Select Year In Date Picker    ${year}
    Select View In Date Picker    month
    ${month_name}=    Evaluate    calendar.month_abbr[${month}]    modules=calendar
    ${month_name}=    Evaluate    $month_name.capitalize()
    Select Month In Date Picker    ${month_name}
    Select View In Date Picker    day
    Select Day In Date Picker    ${day}    ${day_filter_mode}

    # need to close Date Picker first to be able to aquire its value
    Close Date Picker
    ${selected_date}=    Get Current Value Of Given Setting    date setting
    # remove astrisk from the selected date if it is present, since the setting value might have an asterisk appended to
    # it when it is different from the saved value. We only care for the value of the set date.
    ${selected_date}=    Replace String    ${selected_date}    *    ${EMPTY}    count=1
    # bring back the date picker
    Open Date Picker
    Should Be Equal As Strings    ${selected_date}    ${date}    msg=Selected date in date picker is not correct. Expected: ${date}, got: ${selected_date}.
    VAR    ${verification_msg}    Selected date ${date} in date picker successfully and verified that the selected date is correct.
    RETURN    ${verification_msg}    ${selected_date}
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: ${verification_msg}    AND    Add Screenshot

##################################################################################
########################## END OF Settings Screen Keywords #######################
##################################################################################

##################################################################################
########################## Visibility Assertion Keywords #########################
##################################################################################

Verify Element Is Visible
    [Documentation]    Verifies that the element referenced by ``object_real_name`` is visible.
    ...                - *Date of Implementation:* 06-03-2026
    ...                - *Author:* Mina Bikhit
    ...                - *Usage:* Performs an assertion to verify that the element referenced by ``object_real_name`` is visible. Fails if the element is not visible.
    [Tags]    98718=5,10    111118=1,3,5
    [Arguments]    ${object_real_name}

    ${object_identifier}=    Get Object Identifier    ${object_real_name}
    ${res}=    Element Should Be Visible    ${object_real_name}
    Should Be True    ${res}    msg=Element '${object_identifier}' should be visible but it is not.
    [Teardown]    Run Keywords    Document Keyword Outcome    Verified element ${object_identifier} is visible.    AND   Add Screenshot

Verify Element Is Not Visible
    [Documentation]    Verifies that the element referenced by ``object_real_name`` is NOT visible.
    ...                - *Date of Implementation:* 06-03-2026
    ...                - *Author:* Mina Bikhit
    ...                - *Usage:* Performs an assertion to verify that the element referenced by ``object_real_name`` is NOT visible. Fails if the element is visible.
    [Tags]    98718=2,7
    [Arguments]    ${object_real_name}

    ${object_identifier}=    Get Object Identifier    ${object_real_name}

    ${res}=    Element Should Not Be Visible    ${object_real_name}
    Should Be True    ${res}    msg=Element '${object_identifier}' should NOT be visible but it is.
    [Teardown]    Run Keywords    Document Keyword Outcome    Verified element ${object_identifier} is not visible.    AND    Add Screenshot

##################################################################################
###################### END OF Visibility Assertion Keywords ######################
##################################################################################

##################################################################################
########################## Property Assertion Keywords ###########################
##################################################################################

Verify Element Property Should Be
    [Documentation]    Verifies that the property ``property_name`` of the element referenced by ``object_real_name``
    ...                matches the ``expected_value``. Comparison is done automatically based on value types (type=auto).
    ...                - *Date of Implementation:* 15-MAY-2026
    ...                - *Author:* Mina Bikhit
    ...                - *Usage:*
    ...                Verify Element Property Should Be    \${header}    color.name    #273848
    ...                Verify Element Property Should Be    \${button}    contentItem.color.name    #dce2ed
    ...                Verify Element Property Should Be    \${text}    font.family    Inter
    ...                Verify Element Property Should Be    \${text}    font.pixelSize    24
    [Tags]    111118=2,4,6,15    58334=2,3
    [Arguments]    ${object_real_name}    ${property_name}    ${expected_value}

    ${object_identifier}=    Get Object Identifier    ${object_real_name}

    ${actual_value}=    Get Property    ${object_real_name}    ${property_name}
    Should Be Equal    ${actual_value}    ${expected_value}    type=auto
    ...    msg=Element '${object_identifier}' property '${property_name}' is ${actual_value} instead of ${expected_value}.
    [Teardown]    Run Keywords    Document Keyword Outcome    Verified element ${object_identifier} property '${property_name}' is ${expected_value}.    AND    Add Screenshot

##################################################################################
###################### END OF Property Assertion Keywords ########################
##################################################################################

##################################################################################
########################## Navigation Assertion Keywords #########################
##################################################################################

Click Back Button And Verify Navigation
    [Documentation]    Clicks the Back button in the Header and verifies navigation to the previous screen.
    ...                Captures the current screen before clicking, then asserts the screen has changed.
    ...                If ``expected_previous_screen`` is provided, it also verifies that the display
    ...                navigated to that specific screen (e.g. "home", "case", "setup", "settings").
    ...                - *Date of Implementation:* 11-MAY-2026
    ...                - *Author:* Mina Bikhit
    ...                - *Usage:*
    ...                Click Back Button And Verify Navigation
    ...                Click Back Button And Verify Navigation    expected_previous_screen=home
    [Tags]    111118=7
    [Arguments]    ${expected_previous_screen}=${EMPTY}
    ${screen_before}=    Get Title
    Select Back Button on Header    expect_confirmation_dialog=False
    ${screen_after}=    Get Title
    Should Not Be Equal As Strings    ${screen_after}    ${screen_before}
    ...    msg=Fail, Screen did not change after clicking the Back button. Still on '${screen_before}'.
    IF    '${expected_previous_screen}' != '${EMPTY}'
        Should Be Equal As Strings    ${screen_after}    ${expected_previous_screen}
        ...    msg=Fail, Expected to navigate to '${expected_previous_screen}' but landed on '${screen_after}'.
    END
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: Back button navigated from '${screen_before}' to '${screen_after}'.    AND    Add Screenshot

##################################################################################
###################### END OF Navigation Assertion Keywords ######################
##################################################################################

##################################################################################
########################## Reports Screen Keywords ###############################
##################################################################################

Navigate To Reports Page
    [Documentation]    Navigates to the Reports page from the main menu.
    ...                - *Date of Implementation:* 11-MAY-2026
    ...                - *Author:* Mina Bikhit
    [Tags]    111118=8
    Open Menu
    Select Option From Menu    report
    ${res}=    Element Should Be Visible    ${reportsScreen}
    Should Be True    ${res}    msg=Fail, Navigation to Reports page failed. Reports screen not visible.
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: Navigated to Reports page successfully.    AND    Add Screenshot

Verify Reports Row Is Displayed
    [Documentation]    Verifies that the Reports screen displays a row for each report.
    ...                If ``expected_row_count`` is provided, also asserts that the actual number
    ...                of rows matches the expected count.
    ...                - *Date of Implementation:* 11-MAY-2026
    ...                - *Author:* Mina Bikhit
    [Tags]    111118=9
    [Arguments]    ${expected_row_count}=${EMPTY}
    ${count}=    Get Number of Items In List View    ${reports_list_view}
    Should Be True    ${count} > 0    msg=Fail, No report rows are displayed on the Reports screen.
    IF    '${expected_row_count}' != '${EMPTY}'
        Should Be Equal As Integers    ${count}    ${expected_row_count}
        ...    msg=Fail, Expected ${expected_row_count} report row(s) but found ${count}.
    END
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: Reports screen displays ${count} report row(s).    AND    Add Screenshot

Verify Element Is Visible In Every Reports Row
    [Documentation]    Iterates through every row in the Reports list and verifies that the element
    ...                referenced by ``object_real_name`` is visible in each row.
    ...                The locator should use a RegularExpression for objectName to match all row indices.
    ...                Uses Position List View at Index to scroll to each row before checking.
    ...                - *Date of Implementation:* 11-MAY-2026
    ...                - *Author:* Mina Bikhit
    ...                - *Usage:* Verify Element Is Visible In Every Reports Row    \${reports_view_button}
    [Tags]    111118=10,14
    [Arguments]    ${object_real_name}
    ${object_identifier}=    Get Object Identifier    ${object_real_name}
    ${count}=    Get Number of Items In List View    ${reports_list_view}
    Should Be True    ${count} > 0    msg=Fail, No report rows found in the Reports list.
    FOR    ${index}    IN RANGE    ${count}
        Position List View at Index    ${reports_list_view}    ${index}
        ${res}=    Element Should Be Visible    ${object_real_name}
        Should Be True    ${res}    msg=Fail, Element '${object_identifier}' is not visible in row ${index}.
    END
    [Teardown]    Run Keywords    Document Keyword Outcome    Verified element ${object_identifier} is visible in all ${count} report row(s).    AND    Add Screenshot

Verify Element Property In Every Reports Row
    [Documentation]    Iterates through every row in the Reports list and verifies that the property
    ...                ``property_name`` of the element referenced by ``object_real_name`` matches
    ...                the ``expected_value`` in each row.
    ...                The locator should use a RegularExpression for objectName to match all row indices.
    ...                Uses Position List View at Index to scroll to each row before checking.
    ...                If ``as_integer`` is set to True, comparison is done as integers.
    ...                - *Date of Implementation:* 15-MAY-2026
    ...                - *Author:* Mina Bikhit
    ...                - *Usage:*
    ...                Verify Element Property In Every Reports Row    \${reports_row_case_name}    color.name    #ffffff
    ...                Verify Element Property In Every Reports Row    \${reports_row_case_name}    font.family    Inter
    ...                Verify Element Property In Every Reports Row    \${reports_row_case_name}    font.pixelSize    24
    [Tags]    111118=10,11,12,13
    [Arguments]    ${object_real_name}    ${property_name}    ${expected_value}
    ${object_identifier}=    Get Object Identifier    ${object_real_name}
    ${count}=    Get Number of Items In List View    ${reports_list_view}
    Should Be True    ${count} > 0    msg=Fail, No report rows found in the Reports list.
    FOR    ${index}    IN RANGE    ${count}
        Position List View at Index    ${reports_list_view}    ${index}
        ${actual_value}=    Get Property Of Nth Object    ${object_real_name}    ${index}    ${property_name}
        Should Be Equal    ${actual_value}    ${expected_value}    type=auto
        ...    msg=Row ${index}: Element '${object_identifier}' property '${property_name}' is ${actual_value} instead of ${expected_value}.
    END
    [Teardown]    Run Keywords    Document Keyword Outcome    Verified element ${object_identifier} property '${property_name}' is ${expected_value} in all ${count} row(s).    AND    Add Screenshot

Verify View Report Navigation In Every Reports Row
    [Documentation]    Iterates through every row in the Reports list, clicks the View Report button,
    ...                verifies that the Case Summary screen opens, then navigates back to the Reports page.
    ...                Repeats for all rows to ensure every View Report button is functional.
    ...                - *Date of Implementation:* 15-MAY-2026
    ...                - *Author:* Mina Bikhit
    [Tags]    111118=16
    ${count}=    Get Number of Items In List View    ${reports_list_view}
    Should Be True    ${count} > 0    msg=Fail, No report rows found in the Reports list.
    FOR    ${index}    IN RANGE    ${count}
        Position List View at Index    ${reports_list_view}    ${index}
        Click Nth Element    ${reports_view_button}    ${index}
        ${res}=    Element Should Be Visible    ${caseSummaryScreen}
        Should Be True    ${res}    msg=Fail, Case Summary screen is not visible after clicking View Report button in row ${index}.
        Add Screenshot
        Select Back Button on Header    expect_confirmation_dialog=False
        ${res}=    Element Should Be Visible    ${reportsScreen}
        Should Be True    ${res}    msg=Fail, Reports screen is not visible after navigating back from row ${index}.

    END
    [Teardown]    Run Keywords    Document Keyword Outcome    Verification Passed: All ${count} View Report button(s) navigated to Case Summary and back successfully.    AND    Add Screenshot

##################################################################################
###################### END OF Reports Screen Keywords ############################
##################################################################################

##################################################################################
########################## Ablation Trigger Keywords #############################
##################################################################################

Trigger Complete Ablation
    [Documentation]    Configures electrodes (if provided), starts ablation,
    ...                and waits for the ablation to complete (generator returns to kGeneratorTherapyReady).
    ...                - *Date of Implementation:* 20-MAY-2026
    ...                - *Author:* Mina Bikhit
    ...                - *Arguments:*
    ...                - ``exp_electrodes_states``: Dict of electrodes and their expected statuses (optional)
    ...                  e.g. D1=enabled 2=disabled 3=enabled P4=disabled
    [Tags]         58334=4
    [Arguments]    &{exp_electrodes_states}
    ${has_electrodes}=    Get Length    ${exp_electrodes_states}
    IF    ${has_electrodes} > 0
        Set electrodes statuses    &{exp_electrodes_states}
    END
    Start Ablation
    Wait Until HDD Field Equals    generatorState    kGeneratorTherapyAblate    timeout=30s    retry_interval=2s
    Wait Until HDD Field Equals    generatorState    kGeneratorTherapyReady    timeout=90s    retry_interval=5s
    [Teardown]    Document Keyword Outcome    Completed ablation with electrodes: &{exp_electrodes_states}.

Trigger Incomplete Ablation
    [Documentation]    Configures electrodes (if provided), starts ablation,
    ...                waits for the specified duration, then stops the ablation and waits for the
    ...                generator to return to kGeneratorTherapyReady state.
    ...                - *Date of Implementation:* 20-MAY-2026
    ...                - *Author:* Mina Bikhit
    ...                - *Arguments:*
    ...                - ``wait_before_stop``: Time to wait before stopping ablation (default: 30s)
    ...                - ``exp_electrodes_states``: Dict of electrodes and their expected statuses (optional)
    ...                  e.g. D1=enabled 2=disabled 3=enabled P4=disabled
    [Tags]         58334=6
    [Arguments]    ${wait_before_stop}=30s    &{exp_electrodes_states}
    ${has_electrodes}=    Get Length    ${exp_electrodes_states}
    IF    ${has_electrodes} > 0
        Set electrodes statuses    &{exp_electrodes_states}
    END
    Start Ablation
    Wait Until HDD Field Equals    generatorState    kGeneratorTherapyAblate    timeout=30s    retry_interval=2s
    Sleep    ${wait_before_stop}
    Stop Ablation
    Wait Until HDD Field Equals    generatorState    kGeneratorTherapyReady    timeout=90s    retry_interval=5s
    [Teardown]    Document Keyword Outcome    Incomplete ablation stopped after ${wait_before_stop} with electrodes: &{exp_electrodes_states}.

Trigger Multiple Ablations
    [Documentation]    Triggers multiple ablations of the same type in a loop.
    ...                - *Date of Implementation:* 20-MAY-2026
    ...                - *Author:* Mina Bikhit
    ...                - *Arguments:*
    ...                - ``type``: complete or incomplete (required)
    ...                - ``count``: Number of ablations to perform (required)
    ...                - ``wait_before_stop``: Time to wait before stopping (optional, default: 30s, only for incomplete)
    ...                - ``exp_electrodes_states``: Dict of electrodes and their expected statuses (optional)
    ...                - *Usage:*
    ...                Trigger Multiple Ablations    complete    3
    ...                Trigger Multiple Ablations    incomplete    2    wait_before_stop=20s
    ...                Trigger Multiple Ablations    complete    3    D1=enabled    2=disabled    3=enabled    P4=disabled
    [Tags]    internal
    [Arguments]    ${type}    ${count}    ${wait_before_stop}=30s    &{exp_electrodes_states}
    ${count}=    Convert To Integer    ${count}
    FOR    ${index}    IN RANGE    1    ${count} + 1
        Log    Ablation ${index} of ${count} (${type})    console=True
        IF    '${type.lower()}' == 'complete'
            Trigger Complete Ablation    &{exp_electrodes_states}
        ELSE IF    '${type.lower()}' == 'incomplete'
            Trigger Incomplete Ablation    wait_before_stop=${wait_before_stop}    &{exp_electrodes_states}
        ELSE
            Fail    Unknown ablation type '${type}'. Must be 'complete' or 'incomplete'.
        END
    END
    [Teardown]    Document Keyword Outcome    Completed ${count} ${type} ablation(s).

Trigger Ablation Sequence
    [Documentation]    Orchestrator keyword that triggers multiple ablations based on a list of ablation configurations.
    ...                Each ablation config is a dictionary with the following keys:
    ...                - ``type``: complete or incomplete (required)
    ...                - ``tag``: R or L (optional) - selects the tag button before ablation
    ...                - ``wait_before_stop``: time to wait before stopping (optional, default: 30s, only for incomplete)
    ...                - ``D1``, ``2``, ``3``, ``P4``: electrode statuses - enabled/disabled (optional)
    ...                - *Date of Implementation:* 20-MAY-2026
    ...                - *Author:* Mina Bikhit
    ...                - *Usage:*
    ...                \@{ablation_1}=    Create Dictionary    type=complete    tag=R    D1=enabled    2=enabled    3=disabled    P4=disabled
    ...                \@{ablation_2}=    Create Dictionary    type=incomplete    tag=L    wait_before_stop=20s    D1=enabled    2=disabled    3=enabled    P4=enabled
    ...                Trigger Ablation Sequence    ${ablation_1}    ${ablation_2}
    [Tags]    internal
    [Arguments]    @{ablation_configs}
    ${total}=    Get Length    ${ablation_configs}
    FOR    ${index}    ${config}    IN ENUMERATE    @{ablation_configs}    start=1
        Log    Ablation ${index} of ${total}    console=True

        # Extract type (required)
        ${type}=    Get From Dictionary    ${config}    type

        # Extract and remove optional tag
        ${has_tag}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${config}    tag
        IF    ${has_tag}
            ${tag}=    Get From Dictionary    ${config}    tag
            Remove From Dictionary    ${config}    tag
            IF    '${tag.upper()}' == 'R'
                Select R Button
            ELSE IF    '${tag.upper()}' == 'L'
                Select L Button
            END
        END

        # Extract and remove type, leaving only electrode states
        Remove From Dictionary    ${config}    type

        # Extract and remove optional wait_before_stop (only relevant for incomplete)
        ${has_wait}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${config}    wait_before_stop
        IF    ${has_wait}
            ${wait_before_stop}=    Get From Dictionary    ${config}    wait_before_stop
            Remove From Dictionary    ${config}    wait_before_stop
        ELSE
            ${wait_before_stop}=    Set Variable    30s
        END

        # Trigger the appropriate ablation type
        IF    '${type.lower()}' == 'complete'
            Trigger Complete Ablation    &{config}
        ELSE IF    '${type.lower()}' == 'incomplete'
            Trigger Incomplete Ablation    wait_before_stop=${wait_before_stop}    &{config}
        ELSE
            Fail    Unknown ablation type '${type}'. Must be 'complete' or 'incomplete'.
        END
    END
    [Teardown]    Document Keyword Outcome    Completed ablation sequence of ${total} ablation(s).

##################################################################################
###################### END OF Ablation Trigger Keywords ##########################
##################################################################################

