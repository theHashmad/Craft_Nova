*** Settings ***
Documentation       A resource file with reusable keywords and variables intended for use with display related tests.
...                 This resource file heavily depends on SquishLibrary.py file which is imported dynamically in
...                 Open display keyword.

Library             ExcelLibrary
Library             String
Library             Collections
Library             OperatingSystem
Library             JSONLibrary
Library             Process
Library             ../Common_Lib/Squish/SquishUtilLibrary.py
Library             ../Common_Lib/Squish/squish_tools.py
Resource            ../Configuration/CICD/CICD_Configuration.resource
Resource            ../Configuration/TightVNC/TightVNC_Configuration.resource
Resource            Keyword_Common.robot
Resource            Keyword_System.robot
Resource            Keyword_States_API.robot


Variables           ../Configuration/Squish/Squish_Configuration.py
Variables           ../Product_Configuration/UI/Supported_Settings.py
Variables           ../Product_Configuration/UI/Reports_Page.py
Variables           ../Product_Configuration/UI/Case_Page.py


*** Variables ***
${DISPLAY_APP_NAME}     display


*** Keywords ***
Open display
    [Documentation]    Establish squish connection to display app. This keyword is preparing environment for running
    ...    squish based tests - setting up PYTHONPATH and sys.path, dynamically imports SquishLibrary.py,
    ...    dynamically importing Object Repository locators, attaches to AUT and open VNC viewer if applicable.
    ...
    ...    Please note, when calling this method one must call Close display keyword when finished interacting
    ...    with display.
    [Tags]    internal
    Setup Display
    ${host_ip}=    Evaluate    __import__('socket').gethostbyname(r'${HOST}')
    Log    Resolved ${HOST} -> ${host_ip}. Re-registering AUT with squishserver using IP.    DEBUG
    Add Attachable Aut    ${AUT}    ${host_ip}    ${SQUISH_AUT_LISTENER_PORT}
    Wait Until Keyword Succeeds    10x    2s    Connect To AUT
    Open VNC viewer    ${HOST}    5900

Setup display
    [Documentation]    Setup display configuration by setting up PYTHONPATH and sys.path, dynamically importing
    ...    SquishLibrary.py, dynamically importing Object Repository locators
    ...
    [Tags]    internal
    Should Not Be Equal
    ...    ${SQUISH_DIR}
    ...    ${None}
    ...    msg=Variable SQUISH_DIR must be provided in CLI before running UI tests.
    Set environment variables
    # dynamic import is necessary for possibility to set env variable which is needed to set reports dir inside
    # SquishLibrary.py
    # this variable must be set before importing SquishLibrary.py
    # squishtest.setTestResult("xml3.4", "%s/test_results_xml" % os.environ[SQUISH_REPORTS_DIR_ENV_NAME])
    Import Library    Common_Lib/Squish/SquishLibrary.py

    ${config}=    Get Squishserver Configuration    # for debug
    Log To Console And Report    ${config}    level=DEBUG    console=${False}

    Import Object Repository Locators

Import object repository locators
    [Documentation]    Dynamically imports Object Repository locators for display application.
    [Tags]    internal
    Import Variables    Common_Lib/Squish/Object_Repository/Common_Objects.py
    Import Variables    Common_Lib/Squish/Object_Repository/Case_Page_Objects.py
    Import Variables    Common_Lib/Squish/Object_Repository/Settings_Page_Objects.py
    Import Variables    Common_Lib/Squish/Object_Repository/Setup_Page_Objects.py
    Import Variables    Common_Lib/Squish/Object_Repository/Reports_Page_Objects.py
    Import Variables    Common_Lib/Squish/Object_Repository/Case_Summary_Page_Objects.py


Close display
    [Documentation]    Closes connection with display app, stopping squishserver and closes VNC viewer if it was open.
    [Tags]    internal
    Disconnect From AUT
    Close VNC viewer

Connect to AUT
    [Documentation]    Attaches to ${AUT} (display app) hosted on ${HOST} using ${AUT_WRAPPER} toolkit.
    [Tags]    internal

    Attach To Aut    ${AUT}    ${AUT_WRAPPER}

