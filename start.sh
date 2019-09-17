#!/bin/bash

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

# Source function library
## CentOS/Fedora
if [ -f /etc/rc.d/init.d/functions ]
        then
        . /etc/rc.d/init.d/functions
fi

## Ubuntu
if [ -f /lib/lsb/init-functions ]
        then
        . /lib/lsb/init-functions
fi

#---------------------+
#    Configuration    |
#---------------------+
SCRNNAME="mainMC"
SERVICE="server.jar"
MCPATH="/home/minecraft/$SCRNNAME"
BACKUP_PATH="$MCPATH/backups"
WORLDNAME="$(cat $MCPATH/server.properties | grep -E 'level-name' | sed -e s/.*level-name=//)"
SERVERPORT="$(cat $MCPATH/server.properties | grep -E 'server-port' | sed -e s/.*server-port=//)"
USER="minecraft"
CPU_COUNT="2"
MINRAM="1G"
MAXRAM="2G"
INVOCATION="java -server -XX:UseSSE=4 -XX:+UseCMSCompactAtFullCollection -XX:ParallelGCThreads=$CPU_COUNT -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:+DisableExplicitGC -XX:+CMSIncrementalMode -XX:+CMSIncrementalPacing -XX:+AggressiveOpts -Xms$MINRAM -Xmx$MAXRAM -XX:PermSize=128m -jar $SERVICE nogui"

#---------------------+
#       Messages      |
#---------------------+
SAVE_START="Beginning autosave..."
SAVE_END="Autosave complete!"
STOP_WARNING_MAX="Server will shutdown in 5 minutes..."
STOP_WARNING_MID="Server will shutdown in 1 minute..."
STOP_WARNING_FINAL="Server is shutting down NOW!"

#-------------------------------+
#      Utilities/Libraries      |
#-------------------------------+


# Checks who the current script is running as.
as_user() {
        ME="$(whoami)"
        
        if [ "$ME" == "$USER" ]; then
                bash -c "$1"
        else
                su - "$USER" -c "$1"
        fi
}


# Checks if the server is currently running.
is_running() {
        if ps ax | grep -v grep | grep -iv SCREEN | grep $SERVICE > /dev/null; then
                PID=0
                PID="$(ps ax | grep -v grep | grep -iv SCREEN | grep $SERVICE | awk '{print $1}')"
                return 0
        else
                return 1
        fi
}


# Issue specific commands to the Minecraft server.
mc_run() {
        if is_running; then
                as_user "screen -p 0 -S $SCRNNAME -X eval 'stuff \"$1\"\015'"
        fi
}


# Makes annoncements to the minecraft server (notify users of changes to server states, etc.).
mc_alert() {
        mc_run "say $1"
}


# Saves the minecraft server world to the disk (issues "save-all" command on server).
mc_save() {
        if is_running; then
                echo " * Saving Minecraft server to disk..."
                mc_alert "$SAVE_START"
                mc_run "save-off"
                mc_run "save-all"
                sync ; sleep 1
                mc_run "save-on"
                mc_alert "$SAVE_END"
                echo " * World save complete"
         
         # Do not try to save world data if server is not running. 
         else
                echo " * [ERROR] $SCRNNAME was not running, cannot save world"
         fi
}


# Starts the Minecraft server. 
mc_start() {
  # Checks if server is already running. Does nothing if it is already running.
  if is_running ; then
    echo " * [ERROR] $SCRNNAME is already running at [PID $PID]. No action has been taken..."
    exit
  
  # Starts server.
  else
    echo " * $SCRNNAME is not currently running, starting up..."
    as_user "cd \"$MCPATH\" && screen -c /dev/null -dmS $SCRNNAME $INVOCATION"
    
    # Babysits the server, waiting for it to start up (retries 6 times).
    sleep 10
    retryNum=0

    # Checks if server has started.
    if [[ $retryNum -le 6 ]]; then
	# Server succussfully started.
	if is_running; then
		echo " * [OK] $SCRNNAME has started up successfully on [PID $PID]."
		exit
	
	# If server has not started up yet, increase retry number and wait 10 more seconds.
	else
		retryNum=$retryNum+1
		sleep 10
	fi

    # If server fails to start after 6 retries, stop trying.
    else
	echo " * [ERROR] Could not start $SCRNNAME"
	exit
    fi
  fi	
}


