#!/usr/bin/env python3

# Matthew Prins 2023
# https://github.com/MatthewPrins/Jamf/

# Restart all items in a particular mobile group in Jamf

# Minimum permissions:
	# Objects:
		# Mobile Devices (Create, Read)
		# Smart Mobile Device Groups (Read)
		# Static Mobile Device Groups (Read)
	# Actions
		# Send Mobile Device Restart Device Command
		
# pip install requests if not already done

import json
import requests
import datetime

############################
# Editable variables

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
jamfurl="https://xxxxxx.jamfcloud.com"

#Group ID number -- found in URL on group's page
groupid="444"

############################

# fetch API token
response = requests.post(url=jamfurl + "/api/v1/auth/token", headers={'Accept': 'application/json'}, auth=(username, password))
token = response.json()['token']

# import data from API as a dictionary
response = requests.get(jamfurl + "/JSSResource/mobiledevicegroups/id/" + groupid, headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
appdictionary = json.loads(response.text)

# create idlist
idlist=""

# iterate through ids in appdictionary and add to idlist
for entry in appdictionary["mobile_device_group"]["mobile_devices"]:
	idlist += str(entry["id"]) + ","

# delete terminal comma
idlist = idlist[:-1]

#Restart all devices in csv list
response = requests.post(jamfurl + "/JSSResource/mobiledevicecommands/command/RestartDevice/id/" + idlist, headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
print(response.text)
