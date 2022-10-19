#!/bin/bash
#Matthew Prins 2022
#https://github.com/MatthewPrins/Jamf/

#Upload CSV to Inventory Preload via API

###########################

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

#file path for CSV
csvfile="testfile.csv"

###########################

#Token function -- based on https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview
getBearerToken() {
	response=$(curl -s -u "$username":"$password" "$url"/api/v1/auth/token -X POST)
	bearerToken=$(echo "$response" | plutil -extract token raw -)
	tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
	tokenExpirationEpoch=$(date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s")
}

#get token
getBearerToken 

#post CSV file to inventory preload
curl --request POST \
--silent \
--url $url/api/v2/inventory-preload/csv \
--header 'accept: application/json' \
--header 'content-type: multipart/form-data' \
--header "Authorization: Bearer $bearerToken" \
--form "file=@$csvfile"

echo "done"