Disconnect from AUT
    [Documentation]    Detaches from ${AUT} hosted on ${HOST}
    [Tags]    internal

    Detach From Aut

Validate if application is visible
    [Documentation]    Check if main window application is visible (its property visible is set to True). This verifies
    ...    that application showed up.
    [Tags]    internal

    Log    \nValidate visibility of application main window:
    Element Attribute Value Should Be    ${g4_main_window}    visible    True

Validate application
    [Documentation]    Perform simple check of information returned by Squish about AUT like: OS name and AUT name.
    [Tags]    internal

    Validate If Application Is Visible
    ${info_str}=    Get Application Context Info
    Should Contain    ${info_str}    Linux
    Should Contain    ${info_str}    ${DISPLAY_APP_NAME}

Height Should be
    [Documentation]    Verify height of referenced object by inspecting 'height' property of it.
    [Tags]    internal
    [Arguments]    ${object_real_name}    ${expected_height}
    ${height}=    Get Property    ${object_real_name}    height

    IF    ${height} != ${expected_height}
        SquishLibrary.Fail    Expected value is different than actual one (${expected_height} != ${height})
    ELSE
        Log    Values are as expected (${expected_height} == ${height})
    END

Width Should Be
    [Documentation]    Verify width of referenced object by inspecting 'width' property of it.
    [Tags]    internal
    [Arguments]    ${object_real_name}    ${expected_width}
    ${width}=    Get Property    ${object_real_name}    width

    IF    ${width} != ${expected_width}
        SquishLibrary.Fail    Expected value is different than actual one (${expected_width} != ${width})
    ELSE
        Log    Values are as expected (${expected_width} == ${width})
    END

Current Screen Should Be Equal
    [Documentation]    Verifies if current screen is ${screen_expected} by checking 'main.state' property of main_Item.
    [Tags]    99584=3
    [Arguments]    ${screen_expected}
    ${res}=    Get Title
    Log    Current state: ${res}
    ${res}=    Run Keyword And Return Status    Should Be Equal    ${res}    ${screen_expected}
    RETURN    ${res}
    [Teardown]    Document Keyword Outcome    Verified that the ${screen_expected} screen is displayed.

Set Screen State
    [Documentation]    Set current visible screen to ${state} by setting corresponding PatientCircuit State Machine state
    [Tags]    internal
    [Arguments]    ${state}
    IF    '${state}'=='setup' OR '${state}'=='home'
        Set Disconnected State
        Current Screen Should Be Equal    setup
    ELSE IF    '${state}'=='case'
        Set InSheath State
        Current Screen Should Be Equal    case
    ELSE IF    '${state}'=='settings'
        Navigate To Settings Page
        Current Screen Should Be Equal    settings
    ELSE
        Log To Console    don't have conditions for other screens yet - To Be Updated.
    END

Get Property
    [Documentation]    Acquire reference to Qt UI object by ``object_real_name`` parameter, fetches
    ...    ``property_path`` value and returns it.
    ...
    ...    ``object_real_name`` parameter holds the real name of the object (a dictionary) as defined in
    ...    Object Repository.
    ...
    ...    ``property_path`` value can hold path to property joined by dot separator e.g.: ``font.family``.
    ...    This allows to access nested properties if user knows that some object contains property inside
    ...    another property like in aforementioned ``family.font`` example.
    ...
    ...    When property is not present in referenced object the ``None`` value is returned.
    ...
    ...    ``wait_for_object_to_be_visible`` flag determines if Squish should wait for object to become
    ...    visible and enabled first before its reference is returned. When set to ``False`` Squish only
    ...    checks if referenced object exists in the application and in such case returns its reference.
    ...
    ...    Example usage:
    ...    \${property_value}=    Get Property    \${main_Item}    state
    ...    \${property_value}=    Get Property    \${timer_panel_timer_progress_bar}    width    False
    [Tags]    internal
    [Arguments]    ${object_real_name}    ${property_path}    ${wait_for_object_to_be_visible}=True

    ${value}=    SquishLibrary.Get Property    ${object_real_name}    ${property_path}
    ...    ${wait_for_object_to_be_visible}
    RETURN    ${value}

