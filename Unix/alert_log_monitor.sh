
#!/bin/ksh
# set -vx
# script by srivenu kadiyala 
# version 13
# This script will monitor the alert log
# This script will monitor all instances running with on the server with the same userid as this script owner
# This script will read the alert log in reverse (end to start)
# At the start of execution, it will put a start marker MARKER_START at the end of the file
# The start marker is put at the end of the file as the file is read in reverse
# It will start reading from the MARKER_START to the MARKER_END or till the start of the file (if MARKER_END is not found).
# If errors are found, it will send the whole contents of the alert log file (for the 5 mins) 
# between MARKER_START to MARKER_END as a mail to the DBA's.
# At the end it will delete the MARKER_END and convert the MARKER_START to MARKER_END 
# so that the next monitoring will stop at this marker.

check_log()
{

logfile="$1"

# check if alert log file has proper permissions
if [ ! -w $logfile ]
then
 print "file is not writable $logfile"
 exit 1
fi

# if the last line of the alert log is MARKER_END, then the file has not been modified since last check. Just exit.
if tail -1 $logfile|grep -i "MARKER_END" >/dev/null 2>&1
then
 exit 0
fi

# Initialize variables
export linecount=0
export start="n"
export endfound="n"
export logdir=`dirname $logfile`
export filename=`basename $logfile`
export sid=`echo $filename|cut -d "_" -f 2|cut -d "." -f 1`
export logpartfile=$logdir/alert_${sid}.part 	 # We put all lines from the alert log since the past scan in this file
export errfile=$logdir/alert_${sid}.err 	 # we put all the error lines found in alert log since past scan in this file
export errdetfile=$logdir/alert_${sid}.errdet 	 # We put all the details of errors encountered since the past scan in this file
export sqlfile=$logdir/alert_${sid}.sql 	 # Some of the errors need info from the database. This file contains that spooled output.
export mailfile=$logdir/alert_${sid}.mail 	 # If errors are encountered, we put all errors and details and contents of alert log and mail this file
export maillist='srivenu.kadiyala@tatatel.co.in' # Email ids of persons going to recieve the errors

# Null the error and mail files
>$logpartfile
>$errfile
>$errdetfile
>$sqlfile
>$mailfile

#put the marker at the end of the file
echo "MARKER_START">>$logfile

#loop through the file from reverse. stop at MARKER_END or when you reach the starting end of the file or after reading 1000 lines
tail -1000 $logfile|awk '{x[NR]=$0}END{while (NR) print x[NR--]}'| while read line 
do
 echo $line>>$logpartfile 			# we save all the lines in another file so that we dont need to read the alert log again
 if echo $line|grep -i "MARKER_END" >/dev/null 2>&1
 then
  endfound="y"
  break 
 fi
 if echo $line|egrep -i "ORA-|Checkpoint not complete" >/dev/null 2>&1 # add what all things you want to monitor here
 then
  echo $line>>$errfile
 fi
done

#remove the MARKER_END
perl -n -i -e 'print unless /MARKER_END/' $logfile

#change the MARKER_START to MARKER_END
perl -i -p -e  's/MARKER_START/MARKER_END/' $logfile

#remove the MARKER_END from the alert log part file
perl -n -i -e 'print unless /MARKER_START/' $logpartfile
perl -n -i -e 'print unless /MARKER_END/' $logpartfile


# If MARKER_END is found and errors are found (ie the error file is not 0 size) then send a mail with details of errors

if [ -s ${errfile} ]
then
 echo "****************************************************************************************">>$mailfile
 echo "Summary of Errors found in alert log">>$mailfile
 echo "****************************************************************************************">>$mailfile
 cat $errfile>>$mailfile
 echo "">>$mailfile
 tail $logpartfile|awk '{x[NR]=$0}END{while (NR) print x[NR--]}'|while read line
 do
  if echo $line|grep -i "Errors in file" >/dev/null 2>&1
  then
   tracefile=`echo $line|awk '{print $4}'|cut -d ":" -f 1`
  elif echo $line|egrep -i "ORA-00600|ORA-07445" >/dev/null 2>&1
  then
   if [ -f $tracefile ] 
   then
    echo "........................................................................................">>$errdetfile
    echo "$line ">>$errdetfile
    echo "........................................................................................">>$errdetfile
    awk ' BEGIN {x=0} /ORA-00600/||/ORA-07445/ {x=1} x==1 {print}  /Binary Sta/ {exit} '  $tracefile >>$errdetfile
    echo " ">>$errdetfile
   else
    echo "........................................................................................">>$errdetfile
    echo "$line">>$errdetfile
    echo "........................................................................................">>$errdetfile
    echo "Trace file $tracefile not found ">>$errdetfile
    echo " ">>$errdetfile
   fi 
  elif echo $line|egrep -i "ORA-000060" >/dev/null 2>&1
  then
   tracefile=`echo $line|awk '{print substr($8,1,length($8)-1)}'` 
   if [ -f $tracefile ]
   then
    echo "........................................................................................">>$errdetfile
    echo "$line">>$errdetfile
    echo "........................................................................................">>$errdetfile
    awk ' /DEADLOCK DETECTED/,/End of information/'  $tracefile >>$errdetfile
    echo " ">>$errdetfile
   else
    echo "........................................................................................">>$errdetfile
    echo "$line ">>$errdetfile
    echo "........................................................................................">>$errdetfile
    echo "Trace file $tracefile not found ">>$errdetfile
    echo " ">>$errdetfile
   fi
  elif echo $line|egrep -i "ORA-01555" >/dev/null 2>&1
  then
    echo "........................................................................................">>$errdetfile
    echo "$line">>$errdetfile
    echo "........................................................................................">>$errdetfile
  fi
 done
 echo "****************************************************************************************">>$mailfile
 echo "Details of Errors found in alert log">>$mailfile
 echo "****************************************************************************************">>$mailfile
 cat $errdetfile >>$mailfile
 echo "****************************************************************************************">>$mailfile
 echo "Contents of Alert log file for the past 5 minutes">>$mailfile
 echo "****************************************************************************************">>$mailfile
 cat $logpartfile>>$mailfile
 echo "****************************************************************************************">>$mailfile
 if [ $os = "SunOS" ]
 then  
  cat $mailfile|/usr/ucb/Mail -s "Errors found in ${sid} Alert log" $maillist
 elif [ $os = "HP-UX" ] 
 then 
  cat $mailfile|mailx -s "Errors found in ${sid} Alert log" $maillist
 elif [ $os = "Linux" ] 
 then 
  cat $mailfile|mailx -s "Errors found in ${sid} Alert log" $maillist
 fi
fi
}
# end of check_log()

