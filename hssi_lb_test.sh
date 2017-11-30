#!/bin/bash
# Automated HSSI internal loopback test - OPAE
# ----------------------------------------------
# 
# Last revision - 11/16/2017 rev 0.1

. /root/.bashrc

export PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin:/root/bin:/root/Alaska_release_ww43.5/aattk/aattk/build/aattk

temp_OPAE=/root/temp_OPAE
date_0=$(date +%F_%T)
log_lb0=$temp_OPAE/internal_loopback0_"$date_0"_0x5e.log
log_lb1=$temp_OPAE/internal_loopback0_"$date_0"_0xbe.log

mkdir -p $temp_OPAE

workaround() {
echo "performing fpga WA:"
fpgainfo -s0 errors all -c
fpgainfo -s1 errors all -c
sleep 2 
# Leave file registry of OK process
touch $temp_OPAE/opae_workaround_OK
}


init() {
echo "performing init.sh:"
init_dir=/root/Alaska_release_ww43.5
cd $init_dir
./init.sh /sys/devices/pci0000\:5e/0000\:5e\:00.0/resource0
./init.sh /sys/devices/pci0000\:be/0000\:be\:00.0/resource0
./init.sh /sys/devices/pci0000\:5e/0000\:5e\:00.0/resource0
./init.sh /sys/devices/pci0000\:be/0000\:be\:00.0/resource0
sleep 2 
# Leave file registry of process success
# if grep 'ok' condition then:
touch $temp_OPAE/opae_init_OK
# else display error and exit
}


aattk_check() {
echo "performing aattk check:"
aattk_dir=/root/Alaska_release_ww43.5/aattk/aattk/build/aattk
cd $aattk_dir/
./aattk --pci_device /sys/devices/pci0000\:5e/0000\:5e\:00.0/resource0 --device_check
./aattk --pci_device /sys/devices/pci0000\:be/0000\:be\:00.0/resource0 --device_check
sleep 1 
# Leave file registry of process success
touch $temp_OPAE/opae_aattk_check_OK
}


internal_loopback() {
echo "performing hssi_loopback:"
cd /root
hssi_loopback -m e100 -B 0x5e -t 5 send 0 &
hssi_loopback -m e100 -B 0xbe -t 5 send 0 
hssi_loopback -m e100 -B 0x5e status clear
hssi_loopback -m e100 -B 0xbe status clear
sleep 1
date > $log_lb0
date > $log_lb1
hssi_loopback -m e100 -B 0x5e -t 10 send 0 >> $log_lb0 &
hssi_loopback -m e100 -B 0xbe -t 10 send 0 >> $log_lb1
sleep 1
}


reporter() {
lb0_TX=$(cat $log_lb0 | grep "TX STAT" | awk '{print $4}')
lb0_RX=$(cat $log_lb0 | grep "RX STAT" | awk '{print $4}')
lb0_CRC=$(cat $log_lb0 | grep "RX CRC ERR" | awk '{print $5}')

lb1_TX=$(cat $log_lb1 | grep "TX STAT" | awk '{print $4}')
lb1_RX=$(cat $log_lb1 | grep "RX STAT" | awk '{print $4}')
lb1_CRC=$(cat $log_lb1 | grep "RX CRC ERR" | awk '{print $5}')

# For socket 0x5e
if [[ "$lb0_CRC" != "0|" ]]; then
	echo "FAILED: Socket 0x5e - internal loopback 0 has CRC errors!" | tee -a $log_lb0
else
	echo "PASSED: Socket 0x5e - internal loopback 0 - CRC OK!" | tee -a $log_lb0
fi
if [[ "$lb0_TX" != "$lb0_RX" ]]; then
	echo "FAILED: Socket 0x5e - internal loopback 0 missed TX/RX packets!" | tee -a $log_lb0
else 
	echo "PASSED: Socket 0x5e - internal loopback 0 - TX/RX OK!" | tee -a $log_lb0
fi


# For socket 0xbe
if [[ "$lb1_CRC" != "0|" ]]; then
	echo "FAILED: Socket 0xbe - internal loopback 0 has CRC errors!" | tee -a $log_lb1
else
	echo "PASSED: Socket 0xbe - internal loopback 0 - CRC OK!" | tee -a $log_lb1
fi
if [[ "$lb1_TX" != "$lb1_RX" ]]; then
	echo "FAILED: Socket 0xbe - internal loopback 0 missed TX/RX packets!" | tee -a $log_lb1
else 
	echo "PASSED: Socket 0xbe - internal loopback 0 - TX/RX OK!" | tee -a $log_lb1
fi
}


### Main ###
if [[ $1 == "force" ]]; then
	workaround
	init
	aattk_check
	internal_loopback
	reporter
else
	if [[ ! -e $temp_OPAE/opae_workaround_OK ]]; then
		workaround
	fi
	if [[ ! -e $temp_OPAE/opae_init_OK ]]; then
		init
	fi
	if [[ ! -e $temp_OPAE/opae_aattk_check_OK ]]; then
		aattk_check
	fi
	internal_loopback
	reporter
	cat $log_lb0
	cat $log_lb1
fi
