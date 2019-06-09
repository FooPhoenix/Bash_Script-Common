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
#														27.05.2019 - 09.06.2019


# Make Bash a bit more robust to bugs...
# 	e = Exit immediatly on commands returning non-zero exit code.
# 	u = Treat unset variables and parameters as an error.
#	C = Prevent output redirection using '>', '>&', and '<>' from overwriting existing files.
# 	E = Any trap on ERR is inherited by shell functions, command substitutions, and commands executed in a subshell environment.
set -eEuC



#==============================================================================#
#==     Constants pre-definition                                             ==#
#==============================================================================#

readonly SCRIPT_START_TIME=$( date '+%s' ) 		# The script start time
readonly SCRIPT_NAME="${0##*/}"
readonly SCRIPT_PATH="${0}"
readonly SCRIPT_REAL_PATH="$(readlink -qsf "${0}")"

readonly SCRIPT_PID="$BASHPID"		# Store the BASHPID value is usefull to give it to a subshell, since use BASHPID don't
									# expand to the good PID inside the subshell itself, and the BASHPPID don't exist...
readonly SCRIPT_END_TAG=':END:'		# Used in pipes to say to a loop it can exit.

readonly SCRIPT_WINDOWED_STDERR="${SCRIPT_WINDOWED_STDERR:-0}"

readonly SCRIPT_ACTION_TAG_SIZE=12

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

unset CDPATH 	# Reserved Bash constant. Security issue : https://bosker.wordpress.com/2012/02/12/bash-scripters-beware-of-the-cdpath/
readonly TIMEFORMAT='%R-%U-%S' 	# Reserved Bash constant to choose the format of `time` command.

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

readonly PATH_LOG='/var/log'
readonly PATH_RAM_DISK='/dev/shm'
readonly PATH_TMP="$(mktemp --tmpdir -d "${SCRIPT_NAME%.sh}-XXXXXXXX.tmp")"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# The Infrastructures path can be overrided just before including this script...
readonly PATH_INFRASTRUCTURES="${PATH_INFRASTRUCTURES:-/media/foophoenix/AppKDE/Infrastructures}"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

readonly SPACE_PADDING='                                                                                                                                                                                                                                                               '
readonly ZERO_PADDING='00000000000000000000'

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --




#==============================================================================#
#==     Globals variables pre-definition                                     ==#
#==============================================================================#

time_iteration=10	# Default number of iteration to do with `time`
time_results=( )	# Array to store results of `time`
time_result=''		# The default variable

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

post_script_remove_files=( "$PATH_TMP" )

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

pipe_expected_end=1
pipe_received_end=0
pipe_parent_process_id=''



################################################################################
################################################################################
####                                                                        ####
####     ANSI CSI sequences constants and functions                         ####
####                                                                        ####
################################################################################
################################################################################

