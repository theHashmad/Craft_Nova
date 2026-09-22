from objectmaphelper import *
from Common_Lib.Squish.Object_Repository.Common_Objects import *

caseScreen_Item = {"container": main_Item, "objectName": "caseScreen", "type": "Item"}

#case screen header elememts
#caseID & logo missing object name
caseID = {"container": header, "text": "Case ID: 24APR2025_14:30", "type": "Text"}
closeCaseButton = {"container": header, "objectName": "closeCaseButton", "type": "HeaderButton"}
logo = {"container": header, "id": "logo", "source": "img/wordmark.png", "type": "Image"}

ablationsVertical_AblationsVertical = {"container": caseScreen_Item, "objectName": "ablationsVertical", "type": "AblationsVertical"}

#timer panel
timer_message_panel = {"container": caseScreen_Item, "objectName": "timerMessagePanel", "type": "TimerMessagePanel"}
timer_panel = {"container": timer_message_panel, "objectName": "timerPanel", "type": "TimerPanel"}
timer_panel_timer_progress_bar = {"container": timer_panel, "objectName": "progressBar", "type": "TimerPanelProgressBar"}
timer_panel_stop_watch_icon = {"container": timer_panel, "objectName": "stopWatchIcon", "source": "img/stopwatch_icon.png", "type": "Image"}
timer_panel_time_digits = {"container": timer_panel, "objectName": "timeDigits", "type": "Text"}
timer_panel_time_units = {"container": timer_panel, "objectName": "timeLiteral", "type": "Text"}

#rlPanel
rlPanel_RLPanel = {"container": caseScreen_Item, "objectName": "rlPanel", "type": "RLPanel"}
rlPanel_AblationTitle = {"container": rlPanel_RLPanel, "objectName": "ablationsText", "type": "Text"}
rlPanel_AblationCount = {"container": rlPanel_RLPanel, "objectName": "ablationCount", "type": "Text"}
rlPanel_AblationCountRight = {"container": rlPanel_RLPanel, "objectName": "tagCountRight", "type": "Text"}
rlPanel_AblationCountLeft = {"container": rlPanel_RLPanel, "objectName": "tagCountLeft", "type": "Text"}

tagButtonsRowLayout_RowLayout = {"container": rlPanel_RLPanel, "objectName": "tagButtonsRowLayout", "type": "RowLayout"}
right_button_tag = {"container": tagButtonsRowLayout_RowLayout, "objectName": "tagButtonRight", "type": "TagButton"}
left_button_tag = {"container": tagButtonsRowLayout_RowLayout, "objectName": "tagButtonLeft", "type": "TagButton"}
right_button = {"container": right_button_tag, "objectName": "rlButtonRectangleFortagButtonRight", "type": "Rectangle"}
left_button = {"container": left_button_tag, "objectName": "rlButtonRectangleFortagButtonLeft", "type": "Rectangle"}
right_button_text = {"container": right_button, "objectName": "rlButtonTextForrlButtonRectangleFortagButtonRight", "type": "Text"}
left_button_text = {"container": left_button, "objectName": "rlButtonTextForrlButtonRectangleFortagButtonLeft", "type": "Text"}

# electrodes column
main_case_panel_MainCasePanel = {"container": caseScreen_Item, "objectName": "mainCasePanel", "type": "MainCasePanel"}
runNumberBox = {"container": main_case_panel_MainCasePanel, "objectName": "runNumberBox", "type": "Item"}
runNumberText = {"container": runNumberBox, "objectName": "runNumberText", "type": "Text"}

# catheter snake visualisation
o_QQuickApplicationWindow = {"type": "QQuickApplicationWindow", "unnamed": 1, "visible": True}
cathederImg_Image = {"container": o_QQuickApplicationWindow, "id": "cathederImg", "source": "img/CATHETER_with_shadow.png", "type": "Image", "unnamed": 1, "visible": True}
catheterSnake_electrode_D1_enabled = {"container": o_QQuickApplicationWindow, "id": "bulb", "source": "img/c1_on_small.png", "type": "Image", "unnamed": 1, "visible": True}
catheterSnake_electrode_2_enabled = {"container": o_QQuickApplicationWindow, "id": "bulb", "source": "img/c2_on_small.png", "type": "Image", "unnamed": 1, "visible": True}
catheterSnake_electrode_3_enabled = {"container": o_QQuickApplicationWindow, "id": "bulb", "source": "img/c3_on_small.png", "type": "Image", "unnamed": 1, "visible": True}
catheterSnake_electrode_P4_enabled = {"container": o_QQuickApplicationWindow, "id": "bulb", "source": "img/c4_on_small.png", "type": "Image", "unnamed": 1, "visible": True}
catheterSnake_electrode_D1_disabled = {"container": o_QQuickApplicationWindow, "id": "bulb", "source": "img/c1_off_small.png", "type": "Image", "unnamed": 1, "visible": True}
catheterSnake_electrode_2_disabled = {"container": o_QQuickApplicationWindow, "id": "bulb", "source": "img/c2_off_small.png", "type": "Image", "unnamed": 1, "visible": True}
catheterSnake_electrode_3_disabled = {"container": o_QQuickApplicationWindow, "id": "bulb", "source": "img/c3_off_small.png", "type": "Image", "unnamed": 1, "visible": True}
catheterSnake_electrode_P4_disabled = {"container": o_QQuickApplicationWindow, "id": "bulb", "source": "img/c4_off_small.png", "type": "Image", "unnamed": 1, "visible": True}

