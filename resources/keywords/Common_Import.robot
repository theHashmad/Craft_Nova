*** Settings ***
Resource        ../Configuration/CICD/CICD_Configuration.resource
Resource        Keyword_Common_API.robot
Resource        Keyword_Codebeamer.robot
Resource        Keyword_Deploy.robot
Resource        Keyword_System.robot
Resource        Keyword_Display.robot
Resource        Keyword_Display_Functional.robot
Resource        Keyword_Common.robot
Library         ../Tools/StepResult.py
Variables       ../Common_Lib/G4_API/Core/messages/units_pb2.py
