#!/bin/bash
#Matthew Prins 2022
#https://github.com/MatthewPrins/Jamf/

#Choose x random members of a computer/device/user smart group as a static group

###########################
#Editable Variables

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

#input group ID number for input -- found in URL on group's page
inputgroupid="93"

#output Static Group ID number for output
outputgroupid="99"

#type of smart group: $typegroup can be "user", "computer", or "device"
typegroup="device"

#number of random members to choose -- make sure smaller than input group
randommembers=500

############################

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
if [[ $typegroup = "computer" ]]; then
	grouptype="computergroups"
	pathtype="computer"
elif [[ $typegroup = "user" ]]; then	
	grouptype="usergroups"
	pathtype="user"
elif [[ $typegroup = "device" ]]; then
	grouptype="mobiledevicegroups"
	pathtype="mobile_device"
fi

#pull XML data from Jamf, change it to a csv list

#curl: pull XML data based on group ID
#xmllint: keep only the mobile device IDs from the XML (e.g. <id>456</id>)
#1st sed: delete "<id>"s
#2nd sed: replace "</id>"s with spaces
#3rd sed: delete extra final space

devices=$(curl -s -H "Authorization: Bearer ${bearerToken}" "Accept: application/xml" \
	$url/JSSResource/$grouptype/id/$inputgroupid \
	| xmllint --xpath "//$pathtype/id" - \
	| sed 's/<id>//g' \
	| sed 's/<\/id>/ /g' \
	| sed 's/.$//')

#get total count of devices -- counting the number of "words" in $devices
numberDevices=$(echo -n "$devices" | wc -w)

echo $numberDevices Devices
echo 

#put devices into array
devicesarray=()
randomarray=()
for value in $devices; do
	devicesarray+=("$value")
done

#get random devices/computers/users
while [[ ${#randomarray[@]} -lt $randommembers ]]; do
	randomadd=${devicesarray[$(($RANDOM%${#devicesarray[@]}))]}
	
	#if not already added to $randomarray, add it
	if [[ ! " ${randomarray[@]} " =~ " $randomadd " ]]; then
		randomarray+=("$randomadd")
	fi
done

echo importing ${#randomarray[@]} random devices
echo
echo 0 / ${#randomarray[@]}

#iterate over the IDs in this device group

groupaddlist=""
counter=0

#add proper xml to $groupaddlist for device
for value in ${randomarray[@]}; do
	groupaddlist="$groupaddlist<$pathtype><id>$value</id></$pathtype>"
	
	#print status every 50
	let "counter+=1" 
	if [[ $(expr $counter % 50) = "0" ]]
	then
		echo $counter / ${#randomarray[@]}
	fi

done
echo ${#randomarray[@]} / ${#randomarray[@]}
echo updating...

#send PUT command to Jamf to update group membership
curl --silent \
	--request PUT \
	--url $url/JSSResource/$grouptype/id/$outputgroupid \
	--header "Authorization: Bearer $bearerToken" \
	--header 'Accept: application/xml' \
	--header 'Content-Type: application/xml' \
	--data "<"$pathtype"_group><"$pathtype"_additions>$groupaddlist</"$pathtype"_additions></"$pathtype"_group>" \
	--output /dev/null

echo "done"