Get Text
    [Documentation]    Returns the value as text if the element contains a text property
    [Tags]    internal
    [Arguments]    ${object_real_name}

    ${text}=    Get Property    ${object_real_name}    text
    RETURN    ${text}

Get Color
    [Documentation]    Returns the value of color property if element contains it.
    [Tags]    internal
    [Arguments]    ${object_real_name}

    ${color}=    Get Property    ${object_real_name}    color.name
    RETURN    ${color}

Get Title
    [Documentation]    Returns the name of the current screen, for example: "home", "case", "demoSummery", "settings"
    [Tags]    internal

    ${title}=    Get Property    ${main_Item}    state
    RETURN    ${title}

Get Display Application Resolution
    [Documentation]    Gets resolution of entire display application by fetching width and height of main object (root)
    ...    of application.
    [Tags]    internal
    ${width}    ${height}=    Get Element Size    ${g4_main_window}
    RETURN    ${width}    ${height}

Element Attribute Value Should Be
    [Documentation]    Fetch attribute/property value specified by ``attribute`` in referenced ``object_real_name``
    ...    object, performs comparison with expected value and returns comparison result as ``boolean``.
    [Tags]    internal
    [Arguments]    ${object_real_name}    ${attribute}    ${expected_value}    ${wait_for_object_to_be_visible}=True

    ${property_value}=    Get Property    ${object_real_name}    ${attribute}    ${wait_for_object_to_be_visible}

    ${res}=    Run Keyword And Return Status    Should Be Equal    ${property_value}    ${expected_value}    type=auto
    VAR    ${msg}=    SEPARATOR=\n
    ...    Property: ${attribute}
    ...    Current value: ${property_value}
    ...    Expected: ${expected_value}
    ...    Result: ${res}
    Log    ${msg}
    RETURN    ${res}

Element Should Be Visible
    [Documentation]    Returns ``True`` if ``visible`` property in referenced ``object_real_name`` is set to
    ...    ``True``. ``False`` otherwise.
    [Tags]    internal
    [Arguments]    ${object_real_name}

    ${is_visible}=    Get Property    ${object_real_name}    visible    False
    ${res}=    Run Keyword And Return Status    Should Be True    ${is_visible}

    RETURN    ${res}

Element Should Not Be Visible
    [Documentation]    Returns ``True`` if ``visible`` property in referenced ``object_real_name`` is set to
    ...    ``False``. ``False`` otherwise.
    [Tags]    internal
    [Arguments]    ${object_real_name}

    ${is_visible}=    Get Property    ${object_real_name}    visible    False
    ${res}=    Run Keyword And Return Status    Should Not Be True    ${is_visible}

    RETURN    ${res}

Wait for Element to be Invisible
    [Documentation]    Waits until element referenced by ``object_real_name`` becomes invisible or timeout occurs.
    [Tags]    internal
    [Arguments]    ${object_real_name}    ${timeout_ms}=2000
    SquishLibrary.Wait Until Not Visible    ${object_real_name}    ${timeout_ms}

Click Element
    [Documentation]    Clicks element referenced by ``object_real_name``.
    ...    If optional parameters are provided then click is performed at specific coordinates inside the element
    ...    bounds and/or with specific mouse button and/or with specific modifier key pressed.
    ...
    ...    If no optional parameters are provided then click is
    ...    performed at center of the element bounds with left mouse button without any modifier key pressed.
    [Tags]    internal
    [Arguments]    ${object_real_name}    ${x}=${EMPTY}    ${y}=${EMPTY}    ${modifier}=${EMPTY}    ${button}=${EMPTY}

    # Always forward optional args; the Python keyword decides whether to use defaults
    SquishLibrary.Mouse Click    ${object_real_name}    x=${x}    y=${y}    modifier=${modifier}    button=${button}

