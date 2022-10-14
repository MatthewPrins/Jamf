#!/bin/bash
#Matthew Prins 2022
#https://github.com/MatthewPrins/Jamf/

#Deletes ALL classes in Jamf 

###########################
#Editable variables

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

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
#curl: pull XML data 
#xmllint: keep only the IDs from the XML (e.g. <id>456</id>)
#1st sed: delete "<id>"s
#2nd sed: replace "</id>"s with spaces
#3rd sed: delete extra final space

classes=$(curl --request GET \
	--silent \
	--url $url/JSSResource/classes \
	--header 'accept: application/xml' \
	--header "Authorization: Bearer ${bearerToken}" \
	| xmllint --xpath "//class/id" - \
	| sed 's/<id>//g' \
	| sed 's/<\/id>/ /g' \
	| sed 's/.$//')

#get total count of classes -- counting the number of "words" in $classes
numberClasses=$(echo -n "$classes" | wc -w)

echo $numberClasses Classes
echo 
echo 0 /$numberClasses

#iterate over the IDs in this device group

counter=0

for value in $classes; do

	#delete class by ID
	curl --request DELETE \
	--silent \
	--url $url/JSSResource/classes/id/$value \
	--header 'accept: application/xml' \
	--header "Authorization: Bearer ${bearerToken}" \
	--output /dev/null
	
	#print status every 10
	let "counter+=1" 
	if [[ $(expr $counter % 2) = "0" ]]
	then
		echo $counter /$numberClasses
	fi
	
	#reset token every 500
	if [[ $(expr $counter % 500) = "0" ]]
	then
		getBearerToken
	fi
	
done
echo all classes deleted
