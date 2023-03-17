#!/bin/bash

#Remove admin privileges for all users on a computer except those listed
#Must be run as root

#users to keep as admin -- editable
keepadminarray=("root" "admintokeep1" "admintokeep2" "admintokeep3")

#get admin users
adminUsers=$(dscl . -read Groups/admin GroupMembership | cut -c 18-)

echo "Admin users:" $adminUsers

#make all others users Standard
for user in $adminUsers
do
	if [[ " ${keepadminarray[*]} " =~ " $user " ]];
	then
		echo "Admin user $user left alone"
	else
		dseditgroup -o edit -d $user -t user admin
		if [ $? = 0 ]; then echo "Removed user $user from admin group"; fi
	fi
done
