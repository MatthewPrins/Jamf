#!/usr/bin/env python3
# Matthew Prins 2023
# https://github.com/MatthewPrins/Jamf/

# removes members from mobile device static group temporarily
# IDs of static group members backed up to staticgroupmembers.txt

# pip install requests if not already done

import json
import requests
import time
from datetime import datetime

############################
# Editable variables

# Jamf credentials
username="xxxxxx"
password="xxxxxx"
jamfurl="https://xxxxxx.jamfcloud.com"

# Mobile device static group ID number -- found in URL on group's page
groupID="123"

# Number of minutes to wait until adding members back into static group
waitminutes=10

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

# pull list of group members from API into dictionary
response = requests.get(url=jamfurl + "/JSSResource/mobiledevicegroups/id/" + str(groupID), headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
dictionary=json.loads(response.text)["mobile_device_group"]

#iterate through dictionary to get IDs
IDs = []
for device in dictionary["mobile_devices"]:
	IDs.append(device["id"])

# for safety write IDs to staticgroupmembers.txt
print(str(len(IDs)) + " members in static group: " + str(dictionary["name"]) + " (" + groupID + ")\n")
if IDs != []:
	with open('staticgroupmembers.txt', 'w') as f:
		f.write(str(IDs))
	print("backed up group members to staticgroupmembers.txt\n")

#iterate through IDs to create XML to delete group members
XML = "<mobile_device_group><mobile_device_deletions>"
for ID in IDs:
	XML = XML + "<mobile_device><id>" + str(ID) + "</id></mobile_device>"
XML = XML + "</mobile_device_deletions></mobile_device_group>"

#API call to delete members
print("sending command to delete members, please wait\n")
response = requests.put(url=jamfurl + "/JSSResource/mobiledevicegroups/id/" + str(groupID), headers={'Content-Type': 'application/xml','Authorization': 'Bearer ' + token}, data=XML)
print("members deleted\n")

#wait
print("waiting for " + str(waitminutes) + " minutes\n")
time.sleep(waitminutes*60)
print("waiting done\n")

#change XML to add group members instead of deleting
XML = XML.replace("mobile_device_deletions", "mobile_device_additions")

# if less than 5 minutes left, invalidate token and get a new one		
if (tokenexpiration-datetime.utcnow()).total_seconds() < 600:
	invalidatetoken()
	token,tokenexpiration = fetchtoken()

#API call to restore members
print("sending command to restore members, please wait\n")
response = requests.put(url=jamfurl + "/JSSResource/mobiledevicegroups/id/" + str(groupID), headers={'Content-Type': 'application/xml','Authorization': 'Bearer ' + token}, data=XML)
print("members restored, script closing\n")

exit()
