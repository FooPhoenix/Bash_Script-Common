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
#														27.05.2019 - 30.07.2019


# Make Bash a bit more robust to bugs...
# 	e = Exit immediatly on commands returning non-zero exit code.
# 	u = Treat unset variables and parameters as an error.
#	C = Prevent output redirection using '>', '>&', and '<>' from overwriting existing files.
# 	E = Any trap on ERR is inherited by shell functions, command substitutions, and commands executed in a subshell environment.
set -eEuC



#==============================================================================#
#==     Constants pre-definition                                             ==#
#==============================================================================#

declare -ri SCRIPT_START_TIME=$( date '+%s' ) 		# The script start time
declare -r  SCRIPT_NAME="${0##*/}"
declare -r  SCRIPT_FULLNAME="${0}"
declare -r  SCRIPT_REAL_FULLNAME="$(readlink -qsf "${0}")"

declare -r  SCRIPT_TTY="$(tty > /dev/null && tty || echo '')"
declare -ri SCRIPT_ENSURE_LOCKFILE=${SCRIPT_ENSURE_LOCKFILE:-0}
declare -ri SCRIPT_ENSURE_ROOT=${SCRIPT_ENSURE_ROOT:-0}
declare -ri SCRIPT_ENSURE_TTY=${SCRIPT_ENSURE_TTY:-0}
declare -r  SCRIPT_NEW_TTY_NO_CLOSE="${SCRIPT_NEW_TTY_NO_CLOSE:-}" # -- -- -- SCRIPT_NEW_TTY_NO_CLOSE='NO-CLOSE'
declare -ri SCRIPT_PID=$BASHPID 		# Store the BASHPID value is usefull to give it to a subshell, since use BASHPID don't
										# expand to the good PID inside the subshell itself, and the BASHPPID don't exist...

declare -ri SCRIPT_WINDOWED_STDERR=${SCRIPT_WINDOWED_STDERR:-0}

declare -ri SCRIPT_DARKEN_BOLD=${SCRIPT_DARKEN_BOLD:-1}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

unset CDPATH 	# Reserved Bash constant. Security issue : https://bosker.wordpress.com/2012/02/12/bash-scripters-beware-of-the-cdpath/
declare -r TIMEFORMAT='%R-%U-%S' 	# Reserved Bash constant to choose the format of `time` command.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -r PATH_LOG='/var/log/userlog'
declare -r PATH_LOCK='/run/lock'
declare -r PATH_RAM_DISK='/dev/shm'
declare -r PATH_TMP="$(mktemp --tmpdir -d "${SCRIPT_NAME%.sh}-XXXXXXXX.tmp")"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# The Infrastructures path can be overrided just before including this script...
declare -r PATH_INFRASTRUCTURES="${PATH_INFRASTRUCTURES:-/media/foophoenix/AppKDE/Infrastructures}"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -r  PADDING_SPACE="$(printf ' %.0s' {1..256})"
declare -r  PADDING_ZERO="$(printf '0%.0s' {1..256})"
declare -r  PADDING_EQUAL="$(printf '=%.0s' {1..256})"

declare -ri ACTION_TAG_SIZE=12

declare -r  LOOP_END_TAG=':END:'		# Used in pipes to say to a loop it can exit.

declare -r  FILENAME_FORBIDEN_CHARS="[;\":/\\*?|<>$(echo -en "$(printf '\\x%x' {1..31})")]"
declare -r  FILENAME_FORBIDEN_NAMES='^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\..*)?$'

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --




#==============================================================================#
#==     Globals variables pre-definition                                     ==#
#==============================================================================#

declare -i debugTimeIteration=10	# Default number of iteration to do with `time`
declare -a debugTimeResults=( )	# Array to store results of `time`
declare    debugTimeResult=''		# The default variable

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -a scriptPostRemoveFiles=( "$PATH_TMP" )

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -i pipeExpectedEnd=1
declare -i pipeReceivedEnd=0
declare -i pipeParentProcessID=$SCRIPT_PID

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -i  screenWidth=$(tput cols)
declare -i  filenameMaxSize=80



################################################################################
################################################################################
####                                                                        ####
####     Arrays management functions                                        ####
####                                                                        ####
################################################################################
################################################################################

