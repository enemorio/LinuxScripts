#!/bin/bash
. /root/.bashrc
# Yet another rebooter - this scripts checks for cpu, pci, memory and dmi data and makes a couple of logs and
#			 dirs to hold the data and process it later.
#	Usage: ./this_script [#] 
# [#] = integer number greater than 2 (number of reboot cycles)
# 	eg. ./this_script 1000


# Last revision - 08/24/2017 rev 2.7
# Added custom script call function after every reboot (custom_scripts())
# Added custom script call function after the cycle is finished (housekeeping())
# Original crontab is now saved before rebooter, appended with rebooter and restored to original state when completed. 
# Added dmesg log, does not compare or report on it yet though

# Issues:
# L194 - Not sure how to handle other grubs and paths to binaries, maybe check ubuntu's?


# variables (can be edited according to your needs)
default_cycles=10			# This parameter controls the DEFAULT number of reboot cycles. Set it to any int > 1!
target_dir="/root"			# desired target dir

# log dirs (please do not edit!)
countfile=$target_dir/.count.log				# This file contains a single number with the reboot count
statdir=$target_dir/stats_rebooter			# location for all stats and error logging files
target_cycles=$target_dir/.target_cycles			# a file that holds the total amount of reboots that will be performed
logdir=$statdir/logs					# This dir will contain all raw logs
rebootlog=$statdir/reboot_timestamp.log			# This file keeps the reboot count in a log style, with date and time
this_script=$(basename $0)				# this script's name
this_dir=$(dirname $(realpath $0))			# current dir path
pre_rebooter_scripts_log=pre_rebooter_scripts.log
custom_scripts_log=custom_scripts.log
post_rebooter_scripts_log=post_rebooter_scripts.log

########## FUNCTIONS ##########



# Put your initial pre-rebooter scripts here. These will run a single time right before setting the rebooter
pre_run_scripts() {
# Custom scripts called right before the rebooter starts go in here
date | tr -d '\n'
echo " - exit status: $?"					# exit code
} # &> $target_dir/$pre_rebooter_scripts_log



# Put your custom scripts here. These will run right after reporting SUT's stats and will repeat every reboot
custom_scripts() {
date | tr -d '\n'
echo " $(< $countfile)- "
# Custom scripts repeating every reboot go in here

/root/Desktop/OPAE_power_cycling_WW46/hssi_lb_test.sh force

} &>> $target_dir/$custom_scripts_log



# If you need to run scripts, reports or the like when the rebooter finishes use this function
post_rebooter_script(){
# Custom scripts called when the rebooter is over go in here
date | tr -d '\n'

rm -f /root/temp_OPAE/opae_aattk_check_OK
rm -f /root/temp_OPAE/opae_init_OK
rm -f /root/temp_OPAE/opae_workaround_OK

echo " - exit status: $?"					# exit code
} # &> $target_dir/$post_rebooter_scripts_log



# Usage
usage() {
	echo " ./$this_script: invalid option.
 Usage: ./$this_script #
 # = integer number greater than 2 (number of reboot cycles)
 	eg. ./$this_script 1000

 also: ./$this_script
 for default run of $default_cycles reboot cycles.
"
exit 1
}



# Determine the OS used, save it into a variable (flavour)and point to the right directories for shutdown and lspci. 
determine_OS() {
if [ -e /etc/SuSE-release ]; then
	shutdown_bin() { /sbin/shutdown -r now ;}
	lspci_bin() { /sbin/lspci -v ;}
	dmesg_bin() { /usr/bin/dmesg ;}
	dmidecode_bin() { /usr/sbin/dmidecode ;}
	lscpu_bin() { /usr/bin/lscpu ;}
	flavour=suse
elif [ -e /etc/redhat-release ]; then
	shutdown_bin() { /usr/sbin/shutdown -r now ;}
	lspci_bin() { /usr/sbin/lspci -v ;}
	dmesg_bin() { /usr/bin/dmesg ;}
	dmidecode_bin() { /usr/sbin/dmidecode ;}
	lscpu_bin() { /usr/bin/lscpu ;}
	flavour=redhat
else					# This one should work for ubuntu
	shutdown_bin() { /sbin/shutdown -r now ;}
	lspci_bin() { /usr/bin/lspci -v ;}
	dmesg_bin() { /usr/bin/dmesg ;}
	dmidecode_bin() { /usr/sbin/dmidecode ;}
	lscpu_bin() { /usr/bin/lscpu ;}
	flavour=unknown
fi
}


