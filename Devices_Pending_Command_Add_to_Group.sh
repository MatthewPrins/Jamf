#!/bin/bash
#Matthew Prins 2022
#https://github.com/MatthewPrins/Jamf/

#Mobile devices with a specific pending command -- add to static group

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

#ID number of group PULLING FROM -- found in URL on group's page
groupid="72"

#ID number of static group ADDING TO
addedstaticgroup="73"

#pending command being looked for -- exact name in Jamf
pendingcommand="Install App - Google Chrome"

#Bearer token function -- from https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview
getBearerToken() {
	response=$(curl -s -u "$username":"$password" "$url"/api/v1/auth/token -X POST)
	bearerToken=$(echo "$response" | plutil -extract token raw -)
	tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
	tokenExpirationEpoch=$(date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s")
	echo "New bearer token"
}

#get token
getBearerToken 

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

#get total count of devices -- counting the number of "words" in $devices
numberDevices=$(echo -n "$devices" | wc -w)

echo $numberDevices Devices
echo 
echo 0 /$numberDevices

#iterate over the IDs in this device group

pendinglist=()
counter=0

for value in $devices
do
	#curl: retrieve all device XML data from the current ID
	#xmllint: from that XML, pull the pending commands
	#1st sed: delete "<name>"s
	#2nd sed: replace "</names>"s with commas
	#3rd sed: delete extra final comma
	
	pendingdevice=$(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
		$url/JSSResource/mobiledevicehistory/id/$value/subset/ManagementCommands \
		| xmllint --xpath "//mobile_device_history/management_commands/pending/command/name" 2>/dev/null - \
		| sed 's/<name>//g' \
		| sed 's/<\/name>/,/g' \
		| sed 's/.$//')
		
	if [[ "$pendingdevice" == *"$pendingcommand"* ]]
	then
		pendinglist+=($value)
		curl --silent \
		--request PUT \
		--URL $url/JSSResource/mobiledevicegroups/id/$addedstaticgroup \
		--header "Authorization: Bearer $bearerToken" \
		--header 'Accept: application/xml' \
		--header 'Content-Type: application/xml' \
		--data "<mobile_device_group><mobile_device_additions><mobile_device><id>$value</id></mobile_device></mobile_device_additions></mobile_device_group>" \
		--output /dev/null
	fi
	
	#print status every 10
	let "counter+=1" 
	if [[ $(expr $counter % 10) = "0" ]]
	then
		echo $counter /$numberDevices
	fi

	#reset token every 1000
	if [[ $(expr $counter % 1000) = "0" ]]
	then
		getBearerToken
	fi

done

#print number of pending commands
echo
echo ${#pendinglist[@]} /$numberDevices have pending command: $pendingcommand
