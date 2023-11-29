#!/usr/bin/env python3
# Matthew Prins 2023
# https://github.com/MatthewPrins/Jamf/

# put all mobile devices in a group in Lost Mode 
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

# mobile device group ID number -- found in URL on group's page
groupid="123"

# Information to appear on Lost Mode screen on devices
lm_message = "lost mode message here"
lm_phone = "000-000-0000"
lm_footnote = "footnote here"

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
# get initial token	
token,tokenexpiration = fetchtoken()

# get group information
response = requests.get(url=jamfurl + "/JSSResource/mobiledevicegroups/id/" + str(groupid), headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
groupinfo=json.loads(response.text)['mobile_device_group']

#populate list of IDs
IDlist = []
for member in groupinfo['mobile_devices']:
	IDlist.append(member['id'])

#get approval to put all devices in Lost Mode
print("Mobile Device Group ID: " + str(groupinfo['id']))
print("Name: " + str(groupinfo['name']))
print("Number of Members: " + str(len(IDlist)) + "\n")
print("Type YES (all caps) to put all devices in the group in Lost Mode, anything else to quit:")
approval = input()
print()
if approval != "YES":
	print("ok, exiting")
	exit()

#start iterating through mobile device ID list
for ID in IDlist:

	#from mobile device ID, get device UUID
	response = requests.get(url=jamfurl + "/api/v2/mobile-devices/" + str(ID), headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
	uuid=json.loads(response.text)['managementId']

	#put device in Lost Mode
	commandpayload = {	"commandData": { "commandType": "ENABLE_LOST_MODE", "lostModeMessage": lm_message, "lostModePhone": lm_phone, "lostModeFootnote": lm_footnote }, "clientData": [{ "managementId": uuid }] }	
	response = requests.post(url=jamfurl + "/api/preview/mdm/commands", json=commandpayload, headers={"Accept": "application/json", "content-type": "application/json",'Authorization': 'Bearer ' + token})

	#return success or fail
	try:
		temp=json.loads(response.text)[0]['href']
		print(str(ID) + ": success")
	except:
		print(str(ID) + ": fail")
		print(response.text)

exit()
