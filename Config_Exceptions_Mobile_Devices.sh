#!/usr/bin/env python3

# Print report of exclusions for every mobile device configuration profile

# pip install requests if not already done
import requests
import json
from datetime import datetime

############################
# Editable variables

# Jamf credentials
username = "xxxxxx"
password = "xxxxxx"
jamfurl = "https://xxxxxx.jamfcloud.com"

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

# import data from API as a dictionary
response = requests.get(url=jamfurl + "/JSSResource/mobiledeviceconfigurationprofiles", headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})

# iterate through imported data to get IDs
profilelist=[]
for profile in json.loads(response.text)['configuration_profiles']:
	profilelist.append(profile['id'])
	
# iterate through device IDs
print (str(len(profilelist)) + " configuration profiles")
print()
print("ALL EXCEPTIONS:")
print()

response = requests.get(url=jamfurl + "/JSSResource/mobiledeviceconfigurationprofiles/id/81", headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})

possibleexclusions = ["mobile_devices","buildings","departments","mobile_device_groups","users","user_groups","network_segments","ibeacons","jss_users","jss_user_groups"]

for index,profileID in enumerate(profilelist,start=1):
	#get info for the user into a dictionary
	responseurl = jamfurl + "/JSSResource/mobiledeviceconfigurationprofiles/id/" + str(profileID)
	response = requests.get(url=responseurl, headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
	profiledictionary=json.loads(response.text)
	
	print(str(profiledictionary["configuration_profile"]["general"]["name"]) + ":")
	
	for i in possibleexclusions:
		exclusionlist = profiledictionary["configuration_profile"]["scope"]["exclusions"][i]
		for entry in exclusionlist:
			print("   " + i + ": " + str(entry["name"]))

	print()
		
	# if less than 5 minutes left, invalidate token and get a new one
	if index % 25 == 0:
		if (tokenexpiration-datetime.utcnow()).total_seconds() < 600:
			invalidatetoken()
			token,tokenexpiration = fetchtoken()
			
invalidatetoken()