function removeArrayItem
{
	local -r  ai_array_name="${1}"
	local -ir ai_remove_gaps="${2}"
	shift 2
	local -ar ai_items_to_remove=( "${@}" )

	(( ${#ai_items_to_remove[@]} == 0 )) && return 0

	local    ai_item_to_remove ai_source_code
	local -i ai_array_item_key

	{
		read -rd '' ai_source_code <<-SOURCE_CODE
			for ai_item_to_remove in "\${ai_items_to_remove[@]}"; do
				for ai_array_item_key in "\${!${ai_array_name}[@]}"; do
					[[ "\${${ai_array_name}[\$ai_array_item_key]}" == "\$ai_item_to_remove" ]] && unset "${ai_array_name}[\$ai_array_item_key]"
				done
			done
			(( ai_remove_gaps > 0 )) && ${ai_array_name}=( "\${${ai_array_name}[@]}" )
			:
		SOURCE_CODE
	} || :		# TODO finish with } && eval ... for more robust error handling ?

	eval "$ai_source_code"
}

function removeArrayDuplicate
{
	local -r  ad_array_name="${1}"
	local -ir ad_remove_gaps="${2}"
	shift 2
	local -a  ad_items_to_remove=( "${@}" )

	(( ${#ad_items_to_remove[@]} == 0 )) &&
		eval "ad_items_to_remove=( \"\${${ad_array_name}[@]}\" )"

	local    ad_item_to_remove ad_source_code
	local -i ad_array_item_key ad_item_count

	{
		read -rd '' ad_source_code <<-SOURCE_CODE
			while (( \${#ad_items_to_remove[@]} > 0 )); do
				ad_item_to_remove="\${ad_items_to_remove[0]}"
				removeArrayItem ad_items_to_remove 1 "\$ad_item_to_remove"

				ad_item_count=0
				for ad_array_item_key in "\${!${ad_array_name}[@]}"; do
					[[ "\${${ad_array_name}[\$ad_array_item_key]}" == "\$ad_item_to_remove" ]] && (( ++ad_item_count > 1 )) && unset "${ad_array_name}[\$ad_array_item_key]"
				done
			done
			(( ad_remove_gaps > 0 )) && ${ad_array_name}=( "\${${ad_array_name}[@]}" )
			:
		SOURCE_CODE
	} || :		# TODO finish with } && eval ... for more robust error handling ?

	eval "$ad_source_code"
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -rf removeArrayItem removeArrayDuplicate



################################################################################
################################################################################
####                                                                        ####
####     ANSI CSI sequences constants and functions                         ####
####                                                                        ####
################################################################################
################################################################################

function _getCSI
{
	local -r type="${1}"; shift

	local -r IFS=';'
	local -r parameters="${*}"

	echo -en "\e[${parameters}${type}"
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -ri _CSIM_BOLD=1
declare -ri _CSIM_DARK=2
declare -ri _CSIM_ITALIC=3
declare -ri _CSIM_UNDERLINE=4
declare -ri _CSIM_BLINK=5
declare -ri _CSIM_BARRED=9

declare -ri _CSIM_RESET_ALL=0
declare -ri _CSIM_RESET_BOLD=21
declare -ri _CSIM_RESET_DARK=22
declare -ri _CSIM_RESET_ITALIC=23
declare -ri _CSIM_RESET_UNDERLINE=24
declare -ri _CSIM_RESET_BLINK=25
declare -ri _CSIM_RESET_BARRED=29
declare -ri _CSIM_RESET_COLORF=39
declare -ri _CSIM_RESET_COLORB=49

declare -ri _CSIM_FOREGROUND_BLACK=30
declare -ri _CSIM_FOREGROUND_RED=31
declare -ri _CSIM_FOREGROUND_GREEN=32
declare -ri _CSIM_FOREGROUND_YELLOW=33
declare -ri _CSIM_FOREGROUND_BLUE=34
declare -ri _CSIM_FOREGROUND_MAGENTA=35
declare -ri _CSIM_FOREGROUND_CYAN=36
declare -ri _CSIM_FOREGROUND_LIGHT_GRAY=37
declare -ri _CSIM_FOREGROUND_DARK_GRAY=90
declare -ri _CSIM_FOREGROUND_LIGHT_RED=91
declare -ri _CSIM_FOREGROUND_LIGHT_GREEN=92
declare -ri _CSIM_FOREGROUND_LIGHT_YELLOW=93
declare -ri _CSIM_FOREGROUND_LIGHT_BLUE=94
declare -ri _CSIM_FOREGROUND_LIGHT_MAGENTA=95
declare -ri _CSIM_FOREGROUND_LIGHT_CYAN=96
declare -ri _CSIM_FOREGROUND_WHITE=97

declare -ri _CSIM_BACKGROUND_BLACK=40
declare -ri _CSIM_BACKGROUND_RED=41
declare -ri _CSIM_BACKGROUND_GREEN=42
declare -ri _CSIM_BACKGROUND_YELLOW=43
declare -ri _CSIM_BACKGROUND_BLUE=44
declare -ri _CSIM_BACKGROUND_MAGENTA=45
declare -ri _CSIM_BACKGROUND_CYAN=46
declare -ri _CSIM_BACKGROUND_LIGHT_GRAY=47
declare -ri _CSIM_BACKGROUND_DARK_GRAY=100
declare -ri _CSIM_BACKGROUND_LIGHT_RED=101
declare -ri _CSIM_BACKGROUND_LIGHT_GREEN=102
declare -ri _CSIM_BACKGROUND_LIGHT_YELLOW=103
declare -ri _CSIM_BACKGROUND_LIGHT_BLUE=104
declare -ri _CSIM_BACKGROUND_LIGHT_MAGENTA=105
declare -ri _CSIM_BACKGROUND_LIGHT_CYAN=106
declare -ri _CSIM_BACKGROUND_WHITE=107

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function getCSIm
{
	_getCSI 'm' "${@}"
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -r SCRIPT_DARKEN_BOLD_TAG="$( (( SCRIPT_DARKEN_BOLD == 0 )) || getCSIm ${_CSIM_DARK} )"

declare -r S_NO="$(getCSIm ${_CSIM_RESET_ALL})"	# NO > NORMAL
declare -r S_BO="$(getCSIm ${_CSIM_BOLD})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_DA="$(getCSIm ${_CSIM_DARK})"
declare -r S_IT="$(getCSIm ${_CSIM_ITALIC})"
declare -r S_UN="$(getCSIm ${_CSIM_UNDERLINE})"
declare -r S_BL="$(getCSIm ${_CSIM_BLINK})"
declare -r S_BA="$(getCSIm ${_CSIM_BARRED})"

declare -r S_R_AL="$(getCSIm ${_CSIM_RESET_ALL})"
declare -r S_R_BO="$(getCSIm ${_CSIM_RESET_BOLD})"
declare -r S_R_DA="$(getCSIm ${_CSIM_RESET_DARK})"
declare -r S_R_IT="$(getCSIm ${_CSIM_RESET_ITALIC})"
declare -r S_R_UN="$(getCSIm ${_CSIM_RESET_UNDERLINE})"
declare -r S_R_BL="$(getCSIm ${_CSIM_RESET_BLINK})"
declare -r S_R_BA="$(getCSIm ${_CSIM_RESET_BARRED})"
declare -r S_R_CF="$(getCSIm ${_CSIM_RESET_COLORF})"
declare -r S_R_CB="$(getCSIm ${_CSIM_RESET_COLORB})"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# FOREGROUND COLOR
declare -r S_BLA="$(getCSIm ${_CSIM_FOREGROUND_BLACK})"
declare -r S_RED="$(getCSIm ${_CSIM_FOREGROUND_RED})"
declare -r S_GRE="$(getCSIm ${_CSIM_FOREGROUND_GREEN})"
declare -r S_YEL="$(getCSIm ${_CSIM_FOREGROUND_YELLOW})"
declare -r S_BLU="$(getCSIm ${_CSIM_FOREGROUND_BLUE})"
declare -r S_MAG="$(getCSIm ${_CSIM_FOREGROUND_MAGENTA})"
declare -r S_CYA="$(getCSIm ${_CSIM_FOREGROUND_CYAN})"
declare -r S_LGY="$(getCSIm ${_CSIM_FOREGROUND_LIGHT_GRAY})"
declare -r S_DGY="$(getCSIm ${_CSIM_FOREGROUND_DARK_GRAY})"
declare -r S_LRE="$(getCSIm ${_CSIM_FOREGROUND_LIGHT_RED})"
declare -r S_LGR="$(getCSIm ${_CSIM_FOREGROUND_LIGHT_GREEN})"
declare -r S_LYE="$(getCSIm ${_CSIM_FOREGROUND_LIGHT_YELLOW})"
declare -r S_LBL="$(getCSIm ${_CSIM_FOREGROUND_LIGHT_BLUE})"
declare -r S_LMA="$(getCSIm ${_CSIM_FOREGROUND_LIGHT_MAGENTA})"
declare -r S_LCY="$(getCSIm ${_CSIM_FOREGROUND_LIGHT_CYAN})"
declare -r S_WHI="$(getCSIm ${_CSIM_FOREGROUND_WHITE})"

# BACKGROUND COLOR
declare -r S_B_BLA="$(getCSIm ${_CSIM_BACKGROUND_BLACK})"
declare -r S_B_RED="$(getCSIm ${_CSIM_BACKGROUND_RED})"
declare -r S_B_GRE="$(getCSIm ${_CSIM_BACKGROUND_GREEN})"
declare -r S_B_YEL="$(getCSIm ${_CSIM_BACKGROUND_YELLOW})"
declare -r S_B_BLU="$(getCSIm ${_CSIM_BACKGROUND_BLUE})"
declare -r S_B_MAG="$(getCSIm ${_CSIM_BACKGROUND_MAGENTA})"
declare -r S_B_CYA="$(getCSIm ${_CSIM_BACKGROUND_CYAN})"
declare -r S_B_LGY="$(getCSIm ${_CSIM_BACKGROUND_LIGHT_GRAY})"
declare -r S_B_DGY="$(getCSIm ${_CSIM_BACKGROUND_DARK_GRAY})"
declare -r S_B_LRE="$(getCSIm ${_CSIM_BACKGROUND_LIGHT_RED})"
declare -r S_B_LGR="$(getCSIm ${_CSIM_BACKGROUND_LIGHT_GREEN})"
declare -r S_B_LYE="$(getCSIm ${_CSIM_BACKGROUND_LIGHT_YELLOW})"
declare -r S_B_LBL="$(getCSIm ${_CSIM_BACKGROUND_LIGHT_BLUE})"
declare -r S_B_LMA="$(getCSIm ${_CSIM_BACKGROUND_LIGHT_MAGENTA})"
declare -r S_B_LCY="$(getCSIm ${_CSIM_BACKGROUND_LIGHT_CYAN})"
declare -r S_B_WHI="$(getCSIm ${_CSIM_BACKGROUND_WHITE})"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# NORMAL + FOREGROUND COLOR
declare -r S_NOBLA="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_BLACK})"
declare -r S_NORED="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_RED})"
declare -r S_NOGRE="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_GREEN})"
declare -r S_NOYEL="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_YELLOW})"
declare -r S_NOBLU="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_BLUE})"
declare -r S_NOMAG="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_MAGENTA})"
declare -r S_NOCYA="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_CYAN})"
declare -r S_NOLGY="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_LIGHT_GRAY})"
declare -r S_NODGY="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_DARK_GRAY})"
declare -r S_NOLRE="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_LIGHT_RED})"
declare -r S_NOLGR="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_LIGHT_GREEN})"
declare -r S_NOLYE="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_LIGHT_YELLOW})"
declare -r S_NOLBL="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_LIGHT_BLUE})"
declare -r S_NOLMA="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_LIGHT_MAGENTA})"
declare -r S_NOLCY="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_LIGHT_CYAN})"
declare -r S_NOWHI="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_WHITE})"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# BOLD + FOREGROUND COLOR
declare -r S_BOBLA="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_BLACK})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_BORED="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_RED})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_BOGRE="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_GREEN})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_BOYEL="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_YELLOW})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_BOBLU="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_BLUE})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_BOMAG="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_MAGENTA})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_BOCYA="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_CYAN})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_BOLGY="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_LIGHT_GRAY})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_BODGY="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_DARK_GRAY})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_BOLRE="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_LIGHT_RED})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_BOLGR="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_LIGHT_GREEN})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_BOLYE="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_LIGHT_YELLOW})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_BOLBL="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_LIGHT_BLUE})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_BOLMA="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_LIGHT_MAGENTA})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_BOLCY="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_LIGHT_CYAN})$SCRIPT_DARKEN_BOLD_TAG"
declare -r S_BOWHI="$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_WHITE})$SCRIPT_DARKEN_BOLD_TAG"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function getCSI_RGB
{
	local -ir R="${1}"
	local -ir G="${2}"
	local -ir B="${3}"
	local     D="${4:-F}"

	[[ "$D" == 'B' ]] && D='48' || D='38'

	local -i color

	(( (R >= 0 && R <= 5) && (G >= 0 && G <= 5) && (B >= 0 && B <= 5) )) || errcho ':EXIT:' 'RGB value need to be between 0 and 5 !'
	(( color =  16 + ((R * 36) + (G * 6) + B) ))

	getCSIm $D 5 $color
}

