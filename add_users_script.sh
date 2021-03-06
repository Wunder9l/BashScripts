#!/bin/sh

##### FUNCTIONS #####

function check_for_admin() {
    if [ $(id -u) -eq 0 ]; then
        echo "Wellcome, root user"
	return 0
    else
        echo "You are not root, only root is allowed to add users"
        exit 2 
    fi
}

function create_group() {
local groupname=$1
if [ $(getent group $groupname) ]; then
   echo "Group with name $groupname already exists"
else
   echo "Creating group: groupadd $groupname"
   groupadd $groupname
fi
}

function set_groups_arg() {
if [ "$groups" == "" ]; then
    groups_arg=""
else
   local temp=$IFS
   IFS=','
   local list=($groups)
   for item in "${list[@]}"
   do
       create_group "$item"
   done
   IFS=$temp
   groups_arg="-G$groups"
fi
}

function set_password_arg() {
if [ "$password" == "" ]; then
    passw_arg=""
else
    passw_arg="-p$password"
fi
}

function set_primary_group_arg() {
if [ "$primary" == "" ]; then
    primary_group_arg=""
else
    create_group "$primary"
    primary_group_arg="-g$primary"
fi
}  

function set_uid() {
if [ "$uid" == "" ]; then
    uid_arg=""
else
    uid_arg="-u$uid"
fi
}  

function check_shell_path(){
if [ "$shell" == "" ]; then
    shell_arg=""
    return 0 
elif [ -x "$shell" ]; then
    shell_arg="-s$shell"
    return 0
else
    shell_arg=""
    echo "Shell path ($shell) does not exist or not not executable"
    return 1
fi
}

function check_homedir(){
if [ "$homedir" == "" ]; then
    homedir="/home/$username/"
    check_homedir
    return $? 
elif [ -d "$homedir" ]; then
    if [ $(cat /etc/passwd | grep "::$homedir:") ]; then
        echo "another user is an owner of $homedir"
        return 1
    else
        echo no user has $homedir as home directory
        return 0
    fi
#    echo directory $homedir already exists
#    homedir_arg=""
#    return 1
else
    echo mkdir $homedir
    mkdir $homedir
    homedir_arg="-d$homedir"
    return 0
fi

if [ $(cat /etc/passwd | grep $homedir) ]; then
    echo "another user is an owner of $homedir"
    return 1
else
    echo no user has $homedir as home directory
    return 0
fi
}

function change_owner(){
local gid=$(id -g $username)
echo chown -R $username:$gid $homedir
chown -R $username:$gid $homedir
}

function add_user(){
if [ "$username" != "" ]; then
if [ $(getent passwd $username) ]; then
    echo "User $username already exists"
else
    check_shell_path
    if [ $? -eq 0 ]; then
      check_homedir
      if [ $? -eq 0 ];then
          set_groups_arg
          set_password_arg
          set_primary_group_arg
          set_uid
          echo useradd: $username $passw_arg $primary_group_arg $groups_arg $homedir_arg $shell_arg $uid_arg
          useradd $username $passw_arg $primary_group_arg $groups_arg $homedir_arg $shell_arg $uid_arg
          change_owner
      else
          echo Can not create user $username  with homedir=$homedir
      fi
    else
        echo Can not create user $username with shell path=$shell
    fi

fi; fi
username=""
groups=""
primary=""
password=""
homedir=""
uid=""
shell=""
}
####### END OF FUNCTIONS ########

filename=$1
check_for_admin
echo FILENAME: $filename

if [ -f "$filename" ]; then           #If the file user specified exists
GROUPS_LABEL="Groups"
USERNAME_LABEL="Username"
PASSWORD_LABEL="Password"
HOMEDIR_LABEL="Homedir"
PRIMARY_GROUP_LABEL="PrimaryGroup"
UID_LABLE="Uid"
SHELL_LABEL="Shell"

username=""
groups=""
primary=""
password=""
homedir=""
uid=""
shell=""

IFS="="
while read -r name value
do
    if [ "$name" == "$USERNAME_LABEL" ]; then
        # if [ "$username" != "" ]; then - check for this in add_user
        add_user $username $password $groups $homedir
        username="$value"
    elif [ "$name" == "$PASSWORD_LABEL" ]; then
        password="$value"
    elif [ "$name" == "$HOMEDIR_LABEL" ]; then
        homedir="$value"
    elif [ "$name" == "$GROUPS_LABEL" ]; then
        groups="$value"
    elif [ "$name" == "$PRIMARY_GROUP_LABEL" ]; then
        primary="$value"
    elif [ "$name" == "$UID_LABEL" ]; then
        uid="$value"
    elif [ "$name" == "$SHELL_LABEL" ]; then
        shell="$value"
    elif [ "$name" != "" ]; then
        echo "Non valid option $name"    
    fi
done < "$filename"
add_user $username $password $groups $homedir

else  #If the user Specified file doesn't Exists
	echo -e "\nCANNOT FIND or LOCATE THE FILE"
fi;