function _getCSI
{
	local IFS=';'
	local _type="${1}"; shift
	local _parameters="${*}"

	echo -n "\e[${_parameters}${_type}"
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

readonly _CSIM_BOLD='1'
readonly _CSIM_DARK='2'
readonly _CSIM_ITALIC='3'
readonly _CSIM_UNDERLINE='4'
readonly _CSIM_BLINK='5'
readonly _CSIM_BARRED='9'

readonly _CSIM_RESET_ALL='0'
readonly _CSIM_RESET_BOLD='21'
readonly _CSIM_RESET_DARK='22'
readonly _CSIM_RESET_ITALIC='23'
readonly _CSIM_RESET_UNDERLINE='24'
readonly _CSIM_RESET_BLINK='25'
readonly _CSIM_RESET_BARRED='29'
readonly _CSIM_RESET_COLORF='39'
readonly _CSIM_RESET_COLORB='49'

readonly _CSIM_FOREGROUND_BLACK='30'
readonly _CSIM_FOREGROUND_RED='31'
readonly _CSIM_FOREGROUND_GREEN='32'
readonly _CSIM_FOREGROUND_YELLOW='33'
readonly _CSIM_FOREGROUND_BLUE='34'
readonly _CSIM_FOREGROUND_MAGENTA='35'
readonly _CSIM_FOREGROUND_CYAN='36'
readonly _CSIM_FOREGROUND_LIGHT_GRAY='37'
readonly _CSIM_FOREGROUND_DARK_GRAY='90'
readonly _CSIM_FOREGROUND_LIGHT_RED='91'
readonly _CSIM_FOREGROUND_LIGHT_GREEN='92'
readonly _CSIM_FOREGROUND_LIGHT_YELLOW='93'
readonly _CSIM_FOREGROUND_LIGHT_BLUE='94'
readonly _CSIM_FOREGROUND_LIGHT_MAGENTA='95'
readonly _CSIM_FOREGROUND_LIGHT_CYAN='96'
readonly _CSIM_FOREGROUND_WHITE='97'

readonly _CSIM_BACKGROUND_BLACK='40'
readonly _CSIM_BACKGROUND_RED='41'
readonly _CSIM_BACKGROUND_GREEN='42'
readonly _CSIM_BACKGROUND_YELLOW='43'
readonly _CSIM_BACKGROUND_BLUE='44'
readonly _CSIM_BACKGROUND_MAGENTA='45'
readonly _CSIM_BACKGROUND_CYAN='46'
readonly _CSIM_BACKGROUND_LIGHT_GRAY='47'
readonly _CSIM_BACKGROUND_DARK_GRAY='100'
readonly _CSIM_BACKGROUND_LIGHT_RED='101'
readonly _CSIM_BACKGROUND_LIGHT_GREEN='102'
readonly _CSIM_BACKGROUND_LIGHT_YELLOW='103'
readonly _CSIM_BACKGROUND_LIGHT_BLUE='104'
readonly _CSIM_BACKGROUND_LIGHT_MAGENTA='105'
readonly _CSIM_BACKGROUND_LIGHT_CYAN='106'
readonly _CSIM_BACKGROUND_WHITE='107'

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function getCSIm
{
	_getCSI 'm' "${@}"
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

readonly S_NO="$(getCSIm ${_CSIM_RESET_ALL})"	# NO > NORMAL
readonly S_BO="$(getCSIm ${_CSIM_BOLD})"
readonly S_DA="$(getCSIm ${_CSIM_DARK})"
readonly S_IT="$(getCSIm ${_CSIM_ITALIC})"
readonly S_UN="$(getCSIm ${_CSIM_UNDERLINE})"
readonly S_BL="$(getCSIm ${_CSIM_BLINK})"
readonly S_BA="$(getCSIm ${_CSIM_BARRED})"

readonly S_R_AL="$(getCSIm ${_CSIM_RESET_ALL})"
readonly S_R_BO="$(getCSIm ${_CSIM_RESET_BOLD})"
readonly S_R_DA="$(getCSIm ${_CSIM_RESET_DARK})"
readonly S_R_IT="$(getCSIm ${_CSIM_RESET_ITALIC})"
readonly S_R_UN="$(getCSIm ${_CSIM_RESET_UNDERLINE})"
readonly S_R_BL="$(getCSIm ${_CSIM_RESET_BLINK})"
readonly S_R_BA="$(getCSIm ${_CSIM_RESET_BARRED})"
readonly S_R_CF="$(getCSIm ${_CSIM_RESET_COLORF})"
readonly S_R_CB="$(getCSIm ${_CSIM_RESET_COLORB})"

(( ${SCRIPT_DARKEN_BOLD:-1} == 1 )) &&
	readonly SCRIPT_DARKEN_BOLD="${S_DA}" ||
	readonly SCRIPT_DARKEN_BOLD=''

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# FOREGROUND COLOR
readonly S_BLA="$(getCSIm ${_CSIM_FOREGROUND_BLACK})"
readonly S_RED="$(getCSIm ${_CSIM_FOREGROUND_RED})"
readonly S_GRE="$(getCSIm ${_CSIM_FOREGROUND_GREEN})"
readonly S_YEL="$(getCSIm ${_CSIM_FOREGROUND_YELLOW})"
readonly S_BLU="$(getCSIm ${_CSIM_FOREGROUND_BLUE})"
readonly S_MAG="$(getCSIm ${_CSIM_FOREGROUND_MAGENTA})"
readonly S_CYA="$(getCSIm ${_CSIM_FOREGROUND_CYAN})"
readonly S_LGY="$(getCSIm ${_CSIM_FOREGROUND_LIGHT_GRAY})"
readonly S_DGY="$(getCSIm ${_CSIM_FOREGROUND_DARK_GRAY})"
readonly S_LRE="$(getCSIm ${_CSIM_FOREGROUND_LIGHT_RED})"
readonly S_LGR="$(getCSIm ${_CSIM_FOREGROUND_LIGHT_GREEN})"
readonly S_LYE="$(getCSIm ${_CSIM_FOREGROUND_LIGHT_YELLOW})"
readonly S_LBL="$(getCSIm ${_CSIM_FOREGROUND_LIGHT_BLUE})"
readonly S_LMA="$(getCSIm ${_CSIM_FOREGROUND_LIGHT_MAGENTA})"
readonly S_LCY="$(getCSIm ${_CSIM_FOREGROUND_LIGHT_CYAN})"
readonly S_WHI="$(getCSIm ${_CSIM_FOREGROUND_WHITE})"

# BACKGROUND COLOR
readonly S_B_BLA="$(getCSIm ${_CSIM_BACKGROUND_BLACK})"
readonly S_B_RED="$(getCSIm ${_CSIM_BACKGROUND_RED})"
readonly S_B_GRE="$(getCSIm ${_CSIM_BACKGROUND_GREEN})"
readonly S_B_YEL="$(getCSIm ${_CSIM_BACKGROUND_YELLOW})"
readonly S_B_BLU="$(getCSIm ${_CSIM_BACKGROUND_BLUE})"
readonly S_B_MAG="$(getCSIm ${_CSIM_BACKGROUND_MAGENTA})"
readonly S_B_CYA="$(getCSIm ${_CSIM_BACKGROUND_CYAN})"
readonly S_B_LGY="$(getCSIm ${_CSIM_BACKGROUND_LIGHT_GRAY})"
readonly S_B_DGY="$(getCSIm ${_CSIM_BACKGROUND_DARK_GRAY})"
readonly S_B_LRE="$(getCSIm ${_CSIM_BACKGROUND_LIGHT_RED})"
readonly S_B_LGR="$(getCSIm ${_CSIM_BACKGROUND_LIGHT_GREEN})"
readonly S_B_LYE="$(getCSIm ${_CSIM_BACKGROUND_LIGHT_YELLOW})"
readonly S_B_LBL="$(getCSIm ${_CSIM_BACKGROUND_LIGHT_BLUE})"
readonly S_B_LMA="$(getCSIm ${_CSIM_BACKGROUND_LIGHT_MAGENTA})"
readonly S_B_LCY="$(getCSIm ${_CSIM_BACKGROUND_LIGHT_CYAN})"
readonly S_B_WHI="$(getCSIm ${_CSIM_BACKGROUND_WHITE})"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# NORMAL + FOREGROUND COLOR
readonly S_NOBLA="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_BLACK})"
readonly S_NORED="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_RED})"
readonly S_NOGRE="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_GREEN})"
readonly S_NOYEL="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_YELLOW})"
readonly S_NOBLU="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_BLUE})"
readonly S_NOMAG="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_MAGENTA})"
readonly S_NOCYA="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_CYAN})"
readonly S_NOLGY="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_LIGHT_GRAY})"
readonly S_NODGY="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_DARK_GRAY})"
readonly S_NOLRE="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_LIGHT_RED})"
readonly S_NOLGR="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_LIGHT_GREEN})"
readonly S_NOLYE="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_LIGHT_YELLOW})"
readonly S_NOLBL="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_LIGHT_BLUE})"
readonly S_NOLMA="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_LIGHT_MAGENTA})"
readonly S_NOLCY="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_LIGHT_CYAN})"
readonly S_NOWHI="$(getCSIm ${_CSIM_RESET_ALL} ${_CSIM_FOREGROUND_WHITE})"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# BOLD + FOREGROUND COLOR
readonly S_BOBLA="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_BLACK})"
readonly S_BORED="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_RED})"
readonly S_BOGRE="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_GREEN})"
readonly S_BOYEL="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_YELLOW})"
readonly S_BOBLU="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_BLUE})"
readonly S_BOMAG="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_MAGENTA})"
readonly S_BOCYA="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_CYAN})"
readonly S_BOLGY="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_LIGHT_GRAY})"
readonly S_BODGY="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_DARK_GRAY})"
readonly S_BOLRE="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_LIGHT_RED})"
readonly S_BOLGR="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_LIGHT_GREEN})"
readonly S_BOLYE="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_LIGHT_YELLOW})"
readonly S_BOLBL="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_LIGHT_BLUE})"
readonly S_BOLMA="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_LIGHT_MAGENTA})"
readonly S_BOLCY="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_LIGHT_CYAN})"
readonly S_BOWHI="${SCRIPT_DARKEN_BOLD}$(getCSIm ${_CSIM_BOLD} ${_CSIM_FOREGROUND_WHITE})"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function getCSI_RGB
{
	local R="${1:?unbound variable: function getCSI_RGB need red, green and blue values !}"
	local G="${2:?unbound variable: function getCSI_RGB need red, green and blue values !}"
	local B="${3:?unbound variable: function getCSI_RGB need red, green and blue values !}"

	local D="${4:-}"

	[[ "$D" == 'B' ]] && D='48' || D='38'

	local _regex='^[0-5]$'

	[[ "$R" =~ $_regex ]] || R=5
	[[ "$G" =~ $_regex ]] || G=5
	[[ "$B" =~ $_regex ]] || B=5

	local _color=$(( 16 + ((R * 36) + (G * 6) + B) ))

	getCSIm $D 5 $_color
}

function getCSI_GRAY
{
	local G="$1"

	local D="${2:-}"

	[[ "$D" == 'B' ]] && D='48' || D='38'

	local _regex='^[1-9]?[0-9]$'

	[[ "$G" =~ $_regex ]] || G='12'
	(( G > 23 )) && G='23'

	local _color=$(( 232 + G ))

	getCSIm $D 5 $_color
}

function showRGB_Palette
{
	local R G B F _index

	echo -e "${S_NO}"

	for R in {0..5}; do
		for G in {0..5}; do
			echo -e "${S_NO}"

			(( G < 3 )) && F='23' || F='0'

			for B in {0..5}; do
				echo -en "$(getCSI_GRAY $F)$(getCSI_RGB $R $G $B B)   $R-$G-$B   "
			done
		done
	done

	echo -e "${S_NO}"

	_index=0
	for G in {0..23}; do
		(( _index < 12 )) && F='23' || F='0'

		echo -en "$(getCSI_GRAY $F)$(getCSI_GRAY $G B)    $(printf '%3s' $_index)    "
		(( ++_index % 6 == 0 )) && echo -e "${S_NO}"
	done
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function getCSI_CursorMove
{
	# Possible direction :
	#		Left, Right =				Move the cursor from their current location to the direction by ${2} characters.
	#		Up, Down =					Move the cursor from their current location to the direction by ${2} lines.
	#		Column =					Move the cursor to the ${2} column of the current line.
	#		Position =					Move the cursor to the ${2} line and the ${3} column.

	local _direction="${1:?unbound variable: function getCSI_CursorMove need a direction...}"
	local _number1="${2:-}"
	local _number2="${3:-}"

	_direction="${_direction:0:1}"

	_direction="$( echo "${_direction^^}" | tr 'PCUDRL' 'HGABCD' )"
	[[ "$_number1" != '' ]] && (( _number1 )) # if _number1 is not empty then if _number1 == 0 or is not a number raise an error, otherwith continue
	[[ 'HGABCD' == *${_direction}* ]] || errcho ':EXIT:' 'function getCSI_CursorMove need a valid direction...'

	[[ "${_direction}" == 'H' ]] &&	[[ "$_number2" != '' ]] &&
		{
			(( _number2 ))
			_getCSI "${_direction}" "${_number1}" "${_number2}"
			return 0
		}

	_getCSI "${_direction}" "${_number1}"
}

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

readonly CO_HIDE="$(_getCSI 'l' '?25')"
readonly CO_SHOW="$(_getCSI 'h' '?25')"

readonly CO_SAVE_POS="$(_getCSI 's')"
readonly CO_RESTORE_POS="$(_getCSI 'u')"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

readonly ES_CURSOR_TO_SCREEN_END="$(_getCSI 'J' '0')"
readonly ES_CURSOR_TO_SCREEN_START="$(_getCSI 'J' '1')"
readonly ES_ENTIRE_SCREEN="$(_getCSI 'J' '2')"

readonly ES_CURSOR_TO_LINE_END="$(_getCSI 'K' '0')"
readonly ES_CURSOR_TO_LINE_START="$(_getCSI 'K' '1')"
readonly ES_ENTIRE_LINE="$(_getCSI 'K' '2')"

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

function getCSI_ScreenMove
{
	local _direction="${1:?unbound variable: function getCSI_ScreenMove need a direction...}"
	local _number="${2:-}"

	_direction="${_direction:0:1}"

	_direction="$( echo "${_direction^^}" | tr 'UDIR' 'STLM' )"
	[[ "$_number" != '' ]] && (( _number )) # if _number1 is not empty then if _number1 == 0 or is not a number raise an error, otherwith continue
	[[ 'STLM' == *${_direction}* ]] || errcho ':EXIT:' 'function getCSI_ScreenMove need a valid direction...'

	_getCSI "${_direction}" "${_number}"
}



################################################################################
################################################################################
####                                                                        ####
####     Actions tags declaration                                           ####
####                                                                        ####
################################################################################
################################################################################

function getActionTag
{
	local _tag_name="${1:?unbound variable: function getActionTag need a action tag name !}"
	local _tag_color="${2:-}"

	local _tag_name_size1 _tag_name_size2

	((	_tag_name_size1 = SCRIPT_ACTION_TAG_SIZE - ${#_tag_name},
		_tag_name_size2 = (_tag_name_size1 / 2) + (_tag_name_size1 % 2),
		_tag_name_size1 = (_tag_name_size1 / 2)		))

	echo "${S_NOWHI}[${_tag_color}${SPACE_PADDING:0:$_tag_name_size1}${_tag_name}${SPACE_PADDING:0:$_tag_name_size2}${S_NOWHI}]${S_R_AL}"
}

readonly A_IN_PROGRESS="$(getActionTag 'IN PROGRESS' "$S_NO")"
readonly A_OK="$(getActionTag 'OK' "$S_GRE")"
readonly A_FAILED_R="$(getActionTag 'FAILED' "$S_RED")"
readonly A_FAILED_Y="$(getActionTag 'FAILED' "$S_YEL")"
readonly A_SUCCESSED="$(getActionTag 'SUCCESSED' "$S_GRE")"
readonly A_SKIPPED="$(getActionTag 'SKIPPED' "$S_CYA")"

readonly A_ABORTED_NR="$(getActionTag 'ABORTED' "$S_RED")"
readonly A_ABORTED_RR="$(getActionTag 'ABORTED' "$S_B_RED$S_BLA")"
readonly A_ABORTED_NY="$(getActionTag 'ABORTED' "$S_YEL")"

readonly A_WARNING_NR="$(getActionTag 'WARNING' "$S_RED")"
readonly A_WARNING_RR="$(getActionTag 'WARNING' "$S_B_RED$S_BLA")"
readonly A_WARNING_NY="$(getActionTag 'WARNING' "$S_YEL")"

readonly A_ERROR_NR="$(getActionTag 'ERROR' "$S_RED")"
readonly A_ERROR_BR="$(getActionTag 'ERROR' "$S_BL$S_RED")"
readonly A_ERROR_RR="$(getActionTag 'ERROR' "$S_B_RED$S_BLA")"

readonly A_UP_TO_DATE_G="$(getActionTag 'UP TO DATE' "$S_GRE")"
readonly A_MODIFIED_Y="$(getActionTag 'MODIFIED' "$S_YEL")"
readonly A_UPDATED_Y="$(getActionTag 'UPDATED' "$S_YEL")"
readonly A_UPDATED_G="$(getActionTag 'UPDATED' "$S_GRE")"
readonly A_ADDED_B="$(getActionTag 'ADDED' "$S_LBL")"
readonly A_COPIED_G="$(getActionTag 'COPIED' "$S_GRE")"
readonly A_MOVED_G="$(getActionTag 'MOVED' "$S_GRE")"
readonly A_REMOVED_R="$(getActionTag 'REMOVED' "$S_RED")"
readonly A_EXCLUDED_R="$(getActionTag 'EXCLUDED' "$S_RED")"
readonly A_BACKUPED_G="$(getActionTag 'BACKUPED' "$S_GRE")"

readonly A_EMPTY_TAG="$(getActionTag '  ' "$S_NO")"
readonly A_TAG_LENGTH_SIZE="${SPACE_PADDING:0:$(( SCRIPT_ACTION_TAG_SIZE + 2 ))}"



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

	local _line="${BASH_LINENO[0]}"
	local _source="${BASH_SOURCE[1]}"
	local _need_exit=0

	local _regex="^:EXIT:([0-9]+)?$"

	# Check here if the function has received an :EXIT: tag.
	if [[ "${1:?unbound variable: errcho need at least one parameter !}" =~ $_regex ]]; then
		_need_exit=${BASH_REMATCH[1]:-1} 		# If BASH_REMATCH[1] is empty or unset, force it to be 1
		_need_exit=$(( _need_exit == 0 ? 1 : _need_exit )) 		# :EXIT:0 has no sense after an error, force it to be :EXIT:1
		shift
	fi

	echo "$_source: line $_line: ${@}" >&2

 	[[ $_need_exit != 0 ]] && exit $_need_exit || return 0
}

function checkLoopFail
{
	# This function check if a loop in a subshell need to exit or not.
	#
	# The loop exit immediately if the parent shell unexpectedly exit.
	# This is a anti infinite loop security.

	local _related_pid="${1:-$SCRIPT_PID}"

	(( $(ps -p $_related_pid -ho pid || echo 0) != $_related_pid )) && return 1

	sleep 0.5
	return 0
}

function checkLoopEnd
{
	# This function check if a loop in a subshell need to exit or not.
	#
	# The loop exit normally if a SCRIPT_END_TAG is received via a pipe.

	[[ "${1:?unbound variable: function checkLoopEnd has a mendatory argument !}" == "$SCRIPT_END_TAG" ]] &&
		(( ++pipe_received_end, pipe_received_end >= pipe_expected_end )) && return 0

	return 1
}

function getProcessTree()
{
	local _var_name="${1:-}"
	local _pid _ppid _command _ppids=( ) _commands=( )

	# Take all elements given by `ps` and store it in arrays.
	# The index of elements is its PID !
	while read -r _pid _ppid _command ; do
		_ppids[$_pid]="$_ppid"
		_commands[$_pid]="$_command"
	done <<< $(ps --no-headers -ax -o pid:5,ppid:5,command ) # For debug : ps --no-headers --forest -ax -o pid:5,ppid:5,command

	#---------------------------------------------------------------------------

	# Build the list of parents process and children process and store it in _pids[]
	# The _children[] array will store how many children has each process
	# The _relationship[] array will manage the output color, 0 = no relation, 1 = parent tree, 2 = myself, 3 = children tree

	local _current_pid="$BASHPID" _pids=( ) _children=( ) _relationship=( )

	# Build parents process list here
	_pid=$_current_pid
	while (( 1 )); do
		_pids+=( $_pid ) # add the current pid
		_pid=${_ppids[$_pid]} # retreive the ppid of the current pid
		_children[$_pid]=1
		_relationship[$_pid]=1
		if (( _pid == 1 )); then
			break
		fi
	done

	local _index _check_pid _children_pids

	# Build children process list here
	_children_pids=( $_current_pid ) # Contain the list of all pid waiting to be evaluated
	_children[$_current_pid]=0
	_relationship[$_current_pid]=2
	_index=0
	while (( _index < ${#_children_pids[@]} )); do
		_pid=${_children_pids[$_index]}
		if (( _pid != 0 )); then
			for _check_pid in ${!_ppids[@]}; do # ${!_ppids[@]} return the list of all pid because each ppid has their own pid as key
				if (( _pid == _ppids[_check_pid] )); then
					_pids+=( $_check_pid ) # add the current checked pid
					_relationship[$_check_pid]=3
					_children[$_check_pid]=0
					(( ++_children[_pid] )) # add one children
					_children_pids+=( $_check_pid ) # add this pid to be evaluated later
				fi
			done
		fi
		(( ++_index ))
	done

	#---------------------------------------------------------------------------

	# sort all pid
	_pids=( $(printf "%s\n" "${_pids[@]}" | sort -n ) )

	# Build children process of the root process in the tree
	_children_pids=( ${_pids[0]} ) # Contain the list of all pid waiting to be evaluated
	_index=0
	while (( _index < ${#_children_pids[@]} )); do
		_pid=${_children_pids[$_index]}
		if (( _pid != 0 )); then
			for _check_pid in ${!_ppids[@]}; do # ${!_ppids[@]} return the list of all pid because each ppid has their own pid as key
				if (( _pid == _ppids[_check_pid] )); then
					if (( _relationship[_check_pid] == 0 )); then # if _relationship[_check_pid] is not 0, so this pid is already in the list, just do nothing
						_pids+=( $_check_pid ) # add the current checked pid
						_relationship[$_check_pid]=0
						_children[$_check_pid]=${_children[$_check_pid]:-0}
						(( ++_children[_pid] )) # add one children
					fi
					_children_pids+=( $_check_pid ) # add this pid to be evaluated later
				fi
			done
		fi
		(( ++_index ))
	done

	#---------------------------------------------------------------------------

	# sort all pid
	_pids=( $(printf "%s\n" "${_pids[@]}" | sort -n ) )

	#---------------------------------------------------------------------------

	local _level _output='' _screen_size=$(( $(tput cols) - 6 ))

	_children_pids=( ${_pids[0]} )
	_index=0
	while (( ${#_children_pids[@]} > 0 )); do

		_pid=${_children_pids[$_index]}
		unset -v _children_pids[$_index]
		_index=$(( _index - 1 ))
		_children_pids=( ${_children_pids[@]} ) # Rebuild all index keys to be continuous

		_check_pid=${_ppids[$_pid]}
		_children[$_check_pid]=$(( _children[$_check_pid] - 1 ))

		for _check_pid in ${_pids[@]}; do
			if (( _pid == _ppids[_check_pid] )); then
				_children_pids+=( $_check_pid )
				_index=$(( _index + 1 ))
			fi
		done

		_command=''

		_check_pid=$_pid
		_level=0
		while (( 1 )); do
			_check_pid=${_ppids[$_check_pid]}
			if (( _check_pid == 1 )); then
				break
			fi
			if (( _children[_check_pid] > 0 )); then
				if (( _level == 0 )); then
					_command="+-$_command"
				else
					_command="| $_command"
				fi
			else
				if (( _level == 0 )); then
					_command="+-$_command"
				else
					_command="  $_command"
				fi
			fi
			(( ++_level ))
		done

		(( _level = _screen_size - ((_level * 2) + 4) ))

		case ${_relationship[$_pid]} in
			0)
				_command="${_command}??? ${_commands[$_pid]:0:$_level}"	;;
			1)
				_command="${_command}\e[2;33m?\e[0m?? \e[2;33m${_commands[$_pid]:0:$_level}\e[0m"	;;
			2)
				_command="${_command}\e[0;31m?\e[0m?? \e[0;31m${_commands[$_pid]:0:$_level}\e[0m"	;;
			3)
				_command="${_command}\e[0;33m?\e[0m?? \e[0;33m${_commands[$_pid]:0:$_level}\e[0m"	;;
		esac

		printf -v _pid '%5d' $_pid
		[[ -z "$_var_name" ]] &&
			echo -e "${_output}${_pid} ${_command}" ||
			_output="${_output}${_pid} ${_command}\n"

#  		echo -e "${_pid} ${_command}"
	done

	[[ -n "$_var_name" ]] &&
		printf -v $_var_name '%s' "$_output"

	return 0
}

function _showExitHeader
{
	local _exit_tag="${1:-NO}"
	local _exit_reason="${2:-}"

	[[ "$_exit_tag" == 'NO' ]] && return 0

	local _crash_time _crash_after

	printf -v _crash_time '%(%A %-d %B %Y @ %X)T' -1
	TZ=UTC printf -v _crash_after '%(%X)T' $SECONDS

	echo
	echo -en "\r\e[0J"									########### TODO e[0J ???
	echo -e "${_exit_tag} ${_exit_reason}"
	echo -e "This has happened at ${S_NOWHI}${_crash_time}${S_NO}, after the script has run for ${S_NOWHI}${_crash_after}${S_NO}..."
	echo
}

function _showDebugDetails
{
	local _line_number="${1}"
	local _subshell_level="${2}"
	local _last_exit_status="${3}"
	local _last_command="${4}"

	echo -e "${S_NOWHI}Calls history :${S_NO}"
	for _index in ${!BASH_LINENO[@]}; do
		printf '%5d ' ${BASH_LINENO[$_index]}
		echo -e "${FUNCNAME[$_index]} \e[2m( in ${BASH_SOURCE[$_index]} )\e[0m"
	done
	echo

	echo -e "Error reported near ${S_NOWHI}the line $_line_number${S_NO}, last known exit status is ${S_NOWHI}$_last_exit_status${S_NO}, the last executed command is :\n"
	echo -e "\t${S_NOYEL}$_last_command${S_NO}"
	echo

	echo -e "${S_NOWHI}  PID   Commands${S_NO}"
	getProcessTree
	echo
}

function _exitProperly
{
	# Reset all trap to default...
	trap - EXIT INT QUIT TERM HUP ERR

	# Desactive the hooked stderr...
	echo "$SCRIPT_END_TAG" >&2
	sleep 1
	exec 2>&${stderr_backup}

	if (( $(wc -l < "$SCRIPT_STDERR_FILE") > 0 )); then
		echo -e "${S_NOWHI}While it was running, the script has ouptut this on the STDERR :${S_NO}"
		cat "$SCRIPT_STDERR_FILE" >&2
		echo
	fi

	local _file_name

	# Remove all temporaries files...
	for _file_name in "${post_script_remove_files[@]}"; do
		if [[ -d "$_file_name" ]]; then
			rm --preserve-root -f -r "$_file_name"
		else
			rm --preserve-root -f "$_file_name"
		fi
	done
}

function safeExit
{
	_showExitHeader 'NO'
	_exitProperly
	exit 0
}

function unexpectedExit
{
	local _line_number="${1}"
	local _subshell_level="${2}"
	local _last_exit_status="${3}"
	local _last_command="${4}"

	_showExitHeader "$A_ERROR_NR" "The script has unexpectedly exited for an unknown reason."
	_showDebugDetails "$_line_number" "$_subshell_level" "$_last_exit_status" "$_last_command"
	_exitProperly
	exit 1
}

function interruptExit		# CTRL-C
{
	_showExitHeader "$A_ABORTED_NY" "The script has exited because used has pressed [CTRL]-[C]."
	_exitProperly
	exit 1
}

function terminateExit		# `kill`
{
	_showExitHeader "$A_ABORTED_NY" "The script has stopped because the signal TERM has been received."
	_exitProperly
	exit 1
}

function errorExit
{
	local _line_number="${1}"
	local _subshell_level="${2}"
	local _last_exit_status="${3}"
	local _last_command="${4}"

	_showExitHeader "$A_ERROR_BR" "The script has crashed because of an unexpected error."
	_showDebugDetails "$_line_number" "$_subshell_level" "$_last_exit_status" "$_last_command"
	_exitProperly
	exit 1
}

trap 'unexpectedExit "$LINENO" "$BASH_SUBSHELL" "$?" "$BASH_COMMAND"' EXIT
trap 'interruptExit' INT QUIT
trap 'terminateExit' TERM HUP
trap 'errorExit "$LINENO" "$BASH_SUBSHELL" "$?" "$BASH_COMMAND"' ERR



################################################################################
################################################################################
####                                                                        ####
####     Filenames and paths functions                                      ####
####                                                                        ####
################################################################################
################################################################################

function getFileTypeV
{
	local _file_name="${1:?unbound variable: function getFileTypeV need a filename to check !}"

	local _return_var_name="${2:-file_type}"

	local _type _exist _link

	[[ -L "$_file_name" ]] && _link='l' || _link=' '
	if [[ -e "$_file_name" ]]; then
		_exist='E'
		if [[ -f "$_file_name" ]]; then
			_type='f'
		elif [[ -d "$_file_name" ]]; then
			_type='d'
		elif [[ -p "$_file_name" ]]; then
			_type='p'
		elif [[ -S "$_file_name" ]]; then
			_type='s'
		elif [[ -b "$_file_name" ]]; then
			_type='b'
		elif [[ -c "$_file_name" ]]; then
			_type='c'
		else
			_type='?'
		fi
	else
		_exist=' '
		_type=' '
	fi

	printf -v "$_return_var_name" '%s%s%s' "$_exist" "$_link" "$_type"
}



################################################################################
################################################################################
####                                                                        ####
####     Debug functions                                                    ####
####                                                                        ####
################################################################################
################################################################################

function processTimeResultsV
{
	# Process the content of the array time_results[] to make the average time.
	# This function reset the time_results[] array's content !
	#
	# The function return the result in the variable time_result by default, like that :
	# "0.000s 0.000s 0.000s" (respectively : real time, user time and system time).
	#
	# Be warned ! For efficiency side, this function don't check the validity of the content's format of
	# the array time_results[] ! Each element in the array is expected to be like "0.000-0.000-0.000" and this function assume
	# all elements are ok.

	local _return_var_name="${1:-time_result}"

	(( ${#time_results[@]} == 0 )) && errcho ':EXIT:' 'function processTimeResults need a non-empty time_results[] array.'

	local _read_time _extglob
	local _real_time=0 _user_time=0 _system_time=0		# for units parts
	local _real_time2=0 _user_time2=0 _system_time2=0	# for decimals parts

	shopt -q extglob
	_extglob="$?"

	[[ $_extglob -eq 1 ]] && shopt -s extglob

	# See TIMEFORMAT above for the format of one time_results value.
	# Normally "0.000-0.000-0.000"
	for _read_time in "${time_results[@]}"; do
		_read_time="${_read_time//./}"			#		"0.000-0.000-0.000" become "0000-0000-0000" because bash don't know float...
		_read_time=( ${_read_time//-/ } )		#		"0000-0000-0000" become "0000" "0000" "0000" in an array

		_read_time[0]="${_read_time[0]##+(0)}"	#		Here all 0 at the start of the string are removed (need extglob on !)
		_read_time[1]="${_read_time[1]##+(0)}"	#		"0000" become "", "0002" become "2", "0020" become "20"
		_read_time[2]="${_read_time[2]##+(0)}"	#

		# Adding all number together. if the string in _read_time[x] is empty the default is 0.
		((	_real_time   += ${_read_time[0]:-0},
			_user_time   += ${_read_time[1]:-0},
			_system_time += ${_read_time[2]:-0}, 1 ))
	done

	[[ $_extglob -eq 1 ]] && shopt -u extglob

	# 1 Calculate the average.
	# 2 Get the decimals parts.
	# 3 Get the units parts.
	((	_real_time   /= ${#time_results[@]},
		_user_time   /= ${#time_results[@]},
		_system_time /= ${#time_results[@]},

		_real_time2   = _real_time   % 1000,
		_user_time2   = _user_time   % 1000,
		_system_time2 = _system_time % 1000,

		_real_time   /= 1000,
		_user_time   /= 1000,
		_system_time /= 1000, 1	))

	printf -v "$_return_var_name" '%d.%03ds %d.%03ds %d.%03ds'	$_real_time $_real_time2 $_user_time $_user_time2 $_system_time $_system_time2

	time_results=( )
}



################################################################################
################################################################################
####                                                                        ####
####     Script pre-initialization                                          ####
####                                                                        ####
################################################################################
################################################################################

# Ensure this script is inclued into an other and not executed itself !
[[ "$SCRIPT_NAME" == '.script_common.sh' ]] && errcho ':EXIT:' 'ERROR: The script .script_common.sh need to be inclued in an other script...'

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# Make the ram part of the temporary directory
post_script_remove_files+=( $(
	path_tmp_ram="$PATH_RAM_DISK/${PATH_TMP##*/}"

	cd "$PATH_TMP" > /dev/null

	mkdir "$path_tmp_ram"
	ln --symbolic "$path_tmp_ram/" "MEMORY"
	echo "$path_tmp_ram"
) )

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --





#==============================================================================#
#==     Constants post-definition                                            ==#
#==============================================================================#

readonly SCRIPT_STDERR_FILE="$PATH_TMP/MEMORY/stderr.log"
readonly SCRIPT_STDERR_PIPE="$PATH_TMP/stderr.pipe"

#==============================================================================#
#==     Globals variables post-definition                                    ==#
#==============================================================================#



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

	while read -u ${stderr_pipe} -t 120 message || checkLoopFail; do
		[[ -z "$message" ]] && continue
		checkLoopEnd "$message" && break

		printf -v current_time '%(%X)T' -1
		TZ=UTC printf -v elapsed_time '%(%X)T' $SECONDS
		printf '[%s - %s] %s\n' "$current_time" "$elapsed_time" "$message" >&${stderr_file}
	done

	exec {stderr_pipe}<&-
	exec {stderr_file}<&-
} &



################################################################################
################################################################################



function __change_log__
{
	: << 'COMMENT'

	09.06.2019
		Add a more generic function to create CSI ANSI codes.
		Add some functions and constants for ANSI cursor and screen manipulation.
		Removed an echoed empty line when the script finish normally without any message.

	04.06.2019
		Add a dummy function __change_log__ to write some... change log ;)
		Add some functions for ANSI colors managements.
		Add the elapsed time since the script start in the stderr log file.
		Fix some ANSI colors constants names conflicts between S_LGR(ay) and S_LGR(een) and others.

COMMENT
}
