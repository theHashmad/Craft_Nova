import requests
from requests.auth import HTTPBasicAuth
import urllib3
import sys
from cb_configurations import load_codebeamer_config

USERNAME, PASSWORD = load_codebeamer_config()

availability = {"Available":1, "In Use":2, "Partially Available":3}
READONLY_FIELDS = {
    "version", "createdAt", "createdBy", "modifiedAt", "modifiedBy",
    "typeName", "comments", "children", "formality", "tracker",
    "accrueTimeTo", "storyPoints", "closedAt"
}

def updateTestConfig(tcID, status, pipelineID=None, buildID=None):
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    url = "https://crdn.codebeamer.com/rest/v3/items/"+str(tcID)+"/"
    session = requests.session()
    session.verify = False
    session.auth = HTTPBasicAuth(USERNAME, PASSWORD)
    response = session.get(url)
    # Start from the full existing item body to preserve all mandatory fields
    finalBodyBlock = response.json()

    # Remove read-only fields that the API rejects on PUT
    for field in READONLY_FIELDS:
        finalBodyBlock.pop(field, None)

    # Build updated custom fields
    tmpAvailabilityValueID = availability[status]
    availabilityValueBlock = {"id": tmpAvailabilityValueID, "name": status, "type": "ChoiceOptionReference"}
    finalAvailability = {"fieldId": 1000, "name": "Availability", "type": "ChoiceFieldValue", "values": [availabilityValueBlock]}

    if status == "In Use":
        if pipelineID is None or buildID is None:
            print("Error: pipelineID and buildID are required when status is 'In Use'")
            sys.exit(1)
        pipeLineIDBlock = {"fieldId": 10001, "name": "PipelineID", "type": "IntegerFieldValue", "value": int(pipelineID)}
        buildIdBlock = {"fieldId": 10002, "name": "BuildID", "type": "IntegerFieldValue", "value": int(buildID)}
        assignmentBlock = {"id": 121, "name": "craft-runner", "type": "UserReference", "email": "karvec2@medtronic.com"}
        finalBodyBlock["assignedTo"] = [assignmentBlock]
        overrideFields = {1000: finalAvailability, 10001: pipeLineIDBlock, 10002: buildIdBlock}
        removeFieldIds = set()
    else:
        finalBodyBlock["assignedTo"] = []
        overrideFields = {1000: finalAvailability}
        removeFieldIds = {10001, 10002}

    # Merge our custom fields into existing ones, replacing by fieldId
    existingCustomFields = finalBodyBlock.get("customFields", [])
    updatedCustomFields = []
    seenFieldIds = set()
    for field in existingCustomFields:
        fid = field.get("fieldId")
        if fid in removeFieldIds:
            continue
        elif fid in overrideFields:
            updatedCustomFields.append(overrideFields[fid])
            seenFieldIds.add(fid)
        else:
            updatedCustomFields.append(field)
    # Add any override fields not already present
    for fid, block in overrideFields.items():
        if fid not in seenFieldIds:
            updatedCustomFields.append(block)
    finalBodyBlock["customFields"] = updatedCustomFields

    # Override status/categories/subjects as before
    finalBodyBlock["status"] = {"id": 7, "name": "Online", "type": "ChoiceOptionReference"}
    finalBodyBlock["categories"] = [{"id": 2, "name": "Pipeline_Board", "type": "ChoiceOptionReference"}]
    finalBodyBlock["subjects"] = [{"id": 2, "name": "G4", "type": "ChoiceOptionReference"}]

    response = session.put(url, json=finalBodyBlock)
    if response.status_code == 200:
        print(f"Test Configuration {tcID} updated successfully!")
    else:
        print(f"Failed to update Test Configuration {tcID}. Status Code: {response.status_code}")
        print("Response:", response.text)   

def getTestConfig(testConfigName):
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    url = "https://crdn.codebeamer.com/rest/v3/trackers/261904/items/"
    session=requests.session()
    session.verify=False
    session.auth=HTTPBasicAuth(USERNAME,PASSWORD)
    response=session.get(url)
    id=response.json().get("itemRefs")
    for item in id:
        if item.get("name") == testConfigName:
            print("Found Test Config:", item.get("name"), "with ID:", item.get("id"))
            return item.get("id")
    print("Test Config with name", testConfigName, "not found. Please note, the name has to be an exact match!")
    sys.exit(1)


configID = getTestConfig(sys.argv[1])
status = sys.argv[2]
pipelineID = sys.argv[3] if len(sys.argv) > 3 else None
buildID = sys.argv[4] if len(sys.argv) > 4 else None
updateTestConfig(configID, status, pipelineID, buildID)
