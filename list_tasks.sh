#! /bin/bash
# This script reads task filtering rules from the conditions.txt file formatted as following:
# Task name in quotes, folowed by threshold duration in second separated by a colon
# each rule should be on a separate line, eg:
# "Identity Termination":64800
# "Batch request":86400


# init vars
global="false"
global_threshold=999999999

# actually useful vars
date_format='%d/%b/%Y_%T_%Z'
minimum_duration_seconds=3600 # only look at tasks running for more than an hour
# do the conversion since IIQ outputs time in milliseconds
start_ms=$(($(date +%s) * 1000))
newer_than=$(($start_ms-$minimum_duration_seconds*1000))

if  [ -z "$1" ]; then
  # no parameters means not in global mode,
  # read task names (or parts of them) and corresponding thresholds (in seconds)
  # awk will print error msg if anything wrong
  echo reading conditions
  tasks_array=$(awk 'BEGIN {FS=":"}{print $1}' conditions.txt) || exit 1
  times_array=$(awk 'BEGIN {FS=":"}{print $2}' conditions.txt) || exit 1
# switch to global mode (ignore conditions file)
elif [ $1 == "all" ]; then
    if [ $2 -gt 0 ]
       then
         global_threshold=$2
         global=$1
         echo running in global mode, with threshold=$global_threshold
    else 
      echo please specify global threshold, only integer values allowed
      exit 1
    fi
else
 echo unrecognized option \'$1\', try \'all [duration in seconds]\'
 exit 1 
fi

# build mysql query
running_tasks="SELECT name, launcher, host,\
 launched, completed, definition, completion_status\
  FROM identityiq.spt_task_result WHERE completed IS NULL AND launched<${newer_than};"
#echo "query: $running_tasks"

# specify remote connection details or leave host_connection empty for localhost
# e.g. remote_connection="-h mysql.server.com -P 50000" 
remote_connection=""

#command="/opt/rh/rh-mysql56/root/usr/bin/mysql ${remote_connection} -u identityiq -pidentityiq -N -B -e '${running_tasks}'"
command="cat test_data.txt"

echo -e "Execution time: `date +$date_format` (epoch: ${start_ms})\n"

# wrap this in function to get timings
main() {
    # iterating through the IIQ tasks
    # expecting TAB sparated values
    while IFS= read -r line
    #echo $line
    do
      counter=$(($counter + 1))
      task=$( echo "$line" |cut -f1 )
    # this is in milliseconds
      launched=$( echo "$line" |cut -f4 )
      launched_human=$(date -d @${launched::-3} +$date_format) # or /usr/bin/date
    # convert the result back to seconds for comparison
      duration_seconds=$((($start_ms - $launched)/1000))

    # if you want to see all tasks uncomment the next line
    # echo "    $task $launched $start_ms $duration_seconds"

    # ignore conditions file if global is set
    if [ $global == "all" ] && [ $duration_seconds -gt "${global_threshold}" ]; then

       echo "- $task [duration:${duration_seconds}s, launched:${launched_human}] [threshold:${global_threshold}s, rule:all]"
       result_counter=$(($result_counter + 1))
    elif [ $global != "all" ]; then
    # iterate through tasks in the conditions file
      for i in ${!tasks_array[@]}; do
    # match IIQ tasknames with entries in the conditions file
       if [[ $line == *"${tasks_array[$i]}"* ]]; then
    # if task running longer than specified in the conditions file, do the action
          if [ $duration_seconds -gt "${times_array[$i]}" ]; then
            #echo "$task(${tasks_array[$i]}) $launched $start_ms $duration_seconds ${times_array[$i]}"
            echo "- $task [duration:${duration_seconds}s, launched:${launched_human}] [threshold:${times_array[$i]}s, rule:${tasks_array[$i]}]"
            result_counter=$(($result_counter + 1))
          fi
        fi
      done
    fi
    done < <(eval $command)
}
time main
echo "lines processed: ${counter}"
echo "lines output: ${result_counter}"
