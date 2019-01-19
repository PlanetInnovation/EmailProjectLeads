#!/bin/bash

# This script emails project leaders with a list of all staff that have access to their project
# See kvv for more info

# path added since we will be calling this from cron
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# remove temp files
rm /tmp/mgrgroups-for-email.txt
rm /tmp/current-mgr-group.txt
rm /tmp/normal-project-users.txt
rm /tmp/composed-letter-to-mgrs.txt


# exit if anything goes awry, since we don't want to spam people with junk
set -e


function emailprojectleader {
# this function takes two inputs - $1 (the name of the project leader) and $2 (the name of their project)
   # check if any of the org groups are listed as managers of the project and if they are exclude them
   if [ "$1" = "directors" ] || [ "$1" = "mgmt" ] || [ "$1" = "groupmgmt" ] || [ "$1" = "qa_admin" ]
      then
         # do nothing, since we don't want to email any groups - only users
         :
      else
         # get first name for this user
         usrfirstname=$(pdbedit -L | grep $1: | awk -F ":" '{print $3}' | awk -F " " '{print $1}')
         # create a letter that we are going to send to the user
         echo "Hello $usrfirstname," > /tmp/composed-letter-to-mgrs.txt
         echo "You are listed as a manager for the project \"$2\"." >> /tmp/composed-letter-to-mgrs.txt
         echo "To ensure that only the correct employees have access to this project, please review the below list of staff members:" >> /tmp/composed-letter-to-mgrs.txt
         cat /tmp/normal-project-users.txt >> /tmp/composed-letter-to-mgrs.txt
         echo -e '\r' >> /tmp/composed-letter-to-mgrs.txt
         echo "If any of the above staff no longer require access to $2, then please contact IT support." >> /tmp/composed-letter-to-mgrs.txt
         echo "Thanks in advance," >> /tmp/composed-letter-to-mgrs.txt
         echo "The IT support team." >> /tmp/composed-letter-to-mgrs.txt
         # actually send the email
         mail -s " Access to project $2 " -a "From: it-support@YourCompanyName.com" $1@YourCompanyName.com < /tmp/composed-letter-to-mgrs.txt
   fi

}


# gather list of project management groups
samba-tool group list | grep _m > /tmp/mgrgroups-for-email.txt
# add the group names to an array
mgrgroups=( `/bin/cat "/tmp/mgrgroups-for-email.txt" `)

# this loop reads in the title of each "manager" group and then the sub loop emails each project leader
for currentgroup in "${mgrgroups[@]}"
   do
      # derive project name from manager group
      subgroup=$(echo $currentgroup | sed 's/..$//')
      # generate list of all users with non-manager access to this project
      samba-tool group listmembers $subgroup > /tmp/normal-project-users.txt
      # query for members of this management group
      samba-tool group listmembers $currentgroup > /tmp/current-mgr-group.txt
      currentmgrmembers=( `/bin/cat "/tmp/current-mgr-group.txt" `)
      # do a nested loop to email each manager
      for currentmanagerusername in "${currentmgrmembers[@]}"
         do
            emailprojectleader $currentmanagerusername $subgroup
         done
   done


# end of script
