#!/usr/bin/env python3

# Report of all computer or mobile device models by OS version installed
# pip install requests if not already done

import json
import requests

############################
# Editable variables

# Jamf credentials
username="xxxxxx"
password="xxxxxx"
jamfurl="https://xxxxxx.jamfcloud.com"

# searching for computers or mobile devices? if iscomputer=True then computers, if =False then mobile devices
iscomputer=False

############################

# fetch API token
response = requests.post(url=jamfurl + "/api/v1/auth/token", headers={'Accept': 'application/json'}, auth=(username, password))
token = response.json()['token']

# variables for computer v. mobile device
if iscomputer:
	devicetype="computers"
	devicetypejson="computers"
	devicetypejsonsingular="computer"
	devicesubset="hardware"
	deviceostype="os_name"
else:
	devicetype="mobiledevices"
	devicetypejson="mobile_devices"
	devicetypejsonsingular="mobile_device"
	devicesubset="general"
	deviceostype="os_type"
	
# import data from API as a dictionary
response = requests.get(url=jamfurl + "/JSSResource/" + devicetype, headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})

# iterate through imported data to get IDs
devicelist=[]
for device in json.loads(response.text)[devicetypejson]:
	devicelist.append(device['id'])

# wildcard logic class
class Wildcard:
	def __eq__(self, anything):
		return True

# create applist
oslist=[]

# iterate through device IDs
print (str(len(devicelist)) + " devices:")
print
for index,deviceID in enumerate(devicelist,start=1):
	responseurl=jamfurl + "/JSSResource/" + devicetype + "/id/" + str(deviceID) + "/subset/" + devicesubset
	response = requests.get(url=responseurl, headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
	devicedictionary=json.loads(response.text)
	
	# pull needed variables from devicedictionary
	model=devicedictionary[devicetypejsonsingular][devicesubset]['model']
	ostype=devicedictionary[devicetypejsonsingular][devicesubset][deviceostype]
	osversion=devicedictionary[devicetypejsonsingular][devicesubset]['os_version']
	
	# if device/OS version combo new to list, add it to OSlist
	if oslist.count([model,ostype + " " + osversion,Wildcard()]) == 0:
		oslist.append([model,ostype + " " + osversion,1])
	# otherwise update the number of minutes
	else:
		oslist[oslist.index([model,ostype + " " + osversion,Wildcard()])][2]+=1

	#print status every 10
	if index % 10 == 0:
		print (str(index) + " / " + str(len(devicelist)))

# print final status (if not already printed)
if len(devicelist) % 10 != 0:
	print (str(len(devicelist)) + " / " + str(len(devicelist)))
print()	

# sort oslist by number of devices high to low
oslist.sort(key=lambda x : x[2], reverse=True)
	
# grab all models and dedup -- list/set command is doing the deduping
allmodels=list(set([item[0] for item in oslist]))
allmodels.sort()
		
# iterate through every model
for thismodel in allmodels:
	print(thismodel + ":")
	
	# iterate through oslist finding sublists that are from this model and printing them
	for os in oslist:
		if thismodel == os[0]:
			#if blank OS print not reported, otherwise print OS
			if os[1] == " ":
				print ("   not reported: " + str(os[2]))
			else:
				print("   " + os[1] + ": " + str(os[2]))
	print()
