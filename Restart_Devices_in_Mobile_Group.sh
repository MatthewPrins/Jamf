#!/bin/bash
#Matthew Prins 2023
#https://github.com/MatthewPrins/Jamf/

#Restart all items in a particular mobile group in Jamf

#Minimum permissions:
	#Objects:
		#Mobile Devices (Create, Read)
		#Smart Mobile Device Groups (Read)
		#Static Mobile Device Groups (Read)
	#Actions
		#Send Mobile Device Restart Device Command

#Code for getting token from https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

#Group ID number -- found in URL on group's page
groupid="44"

#Token variable declarations
bearerToken=""
tokenExpirationEpoch="0"

getBearerToken() {
	response=$(curl -s -u "$username":"$password" "$url"/api/v1/auth/token -X POST)
	bearerToken=$(echo "$response" | plutil -extract token raw -)
	tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
	tokenExpirationEpoch=$(date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s")
}

checkTokenExpiration() {
	nowEpochUTC=$(date -j -f "%Y-%m-%dT%T" "$(date -u +"%Y-%m-%dT%T")" +"%s")
	if [[ tokenExpirationEpoch -gt nowEpochUTC ]]
	then
		echo "Token valid until the following epoch time: " "$tokenExpirationEpoch"
	else
		echo "No valid token available, getting new token"
		getBearerToken
	fi
}

#get token
checkTokenExpiration

#pull XML data from Jamf, change it to a csv list

#curl: pull XML data based on group ID
#xmllint: keep only the mobile device IDs from the XML (e.g. <id>456</id>)
#tr: delete whitespace
#1st sed: delete "<id>"s
#2nd sed: replace "</id>"s with commas
#3rd sed: delete extra final comma

echo $(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
	$url/JSSResource/mobiledevicegroups/id/$groupid )

csv=$(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
	$url/JSSResource/mobiledevicegroups/id/$groupid \
	| xmllint --xpath "//mobile_device/id" - \
	| tr -d '[:space:]' \
	| sed 's/<id>//g' \
	| sed 's/<\/id>/,/g' \
	| sed 's/.$//')

#Restart all devices in csv list

curl -s -X POST -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
$url/JSSResource/mobiledevicecommands/command/RestartDevice/id/$csv
