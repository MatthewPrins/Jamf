#!/bin/bash
#Matthew Prins 2023
#https://github.com/MatthewPrins/Jamf/

#Update and enforce mobile device names based on CSV file 

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

#path of CSV file
#CSV file should have two columns --  first serials, second device names
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
	serialarray+=("${array[0]}")
	namearray+=("${array[1]}")
done < $CSVfile

echo "${#serialarray[@]} lines in CSV file"

#get token
getBearerToken 

#get total count of devices 
numberDevices=${#serialarray[@]}

echo 
echo 0 / $numberDevices

#iterate over serials in CSV

counter=0

for value in ${!serialarray[@]}
do
	serial=${serialarray[$value]}
	name=$(echo ${namearray[$value]} | tr -d '[:cntrl:]')
	
	
	id=$(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
	$url/JSSResource/mobiledevices/serialnumber/$serial/subset/General \
	| xmllint --xpath "//mobile_device/general/id" - 2> /dev/null \
	| sed 's/<id>//g' \
	| sed 's/<\/id>/ /g' \
	| sed 's/.$//')
	
	#update if id is not blank
	
	if [[ $id != "" ]]
	then
		curl --request PATCH \
		--header "Authorization: Bearer ${bearerToken}" \
		--silent \
		--url $url/api/v2/mobile-devices/$id \
		--header 'accept: application/json' \
		--header 'content-type: application/json' \
		--data '{"name": "'"$name"'", "enforceName": true}' \
		--output /dev/null
		
		echo $serial "changed to" $name
	fi
	
	#print status every 10
	let "counter+=1" 
	if [[ $(expr $counter % 10) = "0" ]]
	then
		echo $counter / $numberDevices
	fi

	#reset token every 1000
	if [[ $(expr $counter % 1000) = "0" ]]
	then
		getBearerToken
	fi

done
