#!/bin/bash
#Matthew Prins 2022
#https://github.com/MatthewPrins/Jamf/

#Reinstalls Jamf Management Framework on every computer in a group

###########################

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"
source credentials.sh

#Group ID number -- found in URL on computer group's page
groupid="33"

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

#pull XML data from Jamf, change it to a list

#curl: pull XML data based on group ID
#xmllint: keep only the mobile device IDs from the XML (e.g. <id>456</id>)
#1st sed: delete "<id>"s
#2nd sed: replace "</id>"s with spaces
#3rd sed: delete extra final space

devices=$(curl --request GET \
	--silent \
	--url $url/JSSResource/computergroups/id/$groupid \
	--header 'Accept: application/xml' \
	--header "Authorization: Bearer ${bearerToken}" \
	| xmllint --xpath "//computer/id" - \
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
	#redeploy Jamf management framework for $value
	curl --request POST \
	--silent \
	--url $url/api/v1/jamf-management-framework/redeploy/$value \
	--header 'accept: application/json' \
	--header "Authorization: Bearer $bearerToken" \
	--output /dev/null
	
	#print status every 10
	let "counter+=1" 
	if [[ $(expr $counter % 10) = "0" ]]
	then
		echo $counter /$numberDevices
	fi
	
	#reset token every 500
	if [[ $(expr $counter % 500) = "0" ]]
	then
		getBearerToken
	fi
	
done
echo $numberDevices /$numberDevices
