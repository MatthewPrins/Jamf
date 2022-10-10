#!/usr/bin/env python3

# CSV report of computer audit log

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

# If looking for a specific event (e.g. "Issued Remove MDM Profile Command"), put in this variable; otherwise, leave blank
givenevent=""

# If looking for a specific username, put in this variable; otherwise, leave blank
givenusername=""

############################

# definition for fetching API token
def fetchtoken():
	response = requests.post(url=jamfurl + "/api/v1/auth/token", headers={'Accept': 'application/json'}, auth=(username, password))
	print("new token fetched")
	return response.json()['token'], datetime.strptime(response.json()['expires'], '%Y-%m-%dT%H:%M:%S.%fZ')

# definition for invalidating API token
def invalidatetoken():	
	response = requests.post(url=jamfurl + "/api/v1/auth/invalidate-token", headers={'Authorization': 'Bearer ' + token})	
	
# wildcard logic class
class Wildcard:
	def __eq__(self, anything):
		return True
	
############################
	
# get initial token	
token,tokenexpiration = fetchtoken()

# import computer group data from API as a dictionary
response = requests.get(url=jamfurl + "/JSSResource/computers", headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})

# iterate through imported data to get IDs
computerlist=[]
for profile in json.loads(response.text)['computers']:
	computerlist.append(profile['id'])

# create auditlist
auditlist=[]
	
print (str(len(computerlist)) + " Computers")
print()
# iterate through device IDs
for index,computerid in enumerate(computerlist,start=1):
	
	# get info for the user into a dictionary
	responseurl = jamfurl + "/JSSResource/computerhistory/id/" + str(computerid) + "/subset/General&Audit"
	response = requests.get(url=responseurl, headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
	computerdictionary=json.loads(response.text)
		
	#iterate through events and add to auditlist
	for event in computerdictionary["computer_history"]["audits"]:
		#computer ID, computer name, event, username, time UTC
		auditlist.append([computerdictionary["computer_history"]["general"]["id"], computerdictionary["computer_history"]["general"]["name"], event["event"] , event["username"], event["date_time_utc"]])
	
	# print status every 25
	if index % 25 == 0:
		print (str(index) + " / " + str(len(computerlist)))
		
		# if less than 5 minutes left, invalidate token and get a new one
		if (tokenexpiration-datetime.utcnow()).total_seconds() < 600:
			invalidatetoken()
			token,tokenexpiration = fetchtoken()

print("done")
print()	
print("computer ID, computer name, event, username, time")

#iterate through auditlist and print events that meet criteria
for event in auditlist:
	if (givenevent == "" or givenevent == event[2]) and (givenusername == "" or givenusername == event[3]):
		print(str(event[0]) + ',"' + str(event[1]) + '","' + event[2] + '","' + event[3] + '",' + event[4])

invalidatetoken()
