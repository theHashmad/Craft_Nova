from objectmaphelper import *
from python.objectmaphelper import RegularExpression

from Common_Lib.Squish.Object_Repository.Common_Objects import *

settingsScreen = {"container": main_Item, "objectName": "settingsScreen", "type": "Item"}

settings_gear_icon = {"container": settingsScreen, "objectName": "settingsGearIcon", "source": "img/gear_icon.png", "type": "Image"}
settings_gear_text = {"container": settingsScreen, "objectName": "settingsGearText", "type": "Text"}

settings_tab_bar = {"container": settingsScreen, "objectName": "settingsTabBar", "type": "TabBarComponent"}
settings_tab_bar_adv_btn = {"container": settings_tab_bar, "objectName": "Advanced", "type": "TabButtonComponent"}
settings_tab_bar_gen_btn = {"container": settings_tab_bar, "objectName": "General", "type": "TabButtonComponent"}
settingsTabBar_Advanced_Text = {"container": settings_tab_bar, "text": "Advanced", "type": "Text", "unnamed": 1, "visible": True}
# General Tab Objects
# Date Box Objects
general_settings_date_box = {"container": settingsScreen, "objectName": "generalSettingsDateBox", "type": "CalendarBox"}
general_settings_date_label = {"container": general_settings_date_box, "objectName": "dateLabel", "type": "Text"}
general_settings_current_date_item = {"container": general_settings_date_box, "objectName": "currentDateItem", "type": "Rectangle"}
general_settings_current_date_text = {"container": general_settings_current_date_item, "objectName": "contentDateText", "type": "Text"}
general_settings_current_date_indicator = {"container": general_settings_current_date_item, "objectName": "dateIndicatorImage", "type": "Image"}
# Calendar Drop Down Object
# calendar header and its elements
general_settings_current_date_drop_down = {"container": general_settings_date_box, "objectName": "dropDownDate", "type": "CalendarComponent"}
general_settings_calendar_header = {"container": general_settings_current_date_drop_down, "objectName": "calendarHeader", "type": "CalendarHeader"}
general_settings_calendar_jump_back_btn = {"container": general_settings_calendar_header, "objectName": "jumpBackBtn", "type": "Button"}
general_settings_calendar_prev_btn = {"container": general_settings_calendar_header, "objectName": "prevBtn", "type": "Button"}
general_settings_calendar_month_year_btn = {"container": general_settings_calendar_header, "objectName": "monthYearBtn", "type": "Button"}
general_settings_calendar_next_btn = {"container": general_settings_calendar_header, "objectName": "nextBtn", "type": "Button"}
general_settings_calendar_jump_forward_btn = {"container": general_settings_calendar_header, "objectName": "todayBtn", "type": "Button"}
# calendar item delegate objects
general_settings_calendar_day_month_delegate_saved = {"container": general_settings_current_date_drop_down, "objectName": RegularExpression(r".+Delegate\d+(_\d+)?"), "type": "Rectangle", "visible": True, "isSavedDate": True}
general_settings_calendar_year_delegate_saved = {"container": general_settings_current_date_drop_down, "objectName": RegularExpression(r".+Delegate\d+(_\d+)?"), "type": "Rectangle", "visible": True, "isSavedYear": True}
general_settings_calendar_item_delegate_selected = {"container": general_settings_current_date_drop_down, "objectName": RegularExpression(r".+Delegate\d+(_\d+)?"), "type": "Rectangle", "visible": True, "isSelected": True}
# calendar day view
general_settings_calendar_day_view = {"container": general_settings_current_date_drop_down, "objectName": "CalendarDayView", "type": "CalendarDayView"}
general_settings_calendar_month_days_grid = {"container": general_settings_calendar_day_view, "objectName": "monthGrid", "type": "MonthGrid"}
general_settings_calendar_month_all_days = {"container": general_settings_calendar_month_days_grid, "objectName": RegularExpression(r"dayDelegate\d+(_\d+)?"), "type": "Rectangle"}
# calendar month view
general_settings_calendar_month_view = {"container": general_settings_current_date_drop_down, "objectName": "CalendarMonthView", "type": "CalendarMonthView"}
general_settings_calendar_all_months = {"container": general_settings_calendar_month_view, "objectName": RegularExpression(r"monthDelegate\d+"), "type": "Rectangle"}
# TODO how to add month grid view?
# calendar year view
general_settings_calendar_year_view = {"container": general_settings_current_date_drop_down, "objectName": "CalendarYearView", "type": "CalendarYearView"}
general_settings_calendar_all_years = {"container": general_settings_calendar_year_view, "objectName": RegularExpression(r"yearDelegate\d+"), "type": "Rectangle"}
# TODO how to add year grid view?