# A simple time delay to give the users time to escape the script in case the settings were incorrect
countdown () {
i=5
sleep 1
echo "Starting reboot cycle in $i seconds..."
echo "Hit ctrl+C to Cancel"
for (( i; i > 0 ; i-- )); do
	echo -n "$i "
	sleep 1
done
echo
}



# Search and backup currentrebooter log files
backup_current_run() {
	tar -czf rebooter_logs_$(date +%d%m%Y-%H%M).tar.gz $pre_rebooter_scripts_log $custom_scripts_log $post_rebooter_scripts_log $statdir/
}



# Search and backup previous rebooter log files
remove_previous_run_files() {
	echo "Removing old log files..."
	rm -rf $statdir/
	rm -f $pre_rebooter_scripts_log $custom_scripts_log $post_rebooter_scripts_log
	echo "done!"
}



# Check if this script is located at $target_dir and relocate and relaunch this script to adjust to new path
test_if_root_path() {
if [[ $USER != "root" ]]; then			# Test if this user is root
	echo "This script requires root privileges. Please run as root."
	exit 1
fi
if ! [[ -e $target_dir ]]; then
	mkdir -p $target_dir
fi
if [[ $this_dir != $target_dir ]]; then
	echo "$this_dir/$this_script is not in $target_dir/, moving script and preparing logs in $target_dir..."
	echo "$this_dir/$this_script" > /root/.try0
	cp $this_script $target_dir
	chmod +x $target_dir/$this_script
	cd $target_dir
	$0

else
	if [ -e /root/.try0 ]; then
		rm -f $(< /root/.try0)		# delete script in incorrect location
		rm -f /root/.try0

	fi
fi
}



# This function keeps a log of the reboot time and date, concatenating the sequencial number of the reboot and the timestamp
reboot_timestamp() {
echo -n "$(< $countfile): " >> $rebootlog && date >> $rebootlog
}



# This function generates all necessary logs
get_stats() {
# get dmidecode 
dmidecode_bin &> $logdir/$(< $countfile)_dmidecode.log
# get cpu info
lscpu_bin &> $logdir/$(< $countfile)_lscpu.log
# get cpu amount
cat /proc/cpuinfo | grep processor -c &> $logdir/$(< $countfile)_processor_count.log
# get cpu freq (bogomips)
cat /proc/cpuinfo | grep bogomips | grep -o "[0-9][0-9]*.[0-9][0-9]*" &> $logdir/$(< $countfile)_cpubogomips.log
# check ram
cat /proc/meminfo | grep MemTotal | grep -o "[0-9][0-9]*" &> $logdir/$(< $countfile)_memtotal.log
# check pci
lspci_bin &> $logdir/$(< $countfile)_pci.log
# get dmesg
dmesg_bin &> $logdir/$(< $countfile)_dmesg.log
}



# This function makes a backup of grub and crontab and sets new values for them
#  to speed up boot time in grub and to install the rebooter in cron
set_grub_and_cron() {
crontab -l > /etc/rc.d/crontab.bak
crontab -l > /etc/rc.d/cronjob
echo "@reboot sleep 3; /root/$0" >> /etc/rc.d/cronjob
crontab -u root /etc/rc.d/cronjob
if [ "$flavour" == "redhat" ]; then
	sed s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=1/ < /etc/default/grub > /etc/default/custom_grub
fi
if [ "$flavour" == "suse" ]; then
	sed s/GRUB_TIMEOUT=8/GRUB_TIMEOUT=1/ < /etc/default/grub > /etc/default/custom_grub
fi
if [ "$flavour" == "unknown" ]; then
	# Not sure how to handle other grubs, maybe check ubuntu's?
	echo "Ups! I do not know how to handle this particular grub, leaving it as is."
	sleep 5
fi
mv /etc/default/grub /etc/default/grub.bak
mv /etc/default/custom_grub /etc/default/grub
/usr/sbin/grub2-mkconfig -o $(find /boot -name "grub.cfg")
}



