#!/usr/bin/env python3

# Search for computer by serial using only the new Jamf Pro API, not classic
# pip install requests if not already done

import json
import requests
import math

############################
# Editable variables

# Jamf credentials
username = "xxxxxx"
password = "xxxxxx"
jamfurl = "https://xxxxxx.jamfcloud.com"

# number of computers to pull at one time -- max 2000
computersToPull=100

#serial number of computer looking for
serialNumber='H4TFXXXX1255'

############################

# fetch API token
response = requests.post(url=jamfurl + "/api/v1/auth/token", headers={'Accept': 'application/json'}, auth=(username, password))
token = response.json()['token']
	
# get number of pages to pull from API
response = requests.get(url=jamfurl + "/api/preview/computers", headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
numberPages=math.ceil(json.loads(response.text)['totalCount']/computersToPull)
print(numberPages)

# import data from API as dictionaries within a list
computerList = []
for i in range(0, numberPages):
	response = requests.get(url=jamfurl + "/api/preview/computers?page=" + str(i) + "&page-size=" + str(computersToPull), headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
	for computer in json.loads(response.text)['results']:
		computerList.append(computer)	

# iterate through list to find serial number
for computer in computerList:
	if computer['serialNumber'] == serialNumber:
		print(computer)
