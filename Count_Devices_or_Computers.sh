#!/bin/bash
#Matthew Prins 2022
#https://github.com/MatthewPrins/Jamf/

#Count number of computers or devices on each OS in a particular group
#Combines iOS/iPadOS/tvOS, so separate them into Jamf groups if that isn't what you want

#Token code based on https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

#Group ID number -- found in URL on group's page
groupid="xxxxxx"

#computers or mobile devices -- if $computers is true then computers, if false then mobile devices
computers=true

#Token variable declarations -- leave alone
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

#get path for computer or devices
if [[ $computers = true ]]; then
	grouptype="computergroups"
	pathtype="computer"
	JSSpathtype="computers"
else
	grouptype="mobiledevicegroups"
	pathtype="mobile_device"
	JSSpathtype="mobiledevices"
fi

#pull XML data from Jamf, change it to a csv list

#curl: pull XML data based on group ID
#xmllint: keep only the mobile device IDs from the XML (e.g. <id>456</id>)
#1st sed: delete "<id>"s
#2nd sed: replace "</id>"s with spaces
#3rd sed: delete extra final space

devices=$(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
	$url/JSSResource/$grouptype/id/$groupid \
	| xmllint --xpath "//$pathtype/id" - \
	| sed 's/<id>//g' \
	| sed 's/<\/id>/ /g' \
	| sed 's/.$//')

#get total count of devices -- counting the number of "words" in $devices
numberDevices=$(echo -n "$devices" | wc -w)

echo $numberDevices Devices
echo 
echo 0 /$numberDevices

#iterate over the IDs in this device group

OSlist=()
counter=0

for value in $devices
do
	#curl: retrieve all device XML data from the current ID
	#xmllint: from that XML, pull the OS Version field
	
	OS=$(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
		$url/JSSResource/$JSSpathtype/id/$value \
		| xmllint --xpath "//os_version/text()" - )
	
	#add to OSlist
	OSlist+=($OS)

	#print status every 10
	let "counter+=1" 
	if [[ $(expr $counter % 10) = "0" ]]
	then
		echo $counter /$numberDevices
	fi
done
echo

#count unique members and echo, from https://stackoverflow.com/questions/49263599/count-unique-values-in-a-bash-array

(IFS=$'\n'; sort <<< "${OSlist[*]}") | uniq -c
