#!/bin/bash
#Matthew Prins 2022
#https://github.com/MatthewPrins/Jamf/

#Find all devices or computers assigned at some point to a particular user

######################

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"
source credentials.sh

#computers or mobile devices -- if $computers is true then computers, if false then mobile devices
computers=false

#email for user searching for
useremail="xxxxxx@xxxxxx.org"

######################

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
	pathtype="computer"
	JSSpathtype="computers"
	xpathtype="computer_history"
	urltype="computerhistory"
else
	pathtype="mobile_device"
	JSSpathtype="mobiledevices"
	xpathtype="mobile_device_history"
	urltype="mobiledevicehistory"
fi

#pull XML data from Jamf, change it to a list

#curl: pull XML data based on group ID
#xmllint: keep only the mobile device IDs from the XML (e.g. <id>456</id>)
#1st sed: delete "<id>"s
#2nd sed: replace "</id>"s with spaces
#3rd sed: delete extra final space

devices=$(curl --request GET \
	--silent \
	--url $url/JSSResource/$JSSpathtype \
	--header 'Accept: application/xml' \
	--header "Authorization: Bearer ${bearerToken}" \
	| xmllint --xpath "//$pathtype/id" - \
	| sed 's/<id>//g' \
	| sed 's/<\/id>/ /g' \
	| sed 's/.$//')

#get total count of devices -- counting the number of "words" in $devices
numberDevices=$(echo -n "$devices" | wc -w)

echo $numberDevices Devices
echo 
echo 0 /$numberDevices

#iterate over the IDs

idarray=()
xmlarray=()
counter=0

#shopt -s lastpipe makes last command in the pipeline execute in current shell
#necessary for the for/do pipe to save variables to array
shopt -s lastpipe

for value in $devices
do
	#pull history for device $value
	#curl: retrieve all device UserLocation History XML data from the current ID
	#xmllint: from that XML, pull the Location fields
	#1st sed: delete any <location>
	#2nd sed: delete any </location>, replace with line break
	#while/do: read each line; if email address matches then save line to $xmlarray and ID to $idarray
	
	curl --request GET \
		--silent \
		--url $url/JSSResource/$urltype/id/$value/subset/UserLocation \
		--header 'Accept: application/xml' \
		--header "Authorization: Bearer ${bearerToken}" \
		| xmllint --xpath "//$xpathtype/user_location/location" - \
		| sed 's/<location>//g' \
		| sed 's/<\/location>/\n/g' \
		| while IFS= read -r line; do if [[ $line == *"<email_address>$useremail</email_address>"* ]]; then xmlarray+=("$line"); idarray+=("$value"); fi; done
		
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

echo
echo "ID,date"

#iterate through $xmlarray/$idarray
#seds: delete everything before/after date_time_utc field
#0:10 in echo: only print the first 10 characters of that field (date only)

for i in $(seq 0 $((${#idarray[@]}-1))); do 
	devicedate=$(echo "${xmlarray[i]}" \
		| sed 's/.*<date_time_utc>//g' \
		| sed 's/<\/date_time_utc>.*//g' )
	echo ${idarray[i]},${devicedate:0:10}
done
