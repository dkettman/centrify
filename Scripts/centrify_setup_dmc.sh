#!/bin/bash
#set -x

### Global Variables (start)
ccli_download_url=https://github.com/centrify/centrifycli/releases/download/v1.0.5.0/ccli-v1.0.5.0-linux-x64.tar.gz
ccli_install_path=/opt/centrify/ccli
commands_to_run=()

# Standard file that contains OS release information used in case statement below
# Sourcing the file to bring in the variables contained withing (specifically using the "ID" variable)
source /etc/os-release

### Global Variables (end)

## print_help function (start)
function print_help {
	echo
	echo "Usage:"
	echo "	$0 -c <PAS Enrollment Code> -t https://<PAS Tenant URL> [-o \"<Extra arguments to cenroll>\"]"
	echo
	exit 10;
}
## print_help function (end)

### Command-line Options Processing (start)
while getopts ":t:c:o:h" opt; do
	case ${opt} in
		c )
			enrollment_code=$OPTARG
			;;
		t )
			enrollment_tenant=$OPTARG
			;;
		o )
			enrollment_options=$OPTARG
			;;
		h )
			print_help
			;;
		\? )
			echo "Invalid option: $OPTARG" 1>&2
			print_help
			;;
		: )
			echo "Invalid option: $OPTARG requires an enrollment code" 1>&2
			print_help
			;;
	esac
done

shift $((OPTIND -1))
### Command-line Options Processing (end)

