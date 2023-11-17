#!/usr/bin/env python3
# Matthew Prins 2023
# https://github.com/MatthewPrins/Jamf/

# graphs of the drive space used in mobile devices in a group (percentage and actual)

# pip install requests, matplotlib, and numpy if not already done

import json
import requests
from datetime import datetime
import matplotlib.pyplot as plt
import numpy as np

############################
# Editable variables
# Jamf credentials
username="xxxxxx"
password="xxxxxx"
jamfurl="https://xxxxxx.jamfcloud.com"

#Group ID number -- found in URL on group's page
groupid="123"

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

# import data from API as a dictionary
response = requests.get(jamfurl + "/JSSResource/mobiledevicegroups/id/" + groupid, headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
appdictionary = json.loads(response.text)

# create idlist and data lists
idlist=[]
storagepercentageusedlist=[]
actualstorageusedlist=[]

# iterate through ids in appdictionary and add to idlist
for entry in appdictionary["mobile_device_group"]["mobile_devices"]:
	idlist.append(entry["id"]) 
	
print (str(len(idlist)) + " devices\n")
	
# iterate through idlist
for index,deviceid in enumerate(idlist,start=1):
	response = requests.get(jamfurl + "/api/v2/mobile-devices/" + str(deviceid) + "/detail", headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
	storagepercentageusedlist.append(json.loads(response.text)["ios"]["percentageUsed"])
	actualstorageusedlist.append(json.loads(response.text)["ios"]["capacityMb"] - json.loads(response.text)["ios"]["availableMb"] )
	
	# print update every 25
	if index % 25 == 0 or index == len(idlist):
		print(str(index) + " / " + str(len(idlist)))
		
	# if less than 5 minutes left, invalidate token and get a new one		
	if (tokenexpiration-datetime.utcnow()).total_seconds() < 600:
		invalidatetoken()
		token,tokenexpiration = fetchtoken()

# first figure
fig1 = plt.figure("Percentage Used")
plt.hist(np.array(storagepercentageusedlist))
plt.xlabel('Percentage of space used')
plt.ylabel('Number of devices')
plt.title('Percentage of space used per device')

# second figure
fig2 = plt.figure("Storage Space Used")
plt.hist(np.array(actualstorageusedlist))
plt.xlabel('Storage space used (MB)')
plt.ylabel('Number of devices')
plt.title('Actual storage space used per device')

# draw them
plt.show()
