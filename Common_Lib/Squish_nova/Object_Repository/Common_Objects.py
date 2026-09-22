from objectmaphelper import *

g4_main_window = {"type": "QQuickApplicationWindow", "unnamed": 1, "visible": True}
main_ContentItem = {"container": g4_main_window, "objectName": "Main", "type": "ContentItem", "visible": True}
main_Item = {"container": main_ContentItem, "objectName": "main", "type": "Item"}
common_screen_background_area = {"container": main_Item, "type": "Rectangle", "visible": True, "height": 720, "width": 1280}


# Header
header = {"container": main_Item, "objectName": "header", "type": "Header"}
header_background = {"container": header, "id": "mainContainer", "type": "Rectangle"}
# Header's elements
hamburger_menu = {"container": header, "objectName": "hamburgerMenu", "type": "Rectangle"}
hamburger_btn = {"container": hamburger_menu, "objectName": "hamburgerButton", "type": "Rectangle"}
hamburger_btn_icon = {"container": hamburger_menu, "objectName": "hamburgerIcon", "type": "Image"}

# logo_image = {}
back_header_btn = {"container": header, "objectName": "backButton", "type": "ControlsButton"}
menu_options = {"container": hamburger_menu, "objectName": "menuOptions", "type": "MenuOptions"}
menu_brightness_option = {"container": menu_options, "objectName": "brightnessOption", "type": "MenuItemBase"}
menu_volume_option = {"container": menu_options, "objectName": "volumeOption", "type": "MenuItemBase"}
menu_settings_option = {"container": menu_options, "objectName": "settingsOption", "type": "MenuItemBase"}
menu_report_option = {"container": menu_options, "objectName": "reportOption", "type": "MenuItemBase"}
menu_help_option = {"container": menu_options, "objectName": "helpOption", "type": "MenuItemBase"}

help_panel = {"container": menu_options, "objectName": "helpPanel", "type": "HelpPanel"}
brightness_panel = {"container": menu_options, "objectName": "brightnessPanel", "type": "BrightnessPanel"}


# Confirmation dialog objects
confirmation_dialog = {"container": main_ContentItem, "objectName": "confirmationForm", "type": "ConfirmationForm"}
confirmation_dialog_header_text = {"container": confirmation_dialog, "objectName": "confirmationInfoHeader", "type": "Text"}
confirmation_dialog_text = {"container": confirmation_dialog, "objectName": "confirmationInfoText", "type": "Text"}
confirmation_dialog_buttons = {"container": confirmation_dialog, "objectName": "confirmationButtons", "type": "ActionButtons"}
confirmation_dialog_cancel_btn = {"container": confirmation_dialog_buttons, "objectName": "cancelButton", "type": "CustomButton"}
confirmation_dialog_ok_btn = {"container": confirmation_dialog_buttons, "objectName": "okButton", "type": "CustomButton"}
