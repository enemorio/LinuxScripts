#!/bin/bash

# Unzip and copy directories
unzip OPAE_Release_ww*_Install_RHEL7.4.zip
unzip Alaska_release_ww*.zip
unzip NLB_Regression_OPAE_*.zip
mv OPAE_Release_ww*_Install_RHEL7.4/ /root
mv Alaska_release_ww*/ /root
mv NLB_Regression_OPAE_*/ /root

# Mount ISO and install required rpms and libs
mkdir /run/media/root/RHEL74DVD && mount -o loop,ro /run/media/root/OS/RHEL7.4x86_64/RHEL-7.4-20170711.0-Server-x86_64-dvd1.iso /run/media/root/RHEL74DVD
cp /run/media/root/RHEL74DVD/media.repo /etc/yum.repos.d/
echo baseurl=file:/run/media/root/RHEL74DVD >> /etc/yum.repos.d/media.repo
yum repolist all
yum install -y cmake json-glib-devel.x86_64 boost.x86_64 boost-devel.x86_64 libhugetlbfs.x86_64 libhugetlbfs-devel.x86_64 libhugetlbfs-utils.x86_64
umount /run/media/root/RHEL74DVD && rm -r /run/media/root/RHEL74DVD/
rm /etc/yum.repos.d/media.repo

# Install OPAE
cd /root/OPAE_Release_ww*_Install_RHEL7.4/
chmod +x *.sh
./opaeInstall_0_12_0v.sh

# Install Alaska drivers
cd /root/Alaska_release_ww*/
chmod +x *.sh
mv OPAE-Alaska_install-ww43.5.sh /root
cd /root
./OPAE-Alaska_install-ww43.5.sh


# Install NLB Regression
chmod +x /root/NLB_Regression_OPAE_110117/NLB_REG_setup_ROOT/*.sh
chmod +x /root/NLB_Regression_OPAE_110117/NLB_REG_setup_OthrUser/*.sh
useradd -m nlb_regression
echo "Passw0rd" | passwd --stdin nlb_regression
mv /root/NLB_Regression_OPAE_110117/NLB_REG_setup_ROOT /root/Desktop/
mkdir -p /home/nlb_regression/Desktop
mv /root/NLB_Regression_OPAE_110117/NLB_REG_setup_OthrUser /home/nlb_regression/Desktop
chown -R nlb_regression:nlb_regression /home/nlb_regression/Desktop
# As root
cd /root/Desktop/NLB_REG_setup_ROOT/
./NLB_REG_setup_ROOT.sh
# As nlb_regression
# (Not fully implemented)
# su - nlb_regression -c "/home/nlb_regression/Desktop/NLB_REG_setup_OthrUser/./NLB_REG_setup_OthrUser.sh"

# WA:
fpgainfo -s0 errors all -c
fpgainfo -s1 errors all -c

cd Alaska_release_ww*/
./init.sh /sys/devices/pci0000\:5e/0000\:5e\:00.0/resource0
./init.sh /sys/devices/pci0000\:be/0000\:be\:00.0/resource0
# Report host/link side up and leave a log entry


sed -i 's|#!/usr/bin/bash|#!/bin/bash\n. /root/.bashrc|' /root/Alaska_release_ww*/init.sh
