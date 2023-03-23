#!/bin/bash
#Matthew Prins 2023
#https://github.com/MatthewPrins/Jamf/

#Add to static group based on CSV file 

#-------------------
#Editable variables

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

#path of CSV file
#CSV file should have one column of serials
CSVfile="xxxxxx.csv"

#type of smart group: $typegroup can be "computer" or "device"
typegroup="device"

#number of mobile device static group -- get from URL
staticgroup="1234"
#-------------------

#Token function -- from https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview
getBearerToken() {
	response=$(curl -s -u "$username":"$password" "$url"/api/v1/auth/token -X POST)
	bearerToken=$(echo "$response" | plutil -extract token raw -)
	tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
	tokenExpirationEpoch=$(date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s")
}

#get path for computer or devices
if [[ $typegroup = "computer" ]]; then
	grouptype="computergroups"
	pathtype="computer"
elif [[ $typegroup = "device" ]]; then
	grouptype="mobiledevicegroups"
	pathtype="mobile_device"
fi

#input CSV to two arrays
while IFS=',' read -ra array; do
	serialarray+=("${array[0]}")
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
groupaddlist=""

for value in ${!serialarray[@]}
do
	#tr bit to get rid of special characters
	serial=$(echo ${serialarray[$value]} | tr -d '[:cntrl:]')
	
	id=$(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
	$url/JSSResource/mobiledevices/serialnumber/$serial/subset/General \
	| xmllint --xpath "//mobile_device/general/id" - 2> /dev/null \
	| sed 's/<id>//g' \
	| sed 's/<\/id>/ /g' \
	| sed 's/.$//')

	#if serial found then add
	if [[ $id != "" ]]
	then
		groupaddlist="$groupaddlist<$pathtype><id>$id</id></$pathtype>"
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

echo $numberDevices / $numberDevices
echo updating...
echo $groupaddlist

#send PUT command to Jamf to update group membership
curl --silent \
--request PUT \
--url $url/JSSResource/$grouptype/id/$staticgroup \
--header "Authorization: Bearer $bearerToken" \
--header 'Accept: application/xml' \
--header 'Content-Type: application/xml' \
--data "<"$pathtype"_group><"$pathtype"_additions>$groupaddlist</"$pathtype"_additions></"$pathtype"_group>" 
echo "done"
