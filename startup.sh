#!/bin/bash

# Your AccessKeyId
AccessKeyId="YOUR_ACCESSKEYID"
# Your AccessKeySecret
AccessKeySecret="YOUR_ACCESSKEYSECRET"

# 检查jq，需要利用jq解析http请求返回的json
CHECK_ENV(){
    ########## epel-release ##########
    # 检查安装epel-release
    if [ -z $(rpm -qa|grep epel-release) ]
    then
        echo "epel-release will be installed in your server. Please wait a minute."
        yum install epel-release -y
    else
        echo "epel-release has been installed."
    fi
    # 再次检查，确认是否已安装epl-release
    if [ -z $(rpm -qa|grep epel-release) ]
    then
        echo "Install epl-release failed. Please try again later."
        exit 1
    fi

    ########## jq ##########
    # 安装jq
    if [ -z $(rpm -qa|grep jq) ]
    then
        echo "jq will be installed in your server. Please wait a minute."
        yum install jq -y
    else
        echo "jq has been installed."
    fi
    # 再次检查，确认是否已安装jq
    if [ -z $(rpm -qa|grep jq) ]
    then
        echo "Install jq failed. Please try again later."
        exit 1
    fi
}

######################################################
cd /usr/local/certbot/certbot-dns-aliyun
CHECK_ENV
# Remove old certbot-auto
rm -f certbot-auto
# Download or update certbot-auto
wget https://dl.eff.org/certbot-auto

if [ ! -f "certbot-auto" ] 
then
    echo "File certbot-auto not found."
    exit 1
fi

# Set Permissions
chmod u+x certbot-auto authenticator.sh cleanup.sh

if [ ! -f "authenticator.sh" ] 
then
    echo "File authenticator.sh not found."
    exit 1
fi

if [ ! -f "cleanup.sh" ] 
then
    echo "File cleanup.sh not found."
    exit 1
fi

if [ ! -d "log" ]
then
    mkdir "log"
fi

if [ "$1" == "test" ]
then
    # Test Scripts
    ./certbot-auto --server https://acme-v02.api.letsencrypt.org/directory -d "*.example.com" --manual --manual-auth-hook "./authenticator.sh $AccessKeyId $AccessKeySecret" --manual-cleanup-hook "./cleanup.sh $AccessKeyId $AccessKeySecret" --manual-public-ip-logging-ok --preferred-challenges dns-01 certonly --dry-run > ./log/$(date +%Y%m%d)-$(date +%H%M%S)-test.log
else
    # Run Scripts
    ./certbot-auto --server https://acme-v02.api.letsencrypt.org/directory -d "*.example.com" --manual --manual-auth-hook "./authenticator.sh $AccessKeyId $AccessKeySecret" --manual-cleanup-hook "./cleanup.sh $AccessKeyId $AccessKeySecret" --manual-public-ip-logging-ok --preferred-challenges dns-01 certonly > ./log/$(date +%Y%m%d)-$(date +%H%M%S).log
fi
