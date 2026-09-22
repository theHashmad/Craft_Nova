import requests
from requests.auth import HTTPBasicAuth
import json
import urllib3
import sys
from cb_configurations import load_codebeamer_config

USERNAME, PASSWORD = load_codebeamer_config()


def getAvailableTestConfig():
    usedList = []
    availableList = []
    availableListID = []
    pipelineList = []
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    url = "https://crdn.codebeamer.com/rest/v3/trackers/261904/items/"
    session=requests.session()
    session.verify=False
    session.auth=HTTPBasicAuth(USERNAME,PASSWORD)
    response=session.get(url)
    testconfigs=response.json().get("itemRefs")
    for item in testconfigs:
        status = getTestConfigStatus(item.get("id"))
        if status != "Local_Board":
            if status != "Inactivated" and status != "New" and status != "Offline":
                # usedList.append(item.get("name")) if status == "In Use" else availableList.append(item.get("name")) and availableListID.append(item.get("id"))
                configIP = getTestConfigIP(item.get("id"))
                if status == "In Use":
                    usedList.append({item.get("name"): configIP})
                else:
                    availableList.append({item.get("name"): configIP})
        else:
            continue

    return availableList, usedList

def getTestConfigStatus(testConfigID):
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    url = "https://crdn.codebeamer.com/rest/v3/items/"+str(testConfigID)+"/"
    session=requests.session()
    session.verify=False
    session.auth=HTTPBasicAuth(USERNAME,PASSWORD)
    response=session.get(url)
    boardType = response.json().get("categories")[0].get("name")
    if boardType == "Pipeline_Board":
        availabilityField = response.json().get("customFields")
        if response.json().get("status").get("name") == "Inactivated":
            return "Inactivated"
        elif response.json().get("status").get("name") == "Offline":
            return "Offline"
        elif response.json().get("status").get("name") == "Activated" or response.json().get("status").get(
                "name") == "Online":
            for field in availabilityField:
                if field.get("fieldId") == 1000:
                    return field.get("values")[0].get("name")
                else:
                    return "Unknown"
        else:
            return "New"
    else:
        return "Local_Board"

def getTestConfigIP(testConfigID):
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    url = "https://crdn.codebeamer.com/rest/v3/items/"+str(testConfigID)+"/"
    session=requests.session()
    session.verify=False
    session.auth=HTTPBasicAuth(USERNAME,PASSWORD)
    response=session.get(url)
    availabilityField = response.json().get("customFields")
    return availabilityField[-1].get("values")[0][1].get("value")


availableConfigs, usedConfigs = getAvailableTestConfig()
print("Available Test Config IDs:", availableConfigs)
print("Used Test Config IDs:", usedConfigs)