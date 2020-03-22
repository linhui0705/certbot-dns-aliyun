#!/bin/bash

AccessKeyId=$1
AccessKeySecret=$2
# echo "AccessKeyId: " $AccessKeyId
# echo "AccessKeySecret: " $AccessKeySecret
# echo "CERTBOT_DOMAIN=" $CERTBOT_DOMAIN
# echo "CERTBOT_VALIDATION=" $CERTBOT_VALIDATION
# echo "CERTBOT_TOKEN=" $CERTBOT_TOKEN

Type="TXT"

# "_acme-challenge"
# $1 -> CERTBOT_DOMAIN
# 
# e.g.: 
# blog.example.com -> [blog]
# *.example.com -> [](empty)
GET_DOMAIN_PREFIX(){
    SubDomain=${1%.*}
    # echo $SubDomain
    index=$(expr index $SubDomain '.')
    # echo $index
    if [ $index == 0 ]; then
        echo ""
    else
        SubDomain=${SubDomain%.*}
        echo $SubDomain
    fi
}

# e.g.: 
# [blog] -> [_acme-challenge.blog]
# [] -> [_acme-challenge]
GET_RR(){
    str=$(GET_DOMAIN_PREFIX $CERTBOT_DOMAIN)
    if [ ${#str} == 0 ]; then
        echo "_acme-challenge"
    else
        echo "_acme-challenge."$str
    fi
}

# $1 -> DomainPrefix
GET_DOMAIN(){
    prefix=$1
    if [ ${#prefix} == 0 ]; then
        echo ${CERTBOT_DOMAIN}
    else
        echo ${CERTBOT_DOMAIN#"$prefix."}
    fi
}

ENCRYPT(){
    StringToSign=$1
    # 根据阿里云API鉴权规则，部分字符按要求转换
    StringToSign=${StringToSign//"="/"%3D"}
    StringToSign=${StringToSign//"+"/"%20"}
    StringToSign=${StringToSign//"*"/"%2A"}
    StringToSign=${StringToSign//"\""/"%22"}
    StringToSign=${StringToSign//"~"/"%7E"}
    StringToSign=${StringToSign//"&"/"%26"}
    StringToSign=${StringToSign//" "/"%20"}
    StringToSign=${StringToSign//":"/"%253A"}
    StringToSign="GET&%2F&$StringToSign"
    
    AKS=$2'&'
    # 加密算法
    sign=$(echo -n $StringToSign | openssl dgst -sha1 -hmac $AKS -binary | openssl base64)
    # UrlEncode编码
    sign=$(echo $sign | tr -d '\n' | xxd -plain | sed 's/\(..\)/%\1/g')
    echo $sign
}

# 产生随机UUID
GET_UUID(){
    echo `cat /proc/sys/kernel/random/uuid`
}

# 获取当前时间戳
GET_TIMESTAMP(){
    echo `date -u +"%Y-%m-%dT%H:%M:%SZ"`
}

# HTTPS请求
REQUEST(){
    accessKeySecret=$1
    params=$2
    # 获取加密后的签名
    sign=$(ENCRYPT $params $accessKeySecret)
    url="https://alidns.aliyuncs.com/?Signature=$sign&$params"
    # echo $url
    echo $( curl -k -s $url )
}

# DescribeSubDomainRecords
# $1 -> AccessKeyId
# $2 -> AccessKeySecret
# $3 -> SubDomain
DescribeSubDomainRecords(){
    DSR_REQ_PARAM="AccessKeyId=$1&Action=DescribeSubDomainRecords&Format=JSON&RegionId=cn-hangzhou&SignatureMethod=HMAC-SHA1&SignatureNonce=$(GET_UUID)&SignatureVersion=1.0&SubDomain=$3&Timestamp=$(GET_TIMESTAMP)&Version=2015-01-09"
    # 调用DescribeSubDomainRecords接口
    DSR_RESPONSE=$(REQUEST $2 $DSR_REQ_PARAM)
    # 若请求结果返回为空
    if [ -z "$DSR_RESPONSE" ] 
    then
        echo "HTTPS请求返回为空，调用失败！"
        exit 1
    fi
    # 若调用Alidns接口失败，返回错误接口错误信息
    code=$(echo $DSR_RESPONSE | jq -r ."Code")
    if [ "$code" != "null" ] 
    then
        echo "Alidns接口调用失败。错误码："$code
        exit 1
    fi
    # 获取RecordId
    RecordId=$(echo $DSR_RESPONSE | jq -r ."DomainRecords.Record[0].RecordId")
    # echo $RecordId
}

# SetDomainRecordStatus
# $1 -> AccessKeyId
# $2 -> AccessKeySecret
# $3 -> RecordId
# $4 -> Status Enable/Disable
SetDomainRecordStatus(){
    # SetDomainRecordStatus接口 请求参数
    SDRS_REQ_PARAM="AccessKeyId=$1&Action=SetDomainRecordStatus&Format=JSON&RecordId=$3&RegionId=cn-hangzhou&SignatureMethod=HMAC-SHA1&SignatureNonce=$(GET_UUID)&SignatureVersion=1.0&Status=$4&Timestamp=$(GET_TIMESTAMP)&Version=2015-01-09"
    # 调用SetDomainRecordStatus接口
    SDRS_RESPONSE=$(REQUEST $2 $SDRS_REQ_PARAM)
    # 若请求结果返回为空
    if [ -z "$SDRS_RESPONSE" ] 
    then
        echo "HTTPS请求返回为空，调用失败！"
        exit 1
    fi
    # 若调用Alidns接口失败，返回错误接口错误信息
    code=$(echo $SDRS_RESPONSE | jq -r ."Code")
    if [ "$code" != "null" ] 
    then
        echo "Alidns接口调用失败。错误码："$code
        exit 1
    fi
    # echo "SDRS_RESPONSE => "$SDRS_RESPONSE
}

################################################
# 域名前缀
DomainPrefix=$(GET_DOMAIN_PREFIX $CERTBOT_DOMAIN)
# echo "PREFIX: "$DomainPrefix
# RR
RR=$(GET_RR)
# echo $RR
# 主域名
DomainName=$(GET_DOMAIN $DomainPrefix)
# echo "DOMAIN-> "$(GET_DOMAIN $DomainPrefix)

SubDomain=$RR"."$DomainName
DescribeSubDomainRecords $AccessKeyId $AccessKeySecret $SubDomain

# 若RecordId不为空，对域名解析设置为暂停解析
if [ "$RecordId" != "null" ]; then
    # 否则，调用更新接口
    echo "找到RecordId，进行更新操作"
    SetDomainRecordStatus $AccessKeyId $AccessKeySecret $RecordId "Disable"
fi

echo "Cleanup finish!"
