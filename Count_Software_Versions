#!/bin/bash
#Matthew Prins 2022
#https://github.com/MatthewPrins/Jamf/

#Count number of computers or devices on a particular version of a given app

#Code for grabbing token from https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

#Group ID number -- found in URL on group's page
groupid="13"

#computers or mobile devices -- if computers is true then computers, if false then mobile devices
computers=true

#app that's version is being counted -- exact name in Jamf (INCLUDE .app extension for computers)
app="8x8 Work.app"

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
	pathtypeapp="computer/software"
	JSSpathtype="computers"
else
	grouptype="mobiledevicegroups"
	pathtype="mobile_device"
	pathtypeapp="mobile_device"
	JSSpathtype="mobiledevices"
fi

#pull XML data from Jamf, change it to a list

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

versionlist=()
counter=0

for value in $devices
do
	#curl: retrieve all device XML data from the current ID
	#xmllint: from that XML, pull the Applications fields
	
	deviceapps=$(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
		$url/JSSResource/$JSSpathtype/id/$value \
		| xmllint --xpath "//$pathtypeapp/applications/application" 2>/dev/null - )

	#if app is in the deviceapps list, then pull the version number

	if [[ $computers = true ]]
	then
		#computer version
		if [[ "$deviceapps" == *"<name>$app</name>"* ]]
		then
			#1st sed: delete everything up to and including the app name
			#2nd sed: if no app version, delete all and replace with "unlisted"
			#3rd sed: delete everything after the version number
			#4th sed: delete everything before the version number
			versionlist+=($(echo $deviceapps \
				| sed "s/.*<name>$app<\/name>//" \
				| sed "s/<version\/>.*/unlisted/" \
				| sed "s/<\/version>.*//" \
				| sed "s/.*<version>//"))
		else
			versionlist+=("app not present")
		fi
	else
		#mobile app version
		if [[ "$deviceapps" == *"<application_name>$app</application_name>"* ]]
		then	
			#1st sed: delete everything up to and including the app name
			#2nd sed: if no app version, delete all and replace with "unlisted"
			#3rd sed: delete everything after the version number
			#4th sed: delete everything before the version number
			versionlist+=($(echo $deviceapps \
				| sed "s/.*<application_name>$app<\/application_name>//" \
				| sed "s/<application_version\/>.*/unlisted/" \
				| sed "s/<\/application_short_version>.*//" \
				| sed "s/.*<application_short_version>//"))
		else
			versionlist+=("app not present")
		fi
	fi
	
	#print status every 10
	let "counter+=1" 
	if [[ $(expr $counter % 10) = "0" ]]
	then
		echo $counter /$numberDevices
	fi
done
echo

#count unique members and echo, from https://stackoverflow.com/questions/49263599/count-unique-values-in-a-bash-array

(IFS=$'\n'; sort <<< "${versionlist[*]}") | uniq -c
