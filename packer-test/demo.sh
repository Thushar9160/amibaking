#!/bin/bash


#Use given below command for reference to get the list of available stable DT oneagent versions.
#wget -q -O - "https://zyu62523.live.dynatrace.com/api/v1/deployment/installer/agent/versions/unix/default" --header="Authorization: Api-Token paastoken | cat

#Current available list of stable versions for reference below.
#1.223.99.20210818-200012","1.221.143.20210805-114220","1.223.105.20210824-140926


#DT install variables

version="latest"
dt_version=$version
dt_user="dtuser"
s3_path=$s3path
home="/tmp"


# SSM parameter

get_ssm_param() {
                aws ssm get-parameter --name $1 --query "Parameter.Value" --output text --region us-east-1
}


# Get latest Version

get_latest_version() {
                 wget -q -O- "https://$1.live.dynatrace.com/api/v1/deployment/installer/agent/unix/default/latest/metainfo" --header="Authorization: Api-Token $2" | cut -d: -f2 | sed -e 's/^"//' -e 's/"}$//'
}


# Variable for getting latest version

dt_env_id=$(get_ssm_param 'env_id')
dt_pass_token=$(get_ssm_param 'token')
dt_latest_version=$(get_latest_version "$dt_env_id" "$dt_pass_token")



# DT latest version install

dt_latest_install() {
                    printf "\nchecking the latest available version\n"
                    dt_version=$dt_latest_version
                    if aws s3 ls s3://oneagentdt/images/ | grep Dynatrace-OneAgent-Linux-$dt_version.sh
                    then
                       s3_install 
                    else
                        wget -O $home/Dynatrace-OneAgent-Linux-$dt_latest_version.sh "https://$dt_env_id.live.dynatrace.com/api/v1/deployment/installer/agent/unix/default/latest?arch=x86&flavor=default" --header="Authorization: Api-Token $dt_pass_token" && sh $home/Dynatrace-OneAgent-Linux-$dt_version.sh
                        if [ $(ps -eaf | grep -w $dt_user| wc -l) -gt 1 ]
                        then
                            s3_push
                        fi
                    fi
}


# version specific installation


dt_version_specific_install() {
             printf "\nchecking the oneagent version defined\n"  
             if aws s3 ls s3://oneagentdt/images/ | grep Dynatrace-OneAgent-Linux-$dt_version.sh
             then
                 s3_install
             else
                 wget -O $home/Dynatrace-OneAgent-Linux-$dt_version.sh "https://$dt_env_id.live.dynatrace.com/api/v1/deployment/installer/agent/unix/default/version/$dt_version?arch=x86&flavor=default" --header="Authorization: Api-Token $dt_pass_token" && sh $home/Dynatrace-OneAgent-Linux-$dt_version.sh
                 if [ $(ps -eaf | grep -w $dt_user| wc -l) -gt 1 ]
                 then
                     s3_push
                 fi
             fi              
}


# download & install from s3 bucket


s3_install() {
            aws s3 cp s3://oneagentdt/images/Dynatrace-OneAgent-Linux-$dt_version.sh $home/Dynatrace-OneAgent-Linux-$dt_version.sh && sh $home/Dynatrace-OneAgent-Linux-$dt_version.sh
}


#push the version of the script to s3


s3_push() {
         aws s3 cp $home/Dynatrace-OneAgent-Linux-$dt_version.sh s3://oneagentdt/images/
}


# Installation of onegent 

final_exec() {
             if [ $dt_version == "latest" ]
             then
                 dt_latest_install
             else
                 dt_version_specific_install
             fi
}


printf "\ninstalling the onegent based on the version defined\n" 
final_exec

