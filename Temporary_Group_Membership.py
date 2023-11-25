#!/usr/bin/env python3
# Matthew Prins 2023
# https://github.com/MatthewPrins/Jamf/

# changes group membership from no mobile devices temporarily to all mobile devices
# can be used with cron job to remove devices from a config profile on a schedule
# create mobile device smart group for this purpose, and add it to exclusions for that config profile
# (criteria when creating the smart group doesn't matter, as it will be deleted)

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

# Mobile device smart group ID number -- found in URL on group's page
# if trying to remove config profile temporarily, set this group in exclusions for that profile
groupID="123"

# Number of minutes to wait before removing all mobile devices from group
waitminutes=60

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

# XML for adding all devices to group membership
XML = "<mobile_device_group><is_smart>true</is_smart><criteria><criterion><name>Serial Number</name><priority>0</priority><and_or>AND</and_or><search_type>is not</search_type><value></value><opening_paren>false</opening_paren><closing_paren>false</closing_paren></criterion></criteria></mobile_device_group>"

#API call to make group all mobile devices
print("sending command to add all mobile devices to group\n")
response = requests.put(url=jamfurl + "/JSSResource/mobiledevicegroups/id/" + groupID, headers={'Content-Type': 'application/xml','Authorization': 'Bearer ' + token}, data=XML)
print("all mobile devices added\n")

#wait
print("waiting for " + str(waitminutes) + " minutes\n")
time.sleep(waitminutes*60)
print("waiting done\n")

# XML for adding all devices to group membership
XML = "<mobile_device_group><is_smart>true</is_smart><criteria><criterion><name>Serial Number</name><priority>0</priority><and_or>AND</and_or><search_type>is</search_type><value></value><opening_paren>false</opening_paren><closing_paren>false</closing_paren></criterion></criteria></mobile_device_group>"

# if less than 5 minutes left, invalidate token and get a new one		
if (tokenexpiration-datetime.utcnow()).total_seconds() < 600:
	invalidatetoken()
	token,tokenexpiration = fetchtoken()

#API call to make group all mobile devices
print("sending command to remove all mobile devices from group\n")
response = requests.put(url=jamfurl + "/JSSResource/mobiledevicegroups/id/" + groupID, headers={'Content-Type': 'application/xml','Authorization': 'Bearer ' + token}, data=XML)
print("all mobile devices removed, script ending\n")

exit()