case $ID in
	ubuntu)
		echo "  - Found Ubuntu OS"
		pkg_install_cmd="/usr/bin/apt install -y"

		# Checking if the centrify repository is setup
		repo_check=$(grep -v '^#' /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null | grep -q repo.centrify.com 2>/dev/null)
		repo_check_rc=$?
		if [[ ${repo_check_rc} -eq 0 ]] ; then
			echo "  ✓ Centrify Repository is configured"
		else
			echo "  ╳ Centrify Repository is NOT configured"
			err_check=1
		fi

		# Checking if CentrifyCC package is installed
		pkg_check=$(/usr/bin/dpkg -l centrifycc 2>/dev/null | grep ^ii)
		pkg_check_rc=$?
		if [[ ${pkg_check_rc} -eq 0 ]] ; then
			echo "  ✓ Centrify Package centrifycc installed"
		else
			echo "  ╳ Centrify Package centrifycc NOT installed"
			err_check=1
			pkgs_to_install+=("centrifycc")
		fi

		# Checking if CCLI is in the path/installed
		ccli_check=$(/usr/bin/which ccli 2> /dev/null)
		ccli_check_rc=$?
		if [[ ${ccli_check_rc} -eq 0 ]] ; then
			echo "  ✓ Centrify CLI found in path: $ccli_check"
		else
			echo "  ╳ Centrify CLI not found in path"
			need_ccli=1
		fi

		# Checking if jq is installed
		jq_check=$(/usr/bin/dpkg -l jq 2>/dev/null)
		jq_check_rc=$?
		if [[ ${jq_check_rc} -eq 0 ]] ; then
			echo "  ✓ OPTIONAL: Package 'jq' installed"
		else
			echo "  ╳ OPTIONAL: Package 'jq' NOT installed"
			pkgs_to_install+=("jq")
		fi

		;;

	centos | redhat | rhel)
		echo "  - Found Centos/RedHat OS"
		pkg_install_cmd="/usr/bin/yum install -y"

		# Checking if the centrify repository is setup
		repo_check=$(/usr/bin/yum repolist | grep -q -i centrify)
		repo_check_rc=$?
		if [[ ${repo_check_rc} -eq 0 ]] ; then
			echo "  ✓ Centrify Repository is configured"
		else
			echo "  ╳ Centrify Repository is NOT configured"
			err_check=1
		fi

		# Checking if CentrifyCC package is installed
		pkg_check=$(/usr/bin/rpm -q CentrifyCC )
		pkg_check_rc=$?
		if [[ ${pkg_check_rc} -eq 0 ]] ; then
			echo "  ✓ Centrify Package CentrifyCC installed"
		else
			echo "  ╳ Centrify Package CentrifyCC NOT installed"
			err_check=1
			pkgs_to_install+=("CentrifyCC")
		fi

		# Checking if CCLI is in the path/installed
		ccli_check=$(/usr/bin/which ccli 2> /dev/null)
		ccli_check_rc=$?
		if [[ ${ccli_check_rc} -eq 0 ]] ; then
			echo "  ✓ Centrify CLI found in path: $ccli_check"
		else
			echo "  ╳ Centrify CLI not found in path"
			need_ccli=1
		fi

		# CentOS/RHEL only, libicu is required for CCLI to work
		libicu_check=$(/usr/bin/rpm -q libicu )
		libicu_check_rc=$?
		if [[ ${libicu_check_rc} -eq 0 ]] ; then
			echo "  ✓ Requisite Package libicu installed"
		else
			echo "  ╳ Requisite Package libicu NOT installed"
			err_check=1
			pkgs_to_install+=("libicu")
		fi
			
		# Checking if jq is installed
		jq_check=$(/usr/bin/rpm -q jq 2>/dev/null)
		jq_check_rc=$?
		if [[ ${jq_check_rc} -eq 0 ]] ; then
			echo "  ✓ OPTIONAL: Package 'jq' installed"
		else
			echo "  ╳ OPTIONAL: Package 'jq' NOT installed. ** Requires EPEL Repository **"
		fi

		;;

	opensuse-leap)
		echo "  - Found SuSE/OpenSuSE"
		pkg_install_cmd="/usr/bin/zypper install -y"

		# Checking if the centrify repository is setup
		repo_check=$(/usr/bin/zypper repos -d | grep -q -i repo.centrify.com)
		repo_check_rc=$?
		if [[ ${repo_check_rc} -eq 0 ]] ; then
			echo "  ✓ Centrify Repository is configured"
		else
			echo "  ╳ Centrify Repository is NOT configured"
			err_check=1
		fi

		# Checking if CentrifyCC package is installed
		pkg_check=$(/usr/bin/rpm -q CentrifyCC )
		pkg_check_rc=$?
		if [[ ${pkg_check_rc} -eq 0 ]] ; then
			echo "  ✓ Centrify Package CentrifyCC installed"
		else
			echo "  ╳ Centrify Package CentrifyCC NOT installed"
			err_check=1
			pkgs_to_install+=("CentrifyCC")
		fi

		# Checking if CCLI is in the path/installed
		ccli_check=$(/usr/bin/which ccli 2> /dev/null)
		ccli_check_rc=$?
		if [[ ${ccli_check_rc} -eq 0 ]] ; then
			echo "  ✓ Centrify CLI found in path: $ccli_check"
		else
			echo "  ╳ Centrify CLI not found in path"
			need_ccli=1
		fi
			
		# Checking if jq is installed
		jq_check=$(/usr/bin/rpm -q jq 2>/dev/null)
		jq_check_rc=$?
		if [[ ${jq_check_rc} -eq 0 ]] ; then
			echo "  ✓ OPTIONAL: Package 'jq' installed"
		else
			echo "  ╳ OPTIONAL: Package 'jq' NOT installed."
			pkgs_to_install+=("jq")
		fi

		;;

	*)
		echo "  - UNKNOWN OS Detected. Exiting"
		exit
		;;
esac

## If the Repo is not configured and the CentrifyCC package isnt installed, exit.
if [[ ${repo_check_rc} -ne 0 && ${pkg_check_rc} -ne 0 ]] ; then
	echo "Repository is not configured and CentrifyCC package is not installed. Cannot continue."
	exit 1
fi

echo


