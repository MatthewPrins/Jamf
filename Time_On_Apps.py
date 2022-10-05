#!/usr/bin/env python3

# Show time spent using applications on specific computer in past x days

# pip install requests if not already done

import json
import requests
import datetime

############################
# Editable variables

# Jamf credentials
username="xxxxxx"
password="xxxxxx"
jamfurl="https://xxxxxx.jamfcloud.com"

# Time period to get application data on -- most recent x days
numberofdays = 90

# Computer number to get application data on -- found in URL
computerid = 440

############################

# fetch API token
response = requests.post(url=jamfurl + "/api/v1/auth/token", headers={'Accept': 'application/json'}, auth=(username, password))
token = response.json()['token']

# URL for API call
today=datetime.datetime.now().strftime("%Y-%m-%d")
pastdate=(datetime.datetime.now() - datetime.timedelta(days=numberofdays)).strftime("%Y-%m-%d")
requestsurl = jamfurl + "/JSSResource/computerapplicationusage/id/" + str(computerid) + "/" + pastdate + "_" + today

# import data from API as a dictionary
response = requests.get(url=requestsurl, headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
appdictionary = json.loads(response.text)

#wildcard logic class
class Wildcard:
	def __eq__(self, anything):
		return True

#create applist
applist=[]

# iterate through dates in appdictionary
for datedata in appdictionary['computer_application_usage']:
	# iterate through apps in each date
	for app in datedata['apps']:
		# if app new to list, add it to applist
		if applist.count([app['name'],Wildcard()]) == 0:
			applist.append([app['name'],app['foreground']])
		# otherwise update the number of minutes
		else:
			applist[applist.index([app['name'],Wildcard()])][1]+=app['foreground']

# sort appdata high to low
applist.sort(key = lambda x: x[1], reverse=True)

# print results
for app in applist:
	print(app[0] + ": " + str(app[1]) + " minutes")	
