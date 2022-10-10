#!/usr/bin/env python3

# Print report of completed policies for every computer in a computer group

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

# Computer group pulling computers from -- ID can be found in URL of group
computergroupid = "11"

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

# import all policy API data as a dictionary
response = requests.get(url=jamfurl + "/JSSResource/computergroups/id/" + computergroupid , headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})

# iterate through imported data to get IDs
computerlist=[]
for profile in json.loads(response.text)['computer_group']['computers']:
	computerlist.append(profile['id'])
	
# iterate through device IDs
print (str(len(computerlist)) + " Computers:")
print()
for index,computerid in enumerate(computerlist,start=1):
  
	# reset policydata
	policydata = []
  
	# get info for the user into a dictionary
	responseurl = jamfurl + "/JSSResource/computerhistory/id/" + str(computerid) + "/subset/General&PolicyLogs"
	response = requests.get(url=responseurl, headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
	computerdictionary=json.loads(response.text)

	# print name of computer
	print(str(computerdictionary["computer_history"]["general"]["name"]) + ":")

	#iterate through policies for computer
	for policy in computerdictionary["computer_history"]["policy_logs"]:

	# if policy new to list and completed, add it to policydata
		if policy['status'] == "Completed" and policydata.count(policy["policy_name"]) == 0:
			policydata.append(policy["policy_name"])
	
	#sort and print nicely policydata
	policydata.sort()
	for policy in policydata:
		print ("   " + policy)
	print()
		
	# if less than 5 minutes left, invalidate token and get a new one
	if index % 25 == 0:
		if (tokenexpiration-datetime.utcnow()).total_seconds() < 600:
			invalidatetoken()
			token,tokenexpiration = fetchtoken()

invalidatetoken()