# Time Box Objects
general_settings_time_box = {"container": settingsScreen, "objectName": "generalSettingsTimeBox", "type": "TimeBox"}
general_settings_time_box_item = {"container": general_settings_time_box, "objectName": "timeBoxItem", "type": "Item"}
general_settings_timer_component = {"container": general_settings_time_box, "objectName": "timerComponent", "type": "Item"}
general_settings_time_label = {"container": general_settings_time_box, "objectName": "timeBoxLabel", "type": "Text"}
general_settings_time_text = {"container": general_settings_time_box, "objectName": "timeBoxText", "type": "Text"}
general_settings_time_indicator = {"container": general_settings_time_box, "objectName": "timeBoxIndicator", "type": "Image"}
general_settings_time_item = {"container": general_settings_time_box, "objectName": "timeBoxItem", "type": "Rectangle"}
# timer edit box
general_settings_spin_hour_up = {"container": general_settings_time_box, "objectName": "arrowUpHour", "type": "Rectangle"}
general_settings_spin_hour_down = {"container": general_settings_time_box, "objectName": "arrowDownHour", "type": "Rectangle"}
general_settings_label_hour = {"container": general_settings_time_box, "objectName": "labelHour", "type": "Text"}
general_settings_spin_value_display_hour = {"container": general_settings_time_box, "objectName": "valueDisplayHour", "type": "Rectangle"}
general_settings_time_edit_colon_indicator = {"container": general_settings_time_box, "objectName": "timeBoxColon", "type": "Image"}
general_settings_spin_min_up = {"container": general_settings_time_box, "objectName": "arrowUpMin", "type": "Rectangle"}
general_settings_spin_min_down = {"container": general_settings_time_box, "objectName": "arrowDownMin", "type": "Rectangle"}
general_settings_label_minute = {"container": general_settings_time_box, "objectName": "labelMin", "type": "Text"}
general_settings_spin_value_display_min = {"container": general_settings_time_box, "objectName": "valueDisplayMin", "type": "Rectangle"}
# Language Selection Objects
general_settings_language_box = {"container": settingsScreen, "objectName": "generalSettingsLanguageBox", "type": "LanguageBox"}
general_settings_language_label = {"container": general_settings_language_box, "objectName": "comboBoxLabel", "type": "Text"}
general_settings_language_current_item_box = {"container": general_settings_language_box, "objectName": "currentItemBox", "type": "Rectangle"}
general_settings_language_current_item_text = {"container": general_settings_language_current_item_box, "objectName": "currentItemText", "type": "Text"}
general_settings_language_current_item_indicator = {"container": general_settings_language_current_item_box, "objectName": "currentItemImage", "type": "Image"}
# Language Drop Down Object
general_settings_language_drop_down = {"container": general_settings_language_box, "objectName": "dropDownList", "type": "Item"}
general_settings_language_list_view = {"container": general_settings_language_drop_down, "objectName": "listView", "type": "ListView"}
general_settings_language_scroll_bar = {"container": general_settings_language_drop_down, "objectName": "scrollBar", "type": "LanguageScrollBar"}    # size: 305 x 45
general_settings_language_up_button = {"container": general_settings_language_scroll_bar, "objectName": "upButton", "type": "Item"}    #size h:45 x w:45
general_settings_language_down_button = {"container": general_settings_language_scroll_bar, "objectName": "downButton", "type": "Item"}    #size h:45 x w:45
general_settings_language_scroll_bar_button = {"container": general_settings_language_scroll_bar, "objectName": "scrollBarItem", "type": "Rectangle"}
general_settings_language_scroll_bar_button_mouse_area = {"container": general_settings_language_scroll_bar, "objectName": "scrollBarArea", "type": "MouseArea"}
general_settings_language_up_button_image = {"container": general_settings_language_scroll_bar, "objectName": "upButtonImage", "type": "Image"}
general_settings_language_down_button_image = {"container": general_settings_language_scroll_bar, "objectName": "downButtonImage", "type": "Image"}




# Advanced Tab Objects
# Set Default View Objects
set_default_view_text = {"container": settingsScreen, "objectName": "advancedPageSetDefaultViewText", "type": "CaptionSemiBoldText"}
electrode_stability_only_setting = {"container": settingsScreen, "objectName": "advancedPageStabilitButton", "type": "RadioButtonComponent"}
electrode_stability_only_modification_indicator = {"container": electrode_stability_only_setting, "source": "img/asterisk.png", "type": "Image"}
electrode_stability_and_impedance_setting = {"container": settingsScreen, "objectName": "advancedPageStabilityImpedanceButton", "type": "RadioButtonComponent"}
electrode_stability_and_impedance_modification_indicator = {"container": electrode_stability_and_impedance_setting, "type": "Image"}
display_impedance_setting = {"container": settingsScreen, "objectName": "advancedPageValueButton", "type": "SwitchComponent"}
display_impedance_modification_indicator = {"container": display_impedance_setting, "source": "img/asterisk.png", "type": "Image"}
# Preview Box Object
preview_box = {"container": settingsScreen, "objectName": "advancedPagePreviewBox", "type": "Rectangle"}
preview_box_text = {"container": preview_box, "objectName": "advancedPagePreviewBoxText", "type": "Text"}
preview_box_image = {"container": preview_box, "objectName": "advancedPagePreviewBoxImage", "type": "Image"}
preview_box_image_imp_val = {"container": preview_box, "objectName": "advancedPagePreviewBoxImage", "source": "img/electrode_stability_impedance_value.png", "type": "Image"}
preview_box_image_electrode_stability = {"container": preview_box, "objectName": "advancedPagePreviewBoxImage", "source": "img/electrode_stability_impedance.png", "type": "Image"}
# Laterality Tagging Objects
laterality_tagging_title = {"container": settingsScreen, "objectName": "advancedPageLateralityTaggingTitle", "type": "CaptionSemiBoldText"}
select_r_or_l_kidney_setting = {"container": settingsScreen, "objectName": "advancedPageLateralityTaggingButton", "type": "CheckBoxComponent"}
select_r_or_l_kidney_modification_indicator = {"container": select_r_or_l_kidney_setting, "source": "img/asterisk.png", "type": "Image"}

# Settings Action Buttons
settings_cancel_btn = {"container": settingsScreen, "objectName": "cancelButton", "type": "CustomButton"}
settings_ok_btn = {"container": settingsScreen, "objectName": "okButton", "type": "CustomButton"}