# Stops the Minecraft server.
mc_stop() {
	# Checks if server is actually running.
	while is_running; do
	        retryNum=0
		
		# First time warns users that server is shutting down.
		if [[ $retryNum -eq 0 ]]; then
	                
	                # Issue 5 minute warning to users.	
			echo " * Shutdown command issued, issuing 5 minute warning to users..."			
			mc_alert "$STOP_WARNING_MAX"
			mc_save
			sleep 4m
			
			# Issue 1 minute warning to users. 
			echo " * Issuing 1 minute shutdown warning to users..."
			mc_alert"$STOP_WARNING_MID"
			mc_save
			sleep 50
			
			# Issue final warning to users and shutdown the server.
		        mc_alert "$STOP_WARNING_FINAL"	
			mc_save
			mc_run "stop"
			retryNum=$retryNum+1
			sleep 20
			
		# If server still hasn't shutdown, log the issue, attempt again, and wait some more time.		
		if [[ $retyNum -lt 10 ]]: then
			echo " * [INFO] Server still hasn't fininshed shutting down, waiting a bit longer (retry $retryNum / 10)..."
			mc_run "stop"
			retryNum=$retryNum+1
			sleep 10
			
		# If server STILL hasn't shutdown, kill the process.					
		if [[ $retryNum -ge 10 ]]; then
			echo " * [ERROR] Server is STILL running, and is not responding to shutdown requests. Killing the process..."
			as_user "kill -9 $PID"
			echo " * [OK] Server process killed successfully."
			exit
		fi
		
	# Notify admin when server has finished shutting down.	
	else
		echo " * [OK] $SCRNNAME is shut down."
	done
}


# Checks the needed folders of the minecraft server to make sure they exist.
mc_verify_folders() {
        # Check Backup path, create new folder if needed.
        if [ ! -d $BACKUP_PATH ]; then
                echo " * [WARNING] Backup path ($BACKUP_PATH) does not exist. Creating it..."
                as_user "/bin/mkdir $BACKUP_PATH"
        fi
        
        # Check server log backup.
        if [ ! -d $BACKUP_PATH/server_logs ]; then
                echo " * [WARNING] Backup path ($BACKUP_PATH/server_logs) does not exist. Creating it..."
                as_user "/bin/mkdir $BACKUP_PATH/server_logs"
        fi
        
        # Check world backups folder
        if [ ! -d $BACKUP_PATH/worlds ]; then
                echo " * [WARNING] Backup path ($BACKUP_PATH/worlds/) does not exist. Creating it..."       
                as_user "/bin/mkdir $BACKUP_PATH/worlds/"
        fi
        
        # Check eatch world backup path.
        if [ ! -d $BACKUP_PATH/worlds/$WORLDNAME/ ]; then
                echo " * [WARNING] Backup path ($BACKUP_PATH/worlds/$WORLDNAME) does not exist. Creating it..."
                as_user "/bin/mkdir $BACKUP_PATH/worlds/$WORLDNAME/"
        fi
        
        # Check old worlds backup path
        if [ ! -d $BACKUP_PATH/worlds/$WORLDNAME/old/ ]; then
                echo " * [WARNING] Backup path ($BACKUP_PATH/worlds/$WORLDNAME/old) does not exist. Creating it..."
                as_user "/bin/mkdir $BACKUP_PATH/worlds/$WORLDNAME/old/"
        fi
}


