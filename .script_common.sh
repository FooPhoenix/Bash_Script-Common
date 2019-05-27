#!/bin/bash

################################################################################
################################################################################
####                                                                        ####
####     .script_common.sh                                                  ####
####                                                                        ####
################################################################################
################################################################################
#																			   #
#	A script that contains all common functions and tools used in a lot		   #
#	of others scripts.														   #
#																			   #
################################################################################
#														27.05.2019 - 27.05.2019

# Ensure this script is inclued into an other and not executed itself !
if [ "${0##*/}" == '.script_common.sh' ]; then
	echo 'ERROR : The script ".script_common.sh" need to be inclued in an other script...'
fi
