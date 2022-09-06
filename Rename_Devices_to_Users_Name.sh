#!/bin/bash

#!/bin/bash
#Matthew Prins 2022 mdprins@gmail.com

#Rename devices to user's name in a Jamf device group 

#Token portion of code based on https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview
#URL encoding function from https://gist.github.com/cdown/1163649

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

#Group ID number -- found in URL on group's page
groupid="xxxxxx"

#Additional text for the device name -- delete if none needed
additionaltext="iPhone 12"

#Enforce device name -- set to false if you do not want that enforced
enforcedevicename=true

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
	echo $value
	
	#curl: retrieve all device XML data from the current ID
	#xmllint: from that XML, pull the Real Name field
	
	realname=$(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
		$url/JSSResource/mobiledevices/id/$value \
		| xmllint --xpath "//real_name/text()" - )
	
	echo $realname
	
	#add additional text to new name if any
	if [[ -z $additionaltext ]]
	then
		newname=$realname
	else
		newname="$realname $additionaltext"
		echo $newname
	fi
	
	#rename mobile device with $newname
	#urlencode to make $newname URL compliant
	
	curl --silent \
	--request PATCH \
	--URL $url/api/v2/mobile-devices/$value \
	--header "Authorization: Bearer $bearerToken" \
	--header 'Accept: application/json' \
	--header 'Content-Type: application/json' \
	--data '{"name":"'"$newname"'","enforceName":"'"$enforcedevicename"'"}'
done
