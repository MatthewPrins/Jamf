#!/usr/bin/env python3
# Matthew Prins 2023
# https://github.com/MatthewPrins/Jamf/

# erase a iOS/iPadOS device while keeping the MDM and wifi profiles on ("Return to Service")
# must be iOS or iPadOS 17 or later and Activation Lock must be disabled

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

# device serial numbers in a list
deviceSerials=["ABCD1234ABCD", "EFGH5678EFGBH"]

# wifi configuration
# create mobile device profile with wifi in Apple Configurator 2,
# then use this command in Terminal to encode it (no brackets): openssl base64 -in [oldfile] -out [newfile]
# then copy the contents of the file below, back-slashing at the end of every line like in the example
wifi="PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPCFET0NUWVBF\
IHBsaXN0IFBVQkxJQyAiLS8vQXBwbGUvL0RURCBQTElTVCAxLjAvL0VOIiAiaHR0\
L2tleT4KCTxhcnJheT4KCQk8ZGljdD4KCQkJPGtleT5BdXRvSm9pbjwva2V5PgoJ\
CQk8dHJ1ZS8+CgkJCTxrZXk+Q2FwdGl2ZUJ5cGFzczwva2V5PgoJCQk8ZmFsc2Uv\
PgoJCQk8a2V5PkRpc2FibGVBc3NvY2lhdGlvbk1BQ1JhbmRvbWl6YXRpb248L2tl\
aW5nPkNvbmZpZ3VyZXMgV2ktRmkgc2V0dGluZ3M8L3N0cmluZz4KCQkJPGtleT5Q\
YXlsb2FkRGlzcGxheU5hbWU8L2tleT4KCQkJPHN0cmluZz5XaS1GaTwvc3RyaW5n\
MEEtQTFFNy03RUJENTM0MEM0RDg8L3N0cmluZz4KCTxrZXk+UGF5bG9hZFZlcnNp\
b248L2tleT4KCTxpbnRlZ2VyPjE8L2ludGVnZXI+CjwvZGljdD4KPC9wbGlzdD4K"

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

#start iterating through serial number list
for serial in deviceSerials:

	#from serial, get mobile device ID of device
	response = requests.get(url=jamfurl + "/JSSResource/mobiledevices/serialnumber/" + str(serial), headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
	jamfid=json.loads(response.text)['mobile_device']['general']['id']

	#from mobile device ID, get device UUID
	response = requests.get(url=jamfurl + "/api/v2/mobile-devices/" + str(jamfid), headers={'Accept': 'application/json','Authorization': 'Bearer ' + token})
	uuid=json.loads(response.text)['managementId']

	#erase device with Return to Service setting
	commandpayload = {"commandData": { "returnToService": { "enabled": True, "wifiProfileData": wifi }, "commandType": "ERASE_DEVICE"}, "clientData": [{ "managementId": uuid }] }	
	response = requests.post(url=jamfurl + "/api/preview/mdm/commands", json=commandpayload, headers={"Accept": "application/json", "content-type": "application/json",'Authorization': 'Bearer ' + token})

	#return success or fail
	try:
		temp=json.loads(response.text)[0]['href']
		print(serial + ": success")
	except:
		print(serial + ": fail")
		print(response.text)

exit()
