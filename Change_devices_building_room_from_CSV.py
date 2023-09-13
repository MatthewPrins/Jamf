#!/usr/bin/env python3
# Matthew Prins 2023
# https://github.com/MatthewPrins/Jamf/

# CSV report of number of devices for all users
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

#csv file name
csvname="xxxxxx.csv"

#map CSV building name to Jamf building name -- first CSV, second Jamf
buildingdict = {
	'CSV Building 1': 'Jamf Building 1',
	'CSV Building 2': 'Jamf Building 2',
	'CSV Building 3': 'Jamf Building 3'
}

############################

# definition for fetching API token
def fetchtoken():
	response = requests.post(url=jamfurl + "/api/v1/auth/token", headers={'Accept': 'application/json'}, auth=(username, password))
	print("new token fetched")
	return response.json()['token'], datetime.strptime(response.json()['expires'], '%Y-%m-%dT%H:%M:%S.%fZ')

# definition for invalidating API token
def invalidatetoken():	
	response = requests.post(url=jamfurl + "/api/v1/auth/invalidate-token", headers={'Authorization': 'Bearer ' + token})	
	
############################
	
# get initial token	
token,tokenexpiration = fetchtoken()

# get buildings from API and add to dictionary
response = requests.get(url=jamfurl + "/JSSResource/buildings", headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
buildingID = {}
for building in json.loads(response.text)['buildings']:
	buildingID[building['name']] = building['id']

# import all mobile devices from from API
response = requests.get(url=jamfurl + "/JSSResource/mobiledevices", headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})

# iterate through imported data to get IDs
devicelist=[]
for device in json.loads(response.text)['mobile_devices']:
	devicelist.append(device['id'])

# import from CSV
import csv
with open(csvname, 'r') as read_obj:
	csvlist= list(csv.reader(read_obj))

#turn csv into two dictionaries
buildingchange={}
roomchange={}

for row in csvlist:
	if row[0] != '':
		roomchange[row[0]] = row[2]
		if row[1] in buildingdict:
			buildingchange[row[0]] = buildingdict[row[1]]
		else:
			buildingchange[row[0]] = row[1]

# iterate through device IDs
print (str(len(devicelist)) + " devices:")
print ()
for index,deviceID in enumerate(devicelist,start=1):
	
	#get API info for the user into a dictionary
	responseurl = jamfurl + "/JSSResource/mobiledevices/id/" + str(deviceID)
	response = requests.get(url=responseurl, headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
	devicedictionary=json.loads(response.text)

	deviceemail=devicedictionary['mobile_device']['location']['email_address']
	devicebuilding=devicedictionary['mobile_device']['location']['building']
	deviceroom=devicedictionary['mobile_device']['location']['room']
	
	#check if current device building = CSV device building
	if deviceemail != '' :
		if deviceemail in buildingchange:
			if buildingchange[deviceemail] != devicebuilding and buildingchange[deviceemail] != '':
				#change building to CSV building
				print (str(deviceID) + ': for ' + deviceemail + ' -- building from ' + devicebuilding + ' to ' + buildingchange[deviceemail])
				response = requests.patch(jamfurl + "/api/v2/mobile-devices/" + str(deviceID), 
					json={ "location": { "buildingId": buildingID[buildingchange[deviceemail]] } },
					headers = {"accept": "application/json", "content-type": "application/json", 'Authorization': 'Bearer ' + token}
				)

	#check if current device room = CSV device room
		if deviceemail in roomchange:
			if roomchange[deviceemail] != deviceroom and roomchange[deviceemail] != '':
				#change room to CSV room
				print (str(deviceID) + ': for ' + deviceemail + ' -- room from ' + deviceroom + ' to ' + roomchange[deviceemail])
				response = requests.patch(jamfurl + "/api/v2/mobile-devices/" + str(deviceID), 
					json = { "location": { "room": roomchange[deviceemail] } },
					headers = {"accept": "application/json", "content-type": "application/json", 'Authorization': 'Bearer ' + token}
				)
				
	
	#print status every 25
	if index % 25 == 0:
		print (str(index) + " / " + str(len(devicelist)))
		
		# if less than 5 minutes left, invalidate token and get a new one
		if (tokenexpiration-datetime.utcnow()).total_seconds() < 600:
			invalidatetoken()
			token,tokenexpiration = fetchtoken()
			
# print final status (if not already printed)
if len(devicelist) % 10 != 0:
	print (str(len(devicelist)) + " / " + str(len(devicelist)))
print()	
	
invalidatetoken()
