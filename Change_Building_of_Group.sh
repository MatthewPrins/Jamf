#!/bin/bash
#Matthew Prins 2023
#https://github.com/MatthewPrins/Jamf/

#Change members of a computer/mobile device group to specific building

###########################
#Editable variables

#Jamf credentials
#or import variables by using source credentials.sh
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

#ID number of group pulling from -- found in URL on group's page
groupid="1234"

#computers or mobile devices -- if $computers is true then computers, if false then mobile devices
computers=false

#ID group of new building -- found in Settings/Network/Buildings
newbuildingid="1234"

############################

#Token function -- from https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview
getBearerToken() {
	response=$(curl -s -u "$username":"$password" "$url"/api/v1/auth/token -X POST)
	bearerToken=$(echo "$response" | plutil -extract token raw -)
	tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
	tokenExpirationEpoch=$(date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s")
}

#get token
getBearerToken 

#get path for computer or devices
if [[ $computers = true ]]; then
	grouptype="computergroups"
	pathtype="computer"
	apipathtype="v1/computers-inventory-detail"
	locationtype="userAndLocation"
else
	grouptype="mobiledevicegroups"
	pathtype="mobile_device"
	apipathtype="v2/mobile-devices"
	locationtype="location"
fi

#pull XML data from Jamf, change it to a csv list

#curl: pull XML data based on group ID
#xmllint: keep only the IDs from the XML (e.g. <id>456</id>)
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

counter=0

for value in $devices
do
	#update devices via PATCH request
	curl --silent \
	--request PATCH \
	--URL $url/api/$apipathtype/$value \
	--header "Authorization: Bearer $bearerToken" \
	--header 'Accept: application/json' \
	--header 'Content-Type: application/json' \
	--data '{"'"$locationtype"'": {"buildingId": "'"$newbuildingid"'"}}' \
	--output /dev/null
	
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
echo $counter /$numberDevices
