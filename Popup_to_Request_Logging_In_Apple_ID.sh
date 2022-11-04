#!/bin/bash
#Matthew Prins 2022
#https://github.com/MatthewPrins/Jamf/

#Initiates a pop-up requesting a user login with the proper Apple ID on the computer
#Set as policy in Jamf

###########################
#Editable variables

#Domain the Apple ID user should have
correctDomain="@xxxxxx.com"

#Message for user not logged in
notLoggedIn="Please login to your proper Apple ID."

#Message for user logged in to the wrong account
wrongLoggedIn="Please logout of your personal Apple ID and login with your proper Apple ID."

#Title for popup window
title="Apple ID Warning"

#Heading for popup window
heading="Please Note"

###########################

# Get logged-in user
loggedInUser=$(stat -f%Su /dev/console)

# Get iCloud account for logged-in user
icloudaccount=$( defaults read /Users/$loggedInUser/Library/Preferences/MobileMeAccounts.plist Accounts | grep AccountID | cut -d '"' -f 2)

if [[ "$icloudaccount" != *"$correctDomain" ]]
then	
	if [[ "$icloudaccount" == "" ]]
	then
		message="$notLoggedIn"
	else
		message="$wrongLoggedIn"
	fi
	
	#popup message
	"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" -windowType utility -title "$title" -heading "$heading" -description "$message" -button1 "OK"

  #open Apple ID pane in System Preferences	
	open -b com.apple.systempreferences /System/Library/PreferencePanes/AppleIDPrefPane.prefPane
fi
