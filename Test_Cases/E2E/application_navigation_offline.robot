*** Settings ***
Documentation    NOVA application inspection test for verifying the application launch,
...              SSO authentication, Offline Update navigation, and Update Device flow.
...              - *Date of Implementation:* 2026-09-11
...              - *Author:* <HashmadAli>
...              - *User Story:* US_ID

Library    FlaUILibrary
Resource   ../../resources/variables/application/application_variables.robot
Resource   ../../resources/keywords/Keyword_Codebeamer.robot
Resource   ../../Keywords/Keyword_Application.robot

Test Setup        Run Keywords    Get Test Start Time
Test Teardown     Run Keywords    Collect Test Result    Close NOVA
Suite Teardown    Run Keywords    Create Test Run In Codebeamer


*** Test Cases ***
143698: Verify navigation to Update Software (Offline)
    [Documentation]    Verify the NOVA application launches successfully, the user can authenticate using SSO,
    ...                navigate to the Offline Update page, verify the required controls,
    ...                and continue to the Update Device flow.
    ...                - *Date of Implementation:* 2026-09-11
    ...                - *Author:* <HashmadAli>
    ...                - *TCID:* [https://crdn.codebeamer.com/item/143698 | 143698]
    ...                - *Verifies:* [https://crdn.codebeamer.com/issue/141004 | 141004]
    [Tags]    application    smoke    ui_interface    positive

    Launch NOVA
    Authenticate Using SSO
    Select Update Software Offline
    Verify Offline Update Controls
    Continue To Update Device