Click on specific point
    [Documentation]    Clicks on specific point on the screen provided by ``x`` and ``y`` parameters. Note that ``x`` and ``y`` are
    ...    relevant from top-left corner of the screen.
    ...    ``modifier`` and ``button`` parameters are optional. If not provided then click is performed
    ...    with left mouse button without any modifier key pressed.
    [Tags]    internal
    [Arguments]    ${x}    ${y}    ${modifier}=0    ${button}=1
    SquishLibrary.Mouse Click At Coordinates    ${x}    ${y}    ${modifier}    ${button}

Get object left upper corner coordinates
    [Documentation]    Returns X and Y coordinates of the element identified by ``object_real_name`` in scope of global bounds.
    [Tags]    internal
    [Arguments]    ${object_real_name}
    ${py_obj}=    Get Object Reference    ${object_real_name}
    ${bounds}=    SquishLibrary.Get Object Global Bounds    ${py_obj}

    RETURN    ${bounds.x}    ${bounds.y}

Click on Screen Background Area
    [Documentation]    Clicks on common screen background area to remove focus from currently focused element.
    [Tags]    internal

    ${x}    ${y}=    Get Object Left Upper Corner Coordinates    ${common_screen_background_area}
    Click On Specific Point    ${x}    ${y}

Get Element Size
    [Documentation]    Returns width and height of the element identified by ``object_real_name``.
    [Tags]    internal
    [Arguments]    ${object_real_name}

    ${width}=    Get Property    ${object_real_name}    width
    ${height}=    Get Property    ${object_real_name}    height

    RETURN    ${width}    ${height}

Select Next Item In List View
    [Documentation]    Selects next item in ListView identified by ``object_real_name``.
    [Tags]    internal
    [Arguments]    ${object_real_name}

    SquishLibrary.ListView Select Next Item    ${object_real_name}

Select Previous Item In List View
    [Documentation]    Selects previous item in ListView identified by ``object_real_name``.
    [Tags]    internal
    [Arguments]    ${object_real_name}

    SquishLibrary.ListView Select Previous Item    ${object_real_name}

Select Item In List View By Text
    [Documentation]    Selects item in ListView identified by ``object_real_name`` by matching its text with ``item_text``.
    [Tags]    internal
    [Arguments]    ${object_real_name}    ${item_text}

    SquishLibrary.ListView Select Item By Text    ${object_real_name}    ${item_text}

Get Number of Items In List View
    [Documentation]    Returns number of items in ListView identified by ``object_real_name``.
    [Tags]    internal
    [Arguments]    ${object_real_name}

    ${num_items}=    SquishLibrary.ListView Get Count    ${object_real_name}

    RETURN    ${num_items}

Position List View at Index
    [Documentation]    Positions ListView identified by ``object_real_name`` to item specified by ``item_index``.
    [Tags]    internal
    [Arguments]    ${object_real_name}    ${item_index}

    SquishLibrary.ListView Position View at Index    ${object_real_name}    ${item_index}

Get Property Of Nth Object
    [Documentation]    Finds all objects matching ``object_real_name``, picks the one at ``index``,
    ...    and returns the value of ``property_path``. Use this instead of Get Property when iterating
    ...    through repeated UI elements (e.g., list rows) where waitForObject always returns the first match.
    [Tags]    internal
    [Arguments]    ${object_real_name}    ${index}    ${property_path}

    ${value}=    SquishLibrary.Get Property Of Nth Object    ${object_real_name}    ${index}    ${property_path}
    RETURN    ${value}

Click Nth Element
    [Documentation]    Finds all objects matching ``object_real_name``, picks the one at ``index``, and clicks it.
    ...    Use this instead of Click Element when iterating through repeated UI elements.
    [Tags]    internal
    [Arguments]    ${object_real_name}    ${index}

    SquishLibrary.Click Nth Object    ${object_real_name}    ${index}

