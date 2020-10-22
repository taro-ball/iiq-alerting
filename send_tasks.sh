#! /bin/bash
# read task list from stdin
tasklist=$(</dev/stdin)
# set the email variables
sender=me@acme.com
recepient=taroball@acme.com
recepient2=support.acme.sailpoint@acme.com
server=smtp.acme.com
mail_file=mail.txt
#assemble send command
command="curl -v smtp://${server} --mail-from ${sender} --mail-rcpt ${recepient} --mail-rcpt ${recepient2} --upload-file ${mail_file}"
# clear file content
true > $mail_file
# assemble file
echo "From: <${sender}>" >> $mail_file
echo "To: <${recepient},${recepient2}>" >> $mail_file
echo -e "Subject: Test alert - IIQ tasks are running longer than expected $(date)\n" >> $mail_file
echo "Content-Type: text/plain; charset=UTF-8; format=flowed" >> $mail_file
echo "Content-Disposition: inline" >> $mail_file
# this is important, as we need a DOS style CRLF to separate headers from body
echo -e "\r\n\r\n" >> $mail_file
echo -e "\nThis is a test alert.\nThe following IIQ tasks are running longer than expected:\n" >> $mail_file
echo "${tasklist}" >> $mail_file
# be verbose
echo -e "$command\n"
cat -eT $mail_file
# execute
eval $command || exit 1
