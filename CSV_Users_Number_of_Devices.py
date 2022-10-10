#!/usr/bin/env python3

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

# import data from API
response = requests.get(url=jamfurl + "/JSSResource/users", headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})

# iterate through imported data to get IDs
userlist=[]
for user in json.loads(response.text)['users']:
	userlist.append(user['id'])

# create userdatalist
userdatalist=[]

# iterate through device IDs
print (str(len(userlist)) + " users:")
print
for index,userID in enumerate(userlist,start=1):

	#get API info for the user into a dictionary
	responseurl = jamfurl + "/JSSResource/users/id/" + str(userID)
	response = requests.get(url=responseurl, headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
	userdictionary=json.loads(response.text)
	
	# pull needed variables from userdictionary
	nameofuser=userdictionary['user']['name']
	email=userdictionary['user']['email']
	computers=len(userdictionary['user']['links']['computers'])
	mobiledevices=len(userdictionary['user']['links']['mobile_devices'])

	# add variables to userdatalist
	userdatalist.append([nameofuser,email,computers,mobiledevices,computers + mobiledevices])

	#print status every 25
	if index % 25 == 0:
		print (str(index) + " / " + str(len(userlist)))
		
		# if less than 5 minutes left, invalidate token and get a new one
		if (tokenexpiration-datetime.utcnow()).total_seconds() < 600:
			invalidatetoken()
			token,tokenexpiration = fetchtoken()

# print final status (if not already printed)
if len(userlist) % 10 != 0:
	print (str(len(userlist)) + " / " + str(len(userlist)))
print()	

# sort userdatalist by number of devices high to low
userdatalist.sort(key=lambda x : x[4], reverse=True)

# print CSV header
print("Name of User,Email,Computers,Mobile Devices,Total Devices")

#print CSV for every line in userdatalist
for user in userdatalist:
	print('"' + user[0] + '","' + user[1] + '",' + str(user[2]) + "," + str(user[3]) + "," + str(user[4]))

invalidatetoken()