# Rotate the minecraft server logs.
mc_log_rotate() {
  mc_verify_folders
  NOW="$(date +%Y-%m-%d.%H-%M-%S)"
  as_user "/bin/cp $MCPATH/server.log $BACKUP_PATH/server_logs/$NOW.log"
  as_user "echo -n \"\" > $MCPATH/server.log"

  LOGLIST=$(ls -r $BACKUP_PATH/server_logs/* | grep -v lck)
  COUNT=12
  CURCOUNT=0
  for i in $LOGLIST; do
    CURCOUNT=$CURCOUNT+1
    if [[ $CURCOUNT -gt $COUNT ]]; then
      as_user "rm -f $i"
    fi
  done
}


# Restarts the Minecraft server.
mc_server_restart() {
        echo " * Server restart command issued, stopping server..."
        mc_stop
        mc_log_rotate
	sleep 5
	sync
	mc_start
}


# Remove old Minecraft worlds
mc_remove_worlds() {
  as_user "/bin/rm -rf $MCPATH/world/DIM_MYST63/"
  as_user "/bin/rm -rf $MCPATH/world/DIM-1/"
  as_user "/bin/rm -rf $MCPATH/world/DIM1/"
  as_user "/bin/rm -rf $MCPATH/world/DIM7/"
  echo " * Removed old worlds"
}


# Runs Minecraft server backup (also verifies backup folders). 
mc_server_backup() {
        echo " * Minecraft server backup command issued, verifiying backup location..."
        mc_verify_folders
               
        # Notifiy users that backup is begining.
        echo " * Backing up Minecraft server..."
        mc_alert "Starting server backup, please forgive any lag..."
        mc_save
        sync
               
        # Starting backup.
        NOW="$(date +%Y-%m-%d_%H-%M-%S)"
        as_user "tar cfzP --exclude='$BACKUP_PATH' --exclude='*.db' --exclude='*.hash' --exclude='*.png' $BACKUP_PATH/$NOW $MCPATH"
        sync
        sleep 1
                
        # Notify users that backup is complete.                
        echo " * [OK] Backup complete."
        mc_alert "Server backup complete!"
        
        echo " * Removing all but the last 7 backups..."
        as_user "cd $BACKUP_PATH && find . -name '*' -type f -mtime +7 | xargs rm -fv"
        echo " * [OK] Removed old backups."
}


# Connect administrator to the Minecraft server console.
mc_console() {
  if is_running; then
    as_user "screen -S $SCRNNAME -dr"
  else
    echo " * [ERROR] $SCRNNAME was not running!"
  fi
}


# Review statistics about the Minecraft server.
mc_info() {
  if is_running; then
    RSS="$(ps --pid $PID --format rss | grep -v RSS)"
    echo " - Java Path          : $(readlink -f $(which java))"
    echo " - Start Command      : $INVOCATION"
    echo " - Server Path        : $MCPATH"
    echo " - World Name         : $WORLDNAME"
    echo " - Process ID         : $PID"
    echo " - Screen Session     : $SCRNNAME"
    echo " - Memory Usage       : $[$RSS/2048] Mb [$RSS kb]"
  # Check for HugePages support in kernel, display statistics if HugePages are in use, otherwise skip
  if [ -n "$(cat /proc/meminfo | grep HugePages_Total | awk '{print $2}')" -a "$(cat /proc/meminfo | grep HugePages_Total | awk '{print $2}')" -gt 0 ]; then
    HP_SIZE="$(cat /proc/meminfo | grep Hugepagesize | awk '{print $2}')"
    HP_TOTAL="$(cat /proc/meminfo | grep HugePages_Total | awk '{print $2}')"
    HP_FREE="$(cat /proc/meminfo | grep HugePages_Free | awk '{print $2}')"
    HP_RSVD="$(cat /proc/meminfo | grep HugePages_Rsvd | awk '{print $2}')"
    HP_USED="$[$HP_TOTAL-$HP_FREE+$HP_RSVD]"
    TOTALMEM="$[$RSS+$[$HP_USED*$HP_SIZE]]"
    echo " - HugePage Usage     : $[$HP_USED*$[$HP_SIZE/1024]] Mb [$HP_USED HugePages]"
    echo " - Total Memory Usage : $[$TOTALMEM/2048] Mb [$TOTALMEM kb]"
  fi
    echo " - Active Connections : "
    netstat --inet -tna | grep -E "Proto|$SERVERPORT"
  else
    echo " * $SCRNNAME is not running. Unable to give info."
  fi
}


#---------------------+
# Commandline parsing |
#---------------------+
#  start:         Starts the service
#  stop:          Stops the service
#  restart:       Restarts the service (if not running, starts the service)
#  console:       Opens the console
#  info:          Tells user some information about connections and server usage
#  backup:        Runs a backup for worlds in $WORLD_DIR
#  run:           Executes a server command
#  say:           Sends a server alert
#---------------------+

case $1 in
	start)
	  mc_start
	;;
	stop)
	  mc_stop
	;;
	save)
	  mc_save
  	;;
	console)
	  mc_console
	;;
	info)
	  mc_info
	;;
	serverCheck)
	   if ! is_running; then
	   	mc_start
	   fi
	;;
	run)
	  echo " * Ran command: \"$2\" on $SCRNNAME"
	  mc_run "$2"
	;;
	say)
	  echo " * Alerted all users on $SCRNNAME that \"$2\""
	  mc_alert "$2"
	;;
	sreset)
	  mc_stop
	  mc_remove_worlds
	  mc_start
  ;;
	srestart)
	  mc_server_restart
	;;
	sbackup)
	  mc_server_backup
	;;
	*)
		echo "Usage: server {start|stop|restart|save|console|info|run|say||sreset|srestart|sbackup}"
  ;;
esac

exit 0 
