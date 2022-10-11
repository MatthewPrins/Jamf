#!/bin/bash
# Matthew Prins 2022
# https://github.com/MatthewPrins/Jamf/

# Mobile device emails change to username

# Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

# Group ID number -- found in URL on group's page
groupid="123"

# Token function -- from https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview
getBearerToken() {
	response=$(curl -s -u "$username":"$password" "$url"/api/v1/auth/token -X POST)
	bearerToken=$(echo "$response" | plutil -extract token raw -)
	tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
	tokenExpirationEpoch=$(date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s")
	echo "New bearer token"
}

# get token
getBearerToken

# pull XML data from Jamf, change it to a list
# curl: pull XML data based on group ID
# xmllint: keep only the mobile device IDs from the XML (e.g. <id>456</id>)
# 1st sed: delete "<id>"s
# 2nd sed: replace "</id>"s with spaces
# 3rd sed: delete extra final space

devices=$(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
	$url/JSSResource/mobiledevicegroups/id/$groupid \
	| xmllint --xpath "//mobile_device/id" - \
	| sed 's/<id>//g' \
	| sed 's/<\/id>/ /g' \
	| sed 's/.$//')

# iterate over the IDs in this device group
for value in $devices
do
	
	# retrieve all device XML data from the current ID
	xmldata=$(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
		$url/JSSResource/mobiledevices/id/$value)

	# pull username and email
	jamfusername=$(echo $xmldata | xmllint --xpath "//username/text()" - 2>/dev/null)
	email=$(echo $xmldata | xmllint --xpath "//email_address/text()" - 2>/dev/null)
	
	# if $jamfusername and $email don't match, change email to $username
	if [[ $jamfusername != $email ]]; then		
		curl --silent \
			--request PATCH \
			--URL $url/api/v2/mobile-devices/$value \
			--header "Authorization: Bearer $bearerToken" \
			--header 'Accept: application/json' \
			--header 'Content-Type: application/json' \
			--data '{"location": {"emailAddress":"'"$jamfusername"'"}}' \
			--output /dev/null
		echo $email "changed to" $jamfusername
	fi
done