# electrodeD1
electrodeD1_Electrode = {"container": main_case_panel_MainCasePanel, "objectName": "electrodeD1", "type": "Electrode"}
electrodeWarningCanvasD1_ElectrodeWarningCanvas = {"container": electrodeD1_Electrode, "objectName": "electrodeWarningCanvasD1", "type": "ElectrodeWarningCanvas"}
electrode_D1_catheterNotDeployedAnimation = {"container": electrodeD1_Electrode, "objectName": "catheterNotDeployedAnimationD1", "type": "CatheterNotDeployedAnimation"}
electrodeD1Label_Text = {"container": electrodeD1_Electrode, "objectName": "electrodeD1Label", "type": "Text"}
impedanceLabelD1_Text = {"container": electrodeD1_Electrode, "objectName": "impedanceLabelD1", "type": "Text"}
impedanceMovingGraphViewD1_GraphsViewPlotArea = {"container": electrodeD1_Electrode, "objectName": "impedanceMovingGraphViewD1", "type": "GraphsViewPlotArea"}
graphViewD1_GraphsViewPlotArea = {"container": electrodeD1_Electrode, "objectName": "graphViewD1", "type": "GraphsViewPlotArea"}
ohmSymbolD1_Image = {"container": electrodeD1_Electrode, "objectName": "ohmSymbolD1", "source": "img/ohm_symbol_small.svg", "type": "Image"}
tempSymbolD1_Image = {"container": electrodeD1_Electrode, "objectName": "tempSymbolD1", "source": "img/temp_symbol.svg", "type": "Image"}
blueBoxD1_Rectangle = {"container": electrodeD1_Electrode, "objectName": "blueBoxD1", "type": "Rectangle"}
tempLabelD1_Text = {"container": blueBoxD1_Rectangle, "objectName": "tempLabelD1", "type": "Text"}
impedanceLabelSmallD1_Text = {"container": electrodeD1_Electrode, "objectName": "impedanceLabelSmallD1", "type": "Text"}
warningSecondsD1_Text = {"container": electrodeD1_Electrode, "objectName": "warningSecondsD1", "type": "Text"}
warningSecondsUnitD1_Text = {"container": electrodeD1_Electrode, "objectName": "warningSecondsUnitD1", "type": "Text"}
turnedOff_electrode_D1 = {"container": electrodeD1_Electrode, "objectName": "turnedOffIconD1", "source": "img/turned_off.svg", "type": "Image"}
warningTextD1_Text = {"container": electrodeD1_Electrode, "objectName": "warningTextD1", "type": "Text"}

# electrode2
electrode2_Electrode = {"container": main_case_panel_MainCasePanel, "objectName": "electrode2", "type": "Electrode"}
electrodeWarningCanvas2_ElectrodeWarningCanvas = {"container": electrode2_Electrode, "objectName": "electrodeWarningCanvas2", "type": "ElectrodeWarningCanvas"}
electrode_2_catheterNotDeployedAnimation = {"container": electrode2_Electrode, "objectName": "catheterNotDeployedAnimation2", "type": "CatheterNotDeployedAnimation"}
electrode2Label_Text = {"container": electrode2_Electrode, "objectName": "electrode2Label", "type": "Text"}
impedanceLabel2_Text = {"container": electrode2_Electrode, "objectName": "impedanceLabel2", "type": "Text"}
impedanceMovingGraphView2_GraphsViewPlotArea = {"container": electrode2_Electrode, "objectName": "impedanceMovingGraphView2", "type": "GraphsViewPlotArea"}
warningSecondsUnit2_Text = {"container": electrode2_Electrode, "objectName": "warningSecondsUnit2", "type": "Text"}
warningSeconds2_Text = {"container": electrode2_Electrode, "objectName": "warningSeconds2", "type": "Text"}
impedanceLabelSmall2_Text = {"container": electrode2_Electrode, "objectName": "impedanceLabelSmall2", "type": "Text"}
blueBox2_Rectangle = {"container": electrode2_Electrode, "objectName": "blueBox2", "type": "Rectangle"}
tempLabel2_Text = {"container": blueBox2_Rectangle, "objectName": "tempLabel2", "type": "Text"}
tempSymbol2_Image = {"container": electrode2_Electrode, "objectName": "tempSymbol2", "source": "img/temp_symbol.svg", "type": "Image"}
ohmSymbol2_Image = {"container": electrode2_Electrode, "objectName": "ohmSymbol2", "source": "img/ohm_symbol_small.svg", "type": "Image"}
graphView2_GraphsViewPlotArea = {"container": electrode2_Electrode, "objectName": "graphView2", "type": "GraphsViewPlotArea"}
turnedOff_electrode_2 = {"container": electrode2_Electrode, "objectName": "turnedOffIcon2", "source": "img/turned_off.svg", "type": "Image"}
warningText2_Text = {"container": electrode2_Electrode, "objectName": "warningText2", "type": "Text"}

