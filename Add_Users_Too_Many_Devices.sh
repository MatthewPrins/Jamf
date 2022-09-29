#!/bin/bash
#Matthew Prins 2022
#https://github.com/MatthewPrins/Jamf/

#Adds users to static group with more/less than x computers/devices 

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

#computers or mobile devices -- if $computers is true then looking for computers, if false then mobile devices
computers=true

#number of devices/computers for a user
#if $greaterthan=true, putting all any user above $maxmindevices in static group; if $greaterthan=false, anything below
maxmindevices=1
greaterthan=true

#user group pulling users from -- if pulling all users set groupid=0
groupid=6

#Static user group to add users to
outputgroupid=7

#############################

#Token function -- from https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview
getBearerToken() {
	response=$(curl -s -u "$username":"$password" "$url"/api/v1/auth/token -X POST)
	bearerToken=$(echo "$response" | plutil -extract token raw -)
	tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
	tokenExpirationEpoch=$(date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s")
}

#get token
getBearerToken 

#set curl url based on group ID (or lack thereof)
if [[ $groupid != "0" ]]; then
	grouppath="usergroups/id/$groupid"
else
	grouppath="users"
fi

#set XML path for computers/devices
if [[ $computers == true ]]; then
	xmlpath="//computer/id"
else
	xmlpath="//mobile_device/id"
fi

#pull XML data from Jamf, change it to a list

#curl: pull XML data based on user group ID
#xmllint: keep only the IDs from the XML (e.g. <id>456</id>)
#1st sed: delete "<id>"s
#2nd sed: replace "</id>"s with spaces
#3rd sed: delete extra final space

userslist=$(curl --request GET \
	--silent \
	--url $url/JSSResource/$grouppath \
	--header 'Accept: application/xml' \
	--header "Authorization: Bearer ${bearerToken}" \
	| xmllint --xpath "//user/id" - \
	| sed 's/<id>//g' \
	| sed 's/<\/id>/ /g' \
	| sed 's/.$//')

#get total count of devices -- counting the number of "words" in $userslist
numberusers=$(echo -n "$userslist" | wc -w)

echo $numberusers Users Inputted
echo 
echo 0 /$numberusers

#iterate over the IDs of the users

counter=0
addcounter=0
groupaddlist=""

for value in $userslist
do
	#curl: retrieve all user XML data from the current ID
	#xmllint: from that XML, pull the mobile devices/computers field
	#1st sed: delete "<id>"s
	#2nd sed: replace "</id>"s with spaces
	#3rd sed: delete extra final space
	#wc: count "words" in list, i.e. number of devices
	
	devicecount=$(curl --request GET \
		--silent \
		--url $url/JSSResource/users/id/$value \
		--header 'Accept: application/xml' \
		--header "Authorization: Bearer ${bearerToken}" \
		| xmllint --xpath "$xmlpath" 2>/dev/null - \
		| sed 's/<id>//g' \
		| sed 's/<\/id>/ /g' \
		| sed 's/.$//' \
		| wc -w)
	
	#if user meets criteria add XML to $groupaddlist
	if [[ $greaterthan = true ]]; then
		if [[ $devicecount -gt $maxmindevices ]]; then
			groupaddlist="$groupaddlist<user><id>$value</id></user>"
			let "addcounter+=1" 
		fi
	else
		if [[ $devicecount -lt $maxmindevices ]]; then
			groupaddlist="$groupaddlist<user><id>$value</id></user>"
			let "addcounter+=1" 
		fi
	fi

	#print status every 10
	let "counter+=1" 
	if [[ $(expr $counter % 10) = "0" ]]
	then
		echo $counter /$numberusers
	fi
	
	#reset token every 500
	if [[ $(expr $counter % 500) = "0" ]]
	then
		getBearerToken
	fi
done

echo $numberusers /$numberusers
echo
echo $addcounter users that meet criteria
echo 
echo updating static group...

#send PUT command to Jamf to update group membership
curl --silent \
--request PUT \
--url $url/JSSResource/usergroups/id/$outputgroupid \
--header "Authorization: Bearer $bearerToken" \
--header 'Accept: application/xml' \
--header 'Content-Type: application/xml' \
--data "<user_group><user_additions>$groupaddlist</user_additions></user_group>" \
--output /dev/null

echo "done"
