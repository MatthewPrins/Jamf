#!/bin/bash
#Matthew Prins 2023
#https://github.com/MatthewPrins/Jamf/

#Sums count of each app in device/computer group

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

#Group ID number -- found in URL on group's page
groupid="123"

#computers or mobile devices -- if $computers is true then computers, if false then mobile devices
computers=true

#Token function -- based on https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview
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
	pathtypeapp="application/name"
	JSSpathtype="computers"
	seddevices="name"
else
	grouptype="mobiledevicegroups"
	pathtype="mobile_device"
	pathtypeapp="application_name"
	JSSpathtype="mobiledevices"
	seddevices="application_name"
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

applist=()
counter=0

for value in $devices
do
	#curl: retrieve all device XML data from the current ID
	#xmllint: from that XML, pull the OS Version field
	
	appsdevice=$(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
		$url/JSSResource/$JSSpathtype/id/$value \
		| xmllint --xpath "//$pathtypeapp" - )

	#echo: get rid of newlines 		
	#1st sed: delete any semicolons
	#2nd sed: change "</name> <name>" combo to semicolon
	#3rd sed: delete any <application_name/> (or <name/>)
	#4th sed: delete any <application_name>
	#5th sed: replace any </application_name> with a semicolon
	#last sed: delete the last extra semicolon
		
	appsdevice=$(echo $appsdevice \
		| sed "s/;//g" \
		| sed "s/<\/$seddevices> <$seddevices>/;/g" \
		| sed "s/<$seddevices\/>//g" \
		| sed "s/<$seddevices>//g" \
		| sed "s/<\/$seddevices>/;/g" \
		| sed "s/.$//" )

	#import $appsdevice into the array $apparray
	IFS=';' read -ra apparray <<< "$appsdevice"
	
	for i in "${apparray[@]}"; do
		applist+=("$i")
	done
	
	#print status every 10
	let "counter+=1" 
	if [[ $(expr $counter % 2) = "0" ]]
	then
		echo $counter /$numberDevices
	fi
	
	#reset token every 500
	if [[ $(expr $counter % 500) = "0" ]]
	then
		getBearerToken
	fi
	
done
echo

#count unique members and echo, from https://stackoverflow.com/questions/49263599/count-unique-values-in-a-bash-array

(IFS=$'\n'; sort <<< "${applist[*]}") | uniq -c