# electrode3
electrode3_Electrode = {"container": main_case_panel_MainCasePanel, "objectName": "electrode3", "type": "Electrode"}
electrodeWarningCanvas3_ElectrodeWarningCanvas = {"container": electrode3_Electrode, "objectName": "electrodeWarningCanvas3", "type": "ElectrodeWarningCanvas"}
electrode3Label_Text = {"container": electrode3_Electrode, "objectName": "electrode3Label", "type": "Text"}
impedanceLabel3_Text = {"container": electrode3_Electrode, "objectName": "impedanceLabel3", "type": "Text"}
electrode_3_catheterNotDeployedAnimation = {"container": electrode3_Electrode, "objectName": "catheterNotDeployedAnimation3", "type": "CatheterNotDeployedAnimation"}
tempSymbol3_Image = {"container": electrode3_Electrode, "objectName": "tempSymbol3", "source": "img/temp_symbol.svg", "type": "Image"}
ohmSymbol3_Image = {"container": electrode3_Electrode, "objectName": "ohmSymbol3", "source": "img/ohm_symbol_small.svg", "type": "Image"}
graphView3_GraphsViewPlotArea = {"container": electrode3_Electrode, "objectName": "graphView3", "type": "GraphsViewPlotArea"}
impedanceMovingGraphView3_GraphsViewPlotArea = {"container": electrode3_Electrode, "objectName": "impedanceMovingGraphView3", "type": "GraphsViewPlotArea"}
blueBox3_Rectangle = {"container": electrode3_Electrode, "objectName": "blueBox3", "type": "Rectangle"}
tempLabel3_Text = {"container": blueBox3_Rectangle, "objectName": "tempLabel3", "type": "Text"}
turnedOff_electrode_3 = {"container": electrode3_Electrode, "objectName": "turnedOffIcon3", "source": "img/turned_off.svg", "type": "Image"}
warningText3_Text = {"container": electrode3_Electrode, "objectName": "warningText3", "type": "Text"}
warningSecondsUnit3_Text = {"container": electrode3_Electrode, "objectName": "warningSecondsUnit3", "type": "Text"}
warningSeconds3_Text = {"container": electrode3_Electrode, "objectName": "warningSeconds3", "type": "Text"}
impedanceLabelSmall3_Text = {"container": electrode3_Electrode, "objectName": "impedanceLabelSmall3", "type": "Text"}

# electrodeP4
electrodeP4_Electrode = {"container": main_case_panel_MainCasePanel, "objectName": "electrodeP4", "type": "Electrode"}
electrodeWarningCanvasP4_ElectrodeWarningCanvas = {"container": electrodeP4_Electrode, "objectName": "electrodeWarningCanvasP4", "type": "ElectrodeWarningCanvas"}
electrodeP4Label_Text = {"container": electrodeP4_Electrode, "objectName": "electrodeP4Label", "type": "Text"}
electrode_P4_catheterNotDeployedAnimation = {"container": electrodeP4_Electrode, "objectName": "catheterNotDeployedAnimationP4", "type": "CatheterNotDeployedAnimation"}
impedanceLabelP4_Text = {"container": electrodeP4_Electrode, "objectName": "impedanceLabelP4", "type": "Text"}
impedanceMovingGraphViewP4_GraphsViewPlotArea = {"container": electrodeP4_Electrode, "objectName": "impedanceMovingGraphViewP4", "type": "GraphsViewPlotArea"}
graphViewP4_GraphsViewPlotArea = {"container": electrodeP4_Electrode, "objectName": "graphViewP4", "type": "GraphsViewPlotArea"}
ohmSymbolP4_Image = {"container": electrodeP4_Electrode, "objectName": "ohmSymbolP4", "source": "img/ohm_symbol_small.svg", "type": "Image"}
tempSymbolP4_Image = {"container": electrodeP4_Electrode, "objectName": "tempSymbolP4", "source": "img/temp_symbol.svg", "type": "Image"}
blueBoxP4_Rectangle = {"container": electrodeP4_Electrode, "objectName": "blueBoxP4", "type": "Rectangle"}
tempLabelP4_Text = {"container": blueBoxP4_Rectangle, "objectName": "tempLabelP4", "type": "Text"}
impedanceLabelSmallP4_Text = {"container": electrodeP4_Electrode, "objectName": "impedanceLabelSmallP4", "type": "Text"}
warningSecondsP4_Text = {"container": electrodeP4_Electrode, "objectName": "warningSecondsP4", "type": "Text"}
warningSecondsUnitP4_Text = {"container": electrodeP4_Electrode, "objectName": "warningSecondsUnitP4", "type": "Text"}
warningTextP4_Text = {"container": electrodeP4_Electrode, "objectName": "warningTextP4", "type": "Text"}
turnedOff_electrode_P4 = {"container": electrodeP4_Electrode, "objectName": "turnedOffIconP4", "source": "img/turned_off.svg", "type": "Image"}
