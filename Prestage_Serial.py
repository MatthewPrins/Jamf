#!/usr/bin/env python3
# Matthew Prins 2023
# https://github.com/MatthewPrins/Jamf/

# finds the prestage for a specific serial number via the API

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

from credentials import *

#Serial number for device looking for
serial="DY5DD13SJ1WF"

#True for computers, False for mobile devices
lookingforcomputer = False

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

if lookingforcomputer:
	apitext = "computer-prestages/"
else:
	apitext = "mobile-device-prestages/"
	
# import data from API as a dictionary
response = requests.get(jamfurl + "/api/v2/" + apitext + "scope", headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
serialdictionary = json.loads(response.text)['serialsByPrestageId']

# get prestage name for that serial number
try:
	response = requests.get(jamfurl + "/api/v2/" + apitext + serialdictionary[serial], headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
	prestagedictionary = json.loads(response.text)
	print(serial + ": " + prestagedictionary['displayName'] + " (" + serialdictionary[serial] + ")")

# error message if not found
except:
	print("serial " + serial + " not found in any prestage")

exit()