Get Object Reference
    [Documentation]    Returns reference to object identified by ``object_real_name``.
    ...    Note: Use with RobotFramework Evaluate keyword to work with returned object reference in Python context.
    ...    Remember to reference returned object in Evaluate kw by $ only without {} brackets.
    ...    Example usage:
    ...    \${obj_ref}=    Get Object Reference    \${my_object_symbolic_name}
    ...    \${ret}=    Evaluate    \$obj_ref.method_from_qt_which_i_want_to_call()
    ...    Log To Console    \${ret}
    ...
    ...    ``wait_for_object_to_be_visible`` flag determines if Squish should wait for object to become
    ...    visible and enabled first before its reference is returned. When set to ``False`` Squish only
    ...    checks if referenced object exists in the application and in such case returns its reference.
    [Tags]    internal
    [Arguments]    ${object_real_name}    ${wait_for_object_to_be_visible}=True

    ${obj_ref}=    SquishLibrary.Get Object Reference    ${object_real_name}    ${wait_for_object_to_be_visible}

    RETURN    ${obj_ref}

Drag Object By Offset
    [Documentation]    Drags a UI object in a given direction by a pixel distance using global screen coordinates (globalBounds + ScreenPoint).
    ...                Works with VNC and without VNC.
    ...                - *Date of Implementation:* 06-03-2026
    ...                - *Author:* Valentyn Karpiuk
    ...                - *Usage:*
    ...    Behavior:
    ...    - The object is dragged starting from its center by default (computed from globalBounds).
    ...    - Direction controls the axis:
    ...        - down/up   -> vertical drag
    ...        - right/left-> horizontal drag
    ...    - Distance is given in pixels (positive integer).
    ...    Start position:
    ...    - Default start point is the center of the object (screen coords).
    ...    Additional parameters (&{kwargs}):
    ...    - start_x  : override drag start X in SCREEN coordinates (default = object center)
    ...    - start_y  : override drag start Y in SCREEN coordinates (default = object center)
    ...    - steps    : number of intermediate move steps (default = 30)
    ...    - delay_ms : delay between steps in milliseconds (default = 10)
    ...    - button   : mouse button to use (default = 1, left button)
    ...    - modifier : keyboard modifier (default = 0, no modifier)
    ...    Notes:
    ...    - direction must be one of: up, down, left, right
    ...    - distance must be numeric and >= 0
    ...    - &{kwargs} is always a dictionary (empty if no extra parameters are provided).
    ...    - Unknown keys in &{kwargs} are ignored.
    ...    Examples:
    ...    Drag Object By Offset    ${OBJ}    down    150
    ...    Drag Object By Offset    ${OBJ}    up      150
    ...    Drag Object By Offset    ${OBJ}    right   80
    ...    Drag Object By Offset    ${OBJ}    left    80    steps=60    delay_ms=5
    ...    Drag Object By Offset    ${OBJ}    down    150    start_x=592    start_y=488
    [Tags]    internal
    [Arguments]    ${mouse_area_object}    ${direction}    ${distance}    &{kwargs}
    ${log}=    SquishLibrary.Drag Object By Offset    ${mouse_area_object}    direction=${direction}    distance=${distance}    &{kwargs}
    RETURN    ${log}

Date Picker Click Day By Text
    [Documentation]    Clicks day in date picker by matching its text with ``day_text``.
    ...    - *Date of Implementation:* 01-04-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:* ``day_text`` is a string which should match text of the day in date picker which we want to click.
    ...    Example: If we want to click day with text "15" then `day_text` should be "15".
    ...    ``filter_mode`` is used to specify if we want to click only days from current month or also days from previous/next month which are visible in calendar. 
    ...    Possible values for ``filter_mode`` are: ``current_month_only``, ``all``, ``beyond_current_month_only``. 
    ...    By default ``filter_mode`` is set to ``current_month_only``.
    [Tags]    internal
    [Arguments]    ${day_text}    ${filter_mode}=current_month_only

    SquishLibrary.Date Picker Click Day By Text    ${general_settings_calendar_month_all_days}    ${day_text}    ${filter_mode}

