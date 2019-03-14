#!/usr/bin/env bash

set -x

# Script which will be called by all BadgerNet scripts to set up the 
# environment and also to ensure that logging is appropriately setup

# set up the default environment
set -e   # Yes this is strict but it forces good behaviour

declare readonly ME=badger-setenv.sh

# usage string is set later
declare usage_string=""

PATH=/usr/local/opt/coreutils/libexec/gnubin:/usr/local/bin:/usr/local/sbin:$PATH
export PARENT_PID=$$

###############################################################################
##
## Function:    die
## Paramaters:	None
##
## Description: kill ourselves
##
###############################################################################
function die()
{
	kill -TERM $PARENT_PID
	exit 1
}

###############################################################################
##
## Function:    log
## Paramaters:	type (DEBUG | INFO | WARNING | ALERT | FATAL )
##              string
##
## Description: create a message of a set format.  For ALERTS and FATAL
##              generate a pushover message 
##
###############################################################################

function log ()
{
	local priority=-1
	local message_type=""

	case $1 in
		"DEBUG" | "INFO" | "WARNING" )
			message_type=$1
			shift
			;;

		"ALERT" )
			message_type=$1
			priority=0
			shift
			;;

		"FATAL" )
			message_type=$1
			priority=1
			shift
			;;

		*)
			pushover.sh -t "$(hostname) - Script Error" \
				"Invalid log level -> $1"
			;;
	esac

	local pid_string=""
	if [ ! -z "${PARENT_PID}" ]; then
		pid_string="(${PARENT_PID})"
	fi

	call_depth=$((${#FUNCNAME[@]} * 2 - 4))

	printf "%s %s %7s:%${call_depth}s%s\n" $(date +%Y%m%d:%H%M%S) ${pid_string} \
		${message_type} " " "$*" >&2

	# Generate a pushover alert if we're not running in a tty
	if [[ ${priority} != -1  && ! -t 0 ]]; then
		pushover.sh -p ${priority} -t "$(hostname) - System Alert"\
			"${message_type}: $*"
	fi

	return 0
}

###############################################################################
##
## Function:    getlogfilename
## Parameters:	processname - used to set log filename and also to determine 
##              uniqueness of execution
##
## Description: create a generate a standard logfile name
##
###############################################################################

function getlogfilename ()
{
	if [[ $# != 1 ]]; then
		log FATAL "getlogfilename: no process name specified"
		die
	fi

	# extract the basename and strip off any trailing '.sh'
	local temp_name=${process_name##*/}
	echo "/usr/local/log/$(date +%Y%m%d)-${temp_name/.sh/}.log"
}

###############################################################################
##
## Function:    usage
## Parameters:	None
##
## Description: Print out the usage base on the passed parameters
##
###############################################################################
function usage()
{
	printf "Usage %s: \n" "${process_name}"

	for arg_string in "${arg_options[@]}"
	do
		log DEBUG "usage: processing -> ${arg_string}"
		local readonly short_name=$(get_arg_value "short_name" "${arg_string}")
		local readonly long_name=$(get_arg_value "long_name" "${arg_string}")
		local readonly parameter=$(get_arg_value "parameter" "${arg_string}")
		local readonly variable_name=$(get_arg_value "variable_name" "${arg_string}")
		local readonly required=$(get_arg_value "required" "${arg_string}")
		local readonly description=$(get_arg_value "description" "${arg_string}")

		declare local param_string=""
		if [[ ${parameter} == "Y" ]]; then
			param_string="<${variable_name}> "
		fi

		declare local arg_string=""
		if [[ -z "${short_name}" ]]; then
			arg_string="${long_name} ${param_string}"
		elif [[ -z "${long_name}" ]]; then
			arg_string="${short_name} ${param_string}"
		else
			arg_string="-${short_name}${param_string+ }${param_string} | --${long_name}${param_string+ }${param_string}"
		fi

		local mand_string="(Optional)"
		if [[ ${mandatory} == "Y" ]]; then
			mand_string="(Required)"
		fi

		printf "    %s %s - %s\n" "${arg_string}" "${mand_string}" "${description}"
	done

	printf "\n\n"
	die
}

###############################################################################
##
## Function:    parse_option_specification
## Parameters:	! separated strings
##
## Description: Returns an associative array based extract from the options 
##				string.  S	# extract the relevant details from the parsed
##              option string.  These adds to the associative array arg_options
##              keyed on the argument name this in turn point to another
##              associative array which contains the following keys:
##                short_name    - single character
##                long_name
##                parameter     - Y/N this option sets a parameter
##                variable_name - the variable to be set - for binary this will
##                                0 or 1  
##                description   - String for usage command
##                required      - if set and parameter is "Y" then this is the
##                                default value if its not set
##
###############################################################################
function parse_option_specification()
{
	log DEBUG "parse_option_string -> $# parameters"

	OLDIFS=$IFS
	IFS=!
	local name=""

	for option_string in "$@" "h!help!N!help_needed!Print this message"
	do
		log DEBUG "parse_option_specification: parsing -> ${option_string}"
	
		set -- $option_string
		for name in short_name long_name parameter variable_name \
				description required
		do
			declare local value="$1"
			export "${name}"="${value}"
			log DEBUG "parse_option_specification: $name -> ${value:-<NOT SET>}"
			
			# Check whether the correct variables have been set
			case "$name" in 
				"long_name")
					if [[ -z "${short_name}" && -z "${long_name}" ]]; then
						log FATAL "parse_option_specification: Option string" \
							" ${option_string} missing long_name and short_name"
						die
					fi
				;;
			
				"required")
					if [[ ! -z "${required}" && ! -z "${required/[YN]/}" ]]; then
						log FATAL "parse_option_specification: Option " \
							"string -> ${option_string}, required is " \
							"${required}.  It must be Y or N"
						die
					fi
					if [[ -z "${required}" ]]; then
						option_string="${option_string}!N"
					fi
				;;

				"long_name" | "short_name" | "variable_name" )
					if [[ "${1/ /}" != "$1" ]]; then
						log FATAL "parse_option_specification: Field ${name}" \
							" in ${option_string} cannot contain a space"
						exit 1
					fi
				;;
			esac

			shift || break
		done

		if [[ $name != "required" ]]; then
			log FATAL "parse_option_specification: Option string -> " \
				"${option_string} does not have enough parameters"
			die
		fi
		
		# Now add the details into the global array - may have to make two
		# entries
		if [[ ! -z "${short_name}" ]]; then
			log DEBUG "parse_option_specification: added -> $short_name"
			arg_options[${short_name}]="${option_string}"
		fi
		if [[ ! -z "${long_name}" ]]; then
			arg_options[${long_name}]="${option_string}"
			log DEBUG "parse_option_specification: added -> $long_name, "\
				"value-> ${arg_options[$long_name]}"
		fi
	done

	log DEBUG "Number of entries in the array -> ${#arg_options[*]}"

	IFS=${OLDIFS}
	return 0
}

###############################################################################
##
## Function:    get_arg_value
## Parameters:	requested parameter
##				arg string 
##
## Description: Extracts the requested parameter
##
###############################################################################
function get_arg_value()
{
	local requested=$1
	local arg_string="$2"
	local value=""

	case "$requested" in
		"short_name")    position=1 ;;
		"long_name")     position=2 ;;
		"parameter")     position=3 ;;
		"variable_name") position=4 ;;
		"description")   position=5 ;;
		"required")      position=6 ;;

		*)
			log FATAL "get_arg_value:  Invalid attribute requested -> ${requested}"
			die
			;;
	esac

	value=$(echo "${arg_string}" | awk -F! '{print $position}' position=$position)
	if [[ -z "${value}" ]]; then
		log FATAL "get_arg_value: Assertion failure.  "\
			"No value for -> ${requested}, arg_string->${arg_string}"
		die
	fi

	echo "${value}"
}

