#!/bin/bash

########################################
# Update below IP to the IP address of #
# the server this will be running on   #
########################################
localIP="192.168.0.2";
backupServerAddr="backup.server.com";
backupServerUser="root";
backupServerPath="/home/server-backups/pbx";
sshKeyPath="/root/sshKey";
sshPort="22";

hostname=$(hostname);
asterisk_version=$(asterisk -V | awk '{print $2}');
file_name=$(locations="/var/lib/asterisk/backups/ /var/spool/asterisk/backup"; for path in $locations; do [ -d "${path}" ] && find $path -type f -name "*\.tgz" -print0 | xargs -0 ls -t | head -n 1; done);
backup_date=$(stat -c %y ${file_name} | cut -d ' ' -f1 | tr -d '-');
lock_file="/var/lock/subsys/copy-pbx-backup";

if [ -f ${lock_file} ]; then
	check_pid=$(cat ${lock_file});
	[ `ps auxf | awk '{print $2}' | grep -v grep | grep -c "${check_pid}";` -eq "0" ] && echo "$$" > ${lock_file} || exit 1;
else
	echo "$$" > ${lock_file};
fi;

# Check if date folder exists else create it
check_dir() {
	count=$(($count + 1));
	[ "${count}" -eq "4" ] && (unset count && sleep 10800);
	[ `ssh -4f -p ${sshPort} -i "${sshKeyPath}" -o ConnectTimeout="60" -o StrictHostKeyChecking="no" -o BatchMode="yes"  ${backupServerUser}@${backupServerAddr} "[ ! -d "${backupServerPath}/${hostname}" ] && mkdir -p ${backupServerPath}/${hostname}"; echo $?` -ne 0 ] && check_dir;
}
check_dir;
unset count;

# Check if file copy was successful
check_transfer() {
	result=$(ssh -4 -p ${sshPort} -i "${sshKeyPath}" -o ConnectTimeout="60" -o BatchMode="no" -o StrictHostKeyChecking="yes"  ${backupServerUser}@${backupServerAddr} "tar -tzf ${backupServerPath}/${hostname}/${backup_date}_${hostname}_${localIP}_asterisk-${asterisk_version}.tgz > /dev/null 2>&1; echo \$?");
	[ "${result}" -ne "0" ] && copy;
}

# Copy latest FreePBX backup to ${backupServerAddr}
copy() {
	count=$(($count + 1));
	[ "${count}" -eq "4" ] && (unset count && sleep 10800);
	[ `scp -4q -P ${sshPort} -i "${sshKeyPath}" -o ConnectTimeout="60" -o BatchMode="no" -o StrictHostKeyChecking="yes" ${file_name} ${backupServerUser}@${backupServerAddr}:${backupServerPath}/${hostname}/${backup_date}_${hostname}_${localIP}_asterisk-${asterisk_version}.tgz; echo $?` -ne 0 ] && copy;
	check_transfer;
}
copy;

\rm -f ${lock_file};
