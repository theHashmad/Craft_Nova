from objectmaphelper import *
from Common_Lib.Squish.Object_Repository.Common_Objects import *

setupScreen = {"container": main_Item, "objectName": "setupScreen", "type": "Item"}

catheter_image = {"container": setupScreen, "objectName": "catheter", "type": "Image"}
catheter_check_mark_image = {"container": setupScreen, "objectName": "catheterCheckMark", "type": "Image"}
rem_pad_check_mark_image = {"container": setupScreen, "objectName": "remPadCheckMark", "type": "Image"}
remote_image = {"container": setupScreen, "objectName": "remote", "type": "Image"}
connect_accessories_text = {"container": setupScreen, "objectName": "connectText", "type": "Text"}
do_not_use_remote_checkbox = {"container": setupScreen, "objectName": "doNotUseRemoteCheckbox", "type": "CheckBoxComponent"}
asterisk_image = {"container": do_not_use_remote_checkbox, "source": "img/asterisk.png", "type": "Image"}