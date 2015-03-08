#!/bin/bash
#
# -----------------------------------------
# Author: Earl Chery / earl.chery@gmail.com
# -----------------------------------------
#
# -------------------------------------------------
# Description: A Bash shell script to add or remove 
# DNS records without the user knowing the commands 
# to do so.
# -------------------------------------------------
#
#
# -------------------------------------------------------------------
# This script will take the following input from the user:
# --DNS hostname
#	- A, CNAME, PTR records	
# --IP of host
# --TTL for records, otherwise will use the default of 86400 seconds
# --Add or remove host
# -------------------------------------------------------------------

###Variables###

DNS_KEY_LOC=/etc/rndc.key
NSUPDATE_BATCH_FILE=nsupdate.txt
TTL=86400
declare -i DNS_SELECTION
ADD_RECORDS=y
DELETE_RECORDS=y
declare -i START_OVER=1

####Script######

#Check if script is being run as root first
if [ `whoami` != root ]; then
    echo Please run this script as root or using sudo
    exit 
fi

#Start the DNS tool
while [ $START_OVER == '1' ];
	do

	#Get input from the user
	echo " "
	echo "*********************"
	echo "*  DNS Update Tool  *"
	echo "*********************"
	echo " "
	echo " "
	echo "Choose from the following options."
	echo ""
	echo " 1 - Add DNS records "
	echo " 2 - Remove DNS records " 
	echo " "
	echo " "
	echo "Enter Selection: "
	read DNS_SELECTION

	
	#####Add DNS Records######
	if [ $DNS_SELECTION == '1' ]; then
		while [ $ADD_RECORDS == 'y' ];
			do

			echo ""
			echo "What type of record do you want to add?"
			echo " 1 - A record"
			echo " 2 - CNAME record"
			echo " 3 - PTR record"
			echo ""
			echo "Enter Selection: "
			read DNS_RECORD_TYPE

			echo ""
			case $DNS_RECORD_TYPE in
				1)
			 	echo "Adding A Record"
				echo "---------------"
				echo "Enter FQDN: (ex:www.example.com)"
				read DNS_A_RECORD
				echo "Enter IP address:"
				read DNS_IP
				echo "update add $DNS_A_RECORD $TTL A $DNS_IP" 1>>$NSUPDATE_BATCH_FILE
				;;

				2) 
				echo "Adding CNAME Record"
				echo "-------------------"
				echo "Enter CNAME: (ex:www.example.com)"
				read DNS_CNAME_RECORD
				echo "Enter real DNS name: (ex:www1.example.com)"
				read DNS_REAL_CNAME
				echo "update add $DNS_CNAME_RECORD $TTL CNAME $DNS_REAL_CNAME." 1>>$NSUPDATE_BATCH_FILE
				;;

				3)  
				echo "Adding PTR Record"
				echo "-----------------"
				echo "Enter Reverse PTR: (ex:235.1.0.10.in-addr.arpa)"
				read DNS_PTR_RECORD
				echo "Enter FQDN of host to point to: (ex:www1.example.com)"
				read DNS_PTR_HOST
				echo "update add $DNS_PTR_RECORD $TTL PTR $DNS_PTR_HOST." 1>>$NSUPDATE_BATCH_FILE
				;;
			esac

			echo " "
			echo "Add more records? (y/n)"
			read ADDITIONAL_RECORDS

			if [ $ADDITIONAL_RECORDS == 'y' ]; then
				#Send user to the beginning of add records loop
				ADD_RECORDS=y
			else
				echo " "
				echo "Would you like to send your updates now? (y/n)"
				read SEND_UPDATES
				if [ $SEND_UPDATES == 'y' ]; then
					
					#Send the batch update
					echo "send" >> $NSUPDATE_BATCH_FILE
					nsupdate -v -k $DNS_KEY_LOC $NSUPDATE_BATCH_FILE
					if [ "$?" = "0" ]; then
						echo "DNS update sent succesfully"
						echo " "
					else
						echo "DNS update failed"
					fi
					echo ""

					#Remove nsupdate batch file when finished(even if it failed)
					rm $NSUPDATE_BATCH_FILE
					
					exit 0
				else
					#Send user to beginning of main loop
					ADD_RECORDS=n
					START_OVER=1
				fi
			fi
		done


	##Delete DNS Records###
	elif [ $DNS_SELECTION == '2' ]; then
		while [ $DELETE_RECORDS == 'y' ];
			do

			echo ""
			echo "What type of record do you want to delete?"
			echo " 1 - A record"
			echo " 2 - CNAME record"
			echo " 3 - PTR record"
			echo ""
			echo "Enter Selection: "
			read DNS_RECORD_TYPE

			echo ""
			case $DNS_RECORD_TYPE in
				1)
			 	echo "Removing A Record"
				echo "-----------------"
				echo "Enter the FQDN: (ex:www.example.com)"
				read DNS_A_RECORD
				echo "update delete $DNS_A_RECORD A" 1>>$NSUPDATE_BATCH_FILE
				;;

				2) 
				echo "Removing CNAME Record"
				echo "---------------------"
				echo "Enter CNAME: (ex:www1.example.com)"
				read DNS_CNAME_RECORD
				echo "update delete $DNS_CNAME_RECORD CNAME" 1>>$NSUPDATE_BATCH_FILE
				;;

				3)  
				echo "Removing PTR Record"
				echo "-------------------"
				echo "Enter reverse PTR: (ex:231.1.0.0.10.in-addr.arpa)"
				read DNS_PTR_RECORD
				echo "Enter DNS host: (ex:www1.example.com)"
				read DNS_HOST 
				echo "update delete $DNS_PTR_RECORD PTR $DNS_HOST." 1>>$NSUPDATE_BATCH_FILE
				;;
			esac

			echo " "
			echo "Delete more records?  (y/n)"
			read ADDITIONAL_RECORDS

			if [ $ADDITIONAL_RECORDS == 'y' ]; then
				#Send user to the beginning of add records loop
				DELETE_RECORDS=y
			else
				echo " "
				echo "Would you like to send your updates now? (y/n)"
				read SEND_UPDATES
				if [ $SEND_UPDATES == 'y' ]; then
					
					#Send the batch update
					echo "send" >>$NSUPDATE_BATCH_FILE
					nsupdate -v -k $DNS_KEY_LOC $NSUPDATE_BATCH_FILE
					if [ "$?" = "0" ]; then
						echo "DNS update sent succesfully"
					else
						echo "DNS update failed"
					fi
					echo " "
		
					#Remove nsupdate batch file when finished(even if it failed)
					rm $NSUPDATE_BATCH_FILE
					
					exit 0
				else
					#Send user to beginning of main loop
					DELETE_RECORDS=n
					START_OVER=1
				fi
			fi
		done
	fi

done



exit 0