###############################################################################
##
## Function:    get_option_string
## Parameters:	1 - LONG | SHORT - which option string are we creating 
##
## Description: Creates the appropriate string for getopt.  Accesses the global 
##              array arg_options
##
###############################################################################
function get_option_string()
{
	local readonly option_type=$1
	log DEBUG "get_option_string: type->${option_type}"

	if [[ $# != 1 ]]; then
		log FATAL "function get_option_string needs one parameters. " \
			"Called with -> $#"
		exit 1
	fi

	if [[ "${option_type}" != "SHORT" && "${option_type}" != "LONG" ]]; then
		log FATAL "First parameter to function get_option_string must be " \
			"LONG or SHORT"
		die
	fi

	declare -A local arg_opts
	declare local arg_string=""
	for arg_opts in "${arg_options[@]}"
	do
		log DEBUG "get_option_string: arg_opts->$arg_opts"

		local name=""
		if [[ "${option_type}" == "SHORT" ]]; then
			name=$(get_arg_value "short_name" "${arg_opts}")
		else
			name=$(get_arg_value "long_name" "${arg_opts}")
		fi

		log DEBUG "get_option_string: name -> ${name}"

		if [[ ! -z "${name}" ]]; then
			arg_string="${arg_string}${name}"
		else
			log FATAL "Assertion failed in get_option_string.  Neither long " \
				"or short name set"
			die
		fi

		if [[ $(get_arg_value "parameter" "${arg_opts}") == "Y" ]]; then
			arg_string="${arg_string}:"
		fi
	done

	log DEBUG "get_option_string: arg_string -> ${arg_string}"
	echo "${arg_string}"
	return 0
}


###############################################################################
##
## Function:    parse_options
## Parameters:	1 - parsing string
##              2 - option as passed to the executable
##
## Description: the parsing string is a set of ! seperated strings defined as
##				follows
##				1 - short variable (optional although the there must be at
##                  least one of short or long). Must be one character only
##              2 - long variable name (optional) - no spaces 
##              3 - parameter (Y/N) (mandatory) - is a parameter required
##              4 - variable name (mandatory) variable set by this option.   
##                  For binary options this will be 0 or 1
##				5 - Description - string for usage command - mandatory
##              6 - Required - Y/N - defaults N ignored for binary options
##                  
##
## 				Splits out the passed parameters and assigns the variables as
##              specified
##
###############################################################################
function parse_options ()
{
	# We use the gnu getopts function to do the dirty work .. At this point
	# we can be assured that it is available - that was checked earlier

	declare local argument_properties
	declare local script_arguments=$@

	long_option_string=$(get_option_string "LONG")
	short_option_string=$(get_option_string "SHORT")

	# check whether the process name has been set in the arg string else 
	# default to 
	#process_name=$(get_process_name "${script_arguments}")

	local temp_process_args=$(getopt -o ${short_option_string} \
		--long ${long_option_string} -n "${process_name}" -- "${script_arguments}")

	if [[ $? != 0 ]]; then
		log FATAL "Failed to process command line arguments for "\
			"${process_name}, args -> ${script_arguments}, "\
			"process string -> ${parsing_string}"
		die
	fi

	# Note the quotes around `$temp_process_args': they are essential!
	eval set -- "${temp_process_args}"

	# iterate through the arguments and set the defined variable as appropriate
	# also do the necessary mandatory checks and defaulting
	while true ; do
		argument=$1
		if [[ "${argument}" == "--" ]]; then
			break
		fi

		# Check for the help request
		if [[ "${argument}" == "--help" || "${argument}" == "-h" ]]; then
			usage
		fi

		shift

		# Check whether its valid
		argument_properties="${arg_options[$argument]}"	

		log DEBUG "parse_options: argument-> ${argument}, arg_options->${arg_options}"

		# In theory getopts should reject invalid args but lets be paranoid
		if [[ -z "${argument_properties}" ]]; then
			log FATAL "Invalid argument set -> ${argument}"
			usage
			die
		fi

		# Extract the necessary information - note that we have to assume this
		# has been correctly set but the sub functions
		local readonly parameter=$(get_arg_value "parameter" "${argument_properties}")
		local readonly variable_name=$(get_arg_value "variable_name" "${argument_properties}")

		local value=0
		if [[ $parameter == "Y" ]]; then
			value="$1"; shift
		else
			value=1
		fi

		# now set the value
		export "${variable_name}"="${value}"

	done

	# now have to iterate through the arg_options array checking for missing 
	# mandatories and set the defaults for binaries

	for argument_properties in "${arg_options[*]}"
	do
		log DEBUG "Checking for missing -> ${argument_properties}"
		local readonly short_name=$(get_arg_value "short_name" "${argument_properties}")
		local readonly long_name=$(get_arg_value "long_name" "${argument_properties}")
		local readonly parameter=$(get_arg_value "parameter" "${argument_properties}")
		local readonly variable_name=$(get_arg_value "variable_name" "${argument_properties}")
		local readonly required=$(get_arg_value "required" "${argument_properties}")

		log DEBUG "variable_name -> ${variable_name}, variable -> $( eval echo \$$variable_name ), required -> ${required}"

		#if the variable is already set then move on
		if [[ ! -z "$( eval echo \$$variable_name )" ]]; then
			continue
		fi

		if [ "${required}" == "Y" ]; then
			log DEBUG "Checking mandatory"
			declare local missing_string=""
			if [ -z "${short_name}" ]; then
				missing_string="${long_name}"
			elif [ -z "${long_name}" ]; then
				missing_string="${short_name}"
			else
				missing_string="${short_name} | ${long_name}"
			fi
			log FATAL "Missing mandatory argument -> ${missing_string}"
			die
		elif [[ $parameter == "N" ]]; then
			export "${variable_name}"=0
		fi
		
	done

	# Reset the arg string in case anything else wants to get at them
	set -- "${script_arguments}"

}


###############################################################################
##
## MAIN
##
###############################################################################

## Do some hygiene checks to make sure that we have the correct tools installed
getopt -T > /dev/null 2>&1 || true

if [[ $? != 0 ]]; then
	log FATAL "gnu getopt is not in the PATH -> $PATH"
	die
fi

# Make sure that the executable name has been passed in 
if [[ $# != 1 ]]; then
	log FATAL \
		"$ME needs to the pathname of the parent executable as a parameter"
	die
fi

# set the default process name - based on basename of $0 which trailing .sh 
# stripped.  This may get changed based on the command line options
readonly script_name=$0
process_name="${1##*/}"
readonly process_name="${process_name/.sh/}"

# See if we're running as a daemon - in which case redirect the output
if [ ! -t 0 ]; then
	# See if the parent name has been set
    exec >> $(getlogfilename "$process_name") 2>&1
fi

# Set up tmpfiles and associated removal on exit
for i in {1..4}
do
	export TMPFILE${i}=/tmp/$$-${i}
done

# Check we're not aready running
readonly pidfile=/tmp/pidfile.$(basename "$process_name")

trap "rm -rf /tmp/$$-[1-4] $pidfile"  exit 1 2 15;

if [ -f "$pidfile" ]; then
    kill -0 "$(cat $pidfile)" 2> /dev/null
    if [ $? -eq 0 ]; then
        # This process is already running
        log FATAL "$1 already running - $$"
        die
    fi
fi

printf "%d" $$ > $pidfile

log INFO "Started -> $(date)"
