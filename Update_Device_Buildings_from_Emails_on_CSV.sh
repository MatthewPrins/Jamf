#!/bin/bash
#Matthew Prins 2022
#https://github.com/MatthewPrins/Jamf/

#Update devices' buildings based on emails in a CSV file 

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

#Group ID number -- found in URL on group's page
groupid="1"

#path of CSV file
#CSV file should have two columns --  first email, second building
CSVfile="xxxxxx.csv"

#Token function -- from https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview
getBearerToken() {
	response=$(curl -s -u "$username":"$password" "$url"/api/v1/auth/token -X POST)
	bearerToken=$(echo "$response" | plutil -extract token raw -)
	tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
	tokenExpirationEpoch=$(date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s")
}

#input CSV to two arrays
while IFS=',' read -ra array; do
	emailarray+=("${array[0]}")
	buildingarray+=("${array[1]}")
done < $CSVfile

echo "${#emailarray[@]} lines in CSV file"

#get token
getBearerToken 

grouptype="mobiledevicegroups"
pathtype="mobile_device"
pathtypeapp="mobile_device"
JSSpathtype="mobiledevices"

#pull XML data from Jamf, change it to a list

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

versionlist=()
counter=0

for value in $devices
do
	#curl: retrieve all device XML data from the current ID
	#xmllint: from that XML, pull the email field
	
	deviceemail=$(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
		$url/JSSResource/mobiledevices/id/$value \
		| xmllint --xpath "//mobile_device/location/email_address/text()" 2>/dev/null - )

	#iterate through email array to see if $deviceemail is there; if is, pull building
	i=0
	newbuilding=""
	while [ $i -le ${#emailarray[@]} ]
	do
		if [[ ${emailarray[i]} == $deviceemail ]]
		then
			newbuilding=${buildingarray[i]}
		fi
		i=$(($i+1))
	done
	
	#convert buildings to building IDs -- found in URLs for buildings in Jamf
	if [[ $newbuilding != "" ]]; then
		if [[ "$newbuilding" == "AAA"]]; then
			newbuilding="1"
		elif [[ "$newbuilding" == "BBB"* ]]; then
			newbuilding="2"
		elif [[ "$newbuilding" == "CCC"* ]]; then
			newbuilding="55"
    #if not found, don't change
    else
      newbuilding=""
	fi
			
	#if $newbuilding exists, write building to Jamf	
	if [[ $newbuilding != "" ]]; then
    curl --silent \
		  --request PATCH \
		  --URL $url/api/v2/mobile-devices/$value \
		  --header "Authorization: Bearer $bearerToken" \
		  --header 'Accept: application/json' \
		  --header 'Content-Type: application/json' \
		  --data '{"location": {"buildingId": "'"$newbuilding"'"}}' \
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