## Checks to see if we have added anything to the 'commands_to_run' and 'pkgs_to_install' arrays to see 
## if there is anything to do. Also checks if ccli is installed where we expect it.
if [[ ${#commands_to_run[@]} -gt 0 || ${#pkgs_to_install[@]} -gt 0 || ${ccli_check_rc} -ne 0 ]] ; then
	echo "The following tasks will be completed automatically:"
	if [[ ${ccli_check_rc} -ne 0 ]] ; then
		echo "  Download and install Centrify 'ccli' to /opt/centrify/bin/ccli"
	fi
	if [[ ${#pkgs_to_install[@]} -gt 0 ]] ; then 
		echo "  Installing the following packages from repository:"
		len=${#pkgs_to_install[@]}
		for (( i=0 ; i<${len} ; i++)); do 
			echo "    - ${pkgs_to_install[$i]}"
		done
	fi
	
	echo
	
	if [[ ${#pkgs_to_install[@]} -gt 0 ]] ; then
		pkgs=${pkgs_to_install[@]}
		commands_to_run+=("${pkg_install_cmd} ${pkgs}")
	fi
	
	if [[ ${ccli_check_rc} -ne 0 ]] ; then
		if [ ! -d /tmp/centrify ] ; then
			commands_to_run+=("mkdir /tmp/centrify_$$")
		fi
		commands_to_run+=("cd /tmp/centrify_$$")
	       	commands_to_run+=("/usr/bin/wget -nv https://github.com/centrify/centrifycli/releases/download/v1.0.5.0/ccli-v1.0.5.0-linux-x64.tar.gz")
		commands_to_run+=("/usr/bin/tar xf /tmp/centrify_$$/ccli-v1.0.5.0-linux-x64.tar.gz -C /opt/centrify/bin")
		commands_to_run+=("ln -s /opt/centrify/bin/ccli /usr/sbin/ccli")
	fi
	
	echo "Going to run the following commands:"
	ctr_len=${#commands_to_run[@]}
	for (( i=0 ; i<${ctr_len} ; i++ )); do 
		echo "  - ${commands_to_run[$i]}"
	done
	echo  
	echo "To continue with these actions, press ENTER to continue or CTRL-C to exit"; read
	
	ctr_len=${#commands_to_run[@]}
	for (( i=0 ; i<${ctr_len} ; i++ )); do 
		${commands_to_run[$i]}
	done
fi

## If both of the commandline options are not provided, nothing to do from here.
if [[ -z ${enrollment_code} || -z ${enrollment_tenant} ]] ; then
	echo "Unable to enroll as the enrollment options are note defined. "
	echo "Review usage of cenroll command and manually enroll system."
       	echo "Halting further action."
	exit 3;
fi

## Checking if we are already enrolled
enrollment_check=$(cinfo)
enrollment_check_rc=$?
if [[ ${enrollment_check_rc} -eq 0 ]] ; then
	echo "System is already enrolled, not taking further action"
	exit 2;
fi
	
## Enrolling system
echo "Passing the following options to cenroll:"
echo "	-c ${enrollment_code} -F ALL -t ${enrollment_tenant} -d ccli:.* ${enrollment_options}"
echo "To continue with these actions, press ENTER to continue or CTRL-C to exit"; read
/usr/sbin/cenroll -c ${enrollment_code} -F ALL -t ${enrollment_tenant} -d ccli:.* ${enrollment_options}
echo

## If there isnt a /root/centrifycli.config file, then setup the configuration file for the defined tenant
if [[ -e /root/centrifycli.config ]] ; then
	echo "CCLI configuration already exists, not overwriting configuration. Exiting..."
	exit 2;
else
	echo "Saving ccli default configuration: /usr/sbin/ccli -url ${enrollment_tenant} saveconfig"
	/usr/sbin/ccli -url ${enrollment_tenant} saveconfig
	echo
	# Now that it is all configured, lets test it out by calling /Security/WhoAmI
	echo "Testing configuration: ccli -m -ms ccli /Security/WhoAmI"
	/usr/sbin/ccli -m -ms ccli /Security/WhoAmI
fi