# This function creates directories and makes a backup of the issue banner
first_run() {
cp /etc/issue /etc/issue.bak
echo "reboot count: 1" >> /etc/issue 
echo 1 > $countfile
mkdir -p $logdir
}



test_default_or_custom() {
if [[ $1 == "default" ]]; then
	echo "Running with DEFAULT settings: $default_cycles reboots"
	echo $default_cycles > $target_cycles
fi
if [[ $1 == "custom" ]]; then
	if (( $2 >= 2 )); then
		echo "Running with CUSTOM settings: $2 reboots"
		echo $2 > $target_cycles
	else
		usage
	fi
fi
}



# This function compares the logs from this run against those from the immediate previous run 
# if differences exist, a line is dropped into an error log
compare_results() {
# Compare dmidecode logs
diff -q $logdir/$(< $countfile)_dmidecode.log $logdir/$(( $(< $countfile) -1 ))_dmidecode.log
if [ $? -ne 0 ]; then		# if they differ, drop a log line
	echo -n "$(< $countfile):$(( $(< $countfile) -1 )) - " >> $statdir/dmi_errors.log
	diff -y --suppress-common-lines $logdir/$(< $countfile)_dmidecode.log $logdir/$(( $(< $countfile) -1 ))_dmidecode.log >> $statdir/dmi_errors.log
fi
# Compare cpu info
diff -q $logdir/$(< $countfile)_lscpu.log $logdir/$(( $(< $countfile) -1 ))_lscpu.log


# Compare cpu core counts logs and cpu frequency logs
diff -q $logdir/$(< $countfile)_processor_count.log $logdir/$(( $(< $countfile) -1 ))_processor_count.log
if [ $? -ne 0 ]; then		# if they differ, drop a log line
	echo -n "$(< $countfile):$(( $(< $countfile) -1 )) - " >> $statdir/cpu_errors.log
	diff  -y --suppress-common-lines $logdir/$(< $countfile)_processor_count.log $logdir/$(( $(< $countfile) -1 ))_processor_count.log >> $statdir/cpu_errors.log
else				# if the processor count is good, check CPU frequencies 
	mapfile -t NEW < $logdir/$(< $countfile)_cpubogomips.log
	mapfile -t OLD < $logdir/$(( $(< $countfile) -1 ))_cpubogomips.log
	current_cpu_log=$logdir/$(< $countfile)_cpubogomips.log
	last_cpu_log=$logdir/$(( $(< $countfile) -1 ))_cpubogomips.log
	limit=$(( $( echo ${NEW[@]} | wc -w ) -1 ))
	for (( i=0 ; i <= $limit ; i++ )); do	# Compare bogomips (NEW/OLD) core by core and drop a log if NEW/OLD > 0.001%
		c1=$(echo "${NEW[i]}/${OLD[i]}" | bc -l)
		if (( (( $(echo "$c1 > 1.0001" | bc -l) != 0 )) || (( $(echo "$c1 < 0.9999" | bc -l) != 0 )) )); then
			echo -n "$(< $countfile):$(( $(< $countfile) -1 )) - "	>> $statdir/cpu_freq_errors.log	
			echo "Core $i frequency deviation above 0.01% detected ($c1%). Check $current_cpu_log and $last_cpu_log for details" >> $statdir/cpu_freq_errors.log
		else
			echo -n "$(< $countfile):$(( $(< $countfile) -1 )) - " >> $logdir/cpu_freq.log
			echo "Core $i frequency OK. ($c1%)" >> $logdir/cpu_freq.log
		fi
	done
fi
# Look for memory changes
diff -q $logdir/$(< $countfile)_memtotal.log $logdir/$(( $(< $countfile) -1 ))_memtotal.log
if [ $? -ne 0 ]; then
	echo -n "$(< $countfile):$(( $(< $countfile) -1 )) - " >> $statdir/memory_errors.log
	diff  -y --suppress-common-lines $logdir/$(< $countfile)_memtotal.log $logdir/$(( $(< $countfile) -1 ))_memtotal.log >> $statdir/memory_errors.log
fi
# Look for pci devices changes
diff -q $logdir/$(< $countfile)_pci.log $logdir/$(( $(< $countfile) -1 ))_pci.log
if [ $? -ne 0 ]; then
	echo -n "$(< $countfile):$(( $(< $countfile) -1 )) - " >> $statdir/pci_errors.log
	diff -y --suppress-common-lines $logdir/$(< $countfile)_pci.log $logdir/$(( $(< $countfile) -1 ))_pci.log >> $statdir/pci_errors.log
fi
}



