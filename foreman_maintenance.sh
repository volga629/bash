#!/bin/bash
#
#
##############################################################################
#
# Description:
#
# Foreman manages everything about a host's configuration
# and can initiate restarts of a host. Zabbix doesn't know that Foreman is
# either restarting and updating services on a host. This script is meant to
# link the Foreman process to Zabbix so unwanted notifications about a host
# being down or services becoming unvailable due to Puppet runs are handled
# properly.
#
##############################################################################


## Define all variables this script will use ##


#Foreman Credentials
FOREMAN_USER=''
FOREMAN_PASS=''
FOREMAN_URL='<foreman_url>'

declare -i FOREMAN_HOST_COUNT
FOREMAN_HOST_COUNT=0


#Zabbix Credentials
ZABBIX_AUTH_TOKEN='<zabbix_auth_token>'
ZABBIX_URL='<zabbix_json_rpc_url>'

declare -i ZABBIX_HOST_ID

#Length of time (in seconds) that a host should be declared 'down' in Zabbix.
ZABBIX_TIME_PERIOD=3600

###############################Script######################################
# We should now check Foreman to determine if there are any hosts currently
# being built or updated, then notify Zabbix on any necessary changes.
###########################################################################


# Get a listing of all hosts currently in Foreman and populate into an array
FOREMAN_HOST_OUTPUT=(`curl -s -u $FOREMAN_USER:$FOREMAN_PASS -H "Accept:application/json" $FOREMAN_URL/api/hosts`)
FOREMAN_HOST=(`echo $FOREMAN_HOST_OUTPUT | python -mjson.tool | grep "name" | cut -d ":" -f2  | cut -d "," -f1 | sed 's/"//g'`)


# Loop through the FOREMAN_HOST array and get the status of each host from Foreman, then process further action as needed.
while [ "$FOREMAN_HOST_COUNT" -ne "${#FOREMAN_HOST[@]}" ]
do
	echo ""	
	echo "Hostname:"
	echo "${FOREMAN_HOST[$FOREMAN_HOST_COUNT]}"
	FOREMAN_HOST_NAME=${FOREMAN_HOST[$FOREMAN_HOST_COUNT]}


	# Use Foreman API to extract the status of each host
	FOREMAN_HOST_STATUS=(`curl -s -u $FOREMAN_USER:$FOREMAN_PASS -H "Accept:application/json" $FOREMAN_URL/api/hosts/$FOREMAN_HOST_NAME/status | cut -d "{" -f2 | cut -d "}" -f1 | cut -d ":" -f2 | sed 's/"//g'`)

	echo "Foreman Status:" 
	echo $FOREMAN_HOST_STATUS

	# Check whether or not the host is in working order on Foreman. 
	# If the host is not listed at 'Active' in Foreman, then it's assumed that it's either down or in some type of 
	# maintenance.
	if [ "$FOREMAN_HOST_STATUS" != "Active" ] ; then

		# We need to contact the Zabbix server and put this host in a maintenance state
		# We first need to find the host ID in Zabbix. This Zabbix API will query the server
		# for any host ID belonging to this host.

		ZABBIX_HOST_ID=(`curl -s -X POST -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"host.get","params":{"output":"extend","filter":{"host":["'"$FOREMAN_HOST_NAME"'"]}}, "auth":"'"$ZABBIX_AUTH_TOKEN"'", "id": 2}' $ZABBIX_URL | python -mjson.tool | grep "hostid" | awk "NR==1{print}" | cut -d ":" -f2  | cut -d "," -f1 | sed 's/"//g'`)
	

		# We should check for null host ID values to determine if we should continue on with the script for this host.
		if  [ -z "$ZABBIX_HOST_ID" ] ; then

			# Host ID does not exist. We don't need to go any further on this host.
			echo "Zabbix Host ID does not exist"
		else
			
			# Now we need to determine if this host has already been put into a maintenance state by grabbing 
			# it's maintenance ID from Zabbix.
			ZABBIX_MAINT_ID=(`curl -s -X POST -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"maintenance.get","params": {"output": "extend", "filter": {"name":"'"$FOREMAN_HOST_NAME"'"}}, "auth":"'"$ZABBIX_AUTH_TOKEN"'", "id":2}' $ZABBIX_URL | python -mjson.tool | grep "maintenanceid" | awk "NR==1{print}" | cut -d ":" -f2  | cut -d "," -f1 | sed 's/"//g'`)
			
			echo "Zabbix Host ID:"
			echo $ZABBIX_HOST_ID
			echo "Zabbix Maintenance ID:"
			echo $ZABBIX_MAINT_ID
	

			# If ZABBIX_MAINT_ID returns a null value then we know that know maintenance has not been assigned to the host.
			if [ -z "$ZABBIX_MAINT_ID" ]; then 
	
				echo "Zabbix Maint ID does not exist. We will create one now."
				
				# Create the maintenance for this host in Zabbix.
				ZABBIX_MAINT_CREATE_ID=(`curl -s -X POST -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0", "method": "maintenance.create", "params": [{"hostids": ["'"$ZABBIX_HOST_ID"'"], "name": "'"$FOREMAN_HOST_NAME"'", "maintenance_type": "0", "description": "Foreman Maintenance", "timeperiods": [{"timeperiod_type": 0, "period": '$ZABBIX_TIME_PERIOD' }] }], "auth":"'"$ZABBIX_AUTH_TOKEN"'","id":3}' $ZABBIX_URL | python -mjson.tool | grep "maintenanceid" | awk "NR==1{print}" | cut -d ":" -f2  | cut -d "," -f1 | sed 's/"//g'`)
		
				echo "Zabbix Maintenance Created ID:" 
				echo $ZABBIX_MAINT_CREATE_ID
				echo " "
			fi		
		fi


	# If Foreman isn't doing anything to this host we should check to see if there is a maintenance window in place on Zabbix
	# since its possible that this script may have put this host in a maintenance state previously. If maintenance is set on this host 
	# and Foreman is listing the status as -Active- then we should turn off maintenance in Zabbix.  

	elif [ "$FOREMAN_HOST_STATUS" == "Active" ] && [[ "$ZABBIX_HOST_ID" -gt 0 ]]; then

			# Get the Zabbix maintenance ID and remove it from the server if found.
			ZABBIX_MAINT_ID=(`curl -s -X POST -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"maintenance.get","params": {"output": "extend", "filter": {"name":"'"$FOREMAN_HOST_NAME"'"}}, "auth":"'"$ZABBIX_AUTH_TOKEN"'", "id":2}' $ZABBIX_URL | python -mjson.tool | grep "maintenanceid" | awk "NR==1{print}" | cut -d ":" -f2  | cut -d "," -f1 | sed 's/"//g'`)
		
			if [ -z "$ZABBIX_MAINT_ID" ]; then
				echo "No Maintenance ID exists"
			else		

				echo  "Zabbix Maintenance ID: "
				echo $ZABBIX_MAINT_ID
				echo ""
		

				#Now that we have the maintenance ID, we shall remove it from Zabbix
				curl -s -X POST -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"maintenance.delete", "params":["'"$ZABBIX_MAINT_ID"'"], "auth":"'"$ZABBIX_AUTH_TOKEN"'", "id": 2}' $ZABBIX_URL
		
				echo " "
				echo "Maintenance on host: $FOREMAN_HOST_NAME removed successfully." 
				echo ""
			fi
	fi


	# Increment the loop to perform actions on the next Foreman host.
	FOREMAN_HOST_COUNT=$FOREMAN_HOST_COUNT+1

done

echo "Foreman / Zabbix maintenance processing complete."
echo " "

exit 0

