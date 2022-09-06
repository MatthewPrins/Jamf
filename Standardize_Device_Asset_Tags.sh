#!/bin/bash

#!/bin/bash
#Matthew Prins 2022 mdprins@gmail.com

#Standardize Asset Tags -- add leading zero to five-digit asset tags to make them six digits long

#Token code based on https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

#Group ID number -- found in URL on group's page
groupid="xxxxxx"

#Token variable declarations
bearerToken=""
tokenExpirationEpoch="0"

#Token functions
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
#1st sed: delete "<id>"s
#2nd sed: replace "</id>"s with spaces
#3rd sed: delete extra final space

devices=$(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
	$url/JSSResource/mobiledevicegroups/id/$groupid \
	| xmllint --xpath "//mobile_device/id" - \
	| sed 's/<id>//g' \
	| sed 's/<\/id>/ /g' \
	| sed 's/.$//')


#iterate over the IDs in this device group
for value in $devices
do
	echo "ID: "$value

	#reset Asset Tag
	assetTag=""
	
	#curl: retrieve all device XML data from the current ID
	#xmllint: from that XML, pull the Asset Tag field
	
	assetTag=$(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
		$url/JSSResource/mobiledevices/id/$value \
		| xmllint --xpath "//asset_tag/text()" - )
	
	echo "Old Asset Tag: "$assetTag

	#if asset tag is 5 digits, add a leading zero and patch that as the new asset tag
	
	if [[ ${#assetTag} -eq 5 ]]
	then
		assetTag="0"$assetTag
		echo "updated to "$assetTag
		curl --silent \
			--request PATCH \
			--URL $url/api/v2/mobile-devices/$value \
			--header "Authorization: Bearer $bearerToken" \
			--header 'Accept: application/json' \
			--header 'Content-Type: application/json' \
			--data '{"assetTag":"'"$assetTag"'"}' \
			--output /dev/null
	fi

echo
done
