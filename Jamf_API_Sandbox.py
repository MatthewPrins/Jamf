#!/usr/bin/env python3
# Matthew Prins 2023
# https://github.com/MatthewPrins/Jamf/

# play with GET requests with the Jamf Pro API

# pip install requests if not already done

import json
import requests
import pprint
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
	print("new token fetched\n")
	return response.json()['token'], datetime.strptime(response.json()['expires'], '%Y-%m-%dT%H:%M:%S.%fZ')

# definition for invalidating API token
def invalidatetoken():	
	response = requests.post(url=jamfurl + "/api/v1/auth/invalidate-token", headers={'Authorization': 'Bearer ' + token})	

############################
	
# fetch API token
token,tokenexpiration = fetchtoken()

#intro
print("Welcome to the Jamf Pro API sandbox!")
print("Only GET requests are supported -- from both the new API and classic API")
print("For paginated endpoints from the new API, the first page of 100 records is shown")
print("Get command info from https://developer.jamf.com/jamf-pro/reference")

#start loop
while True:
	restart = False
	
	#get API input
	print("\nEnter API command URL, excluding the domain")
	print('e.g. "/JSSResource/mobiledevicegroups"')
	APIcommand=str(input())
	
	#restart with blank
	if APIcommand == "":
		print("Error, restarting sandbox\n")
		continue
	
	#make sure slashes are right
	if APIcommand[0] != "/":
		APIcommand = "/" + APIcommand
	if APIcommand[-1] == "/":
		APIcommand = APIcommand [:-1]
	print(APIcommand)

	# if less than 5 minutes left, invalidate token and get a new one		
	if (tokenexpiration-datetime.utcnow()).total_seconds() < 600:
		invalidatetoken()
		token,tokenexpiration = fetchtoken()
	
	#API into dictionary with error handling
	try:
		response = requests.get(jamfurl + APIcommand, headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
		dictionary = json.loads(response.text)
	except:
		print("Error, restarting sandbox\n")
		continue
	
	#print response
	print("\nJSON received:\n")
	pprint.pprint(dictionary)
	
	#start filtering by key logic
	keydir = ""
	while True:
		
		#pick a direction to go
		while True:
			if keydir == "":
				print("\nType F to filter JSON by key, R to restart with a different URL, or Q to quit:")
			else:
				print("\nType F to filter JSON further, K to reset the key filtering, R to restart with a different URL, or Q to quit:")
			letter = str(input())
			if letter == "r" or letter == "R":
				restart = True
				break
			if letter == "q" or letter == "Q":
				exit()
			if letter == "f" or letter == "F":
				filter = True
				break
			if (letter == "k" or letter == "K") and keydir != "":
				keydir = ""
				break

		#go to beginning on restart
		if restart:
			restart = False
			break
	
		#filtering logic
		if filter:
			filter = False
			print("\nEnter key to filter JSON data by:")
			keyinput = str(input())
			keydirold = keydir
			keydir = keydir + "['" + keyinput + "']"
	
		#print JSON data with error handling
		try:
			exec("keyeddictionary = dictionary" + keydir)
			print("\nJSON received:\n")
			pprint.pprint(keyeddictionary)
		except:
			print("Error, resetting key filtering\n")
			keydir = ""