function getCSI_GRAY
{
	local -ir G="${1}"
	local     D="${2:-F}"

	[[ "$D" == 'B' ]] && D='48' || D='38'

	local -i color

	(( G >= 0 && G <= 23 )) || errcho ':EXIT:' 'Gray index need to be between 0 and 23 !'

	(( color = 232 + G ))

	getCSIm $D 5 $color
}

function showRGB_Palette
{
	local -i R G B F index

	echo -en "${S_NO}\r"

	for R in {0..5}; do
		for G in {0..5}; do
			(( G < 3 )) && F='23' || F='0'

			for B in {0..5}; do
				getCSI_GRAY $F
				getCSI_RGB $R $G $B B
				echo -en "   $R-$G-$B   "
			done

			echo -e "${S_NO}"
		done
	done

	index=0
	for G in {0..23}; do
		(( index < 12 )) && F='23' || F='0'

		getCSI_GRAY $F
		getCSI_GRAY $G B
		echo -en "    $(printf '%3s' $index)    "
		(( ++index % 6 == 0 )) && echo -e "${S_NO}"
	done
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function getCSI_CursorMove
{
	# Possible direction :
	#		Left, Right =				Move the cursor from their current location to the direction by ${2} characters.
	#		Up, Down =					Move the cursor from their current location to the direction by ${2} lines.
	#		Column =					Move the cursor to the ${2} column of the current line.
	#		Position =					Move the cursor to the ${2} line and the ${3} column.

	local -u  direction="${1:0:1}"
	local -ir number1="${2:-}"
	local -ir number2="${3:-}"

	[[ 'PCUDRL' == *${direction}* ]] || errcho ':EXIT:' 'function getCSI_CursorMove need a valid direction...'
	direction="$( echo "${direction}" | tr 'PCUDRL' 'HGABCD' )"

	if [[ "${direction}" == 'H' ]] && [[ "$number2" != '' ]]; then
		_getCSI "${direction}" "${number1}" "${number2}"
	else
		_getCSI "${direction}" "${number1}"
	fi
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -r CO_HIDE="$(_getCSI 'l' '?25')"
declare -r CO_SHOW="$(_getCSI 'h' '?25')"

declare -r CO_SAVE_POS="$(_getCSI 's')"
declare -r CO_RESTORE_POS="$(_getCSI 'u')"

declare -r CO_GO_TOP_LEFT="$(getCSI_CursorMove Position 1 1)"
declare -r CO_UP_1="$(getCSI_CursorMove Up 1)"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -r ES_CURSOR_TO_SCREEN_END="$(_getCSI 'J' '0')"
declare -r ES_CURSOR_TO_SCREEN_START="$(_getCSI 'J' '1')"
declare -r ES_ENTIRE_SCREEN="$(_getCSI 'J' '2')"

declare -r ES_CURSOR_TO_LINE_END="$(_getCSI 'K' '0')"
declare -r ES_CURSOR_TO_LINE_START="$(_getCSI 'K' '1')"
declare -r ES_ENTIRE_LINE="$(_getCSI 'K' '2')"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function getCSI_ScreenMove
{
	local -u  direction="${1:0:1}"
	local -ir number="${2:-}"

	[[ 'UDIR' == *${direction}* ]] || errcho ':EXIT:' 'function getCSI_ScreenMove need a valid direction...'
	direction="$( echo "${direction}" | tr 'UDIR' 'STLM' )"

	_getCSI "${direction}" "${number}"
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -r SO_INSERT_1="$(getCSI_ScreenMove Insert 1)"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function removeCSI_Tag
{
	sed -e "s|"$'\e'"\[?\?[0-9]*\(;[0-9]\+\)*[mlhsuJKHGABCDSTLM]||g" <<< "${*}"
}

function getCSI_StringLength
{
	echo $(expr length "$(removeCSI_Tag "${*}")" || :)
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -rf _getCSI getCSIm getCSI_RGB getCSI_GRAY showRGB_Palette getCSI_CursorMove getCSI_ScreenMove removeCSI_Tag getCSI_StringLength



################################################################################
################################################################################
####                                                                        ####
####     Actions tags declaration                                           ####
####                                                                        ####
################################################################################
################################################################################

function getActionTag
{
	local -r tag_name="${1}"
	local -r tag_color="${2:-$S_NO}"

	local -i tag_name_size1 tag_name_size2

	((	tag_name_size1 = ACTION_TAG_SIZE - ${#tag_name},
		tag_name_size2 = (tag_name_size1 / 2) + (tag_name_size1 % 2),
		tag_name_size1 = (tag_name_size1 / 2)		))

	echo -en "${S_NOWHI}[${tag_color}${PADDING_SPACE:0:$tag_name_size1}${tag_name}${PADDING_SPACE:0:$tag_name_size2}${S_NOWHI}]${S_R_AL}"
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -r A_IN_PROGRESS="$(getActionTag 'IN PROGRESS' "$S_NO")"
declare -r A_OK="$(getActionTag 'OK' "$S_GRE")"
declare -r A_FAILED_R="$(getActionTag 'FAILED' "$S_RED")"
declare -r A_FAILED_Y="$(getActionTag 'FAILED' "$S_YEL")"
declare -r A_SUCCESSED="$(getActionTag 'SUCCESSED' "$S_GRE")"
declare -r A_SKIPPED="$(getActionTag 'SKIPPED' "$S_CYA")"

declare -r A_ABORTED_NR="$(getActionTag 'ABORTED' "$S_RED")"
declare -r A_ABORTED_RR="$(getActionTag 'ABORTED' "$S_B_RED$S_BLA")"
declare -r A_ABORTED_NY="$(getActionTag 'ABORTED' "$S_YEL")"

declare -r A_WARNING_NR="$(getActionTag 'WARNING' "$S_RED")"
declare -r A_WARNING_RR="$(getActionTag 'WARNING' "$S_B_RED$S_BLA")"
declare -r A_WARNING_NY="$(getActionTag 'WARNING' "$S_YEL")"

declare -r A_ERROR_NR="$(getActionTag 'ERROR' "$S_RED")"
declare -r A_ERROR_BR="$(getActionTag 'ERROR' "$S_BL$S_RED")"
declare -r A_ERROR_RR="$(getActionTag 'ERROR' "$S_B_RED$S_BLA")"

declare -r A_UP_TO_DATE_G="$(getActionTag 'UP TO DATE' "$S_GRE")"
declare -r A_MODIFIED_Y="$(getActionTag 'MODIFIED' "$S_YEL")"
declare -r A_UPDATED_Y="$(getActionTag 'UPDATED' "$S_YEL")"
declare -r A_UPDATED_G="$(getActionTag 'UPDATED' "$S_GRE")"
declare -r A_ADDED_B="$(getActionTag 'ADDED' "$S_LBL")"
declare -r A_COPIED_G="$(getActionTag 'COPIED' "$S_GRE")"
declare -r A_MOVED_G="$(getActionTag 'MOVED' "$S_GRE")"
declare -r A_REMOVED_R="$(getActionTag 'REMOVED' "$S_RED")"
declare -r A_EXCLUDED_R="$(getActionTag 'EXCLUDED' "$S_RED")"
declare -r A_BACKUPED_G="$(getActionTag 'BACKUPED' "$S_GRE")"
declare -r A_BACKUPED_Y="$(getActionTag 'BACKUPED' "$S_YEL")"

declare -r A_EMPTY_TAG="$(getActionTag '  ' "$S_NO")"
declare -r A_TAG_LENGTH_SIZE="${PADDING_SPACE:0:$(( ACTION_TAG_SIZE + 2 ))}"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -rf getActionTag



################################################################################
################################################################################
####                                                                        ####
####     Errors and exit handling functions                                 ####
####                                                                        ####
################################################################################
################################################################################

function errcho
{
	# Echo a message on the stderr.
	# the message is formatted like that :
	#
	# {source script name}: line {line number}: {message}
	#
	# ${@} = Message to be printed on stderr. Message can be more than one parameters.
	#
	# Optionally the first parameter can be an exit tag like :EXIT: or :EXIT:1 :EXIT:23
	# If this tag is passed, the function will `exit` immediatly after showing the message.
	# If a number follow the :EXIT: tag, it will be used as the exit code number.
	# :EXIT: and :EXIT:0 are always replaced internally by :EXIT:1
	#
	# The exit tag is obviously not printed with the message...

	local -ir line="${BASH_LINENO[0]}"
	local -r  source="${BASH_SOURCE[1]}"
	local -i  need_exit=0

	local -r regex="^:EXIT:([0-9]+)?$"

	# Check here if the function has received an :EXIT: tag.
	[[ "${1}" =~ $regex ]] && {
		need_exit=${BASH_REMATCH[1]:-1} 					# If BASH_REMATCH[1] is empty or unset, force it to be 1
		need_exit=$(( need_exit == 0 ? 1 : need_exit )) 	# :EXIT:0 has no sense after an error, force it to be :EXIT:1
		shift
	}

	echo "$source: line $line: ${@}" >&2

 	[[ $need_exit == 0 ]] ||
		exit $need_exit
}

function checkLoopFail
{
	# This function check if a loop in a subshell need to exit or not.
	#
	# The loop exit immediately if the parent shell unexpectedly exit.
	# This is a anti infinite loop security.

	local -ir related_pid="${pipeParentProcessID}"

	(( $(ps -p $related_pid -ho pid || echo 0) != related_pid )) && return 1

	sleep 0.5
	return 0
}

function checkLoopEnd
{
	# This function check if a loop in a subshell need to exit or not.
	#
	# The loop exit normally if a LOOP_END_TAG is received via a pipe.

	[[ "${1}" == "$LOOP_END_TAG" ]] && {
		(( ++pipeReceivedEnd, pipeReceivedEnd >= pipeExpectedEnd )) &&
			return 1 ||
			return 2
	}

	return 0
}

function getProcessTree
{
	local -r  return_var_name="${1:+-v $1}"
	local -i  screen_size=${2:-$(( $( tput cols ) ))} # TODO : Debug, crash without tty...
	local -i  pid ppid
	local     command
	local -ai ppids
	local -a  commands

	(( screen_size = screen_size == 0 ? 1024 : screen_size, screen_size >= 16 )) || errcho ':EXIT:' "getProcessTree function need more space than $screen_size"

	# Take all elements given by `ps` and store it in arrays.
	# The index of elements is its PID !
	while read -r pid ppid command ; do
		ppids[$pid]="$ppid"
		commands[$pid]="$command"
	done <<< $(ps --no-headers -ax -o pid:5,ppid:5,command ) # For debug : ps --no-headers --forest -ax -o pid:5,ppid:5,command

	#---------------------------------------------------------------------------

	# Build the list of parents process and children process and store it in pids[]
	# The children[] array will store how many children has each process
	# The relationship[] array will manage the output color, 0 = no relation, 1 = parent tree, 2 = myself, 3 = children tree

	local -ir current_pid="$BASHPID"
	local -ai pids children relationship

	# Build parents process list here
	pid=$current_pid
	while (( 1 )); do
		pids+=($pid ) # add the current pid
		pid=${ppids[$pid]} # retreive the ppid of the current pid
		children[$pid]=1
		relationship[$pid]=1
		(( pid == 1 )) && break
	done

	local -i  index check_pid
	local -ai children_pids

	# Build children process list here
	children_pids=( $current_pid ) # Contain the list of all pid waiting to be evaluated
	children[$current_pid]=0
	relationship[$current_pid]=2
	index=0
	while (( index < ${#children_pids[@]} )); do
		pid=${children_pids[$index]}
		(( ++index, pid == 0 )) && continue

		for check_pid in ${!ppids[@]}; do # ${!ppids[@]} return the list of all pid because each ppid has their own pid as key
			(( pid != ppids[check_pid] )) && continue

			pids+=( $check_pid ) # add the current checked pid
			relationship[$check_pid]=3
			children[$check_pid]=0
			(( ++children[pid] )) # add one children
			children_pids+=( $check_pid ) # add this pid to be evaluated later
		done
	done

	#---------------------------------------------------------------------------

	# sort all pid
	pids=( $(printf "%s\n" "${pids[@]}" | sort -n ) )

	# Build children process of the root process in the tree
	children_pids=( ${pids[0]} ) # Contain the list of all pid waiting to be evaluated
	index=0
	while (( index < ${#children_pids[@]} )); do
		pid=${children_pids[$index]}
		(( ++index, pid == 0 )) && continue

		for check_pid in ${!ppids[@]}; do # ${!ppids[@]} return the list of all pid because each ppid has their own pid as key
			(( pid != ppids[check_pid] )) && continue

			children_pids+=( $check_pid ) # add this pid to be evaluated later
			(( relationship[check_pid] != 0 )) && continue  # if relationship[check_pid] is not 0, so this pid is already in the list, just do nothing
			pids+=( $check_pid ) # add the current checked pid
			relationship[$check_pid]=0
			children[$check_pid]=${children[$check_pid]:-0}
			(( ++children[pid] )) # add one children
		done
	done

	#---------------------------------------------------------------------------

	# sort all pid
	pids=( $(printf "%s\n" "${pids[@]}" | sort -n ) )

	#---------------------------------------------------------------------------

	local -i level
	local    output='' padded_pid
	local -r S_DAYEL="$(getCSIm ${_CSIM_DARK} ${_CSIM_FOREGROUND_YELLOW})"


	children_pids=( ${pids[0]} )
	index=0
	while (( ${#children_pids[@]} > 0 )); do

		pid=${children_pids[$index]}
		unset -v children_pids[$index] # TODO : make a takeArrayItem
		index=$(( index - 1 ))
		children_pids=( ${children_pids[@]} ) # Rebuild all index keys to be continuous

		check_pid=${ppids[$pid]}
		children[$check_pid]=$(( children[$check_pid] - 1 ))

		for check_pid in ${pids[@]}; do
			(( pid != ppids[check_pid] )) && continue

			children_pids+=( $check_pid )
			index=$(( index + 1 ))
		done

		command=''

		check_pid=$pid
		level=0
		while (( 1 )); do
			check_pid=${ppids[$check_pid]}
			(( check_pid == 1 )) && break

			(( level++ == 0 )) &&
			{
				(( children[check_pid] > 0 )) &&
					command="+-$command" ||
					command="+-$command"
			} ||
			{
				(( children[check_pid] > 0 )) &&
					command="| $command" ||
					command="  $command"
			}
		done

		(( level = (screen_size - 6) - ((level * 2) + 4) ))

		case ${relationship[$pid]} in # TODO : var+="text" ???
			0)
				command="${command}??? ${commands[$pid]:0:$level}"	;;
			1)
				command="${command}${S_DAYEL}?${S_NO}?? ${S_DAYEL}${commands[$pid]:0:$level}${S_NO}"	;;
			2)
				command="${command}${S_NORED}?${S_NO}?? ${S_NORED}${commands[$pid]:0:$level}${S_NO}"	;;
			3)
				command="${command}${S_NOYEL}?${S_NO}?? ${S_NOYEL}${commands[$pid]:0:$level}${S_NO}"	;;
		esac

		printf -v padded_pid '%5d' $pid
		output="${output}${padded_pid} ${command}\n"

#  		echo -e "${pid} ${command}"
	done

	printf $return_var_name '%b' "$output"
}

function _showExitHeader
{
	local -r exit_tag="${1}"
	local -r exit_reason="${2}"
	# USE temp_stderr_output_file FROM THE CALLER !

	local crash_time crash_after

	printf -v crash_time '%(%A %-d %B %Y @ %X)T' -1
	TZ=UTC printf -v crash_after '%(%X)T' $SECONDS

	(( BASH_SUBSHELL == 0 )) && echo -en "\n\r${ES_CURSOR_TO_SCREEN_END}" >&2 # output this only on the screen !

	{
		echo ' '
		echo -e "${exit_tag} ${exit_reason} (PID: $BASHPID)"
		echo -e "This has happened at ${S_NOWHI}${crash_time}${S_NO}, after the script has run for ${S_NOWHI}${crash_after}${S_NO}..."
		echo ' '
	} >> "$temp_stderr_output_file"
}

function _showDebugDetails
{
	# USE line_number FROM THE CALLER !
	# USE last_exit_status FROM THE CALLER !
	# USE last_command FROM THE CALLER !
	# USE temp_stderr_output_file FROM THE CALLER !

	local -i index

	{
		echo -e "${S_NOWHI}Calls history :${S_NO}"
		for index in ${!BASH_LINENO[@]}; do
			printf '%5d ' ${BASH_LINENO[$index]}
			echo -e "${FUNCNAME[$index]} ${S_DA}( in ${BASH_SOURCE[$index]} )${S_NO}"
		done
		echo ' '

		echo -e "Error reported near ${S_NOWHI}the line $line_number${S_NO}, last known exit status is ${S_NOWHI}$last_exit_status${S_NO}, the last executed command is :"
		echo ' '
		echo -e "        ${S_NOYEL}$last_command${S_NO}"
		echo ' '

		echo -e "${S_NOWHI}  PID   Commands${S_NO}"
		getProcessTree
		echo ' '
	} >> "$temp_stderr_output_file"
}

function _preExitProperly
{
	# Reset all trap to default...
	trap - EXIT INT QUIT TERM HUP ERR

	# Desactive the hooked stderr...
	(( BASH_SUBSHELL == 0 )) &&
		exec 2>&${stderr_backup}
}

function _postExitProperly
{
	(( BASH_SUBSHELL != 0 )) &&	return 0

	local -r temp_stderr_output_file="${temp_stderr_output_file:-//}"
	[[ -f "$temp_stderr_output_file" ]] &&
		cat "$temp_stderr_output_file" >&2

	[[ -f "$SCRIPT_STDERR_FILE" ]] && (( $(wc -l < "$SCRIPT_STDERR_FILE") > 0 )) &&	{
		echo -e "\n${S_NOWHI}While it was running, the script ${S_BOWHI}${SCRIPT_NAME}${S_NOWHI} has ouptut this on the STDERR :${S_NO}"
		cat "$SCRIPT_STDERR_FILE"
		echo
	} >&2

	[[ -f "$temp_stderr_output_file" ]] &&
		cat "$temp_stderr_output_file" >&${stderr_pipe}

	echo "$LOOP_END_TAG" >&${stderr_pipe}
	exec {stderr_pipe}>&-

	{
		sleep 1

		[[ -f "$SCRIPT_STDERR_FILE" ]] && (( $(wc -l < "$SCRIPT_STDERR_FILE") > 0 )) && {
			echo >> "$SCRIPT_STDERR_FILE"
			cat "$SCRIPT_STDERR_FILE" >> "$PATH_LOG/$SCRIPT_NAME.log"
		}

		local file_name

		# Remove all temporaries files...
		for file_name in "${scriptPostRemoveFiles[@]}"; do
			[[ -z "$file_name" ]] && continue
			[[ -d "$file_name" ]] &&
				rm --preserve-root -f -r "$file_name" ||
				rm --preserve-root -f "$file_name"
		done
	} &
}

function safeExit
{
	local -ir exit_status=${1:-0}

	_preExitProperly
	_postExitProperly
	exit $exit_status
}

function unexpectedExit
{
	local -r  signal="${1}"
	local -ir line_number="${2}"
	local -i  last_exit_status="${3}"
	local -r  last_command="${4}"

	local    script
	local -r temp_stderr_output_file="$PATH_TMP/MEMORY/stderr-$BASHPID.log"

	_preExitProperly

	[[ ! -f "$temp_stderr_output_file" ]] && echo -n '' > "$temp_stderr_output_file"

	(( BASH_SUBSHELL == 0 )) &&
		script='The script' ||
		script="A subshell ($BASH_SUBSHELL)"

	case "$signal" in
		'EXIT')
			_showExitHeader "$A_ERROR_BR" "${S_NOWHI}$script${S_NO} has unexpectedly exited for an unknown reason."
			_showDebugDetails
			;;
		'INT')
			_showExitHeader "$A_ABORTED_NY" "${S_NOWHI}$script${S_NO} has exited because used has pressed [CTRL]-[C]."
			;;
		'TERM')
			_showExitHeader "$A_ABORTED_NY" "${S_NOWHI}$script${S_NO} has stopped because the signal TERM has been received."
			;;
		'ERR')
			_showExitHeader "$A_ERROR_BR" "${S_NOWHI}$script${S_NO} has crashed because of an unexpected error."
			_showDebugDetails
			;;
	esac

	if (( BASH_SUBSHELL == 0 )); then
		_postExitProperly
	else
		cat "$temp_stderr_output_file" >&2
	fi

	(( last_exit_status == 0 )) && (( ++last_exit_status ))
	exit $last_exit_status
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -rf errcho checkLoopFail checkLoopEnd getProcessTree _showExitHeader _showDebugDetails _preExitProperly _postExitProperly safeExit unexpectedExit

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

trap 'unexpectedExit "EXIT" "$LINENO" "$?" "$BASH_COMMAND"' EXIT
trap 'unexpectedExit "INT"  "$LINENO" "$?" "$BASH_COMMAND"' INT QUIT
trap 'unexpectedExit "TERM" "$LINENO" "$?" "$BASH_COMMAND"' TERM HUP
trap 'unexpectedExit "ERR"  "$LINENO" "$?" "$BASH_COMMAND"' ERR



################################################################################
################################################################################
####                                                                        ####
####     Files and paths functions                                          ####
####                                                                        ####
################################################################################
################################################################################

function getFileTypeV
{
	local -r return_var_name="${1:+-v $1}"
	local -r filename="${2}"

	local    result

	[[ -e "$filename" ]] &&
	{
		if [[ -f "$filename" ]]; then
			result='Ef'
		elif [[ -d "$filename" ]]; then
			result='Ed'
		elif [[ -p "$filename" ]]; then
			result='Ep'
		elif [[ -S "$filename" ]]; then
			result='Es'
		elif [[ -b "$filename" ]]; then
			result='Eb'
		elif [[ -c "$filename" ]]; then
			result='Ec'
		else
			result='E?'
			errcho "Function getFileTypeV has discovered an unknown type with file $filename"
		fi
	} || result='  '

	[[ -L "$filename" ]] &&
		result+='l' ||
		result+=' '

	printf $return_var_name '%s' "$result"
}

function getFileSizeV
{
	local -r return_var_name="${1:+-v $1}"
	local -r full_filename="${2}"

	printf $return_var_name '%d' "$(stat --format=%s "$full_filename" || echo 0)"
}

function formatSizeV
{
	local -r  return_var_name="${1:+-v $1}"
	local -ir input_size="${2}"
	local -ir padding="${3:-0}"

	local final_size=''
	local size_=$input_size

	(( padding > 0 )) && {
		(( padding >= ${#input_size} )) &&
			final_size="${PADDING_SPACE:0:padding-${#size_}}${final_size}" ||
			size_=+${input_size:0-padding+1}
	}

	local -i index pos length

	(( pos = 0, length = ${#size_} % 3, index = ${#size_} / 3, length > 0 )) && { # pos = 0,
		final_size+=${formatSizeV_Colors[index]}${size_:pos:length}
		(( pos += length ))
	}

	(( --index >= 0 )) && {
		length=3
		while [[ 1 ]]; do
			final_size+=${formatSizeV_Colors[index]}${size_:pos:length}
			(( pos += 3, --index < 0 )) && break
		done
	}

	# TODO : make a return_var_name value check with a pseudo bebug mode to notify if variable name is already a local variable name ??

	printf $return_var_name "${S_NO}%s${S_R_AL}" "$final_size"
}

function checkFilename
{
	# https://docs.microsoft.com/en-us/windows/desktop/FileIO/naming-a-file

	local -r file_name="${1:-}" # Here "empty string" is accepted so return 1 will be executed...

	[[	"$file_name" == '' ||
		"${file_name:(-1)}" == '.' || # TODO : Try to optimize the test order ?
		"${file_name:(-1)}" == ' ' ||
		"${file_name:0:1}" == ' ' ||
		"$file_name" =~ $FILENAME_FORBIDEN_CHARS ||
		"${file_name^^}" =~ $FILENAME_FORBIDEN_NAMES ]] && return 1

	return 0
}

function cloneFolderDetails
{
	local -r foldername="${3}"
	local -r source="${1}/$foldername"
	local -r destination="${2}/$foldername"

	[[ -d "$source" ]] && {
		[[ ! -e "$destination" ]] && mkdir "$destination"
		[[ -d "$destination" ]] && {
			local -ar details=( $(stat -c "%a %u %g" "$source") )

			chown ${details[1]}:${details[2]} "$destination" &&
			chmod ${details[0]} "$destination" &&
			return 0
		}
	}

	return 0
}

function clonePathDetails
{
	local -r source="${1}"
	local -r destination="${2}"
	local    relative_folders_path="${3}"

	[[ ! -d "$destination/$relative_folders_path" ]] && [[ -d "$source/$relative_folders_path" ]] && {
		local -a folders
		local folder folder_path

		IFS='/' read -a folders <<< "$relative_folders_path"

		relative_folders_path=''
		for folder in "${folders[@]}"; do
			relative_folders_path+="/$folder"

			folder_path="$destination/${relative_folders_path:1}"

			[[ ! -e "$folder_path" ]] && {
				local -a details=( $(stat -c "%a %u %g" "$source") )

				mkdir "$folder_path"
				chown ${details[1]}:${details[2]} "$folder_path"
				chmod ${details[0]} "$folder_path"
			}
		done
	}

	return 0
}

function shortenFileNameV
{
	local -r  return_var_name="${1:+-v $1}"
	local     full_filename="${2}"
	local -ir max_size="${3}"
	local -ir max_filename_size="${4:-48}"

	(( ${#full_filename} > max_size )) && {
		local slash=''

		[[ "${full_filename:(-1)}" == '/' ]] && {
			slash='/'
			full_filename="${full_filename:0:(-1)}"
		}

		local     filename_="${full_filename##*/}$slash"
		local     path="${full_filename%/*}/"
		local -ir filename_size=${#filename_}
		local -ir path_size=${#path}

		local -i cut_size_1 cut_size_2 cut_size=$filename_size

		(( filename_size > max_filename_size )) && {
			((  cut_size = max_size - (path_size + max_filename_size),
				cut_size = cut_size > 0 ? cut_size + max_filename_size : max_filename_size,
				cut_size_1 = (cut_size / 2) - 3 + (cut_size % 2),
				cut_size_2 = (cut_size / 2) ))

			filename_="${filename_:0:$cut_size_1}...${filename_:(-$cut_size_2)}"
		}

		(( cut_size = max_size - cut_size, path_size > cut_size )) && {
			(( 	cut_size_1 = (cut_size / 2) - 3 + (cut_size % 2),
				cut_size_2 = (cut_size / 2) ))

			path="${path:0:$cut_size_1}...${path:(-$cut_size_2)}"
		}

		full_filename="${path}${filename_}"
	}

	printf $return_var_name '%s' "$full_filename"
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -rf getFileTypeV checkFilename cloneFolderDetails clonePathDetails shortenFileNameV formatSizeV getFileSizeV



################################################################################
################################################################################
####                                                                        ####
####     Criticals sections functions                                       ####
####                                                                        ####
################################################################################
################################################################################

function checkLockfileOwned
{
	local     lockfile_name="${1:-${SCRIPT_NAME}}"
	local -ir lockfile_pid="${2:-$SCRIPT_PID}"

	lockfile_name="$PATH_LOCK/${lockfile_name%.sh}.lock"

	local -i file_pid

	{
		if [[ -f "$lockfile_name" ]]; then
			read file_pid < "$lockfile_name" && {
				if (( $(ps -p $file_pid -ho pid || echo 0) == file_pid )); then
					(( file_pid == lockfile_pid )) &&
						return 0 || 				# Lockfile is mine :)
						return 3 					# Lockfile isn't mine
				else
					return 4 						# the process dosen't exist anymore
				fi
			}
		else
			return 2								# Lockfile dosen't exist
		fi
	} 2> /dev/null

	return 1 									# Unknown error with read...
}

function takeLockfile
{
	local -r  lockfile_name="${1:-${SCRIPT_NAME}}"
	local -ir lockfile_pid="${2:-$SCRIPT_PID}"

	local lockfile_temp_fullname="${lockfile_name%.sh}-${SCRIPT_NAME%.sh}-${lockfile_pid}-$SCRIPT_PID.tmp-lock"
	local lockfile_fullname="${lockfile_name%.sh}.lock"

	checkFilename "$lockfile_fullname" || errcho ':EXIT:' "function takeLockfile: Invalid file name ! ($lockfile_fullname)"
	checkFilename "$lockfile_temp_fullname" || errcho ':EXIT:' "function takeLockfile: Invalid file name ! ($lockfile_temp_fullname)"

	lockfile_fullname="$PATH_LOCK/$lockfile_fullname"
	lockfile_temp_fullname="$PATH_LOCK/$lockfile_temp_fullname"

	local -i try=5 status file_pid

	while (( try-- > 0 )); do
		checkLockfileOwned "$lockfile_name" "$lockfile_pid" && return 0 || status=$?

		case $status in
			1)
				sleep 0.5
				;;
			2)
				# Create or overwrite the temporary lock file...
				echo "$lockfile_pid" >| "$lockfile_temp_fullname"

				mv -n "$lockfile_temp_fullname" "$lockfile_fullname"
				[[ ! -f "$lockfile_temp_fullname" ]] && {
					(( ++try ))
					scriptPostRemoveFiles+=( "$lockfile_fullname" )
				} || sleep 0.5
				;;
			3)
				break
				;;
			4)
				rm --preserve-root -f "$lockfile_fullname"
				;;
			*)
				break
				;;
		esac

		sleep 0.1
	done

	sleep 0.1
	rm --preserve-root -f "$lockfile_temp_fullname"
	return 1
}

function releaseLockfile
{
	local -r  lockfile_name="${1:-${SCRIPT_NAME}}"
	local -ir lockfile_pid="${2:-$SCRIPT_PID}"

	local lockfile_fullname="${lockfile_name%.sh}.lock"

	checkFilename "$lockfile_fullname" || errcho ':EXIT:' 'function releaseLockfile: Invalid file name !'

	lockfile_fullname="$PATH_LOCK/$lockfile_fullname"
	removeArrayItem scriptPostRemoveFiles 0 "$lockfile_fullname"

	checkLockfileOwned "$lockfile_name" "$lockfile_pid" &&
		rm --preserve-root -f "$lockfile_fullname" ||
		return 1

	return 0
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function checkSectionStatus
{
	local -r section_name="${1}"
	local    section_path="${2:-.}"

	section_path="${section_path%/}"
	section_path="${section_path#/}"

	local -r section_filename="$PATH_TMP/$section_path/section-$section_name.txt"

	[[ -f "$section_filename" ]] &&
	{
		local -l status

		read status < "$section_filename"
		[[ "$status" == 'done' ]] &&
			return 1
	}

	return 0
}

function makeSectionStatusDone
{
	local -r section_name="${1}"
	local    section_path="${2:-.}"

	section_path="${section_path%/}"
	section_path="${section_path#/}"

	checkFilename "$section_name" || errcho ':EXIT:' "Bad section name ! ($section_name)"

	local -r section_filename="$PATH_TMP/$section_path/section-$section_name.txt"

	echo "done" >| "$section_filename"
}

function makeSectionStatusUncompleted
{
	local -r section_name="${1}"
	local    section_path="${2:-.}"

	section_path="${section_path%/}"
	section_path="${section_path#/}"

	checkFilename "$section_name" || errcho ':EXIT:' "Bad section name ! ($section_name)"

	local -r section_filename="$PATH_TMP/$section_path/section-$section_name.txt"

	echo "uncompleted" >| "$section_filename"
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -rf checkLockfileOwned takeLockfile releaseLockfile checkSectionStatus makeSectionStatusDone makeSectionStatusUncompleted



################################################################################
################################################################################
####                                                                        ####
####     Miscellaneous functions                                            ####
####                                                                        ####
################################################################################
################################################################################

function ensureTTY
{
	local no_close="${1:-}"

	[[ -n "$SCRIPT_TTY" ]] || {
		[[ "${no_close^^}" == "NO-CLOSE" ]] && {
			no_close='--noclose'
			shift
		} || no_close=''

		konsole --profile FooPhoenix $no_close -e "$SCRIPT_FULLNAME" 'TTY-OK' "${@}"
		safeExit
	}
}

function ensureRoot
{
	[[ "$(id -nu)" == "root" ]] || {
		sudo "$SCRIPT_FULLNAME" "${@}"
		safeExit
	}
}

function getWordUserChoiceV
{
	local -r return_var_name="${1:+-v $1}"; shift

	local -ar words=( ${*} )

	local -i char_index selected_word
	local    char words_preview="${S_NOYEL}"
	local -u chars='' readed_key
	local -l word

	for word in ${words[@]}; do
		char_index=0
		while (( char_index < ${#word} )); do
			char=${word:$char_index:1}
			if [[ $chars == *${char^^}* ]]; then
				words_preview+="${char}"
			else
				chars+="${char}"
				words_preview+="${S_DA}[${S_BOLYE}${char^^}${S_NOYEL}${S_DA}]${S_NOYEL}"
				(( ++char_index < ${#word} )) && words_preview+="${word:$char_index}"
				words_preview+=" "
				break
			fi
			(( ++char_index ))
		done
	done

	words_preview+="${S_R_AL}: "
	echo -en "$words_preview"

	while (( 1 )); do
		read -sn 1 readed_key

		char_index=0
		selected_word=0
		while (( char_index < ${#chars} )); do
			char=${chars:$char_index:1}
			(( ++char_index ))
			if [[ $char == "$readed_key" ]]; then
				selected_word=$char_index
				break
			fi
		done
		if [ $selected_word -gt 0 ]; then
			break
		fi
	done

	printf $return_var_name '%d' $selected_word
}

# Local static variables :
declare -i _getTimerV_lastSecond=-1
declare    _getTimerV_lastResult=''
function getTimerV
{
	local -r return_var_name="${1:+-v $1}"

	(( _getTimerV_lastSecond != SECONDS )) && {
		local -r time_format="${2:-$getTimerV_Format}"

		TZ=UTC printf -v _getTimerV_lastResult "%($time_format)T" $SECONDS
		_getTimerV_lastSecond=$SECONDS
	}

	printf $return_var_name '%s' "$_getTimerV_lastResult"
}

declare -rf ensureTTY ensureRoot getWordUserChoiceV getTimerV



################################################################################
################################################################################
####                                                                        ####
####     Debug functions                                                    ####
####                                                                        ####
################################################################################
################################################################################

function processTimeResultsV
{
	# Process the content of the array debugTimeResults[] to make the average time.
	# This function reset the debugTimeResults[] array's content !
	#
	# The function return the result in the variable debugTimeResult by default, like that :
	# "0.000s 0.000s 0.000s" (respectively : real time, user time and system time).
	#
	# Be warned ! For efficiency side, this function don't check the validity of the content's format of
	# the array debugTimeResults[] ! Each element in the array is expected to be like "0.000-0.000-0.000" and this function assume
	# all elements are ok.

	local -r return_var_name="${1:-debugTimeResult}"

	(( ${#debugTimeResults[@]} == 0 )) && errcho ':EXIT:' 'function processTimeResults need a non-empty debugTimeResults[] array.'

	local    read_time
	local -i extglob
	local -i real_time=0  user_time=0  system_time=0	# for units parts
	local -i real_time2=0 user_time2=0 system_time2=0	# for decimals parts

	shopt -q extglob &&	extglob=1 || extglob=0

	(( extglob == 1 )) || shopt -s extglob

	# See TIMEFORMAT above for the format of one debugTimeResults value.
	# Normally "0.000-0.000-0.000"
	for read_time in "${debugTimeResults[@]}"; do
		read_time="${read_time//./}"			#		"0.000-0.000-0.000" become "0000-0000-0000" because bash don't know float...
		read_time=( ${read_time//-/ } )			#		"0000-0000-0000" become "0000" "0000" "0000" in an array

		read_time[0]="${read_time[0]##+(0)}"	#		Here all 0 at the start of the string are removed (need extglob on !)
		read_time[1]="${read_time[1]##+(0)}"	#		"0000" become "", "0002" become "2", "0020" become "20"
		read_time[2]="${read_time[2]##+(0)}"	#

		# Adding all number together. if the string in _read_time[x] is empty the default is 0.
		((	real_time   += ${read_time[0]:-0},
			user_time   += ${read_time[1]:-0},
			system_time += ${read_time[2]:-0}, 1 )) # TODO : finish with ")) || : " in place of ", 1 ))" ?
	done

	(( extglob == 1 )) || shopt -u extglob

	# 1 Calculate the average.
	# 2 Get the decimals parts.
	# 3 Get the units parts.
	((	real_time   /= ${#debugTimeResults[@]},
		user_time   /= ${#debugTimeResults[@]},
		system_time /= ${#debugTimeResults[@]},

		real_time2   = real_time   % 1000,
		user_time2   = user_time   % 1000,
		system_time2 = system_time % 1000,

		real_time   /= 1000,
		user_time   /= 1000,
		system_time /= 1000, 1	)) # TODO : finish with ")) || : " in place of ", 1 ))" ?

	printf -v "$return_var_name" '%d.%03ds %d.%03ds %d.%03ds'	$real_time $real_time2 $user_time $user_time2 $system_time $system_time2

	debugTimeResults=( )
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

declare -rf processTimeResultsV


################################################################################
################################################################################
####                                                                        ####
####     Script pre-initialization                                          ####
####                                                                        ####
################################################################################
################################################################################

# Ensure this script is inclued into an other and not executed itself !
[[ "$SCRIPT_NAME" != '.script_common.sh' ]] || errcho ':EXIT:' 'ERROR: The script .script_common.sh need to be inclued in an other script...'

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# Make the ram part of the temporary directory
scriptPostRemoveFiles+=( $(
	declare -r path_tmp_ram="$PATH_RAM_DISK/${PATH_TMP##*/}"

	cd "$PATH_TMP" > /dev/null

	mkdir "$path_tmp_ram"
	ln --symbolic "$path_tmp_ram/" "MEMORY"
	echo "$path_tmp_ram"
) )

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --





#==============================================================================#
#==     Constants post-definition                                            ==#
#==============================================================================#

declare -r SCRIPT_STDERR_FILE="$PATH_TMP/MEMORY/stderr.log"
declare -r SCRIPT_STDERR_PIPE="$PATH_TMP/stderr.pipe"



#==============================================================================#
#==     Globals variables post-definition                                    ==#
#==============================================================================#

declare -a formatSizeV_Colors=( "$S_WHI" "$S_LGR" "$S_GRE" "$S_YEL" "$S_LRE" "$S_RED" "$S_CYA" )
declare    getTimerV_Format='%H:%M:%S'



################################################################################
################################################################################
####                                                                        ####
####     Script post-initialization                                         ####
####                                                                        ####
################################################################################
################################################################################

# Initialize the hooked stderr...
mkfifo "$SCRIPT_STDERR_PIPE"
exec {stderr_pipe}<>"$SCRIPT_STDERR_PIPE" {stderr_backup}>&2 2>&${stderr_pipe}

{
	trap ':' INT QUIT TERM HUP EXIT
	exec {stderr_file}>"$SCRIPT_STDERR_FILE"

	(( $SCRIPT_WINDOWED_STDERR == 1 )) && konsole --profile FooPhoenix -e tail --pid $SCRIPT_PID -qf "$SCRIPT_STDERR_FILE" &

	lastMessage=''
	while IFS= read -u ${stderr_pipe} -t 120 message || checkLoopFail; do
		[[ -n "$message" ]] || continue
		checkLoopEnd "$message" || break

		[[ "$message" == "$lastMessage" ]] && continue
		lastMessage=$"$message"

		printf -v current_time '%(%d.%m.%Y %X)T' -1
		getTimerV 'elapsed_time'
		printf '%s %s %s %s\n' "$current_time" "$elapsed_time" "$SCRIPT_PID" "$message" >&${stderr_file}
	done

	exec {stderr_pipe}<&-
	exec {stderr_file}<&-
} &

[[ "${1:-}" == 'TTY-OK' ]] && {
	shift
	[[ -n "$SCRIPT_TTY" ]] || errcho ':EXIT:' 'ERROR: No TTY available whereas there should be one.'
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

(( SCRIPT_ENSURE_TTY  > 0 )) && ensureTTY $SCRIPT_NEW_TTY_NO_CLOSE "${@}"
(( SCRIPT_ENSURE_LOCKFILE > 0 )) && { takeLockfile || errcho ':EXIT:' 'The lockfile of this script is already in use...'; }
(( SCRIPT_ENSURE_ROOT > 0 )) && ensureRoot "${@}"


################################################################################################################################################################
#
# SCRIPT_START_TIME SCRIPT_NAME SCRIPT_FULLNAME SCRIPT_REAL_FULLNAME SCRIPT_TTY SCRIPT_ENSURE_LOCKFILE SCRIPT_ENSURE_ROOT SCRIPT_ENSURE_TTY SCRIPT_NEW_TTY_NO_CLOSE
# SCRIPT_PID SCRIPT_WINDOWED_STDERR SCRIPT_DARKEN_BOLD PATH_LOG PATH_LOCK PATH_RAM_DISK PATH_TMP PATH_INFRASTRUCTURES PADDING_SPACE PADDING_ZERO ACTION_TAG_SIZE
# LOOP_END_TAG FILENAME_FORBIDEN_CHARS FILENAME_FORBIDEN_NAMES debugTimeIteration debugTimeResults debugTimeResult scriptPostRemoveFiles pipeExpectedEnd pipeReceivedEnd
# pipeParentProcessID removeArrayItem removeArrayDuplicate SCRIPT_DARKEN_BOLD_TAG S_NO S_BO S_DA S_IT S_UN S_BL S_BA S_R_AL S_R_BO S_R_DA S_R_IT S_R_UN S_R_BL S_R_BA
# S_R_CF S_R_CB S_BLA S_RED S_GRE S_YEL S_BLU S_MAG S_CYA S_LGY S_DGY S_LRE S_LGR S_LYE S_LBL S_LMA S_LCY S_WHI S_B_BLA S_B_RED S_B_GRE S_B_YEL S_B_BLU S_B_MAG S_B_CYA
# S_B_LGY S_B_DGY S_B_LRE S_B_LGR S_B_LYE S_B_LBL S_B_LMA S_B_LCY S_B_WHI S_NOBLA S_NORED S_NOGRE S_NOYEL S_NOBLU S_NOMAG S_NOCYA S_NOLGY S_NODGY S_NOLRE S_NOLGR S_NOLYE
# S_NOLBL S_NOLMA S_NOLCY S_NOWHI S_BOBLA S_BORED S_BOGRE S_BOYEL S_BOBLU S_BOMAG S_BOCYA S_BOLGY S_BODGY S_BOLRE S_BOLGR S_BOLYE S_BOLBL S_BOLMA S_BOLCY S_BOWHI
# CO_HIDE CO_SHOW CO_SAVE_POS CO_RESTORE_POS ES_CURSOR_TO_SCREEN_END ES_CURSOR_TO_SCREEN_START ES_ENTIRE_SCREEN ES_CURSOR_TO_LINE_END ES_CURSOR_TO_LINE_START
# ES_ENTIRE_LINE getCSIm getCSI_RGB getCSI_GRAY showRGB_Palette getCSI_CursorMove getCSI_ScreenMove A_IN_PROGRESS A_OK A_FAILED_R A_FAILED_Y A_SUCCESSED A_SKIPPED
# A_ABORTED_NR A_ABORTED_RR A_ABORTED_NY A_WARNING_NR A_WARNING_RR A_WARNING_NY A_ERROR_NR A_ERROR_BR A_ERROR_RR A_UP_TO_DATE_G A_MODIFIED_Y A_UPDATED_Y A_UPDATED_G
# A_ADDED_B A_COPIED_G A_MOVED_G A_REMOVED_R A_EXCLUDED_R A_BACKUPED_G A_EMPTY_TAG A_TAG_LENGTH_SIZE getActionTag errcho checkLoopFail checkLoopEnd getProcessTree safeExit
# formatSizeV_Colors getFileTypeV checkFilename cloneFolderDetails clonePathDetails shortenFileNameV formatSizeV getFileSizeV checkLockfileOwned takeLockfile releaseLockfile
# checkSectionStatus makeSectionStatusDone makeSectionStatusUncompleted ensureTTY ensureRoot getWordUserChoiceV getTimerV processTimeResultsV removeCSI_Tag getCSI_StringLength
# CO_GO_TOP_LEFT CO_UP_1 PADDING_EQUAL A_BACKUPED_Y SO_INSERT_1 screenWidth filenameMaxSize
#
################################################################################################################################################################

function __change_log__
{
	: << 'COMMENT'

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	RELATED COMMIT - 30.07.2019
		Summary : Huge performance optimization.

		Details :	- Huge performance optimization in getTimerV function.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	28.07.2019
		getTimerV function
			- Added two local static variables.
			- Put result in cache and use cache if no difference.
			- Huge performance optimization, but known issue now is time format can't change between cache update !

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	RELATED COMMIT - 26.07.2019
		Summary : Redesigned the return_var_name working way. Optimized the getFileTypeV function.

		Details :	- Optimized and redesigned the getFileTypeV function. !! OUTPUT CHANGE !!
					- Redesigned the return_var_name working way in all functions.
					- Fix some little bugs.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

	26.07.2019
		Since now the change log format will change a bit with new commit details.

	24.07.2019
		Fix : In _postExitProperly function, added the script name to the stderr title.
		Fix : in getFileTypeV function, changed the file_name variable to filename.
		Fix : in getFileTypeV function, let a chance to debug unknown type with an errcho.
		Fix : In _postExitProperly function, added a new line before the stderr title to make it start at the line beginning.
		Fix : Optimized the getFileTypeV function and changed the details order to simplify some basic types recognition.
		Fix : Changing the return_var_name default value to prepend automatically -v if the var name is not empty. (in the whole source code !)

	23.07.2019
		Added SO_INSERT_1 constant.
		Added screenWidth and filenameMaxSize variables.

	22.07.2019
		Added A_BACKUPED_Y constant.

	21.07.2019
		Fix : Now the shortenFileNameV funxtion can accept empty return_var_name.
		Fix : Now the formatSizeV funxtion can accept empty return_var_name.
		Fix : Now the getFileSizeV funxtion can accept empty return_var_name.

	11.07.2019
		Add PADDING_EQUAL constant, and uniformize PADDING_SPACE and PADDING_ZERO generation.

	08.07.2019
		Add the possibility to choose the exit status in safeExit function.

	07.07.2019
		Fix a bug in getCSI_StringLength function that crash with empty string (ie a string with only tags...).
		Fix variable misspelled in shortenFileNameV function.
		Fix variable misspelled in clonePathDetails function.
		Fix bad exit status because of last condition in clonePathDetails and cloneFolderDetails functions.

	01.07.2019
		Add CO_UP_1 constant to move the cursor up by one line.

	29.06.2019
		Add removeCSI_Tag function to remove all CSI tags from a string.
		Add getCSI_StringLength function to count all char from a string wothout counting CSI tags.
		Fix : Allow getTimerV function to work without a return variable name.
		Add CO_GO_TOP_LEFT constant to move the cursor at... top left ;) So, line 1, column 1.
		Add a getTimerV_Format global variable to set a default format for getTimerV function.

	27.06.2019
		Add formatSizeV function.
		Add SCRIPT_ENSURE_LOCKFILE constant and a automatic base lockfile creation.
		Fix : Autorize makeSectionStatusDone and makeSectionStatusUncompled functions to overwrite a section file.
		Make a list of all functions/constants to copy in other script for the autocompletion.

	26.06.2019
		Add ensureRoot function and some constants to ensure the script is executed as root if it need it.
		Add getWordUserChoiceV function (transfered from getSelectableWord function in Make_Backup.sh).
		Fix the variable name var_name to return_var_name in getProcessTree function.
		Create a new source code section named "Criticals sections".
		Add checkSectionStatus, makeSectionStatusDone and makeSectionStatusUncompleted function.
		Add cloneFolderDetails, clonePathDetails, getTimerV and getFileSizeV function.
		Fix : Use the new getTimerV function in the stderr management subshell.
		Add shortenFileNameV function.

	25.06.2019
		Add SCRIPT_TTY constant that contain the current TTY or an empty string if no TTY.
		Add ensureTTY function and some constants to open a konsole if no TTY anvailable and the script need one.
		Fix : Change constant name SCRIPT_PATH to SCRIPT_FULLNAME.
		Fix : Change constant name SCRIPT_REAL_PATH to SCRIPT_REAL_FULLNAME.

	23.06.2019
		Fix missing `local index` declaration in _showDebugDetails function.
		Renormalize variables names inside all functions, and apply flag -i -r -a on `local` declarations.
		Fix extglob variable value (0 or 1) in processTimeResultsV function to be in a more understandable way.
		Fix a bug with SCRIPT_DARKEN_BOLD not working properly.
		Fix : added forgotten S_NOCYA constant, oops...
		Fix : showRGB_Palette function now don't add a new line before the array, but go to the line start anyway.
		Fix checkLoopEnd function : exit with return 0 when loop is ok, return 1 when the loop need to exit...
		Renormalize globals variables names.

	21.06.2019
		Change `readonly` to `declare -r` and include -i for numeric values.
		Make functions readonly.

	19.06.2019
		Add script lockfile management functions. (part 3)
		Add arrays management functions (remove item, remove duplicate item)

	18.06.2019
		Fix : PATH_LOG='/var/log' is not writable for non-root users, so I have make a new folder
				with full rights access, and changed the constant to PATH_LOG='/var/log/userlog'
		Fix : Close the {stderr_pipe} canal on script exit.
		Rebuild all the script exit mechanics... (part 2)
		Add script lockfile management functions. (part 2)
		Fix : Add the PID of the main shell to each log line.
		Fix the _related_pid in checkLoopFail function, to use the correct pipeParentProcessID variable
				instead of the SCRIPT_PID constant.

	11.06.2019
		Rebuild all the script exit mechanics... (part 1)

	10.06.2019
		Add checkFilename function to check if file name is valid or not.
		Add script lockfile management functions. (part 1)
		Fix _exitProperly function, now scriptPostRemoveFiles[] can contain empty string,
				this allow to remove a file in the list.
		Make some optimization with conditions if, [[]], (()), etc... on the whole code.

	09.06.2019
		Add a more generic function to create CSI ANSI codes.
		Add some functions and constants for ANSI cursor and screen manipulation.
		Removed an echoed empty line when the script finish normally without any message.
		Fix some hardcoded ANSI code in _showExitHeader and _showDebugDetails functions.
		Fix hardcoded ANSI code in getProcessTree function.

	04.06.2019
		Add a dummy function __change_log__ to write some... change log ;)
		Add some functions for ANSI colors managements.
		Add the elapsed time since the script start in the stderr log file.
		Fix some ANSI colors constants names conflicts between S_LGR(ay) and S_LGR(een) and others.

COMMENT
}
