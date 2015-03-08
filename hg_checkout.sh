#!/bin/bash
#
#
####################################################
#						   #
#Description: Checkout HG repo every 15 minutes    #
#						   #
#Notes: This script uses ssh to perform the HG     #
# 	checkout. Make sure ssh keys are placed    #
#	where they need to be for full automation. #
####################################################
#
#
#
#
########Variables#######

#Get username (can use basic user account also)
USERNAME=`whoami`

# Path to HG repository (e.g. ssh://server/path/to/repository)
REPO_PATH=ssh://hg@<hg_host>

#Specify the working directory for HG
HG_DIR=/pub/yum/R/.hg
WORKING_DIR=/pub/yum


#######Script##########
#
#
# Create the working HG directory if it doesn't already exist.
# Also implies that a repo doesn't exist on the local system.

	if [ ! -d "$HG_DIR" ]; then
		cd $WORKING_DIR

		#Run HG clone to download repo for the first time.
		echo " Running HG clone.... "
		hg clone $REPO_PATH

		#Setup new cron job to run every 15 mintues via cron
		echo "15 * * * * $USERNAME hg_checkout.sh" >> hg_checkout_cron
		crontab hg_checkout_cron
		rm hg_checkout_cron
	fi

	else
		# Run HG pull to update the local copy of the repo
		echo " Running HG pull.... "
		cd $WORKING_DIR
		hg pull -u -r current $REPO_PATH
		#hg update -r current
	fi

exit 0