Date Picker Click Month By Text
    [Documentation]    Clicks month in date picker by matching its text with ``month_text``.
    ...    - *Date of Implementation:* 01-04-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:* `month_text` is a string which should match text of the month in date picker which we want to click.
    ...    Example: If we want to click month with text "Feb" then `month_text` should be "February" or "Feb".
    [Tags]    internal
    [Arguments]    ${month_text}

    SquishLibrary.Date Picker Click Month By Text    ${general_settings_calendar_all_months}    ${month_text}

Date Picker Click Year By Text
    [Documentation]    Clicks year in date picker by matching its text with ``year_text``.
    ...    - *Date of Implementation:* 01-04-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:* `year_text` is a string which should match text of the year in date picker which we want to click.
    ...    Example: If we want to click year with text "2026" then `year_text` should be "2026".
    [Tags]    internal
    [Arguments]    ${year_text}
    SquishLibrary.Date Picker Click Year By Text    ${general_settings_calendar_all_years}    ${year_text}

Date Picker Get Data Of Currently Selected Delegate
    [Documentation]    Returns dict with data of currently selected delegate in date picker like text and flags like:
    ...    isSelected, isSavedDate, isSavedYear, isCurrentMonth.
    ...    - *Date of Implementation:* 02-04-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:* Returned dict with following keys: text, isSelected, isSavedDate, isSavedYear, isCurrentMonth.
    ...    - *Returns:* dict with data of currently selected delegate in date picker.
    [Tags]    internal
    ${selected_delegate}=    Get Object Reference    ${general_settings_calendar_item_delegate_selected}
    ${delegate_info}=    SquishLibrary.Date Picker Get Delegate Info    ${selected_delegate}
    
    RETURN   ${delegate_info}

Date Picker Get Data Of Currently Saved Delegate
    [Documentation]    Returns dict with data of currently saved delegate in date picker like text and flags like:
    ...    isSelected, isSavedDate, isSavedYear, isCurrentMonth.
    ...    - *Date of Implementation:* 02-04-2026
    ...    - *Author:* Mateusz Rosiek
    ...    - *Usage:* Returned dict with following keys: text, isSelected, isSavedDate, isSavedYear, isCurrentMonth.
    ...    `delegate_type` argument is used to specify which delegate info we want to get - date or year. 
    ...    Possible values for `delegate_type` are: "date" and "year".
    [Tags]    internal
    [Arguments]    ${delegate_type}
    IF    "${delegate_type}" == "date"
        VAR    ${delegate_symbolic_name}=    ${general_settings_calendar_day_month_delegate_saved}
    ELSE IF    "${delegate_type}" == "year"
        VAR    ${delegate_symbolic_name}=    ${general_settings_calendar_year_delegate_saved}
    ELSE
        Fail    Invalid delegate type provided: ${delegate_type}. Possible values are: "date" and "year".
    END
    
    ${saved_delegate}=    Get Object Reference    ${delegate_symbolic_name}
    ${delegate_info}=    SquishLibrary.Date Picker Get Delegate Info    ${saved_delegate}
    
    RETURN   ${delegate_info}

Date Picker Get Header Text
    [Documentation]    Retrieves the header text from the date picker.
    [Tags]    internal
    ${header_middle_button}=    Get Object Reference    ${general_settings_calendar_month_year_btn}
    ${header_text_obj}=    SquishLibrary.Find Child By Type    ${header_middle_button}    QQuickText
    ${header_text}=    SquishLibrary.Get Object Property    ${header_text_obj}    text
    ${header_text}=    Convert To String    ${header_text}

    RETURN    ${header_text}

#####################################################################################################################
######################################### 3party TightVNC related keywords ##########################################
#####################################################################################################################

Open VNC viewer
    [Documentation]    Opens 3party TightVNC client to show preview of GUI during execution.
    ...
    ...    NOTE: Make sure that TightVNC client is installed prior using this keyword.
    [Arguments]    ${hostname}    ${vnc_port}
    IF    $VNC_PREVIEW.lower() == 'true'
        TRY
            ${VNC_PROCESS_HANDLE}=    Start Process    tvnviewer
            ...    -host\=${hostname}    -port\=${vnc_port}    -showcontrols    -viewonly
            ...    -mousecursor\=local    -mouselocal\=normal    alias=vnc    stdout=NUL    stderr=NUL
            Set Suite Variable    ${VNC_PROCESS_HANDLE}
        EXCEPT
            Log To Console    TightVNC client is probably not installed on this machine... VNC preview is not possible.
        END
    END

