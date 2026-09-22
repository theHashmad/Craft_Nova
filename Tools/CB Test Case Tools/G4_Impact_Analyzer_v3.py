import gitlab
import re
from datetime import date, timedelta,datetime
import requests
from requests.auth import HTTPBasicAuth
import json

username="craft-runner"
password="craft-runner"
cburl = "https://crdn.codebeamer.com"
gl = gitlab.Gitlab('https://code.medtronic.com', private_token='gl-prd-RAdk6eam3Nx6Ri7aWDzR')
rf_tags=[]
cbItems=[]
tcAutoList=[]
tcManualList=[]
tcSkipList=[]
skipTagList=["unit","CMake","include","alpha","4ch","dev","gitlab","test","Main"]
skipFileList=[]
daysOlderThan=30
tcTagList=[]
# tcTagList=["temparature","therapy","RF","regression","smoke","hardware","integration","system","generator_api","diagnostic","display","medtronic","hardware_abstraction_layer","hal","ci_cd_pipeline"]
tcQueryTagList=[]
tcTagQueryList=[]
session=requests.session()
session.verify=False
session.auth=HTTPBasicAuth(username,password)
urlTC = "https://crdn.codebeamer.com/rest/v3/items/query"
getTagQuery = "tracker.id = 19968 and status NOT IN ('Rejected','Retired','Outdated')"
getTCTagsPayload = {"queryString": getTagQuery}
getTCTagsResponse = session.post(urlTC, json=getTCTagsPayload)
for tagItem in getTCTagsResponse.json().get("items"):
    tmpTags=tagItem.get("tags")
    if tmpTags:
        for tmpTag in tmpTags:
            tcTagList.append(tmpTag["name"])
print(tcTagList)

tmpDate= datetime.today()
finalDate = tmpDate - timedelta(days=1)
G4_projects=[15635,13142]
for projectid in G4_projects:
    project = gl.projects.get(projectid)
    print("\nProcessing Repository :",project.name)
    # commits = project.commits.list(per_page=1,get_all=False)
    commits = project.commits.list(since='2025-10-01',until='2025-10-5',get_all=True)
    for commit in commits:
            print("\nProcessing Latest Commit ID :",commit.id)
            print("Commit Date :",commit.authored_date[0:10])
            commitDate = datetime.fromisoformat(commit.authored_date[0:10])
            diff = tmpDate - commitDate
            if diff.days > daysOlderThan:
                 print("Skipping Processing Older Merge Request - MR is",diff.days," days old !")
                 continue
            else:
                print("Commit Message:",commit.message)
                if "(#" in commit.message:
                    tmpCBItem = re.split(r'[()#]',commit.message)
                    cbItems.append(tmpCBItem[2])
                    print("CB Item Identified from Commit Message:",tmpCBItem[2])
                else:
                    tmpCBItem = re.split(r'[ ]',commit.message)
                    tmpCBValue=tmpCBItem[0].split('-')
                    print("CB Item Identified from Commit Message:",tmpCBValue)
                    cbItems.append(tmpCBValue[1])
                    print("CB Item Identified from Commit Message:",tmpCBValue)
                # cbItems.append(tmpCBItem[2])               
                diffs = commit.diff(get_all=True)
                changed_files = []

                for diff in diffs:
                    changed_files.append(diff['new_path'])            
                for changed_file in changed_files:

                    if any(subStr in changed_file for subStr in skipTagList):
                        # print("\nSkipping common library or unit test file :",changed_file)
                        skipFileList.append(project.name + ":" + changed_file)
                        continue
                    else:
                            code_file = changed_file.split('/')
                            rf_tags.append(code_file[0])
                            # print("\nAnalyzing Changed File :",code_file)
                            # rf_tags.append(code_file[0])
                            if "display" in code_file and "Medtronic" in code_file:
                                tmpTag=code_file[-2].split('.')
                                rf_tags.append(tmpTag[0])
                                # print(tmpTag)
                            elif "hardware" in code_file and len(code_file)>3:
                                tmpTag=code_file[3].split('.')
                                rf_tags.append(tmpTag[0])                      
                                # print(tmpTag)
                            elif "display" in code_file and len(code_file)<4: 
                                tmpTag=code_file[-1].split('.')
                                rf_tags.append(tmpTag[0])
                                # print(tmpTag)
                            elif "diagnostic" in code_file and code_file[1]=="src": 
                                tmpTag=code_file[2].split('.')
                                rf_tags.append(tmpTag[0])
                                # print(tmpTag)
                            else:
                                tmpTag=code_file[-1].split('.')
                                rf_tags.append(tmpTag[0])
                                print(tmpTag)
                            
                print("Completed Impact Analysis for Commit ID :",commit.id)
                print("Tags Identified:",list(set(rf_tags)))
                print("CB Items Impacted:",list(set(cbItems)))

finalRFTags=list(set(rf_tags))

# print("Final CB Items:",list(set(cbItems)))
tcList=[]
for cbItem in cbItems:
    print("\n\nProcessing CB Item :",cbItem)
    url = "https://crdn.codebeamer.com/rest/items/"+cbItem+"/relations"
    
    response = session.get(url)
    # print("\nResponse Code :",response.json())
    for tmpResponse in response.json():
        if tmpResponse == "canCreateAssociation":
            continue
        else:
            # print("\n\nBLOCK1:",tmpResponse)
            tmpResponseBlock=response.json()[tmpResponse]
            for responseBlock in tmpResponseBlock:
                if responseBlock:
                    # print("\nBLOCK2:",responseBlock)
                    if type(responseBlock) is not dict:
                        continue
                    tmpRelations=responseBlock.get("keyAndId")
                    if tmpRelations is None:
                        continue
                    else:
                        # print("Related Item:",tmpRelations)
                        if "TESTCASE-" in tmpRelations:
                            tmpRelations=tmpRelations.replace("TESTCASE-","")
                            tcList.append(tmpRelations)

