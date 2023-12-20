#!/usr/bin/env python3
# Matthew Prins 2023
# https://github.com/MatthewPrins/Jamf/

# all auto installed mobile apps and their scopes/exclusions

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

# import mobile app data from API as a dictionary
response = requests.get(jamfurl + "/JSSResource/mobiledeviceapplications", headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
appdictionary = json.loads(response.text)

# iterate through ids in appdictionary and add to idlist
idlist=[]
for entry in appdictionary["mobile_device_applications"]:
	idlist.append(entry["id"]) 

print (str(len(idlist)) + " devices\n")
	
# iterate through idlist
for appid in idlist:
	response = requests.get(jamfurl + "/JSSResource/mobiledeviceapplications/id/" + str(appid), headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
	tempdictionary = json.loads(response.text)["mobile_device_application"]

	#check if the app is automatically deployed
	if tempdictionary["general"]["deploy_automatically"] == True :
		print(tempdictionary["general"]["name"] + " (" + str(tempdictionary["general"]["id"]) + "):")
		for key in tempdictionary["scope"]:
			#don't print if definition is empty
			if tempdictionary["scope"][key] != False and tempdictionary["scope"][key] != []:

				#if definition is dictionary and non-empty iterate through and print contents
				if isinstance(tempdictionary["scope"][key], dict) and tempdictionary["scope"][key] != {'users': [], 'user_groups': [], 'network_segments': []} and tempdictionary["scope"][key] != {'mobile_devices': [], 'buildings': [], 'departments': [], 'mobile_device_groups': [], 'users': [], 'user_groups': [], 'network_segments': [], 'jss_users': [], 'jss_user_groups': []} :
					print("   " + str(key) + ":")
					for key2 in tempdictionary["scope"][key]:
						#don't print if definition is empty
						if tempdictionary["scope"][key][key2] != []:
							#iterate through list and print name and ID
							print("      " + str(key2) + ":")
							for listmember in tempdictionary["scope"][key][key2]: 
								print("         " + str(listmember["name"]) + " (" +	str(listmember["id"]) + ")")						

				#if definition is list, iterate through list and print name and ID			
				elif isinstance(tempdictionary["scope"][key], list):
					print("   " + str(key) + ":")
					for listmember in tempdictionary["scope"][key]: 
						print("      " + str(listmember["name"]) + " (" +	str(listmember["id"]) + ")")
		print()
		
	# if less than 5 minutes left, invalidate token and get a new one		
	if (tokenexpiration-datetime.utcnow()).total_seconds() < 600:
		invalidatetoken()
		token,tokenexpiration = fetchtoken()

print("done!")
exit()