Close VNC viewer
    [Documentation]    Closes 3party TightVNC client which was started using Open VNC viewer keyword.
    ...
    ...    NOTE: Make sure that TightVNC client is installed prior using this keyword.
    IF    $VNC_PREVIEW.lower() == 'true'
        TRY
            ${res}=    Is Process Running    vnc
        EXCEPT
            Log To Console    TightVNC client is probably not installed on this machine... VNC preview is not possible.
        ELSE
            IF    ${res}
                Terminate Process    ${VNC_PROCESS_HANDLE}    kill=True
            END
        END
    END

#####################################################################################################################
######################################### 3party Squish related keywords ############################################
#####################################################################################################################

Set environment variables
    [Documentation]    This method sets necessary environment variables like SQUISH_REPORT_DIR which is used during
    ...    import of SquishLibrary.py as well as it appends to PYTHONPATH and sys.path following
    ...    entries: ${SQUISH_LIB_PATHS}. They must be set before importing SquishLibrary.py.
    [Tags]    internal
    Set Environment Variable    SQUISH_REPORTS_DIR    ${SQUISH_REPORTS_DIR}
    Set Pythonpath Environment Variable

Set pythonpath environment variable
    [Documentation]    This method adds paths in: ${SQUISH_LIB_PATHS} and Object_Repository to PYTHONPATH and sys.path.
    [Tags]    internal
    FOR    ${path}    IN    @{SQUISH_LIB_PATHS}
        Append path to pythonpath    ${path}
        # IMPORTANT - need to update sys.path dynamically via Evaluate keyword because setting only PYTHONPATH its not
        # updating automatically sys.path which is responsible for Python module search mechanism.
        # this is necessary because we are importing SquishLibrary dynamically
        Append path to python sys path    ${path}
    END

    Append path to pythonpath    ${OBJECT_REPOSITORY_DIR_PATH}
    Append path to python sys path    ${OBJECT_REPOSITORY_DIR_PATH}

    # verification
    ${pythonpath}=    Get Environment Variable    PYTHONPATH
    ${syspath}=    Evaluate    sys.path    modules=sys
    FOR    ${path}    IN    @{SQUISH_LIB_PATHS}
        Should Contain    ${pythonpath}    ${path}
        Should Contain    ${syspath}    ${path}
    END

    Should Contain    ${pythonpath}    ${OBJECT_REPOSITORY_DIR_PATH}
    Should Contain    ${syspath}    ${OBJECT_REPOSITORY_DIR_PATH}

    Log    PYTHONPATH after update: ${pythonpath}
    Log    sys.path entry after update: ${syspath}

Append path to pythonpath
    [Documentation]    Appends provided path to PYTHONPATH env variable.
    [Tags]    internal
    [Arguments]    ${path}
    ${res}=    Get Environment Variable    PYTHONPATH    None
    # IF    r"${res}" is None
    Append To Environment Variable    PYTHONPATH    ${path}
    # ELSE
    IF    r"${path}" not in r"%{PYTHONPATH}"
        Append To Environment Variable    PYTHONPATH    ${path}
    ELSE
        Log    ${path} is already set in PYTHONPATH
    END
    # END

Append path to python sys path
    [Documentation]    Appends provided path to Python's sys.path internal variable for module search mechanism.
    ...    Its crucial to do this for dynamic import of SquishLibrary.py to work correctly.
    [Tags]    internal
    [Arguments]    ${path}
    ${syspath}=    Evaluate    sys.path    modules=sys
    ${syspath}=    Convert To String    ${syspath}
    Log    ${syspath}
    ${norm_paths}=    Normalize Path    ${syspath}
    Log    ${norm_paths}
    IF    r"${path}" not in r"${norm_paths}"
        Evaluate    sys.path.append(r"${path}")    modules=sys
    ELSE
        Log    ${path} is already set in sys.path
    END