# get os details
export os=`uname -s`

# get username details
if [ $os = "SunOS" ] 
then
 export idname=`id -a|cut -d "(" -f 2|cut -d ")" -f 1`
elif [ $os = "HP-UX" ]
 then  
 export idname=`id|cut -d "(" -f 2|cut -d ")" -f 1`
elif [ $os = "Linux" ]
then
 export idname=`id -a|cut -d "(" -f 2|cut -d ")" -f 1`
fi

# All instance info will be gathered in the file /tmp/alert_log_monitor.instances
tempinstfile='/tmp/alert_log_monitor.instances'
>$tempinstfile
# check if alert log file has proper permissions
if [ ! -w $tempinstfile ]
then
 print "temp file - $tempinstfile - is not writable"
 exit 1
fi



# Find all running oracle instances and get their oracle home details
ps -ef|grep "_pmon_"|grep "$idname"|grep -v grep|awk '{print $2, $NF}'|while read pid comm
do
 export sid=`echo $comm|sed 's/ora_pmon_//'|sed 's/asm_pmon_//'`
 if [ $os = "SunOS" ] 
 then 
  export orahome=`/usr/bin/pwdx $pid|awk ' {print $2}'|sed 's/\/dbs//'`
 elif [ $os = "HP-UX" ]
 then  
  export orahome=`/usr/bin/pmap $pid|grep libjox10|grep "rw"|grep -v grep|awk '{print $6}'|awk 'FS="/lib" {print $1}'`
 print a
 elif [ $os = "Linux" ]
 then 
  export orahome=`ls -l /proc/$pid/exe | awk -F'>' '{ print $2 }' | sed 's/\/bin\/oracle$//'`
 fi
 echo $pid $sid $orahome>>$tempinstfile
done

# for all the instances in the file loop and repeat the below process
cat $tempinstfile| while read pid sid orahome
do
 export ORACLE_SID=$sid
 export ORACLE_HOME=$orahome
 export PATH=$ORACLE_HOME/bin:$PATH
 sqlplus '/ as sysdba'<<EOF
  spool /tmp/alert_log_monitor.lst
  col value form a400
  select '---user_dump_dest--- '||value from v\$parameter where name='background_dump_dest';
EOF

awk '$1=="---user_dump_dest---" {print $2}' /tmp/alert_log_monitor.lst|while read logfilename
do
 check_log ${logfilename}/alert_${sid}.log
done

done