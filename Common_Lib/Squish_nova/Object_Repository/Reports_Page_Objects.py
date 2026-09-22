from objectmaphelper import *
from Common_Lib.Squish.Object_Repository.Common_Objects import *

# Reports screen
reportsScreen = {"container": main_Item, "objectName": "reportsScreen", "type": "Item"}
reportScreen = {"container": reportsScreen, "objectName": "reportScreen", "type": "Item"}
mainReportScreen = {"container": reportScreen, "objectName": "mainReportScreen", "type": "Item"}


# Reports screen top section (label is inside the report screen, not the header)
topItem = {"container": mainReportScreen, "objectName": "topItem", "type": "Item"}
reports_label_text = {"container": topItem, "objectName": "labelText", "type": "Text"}

# Reports list
reports_list_view = {"container": mainReportScreen, "objectName": "reportsListView", "type": "ListView"}

# Reports row elements (use RegularExpression to match any row index)
reports_row_delegate = {"container": mainReportScreen, "objectName": RegularExpression(r"reportsListDelegate_\d+"), "type": "ItemDelegate"}
reports_row_case_name = {"container": mainReportScreen, "objectName": RegularExpression(r"caseName\d+"), "type": "Text"}
reports_view_button = {"container": mainReportScreen, "objectName": RegularExpression(r"viewButton\d+"), "type": "ControlsButton"}