Check python information
    [Documentation]    Method for printing information about used Python interpreter.
    [Tags]    internal
    ${python_info}=    Check Running Python Interpreter
    RETURN    ${python_info}

Get squish user settings directory path
    [Documentation]    Returns path to squish user settings directory based on which OS this keywords runs on.
    [Tags]    internal
    ${home_dir}=    Get Current User Home Directory
    ${os_name}=    Get OS Name
    IF    '${os_name}' == 'Windows'
        VAR    ${squish_user_settings_dir_path}=    ${home_dir}${/}${SQUISH_USER_SETTINGS_DIR_PART_PATH_WIN}
    ELSE IF    '${os_name}' == 'Linux'
        VAR    ${squish_user_settings_dir_path}=    ${home_dir}${/}${SQUISH_USER_SETTINGS_DIR_PART_PATH_LINUX}
    ELSE
        Fail    msg=Invalid OS name detected ${os_name}
    END
    RETURN    ${squish_user_settings_dir_path}

Get squishserver configuration
    [Documentation]    Return contents of the squishserver configuration file.
    [Tags]    internal
    VAR    ${config_sub_path}=    ver1${/}server.ini
    ${squish_settings_dir}=    Get Squish User Settings Directory Path
    VAR    ${squishserver_config_file}=    ${squish_settings_dir}${/}${config_sub_path}
    ${content}=    OperatingSystem.Get File    ${squishserver_config_file}

    RETURN    ${content}

Execute squish config command
    [Documentation]    Execute squishconfig command and verifies if command was successfully executed. It provides
    ...    a way to configure squish using squishconfig executable.
    [Tags]    internal
    [Arguments]    ${squishconfig_path}=squishconfig    @{params}
    ${res}=    Run Process    ${squishconfig_path}    @{params}
    Should Be Equal As Integers    ${res.rc}    0
    ...    Unable to configure suqish using squishconfig command, failed with non zero error code
    Should Be Empty    ${res.stderr}    squishconfig command with ${params} returned error: ${res.stderr}

Configure squish license server
    [Documentation]    This method configures squish installation to use our floating squish license server via
    ...    squishconfig executable.
    [Arguments]    ${hostname}=${SQUISH_LICENSE_SERVER_HOST}    ${port}=${SQUISH_LICENSE_SERVER_PORT}
    Execute Squish Config Command    ${SQUISH_DIR}/bin/squishconfig    --licensekey\=${hostname}:${port}

Add Screenshot
    [Tags]    internal
    ${html}=    Evaluate
    ...    __import__('SquishLibrary').SquishLibrary().capture_and_return_base64_image(${g4_main_window})
    Log    ${html}    html=True
    VAR    ${keyword_result_message}=    ${keyword_result_message}${html}    scope=GLOBAL
    RETURN    ${html}

Get Object Identifier
    [Documentation]    Returns a human-readable identifier for the given UI object dictionary.
    ...                Tries ``objectName`` first, then ``id``, then ``text``, falls back to ``type``.
    ...                If the value is a RegularExpression object, its pattern string is returned.
    ...                - *Date of Implementation:* 11-MAY-2026
    ...                - *Author:* Mina Bikhit
    [Tags]    internal
    [Arguments]    ${object_real_name}
    ${keys_to_try}=    Create List    objectName    id    text    type
    FOR    ${key}    IN    @{keys_to_try}
        ${status}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${object_real_name}    ${key}
        IF    ${status}
            ${value}=    Get From Dictionary    ${object_real_name}    ${key}
            ${is_regex}=    Evaluate    hasattr($value, 'pattern')
            IF    ${is_regex}
                ${object_identifier}=    Evaluate    $value.pattern.replace(r'\d+', '*')
            ELSE
                ${object_identifier}=    Set Variable    ${value}
            END
            RETURN    ${object_identifier}
        END
    END
    RETURN    ${object_real_name}