tcList=list(set(tcList))
# print(tcList)

for tag in tcTagList:
    for RFTag in finalRFTags:
        if tag in RFTag:
            # print("\nRF Tags match with TC Tags for Regression Execution.",tag)
            tcQueryTagList.append(tag)


tmpTagList=str(list(set(tcQueryTagList)))
tmpTagList=tmpTagList.replace("[",'')
tmpTagList=tmpTagList.replace("]",'')
tmpTagList=tmpTagList.replace("_",'')
tmpQueryString= "tracker.id = 19968 and trackerItemTag IN ("+tmpTagList+")"

# print("\nFinal Query String for RF Tag Analysis in CodeBeamer:\n",tmpQueryString)

tcQueryPayload = {"queryString": tmpQueryString}


getTCResponse = session.post(urlTC, json=tcQueryPayload)
totalTCs=getTCResponse.json().get("total")
# print("\nTotal Test Cases identified through RF Tag Analysis in CodeBeamer:",totalTCs)

for tcItem in getTCResponse.json().get("items"):
    tmpTCID=tcItem.get("id")
    print("\nIdentified Test Case ID through RF Tag Analysis:",tmpTCID)
    # tmpTCName=tcItem.get("name")
    # tmpDict = {"id": tmpTCID, "name": tmpTCName,"type":"TrackerItemReference"}
    tcList.append(str(tmpTCID))

# print("\n\nFinal Test Case List identified for Regression Execution:",list(set(tcList)))

for tc in tcList:
    url2="https://crdn.codebeamer.com/rest/v3/items/"+tc
    bdTCDetails=session.get(url2)
    tmpTCStatus=(bdTCDetails.json().get("status"))
    tmpCF=(bdTCDetails.json().get("customFields"))
    tmpName=(bdTCDetails.json().get("name"))
    tmpDict = {"id": tc, "name": tmpName,"type":"TrackerItemReference"}
    # if tmpTCStatus.get("name") == "Outdated" or tmpTCStatus.get("name") == "Rejected" or tmpTCStatus.get("name") == "In Design":
    if tmpTCStatus.get("name") != "Accepted":
        # print ("\nSkipping",tmpTCStatus.get("name"),"TC-",tc)
        tcSkipList.append(tmpDict)
        continue
    else:
        print("\nProcessing Test Case ID:",tc," Name:",tmpName)
        tmpAS=(tmpCF[0].get("values"))
        print("Automation Status:",tmpAS)        
        if (tmpAS[0].get("name"))=="Not Started":
            tcManualList.append(tmpDict)
        else:
            tcAutoList.append(tmpDict)

print("\n\n------------------------------------------------------------------------------------------")
print("Please review the files skipped from analysis with Developer:\n")
for skipFile in skipFileList:
    print(skipFile)
print("------------------------------------------------------------------------------------------")
print("CB Items Identified:\n",list(set(cbItems)))
print("------------------------------------------------------------------------------------------")        
print("Test Tags Identified:\n",list(set(rf_tags)))
print("------------------------------------------------------------------------------------------")        
if len(tcManualList) == 0:
    print("\nNo Manual test identified")
else:
    print("\nAutomation Not Available for TC:\t",tcManualList,"\nPlease execute the tests manually for regression coverage.")
print("------------------------------------------------------------------------------------------")
if len(tcAutoList) > 0:
    print("\nAutomation Available for TC:\t",tcAutoList,"\nThese tests can be executed through Automation suite.")
else:
    print("\nNo Automated test cases identified for Regression Execution!")
print("------------------------------------------------------------------------------------------")
if len(tcSkipList) > 0:
    print("\nThe following TC were skipped as they are not in Accepted status:\t",tcSkipList,"\nPlease review the TC urgently and execute!")
print("------------------------------------------------------------------------------------------")



fullTCList=tcAutoList + tcManualList
# print("\n\nFinal Test Case List for Regression Execution:",fullTCList)
print("\nCreating Test Run in CodeBeamer for Regression Execution...")

testRunObj = {"name" : "TBD_CK_IA_Run_"+date.today().strftime("%Y%m%d"),"description" : "Test Run created through Impact Analyzer Script for Regression Execution.\nCB Items Identified:\n"+str(list(set(cbItems)))+"\nTest Tags Identified:\n"+str(list(set(rf_tags)))}
# print("\n\nTest Run Object to be created in CB for RF Execution:\n",testRunObj)
finalTestRunBody = {"testCaseIds" : fullTCList,"testRunModel" : testRunObj}
# print("\n\nFinal Test Run Body to be used for creating Test Run in CB:\n",finalTestRunBody)
url3 = "https://crdn.codebeamer.com/rest/v3/trackers/19971/testruns"
response3 = session.post(url3, json=finalTestRunBody)
# print("\n\nTest Run Creation Response Code:",response3.status_code)
# print("\n\nTest Run Creation Response Body:",response3.json())
print("Test Run Created : https://crdn.codebeamer.com/item/"+str(response3.json()['id']))
print("------------------------------------------------------------------------------------------")        