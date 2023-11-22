#!/usr/bin/env python3
# Matthew Prins 2023
# https://github.com/MatthewPrins/Jamf/

# list of policies and configuration profiles scoped to a particular department

# pip install requests if not already done

import json
import requests
from datetime import datetime

############################
# Editable variables
# Jamf credentials
username="xxxxxx"
password="xxxxxx"
jamfurl="https://xxxxxx.jamfcloud.com"

#Department ID number -- found in URL on department's page
departmentid="1"

############################
# definition for fetching API token
def fetchtoken():
	response = requests.post(url=jamfurl + "/api/v1/auth/token", headers={'Accept': 'application/json'}, auth=(username, password))
	print("new token fetched\n")
	return response.json()['token'], datetime.strptime(response.json()['expires'], '%Y-%m-%dT%H:%M:%S.%fZ')

# definition for invalidating API token
def invalidatetoken():	
	response = requests.post(url=jamfurl + "/api/v1/auth/invalidate-token", headers={'Authorization': 'Bearer ' + token})	

############################
	
# fetch API token
token,tokenexpiration = fetchtoken()

# what to look for and iterate through (e.g. policies)
# first field name, second field API call, third field JSON term plural, fourth term JSON term singular
searchinfo = [
	["Computer Policies", "policies", "policies", "policy"],
	["Computer Configuration Profiles", "osxconfigurationprofiles", "os_x_configuration_profiles", "os_x_configuration_profile"],
	["Mobile Device Configuration Profiles", "mobiledeviceconfigurationprofiles", "configuration_profiles", "configuration_profile"],	
]

for currentinfo in searchinfo:
	
	# get list of all e.g. policies
	response = requests.get(jamfurl + "/JSSResource/" + currentinfo[1], headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
	iddictionary = json.loads(response.text)
	
	# iterate through ids in appdictionary and add to idlist
	idlist=[]
	for entry in iddictionary[currentinfo[2]]:
		idlist.append(entry["id"]) 
	
	# print introductory info
	print (str(len(idlist)) + " Total " + currentinfo[0] + "\n")
	print (currentinfo[0]+ " with Department " + departmentid + ":\n")
	
	# iterate through policies
	for index,deviceid in enumerate(idlist,start=1):
		response = requests.get(jamfurl + "/JSSResource/" + currentinfo[1] + "/id/" + str(deviceid), headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
		tempdictionary=json.loads(response.text)[currentinfo[3]]
		#see if department is there
		for entry in tempdictionary["scope"]["departments"]:
			if str(entry["id"]) == departmentid:
				print(str(tempdictionary["general"]["id"]) + ": " + tempdictionary["general"]["name"])
			
		# if less than 5 minutes left, invalidate token and get a new one		
		if (tokenexpiration-datetime.utcnow()).total_seconds() < 600:
			invalidatetoken()
			token,tokenexpiration = fetchtoken()
      
	print()
  
print("completed search")
