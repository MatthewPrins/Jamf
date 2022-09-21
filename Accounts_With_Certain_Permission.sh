#!/bin/bash
#Matthew Prins 2022
#https://github.com/MatthewPrins/Jamf/

#List Jamf Pro accounts with a specific permission

#Jamf credentials
username="xxxxxx"
password="xxxxxx"
url="https://xxxxxx.jamfcloud.com"

#specific permission looking for -- first letter capital, many start with Read, Create, Delete, or Update
#examples: Update Computer Enrollment Invitations, Create Advanced Mobile Device Searches, Enable Disk Encryption Configurations Remotely
permission="Update Mobile Device Enrollment Invitations"

#Token function -- based on https://developer.jamf.com/jamf-pro/docs/jamf-pro-api-overview
getBearerToken() {
	response=$(curl -s -u "$username":"$password" "$url"/api/v1/auth/token -X POST)
	bearerToken=$(echo "$response" | plutil -extract token raw -)
	tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
	tokenExpirationEpoch=$(date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s")
}

#get token
getBearerToken 

#pull XML data from Jamf, change it to a csv list

#curl: pull XML data for all accounts
#xmllint: keep only the account IDs from the XML (e.g. <id>456</id>)
#1st sed: delete "<id>"s
#2nd sed: replace "</id>"s with spaces
#3rd sed: delete extra final space

accounts=$(curl --silent \
	--request GET \
	--url $url/JSSResource/accounts \
	--header "Authorization: Bearer $bearerToken" \
	--header 'accept: application/xml' \
	| xmllint --xpath "//user/id" - \
	| sed 's/<id>//g' \
	| sed 's/<\/id>/ /g' \
	| sed 's/.$//')

#get total count of devices -- counting the number of "words" in $devices
numberaccounts=$(echo -n "$accounts" | wc -w)

echo $numberaccounts accounts
echo 
echo Accounts with $permission permissions:
echo

#iterate over all accounts
for value in $accounts; do

	#GET account $value info from API
	accountprivileges=$(curl --silent \
		--request GET \
		--url $url/JSSResource/accounts/userid/$value \
		--header "Authorization: Bearer $bearerToken" \
		--header 'Accept: application/xml' \
		--header 'Content-Type: application/xml')
	
	if [[ $accountprivileges == *"<privilege>$permission</privilege>"*  ]]; then
		echo $accountprivileges | xmllint --xpath "//account/name/text()" -
		echo -n " (" 
		echo $accountprivileges | xmllint --xpath "//account/full_name/text()" 2>/dev/null -
		echo ")" 
	fi
	
done

echo
echo "done"
