#!/usr/bin/env python3
# Matthew Prins 2023
# https://github.com/MatthewPrins/Jamf/

# report of all email addresses connected to more than one user account in a user group
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

# User group ID
usergroupID=123

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

# get users from API
response = requests.get(url=jamfurl + "/JSSResource/usergroups/id/" + str(usergroupID), headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
invalidatetoken()
userlist = []

# add pertinent info to userlist 
# [id, username, full name, email]
for user in json.loads(response.text)['user_group']['users']:
	userlist.append([user['id'],user['username'],user['full_name'],user['email_address']])

print (str(len(userlist)) + " users\n")

# get emails and sort into categories
emaillist=[]
duplicateemaillist=[]
blank = 0
for user in userlist:
	if user[3] in emaillist:
		duplicateemaillist.append(user[3])
	elif user[3] != '':
		emaillist.append(user[3])
	else:
		blank+=1

#print stats
print (str(len(emaillist)) + " distinct emails")
print (str(len(duplicateemaillist)) + " emails with duplicate user accounts")
print (str(blank) + " users with blank emails")

#iterate through duplicate emails
duplicateemaillist.sort()
for dup in duplicateemaillist:
	print("\n"+ dup + ":")
	
	#iterate through userlist and look for matches
	for user in userlist:
		if dup == user[3]:
			print(" * " + str(user[0]) + ": " + user[1] + ", " + user[2])