# This function updates the reboot counter into the login screen (/etc/issue)
update_issue_counter() {
sed s/[0-9][0-9]*/$(< $countfile)/ < /etc/issue > ./new_issue
cp ./new_issue /etc/issue
rm -f ./new_issue
}



# This function restores the shell login screen (/etc/issue) back to its former glory
restore_issue() {
echo '#!/bin/bash
mv -f /etc/issue.bak /etc/issue
rm -f /root/restore_issue.sh
crontab -u root /etc/rc.d/crontab.bak		# Restores original crontab from before rebooter
' > /root/restore_issue.sh
chmod +x restore_issue.sh
echo "@reboot sleep 5; /root/./restore_issue.sh" >> /etc/rc.d/cronjob
crontab -u root /etc/rc.d/cronjob
}



# This function restores the backups we made of crontab and grub
restore_grub_and_cron() {
crontab -u root /etc/rc.d/crontab.bak
mv -f /etc/default/grub.bak /etc/default/grub
/usr/sbin/grub2-mkconfig -o $(find /boot -name "grub.cfg")
}



################# Main ####################
if ! [[ -e $countfile ]]; then			# Check if a file created in 'firstrun' exists. If not treat this as a first run
	if ! [[ -e /root/.try0 ]]; then		# File /root/.try is just a flag to indicate if this is a first run or an invocation
		case "$#" in			# after an automatic relocation of the script to $target
		0) test_default_or_custom default ;;
		1) test_default_or_custom custom $1 ;;
		*) usage ;;
		esac
	fi	
	test_if_root_path
	countdown
	determine_OS
	remove_previous_run_files
	pre_run_scripts
	first_run
	set_grub_and_cron
	get_stats
	custom_scripts
	reboot_timestamp
	shutdown_bin
else						# Treat this as a subsequent run (count >= 1)
	current=$(< $countfile)
	(( current++ )) 			# increment the number of reboots in the counter
	if (( $current < $(< $target_cycles) )); then	# Compare current reboots against target. If current < target there are reboots still pending
		echo $current > $countfile
		determine_OS
		get_stats
		compare_results
		update_issue_counter
		custom_scripts
		reboot_timestamp
		shutdown_bin
	elif (( $(< $target_cycles) == $current )); then	# Compare current reboots against target. If current = target this is the last reboot
		echo $current > $countfile
		update_issue_counter		
		echo -e "\n ### Finished rebooter test!" >> /etc/issue
		restore_issue
		determine_OS
		get_stats
		compare_results 
		custom_scripts
		reboot_timestamp
		shutdown_bin
	else 					# Compare current reboots against target. If current > target then we are logged in after the last reboot
		restore_grub_and_cron
		rm -f $target_cycles $countfile /etc/default/grub.bak /etc/rc.d/cronjob /etc/rc.d/crontab.bak
		backup_current_run
		post_rebooter_script
		exit 0
	fi
fi
