#!/bin/bash

# /sys/devices/pci0000:5e/0000:5e:00.0/resource0
# ./hssi_config -r /sys/devices/pci0000:5e/0000:5e:00.0/resource0 mread 4 0 0x0001 2> /dev/null | cut -b 10

# Variables, set them according to your needs:
w_dir=/root/SR-6.3_HSSI/Alaska_release_ww30.5/hssi_config_loopback/build/bin
resource0_s0=/sys/devices/pci0000:5e/0000:5e:00.0/resource0
resource0_s1=/sys/devices/pci0000:be/0000:be:00.0/resource0
log_file=/root/Desktop/vib_test.log
def_span_min=15		# Default test time


usage(){
echo "ERROR - Invalid parameter: $1, must be an integer greater than 0.
To specify a custom time frame, run this script and provide the number of
minutes as an argument. Ex.:

	./vib_test 30 - runs the test for 30 minutes

You can increase performance by prefixing 'nice -n -20' to the script. Ex.:
	
	nice -n -20 ./vib_test.sh
"
}

if [ $# -eq "1" ]; then
	if [[ ! $1 =~ ^[0-9]+$ ]]; then
		usage $1
		exit 1
	else
		if [ $1 -lt "1" ]; then
			usage $1
			exit 1
		fi
		span_min=$1
	fi
elif [ $# -gt "1" ]; then
	echo "ERROR: Please provide only 1 argument for custom time or no arguments for default $def_span_min minutes."
	exit 1
else
	span_min=$def_span_min
fi

init_time=$(date +%s)
end_time=$(( $span_min*60 + $init_time ))


echo "
--------------------------------------------------------------------------------
				Vibration Test

Hi there! This test has a default time setting of $def_span_min minutes.
This run will last $span_min minutes.
"

cd $w_dir
rm $log_file		# Delete old log file
let x=0
now=$(date)
echo "Test started at $now. Please wait $span_min minutes"
echo "Test started at $now." >> $log_file
while (( $(date +%s) < $end_time )); do
	T=$(./hssi_config -r $resource0_s0 mread 4 0 0x0001 2> /dev/null | cut -b 10)
	U=$(./hssi_config -r $resource0_s1 mread 4 0 0x0001 2> /dev/null | cut -b 10)

	date +%T.%N | tr -d '\n' >> $log_file
	if [ "$T" == "6" ]; then  
		echo " $x: Socket 0 host side link is up. (5e)"  >> $log_file
	else
		echo " $x: Socket 0 host side link is down. (5e)"  >> $log_file
	fi
	
	date +%T.%N | tr -d '\n' >> $log_file
	if [ "$U" == "6" ];then  
		 echo " $x: Socket 1 host side link is up. (be)"  >> $log_file
	else 
		 echo " $x: Socket 1 host side link is down. (be)"  >> $log_file
	fi
	let x+=1
done
grep -c 'down. (5e)' $log_file > /tmp/issues_s0
grep -c 'down. (be)' $log_file > /tmp/issues_s1
echo "There were $(<  /tmp/issues_s0) Socket 0 disconnects" | tee -a $log_file
echo "There were $(<  /tmp/issues_s1) Socket 1 disconnects" | tee -a $log_file
rm /tmp/issues_s0 /tmp/issues_s1
average=$(echo "$x/$span_min" | bc -l)
average=$(echo "$average/60" | bc -l)
echo "
$x cycles completed in $span_min minutes." | tee -a $log_file 
echo "You averaged $average samples per second" | tee -a $log_file

