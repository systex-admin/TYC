#!/bin/bash

DIR=`pwd`
TENANT_LOG=$1
PROJECT_VLAN=$2
PROJECT_DESCRIPTION=$3
PROJECT_EXT_SEGMENT_NUM=$4
PROJECT_EXT_IP_24BIT=$5
PROJECT_MANAGE_IP_24BIT=$6
PROJECT_USER_PASS=$7
default_name="_admin"
DNS1="10.255.4.1"
DNS2="10.255.4.2"

function checkAnsible(){
    if [ -z "${TENANT_LOG}" ] || [ "${TENANT_LOG}" == "" ]; then
        echo "[ERROR] PARAMETER IS EMPTY"
        exit 1
    fi

    if [ -z "${PROJECT_VLAN}" ] || [ "${PROJECT_VLAN}" == "" ]; then
        echo "[ERROR] PARAMETER IS EMPTY"
        exit 1
    fi

    if [ -z "${PROJECT_DESCRIPTION}" ] || [ "${PROJECT_DESCRIPTION}" == "" ]; then
        echo "[ERROR] PARAMETER IS EMPTY"
        exit 1
    fi

    if [ -z "${PROJECT_EXT_SEGMENT_NUM}" ] || [ "${PROJECT_EXT_SEGMENT_NUM}" == "" ]; then
        echo "[ERROR] PARAMETER IS EMPTY"
        exit 1
    fi

    if [ -z "${PROJECT_EXT_IP_24BIT}" ] || [ "${PROJECT_EXT_IP_24BIT}" == "" ]; then
        echo "[ERROR] PARAMETER IS EMPTY"
        exit 1
    fi

    if [ -z "${PROJECT_MANAGE_IP_24BIT}" ] || [ "${PROJECT_MANAGE_IP_24BIT}" == "" ]; then
        echo "[ERROR] PARAMETER IS EMPTY"
        exit 1
    fi

    if [ -z "${PROJECT_MANAGE_IP_24BIT}" ] || [ "${PROJECT_MANAGE_IP_24BIT}" == "" ]; then
        echo "[ERROR] PARAMETER IS EMPTY"
        exit 1
    fi
}

function create_openstack_tenant(){
    checkAnsible
    keystone
    checkTenant
    project
    user
    role
    export OS_PROJECT_NAME=${PROJECT_VLAN}
    network
    subnets
    router
    export OS_PROJECT_NAME=admin
    keypair
    set_tenant_log
}

function keystone(){
    source /home/heat-admin/overcloudrc
}

function project(){
    openstack project create --description "${PROJECT_DESCRIPTION}" ${PROJECT_VLAN} --domain default
}

function user(){
    openstack user create --project ${PROJECT_VLAN} --password ${PROJECT_USER_PASS} "${PROJECT_VLAN}${default_name}"
}

function role(){
    openstack role add --user "${PROJECT_VLAN}${default_name}" --project "${PROJECT_VLAN}" "_member_"
    sleep 1
    openstack role add --user "admin" --project "${PROJECT_VLAN}" "_member_"
    sleep 1
    openstack role add --user "${PROJECT_VLAN}${default_name}" --project "${PROJECT_VLAN}" "admin"
    sleep 1
    openstack role add --user "admin" --project "${PROJECT_VLAN}" "admin"
    sleep 1
}

function network(){
    openstack network create ${PROJECT_VLAN}_external --external --provider-network-type vlan --provider-physical-network datacentre --provider-segment ${PROJECT_EXT_SEGMENT_NUM}
    sleep 1
    openstack network create ${PROJECT_VLAN}_manage --external --provider-network-type vlan --provider-physical-network datacentre --provider-segment 2${PROJECT_EXT_SEGMENT_NUM}
    sleep 1
    openstack network create ${PROJECT_VLAN}_tenant-external --provider-network-type vxlan
    sleep 1
    openstack network create ${PROJECT_VLAN}_tenant-manage --provider-network-type vxlan
    sleep 1
}

function subnets(){
    openstack subnet create ${PROJECT_VLAN}_external-sub --network ${PROJECT_VLAN}_external --subnet-range ${PROJECT_EXT_IP_24BIT}.0/24 --gateway ${PROJECT_EXT_IP_24BIT}.254 --allocation-pool start=${PROJECT_EXT_IP_24BIT}.1,end=${PROJECT_EXT_IP_24BIT}.6 --dhcp --ip-version 4 --dns-nameserver ${DNS1} --dns-nameserver ${DNS2}
    sleep 1
    openstack subnet create ${PROJECT_VLAN}_manage-sub --network ${PROJECT_VLAN}_manage --subnet-range ${PROJECT_MANAGE_IP_24BIT}.0/24 --gateway ${PROJECT_MANAGE_IP_24BIT}.254 --allocation-pool start=${PROJECT_MANAGE_IP_24BIT}.1,end=${PROJECT_MANAGE_IP_24BIT}.6 --dhcp --ip-version 4 --dns-nameserver ${DNS1} --dns-nameserver ${DNS2}
    sleep 1
    openstack subnet create ${PROJECT_VLAN}_tenant-external-sub --network ${PROJECT_VLAN}_tenant-external --subnet-range 10.0.0.0/24 --gateway 10.0.0.1 --allocation-pool start=10.0.0.2,end=10.0.0.254 --dhcp --ip-version 4 --dns-nameserver ${DNS1} --dns-nameserver ${DNS2}
    sleep 1
    openstack subnet create ${PROJECT_VLAN}_tenant-manage-sub --network ${PROJECT_VLAN}_tenant-manage --subnet-range 10.0.1.0/24 --gateway 10.0.1.1 --allocation-pool start=10.0.1.2,end=10.0.1.254 --dhcp --ip-version 4
    sleep 1
}

function router(){
    openstack router create ${PROJECT_VLAN}_external-router
    sleep 1
    openstack router set ${PROJECT_VLAN}_external-router --external-gateway ${PROJECT_VLAN}_external
    sleep 1
    openstack router add subnet ${PROJECT_VLAN}_external-router ${PROJECT_VLAN}_tenant-external-sub
    sleep 1
    openstack router create ${PROJECT_VLAN}_manage-router
    sleep 1
    openstack router set ${PROJECT_VLAN}_manage-router --external-gateway ${PROJECT_VLAN}_manage
    sleep 1
    openstack router add subnet ${PROJECT_VLAN}_manage-router ${PROJECT_VLAN}_tenant-manage-sub
    sleep 1
}

function keypair(){
    KEY_NAME="tyc-${PROJECT_VLAN}-admin"
    openstack keypair create --private-key ${KEY_NAME}.pem ${KEY_NAME}
    sleep 1
    chown -R heat-admin.heat-admin ${DIR}/*.pem
    chmod 600 ${KEY_NAME}.pem
    echo "Please check key: ${DIR}/${KEY_NAME}.pem "
}

function checkTenant(){
    # Check Openstack Tenant Exist
    CH_TENANT=`openstack project list --my-projects | grep "${PROJECT_VLAN}" | awk -F "|" '{print $3}' | sed s/[[:space:]]//g`
    if [ "${CH_TENANT}" == "${PROJECT_VLAN}" ];then
        echo "[ERROR] Openstack Tenant ${PROJECT_VLAN} already exist."
        exit 1
    fi
}

function set_tenant_log(){
    echo "VLAN: ${PROJECT_EXT_SEGMENT_NUM}" >> ${TENANT_LOG}
    echo "EXT_POOL: ${PROJECT_EXT_IP_24BIT}" >> ${TENANT_LOG}
    echo "MANAGE_POOL: ${PROJECT_MANAGE_IP_24BIT}" >> ${TENANT_LOG}
    chmod 755 ${DIR}/${TENANT_LOG}
    chown -R heat-admin.heat-admin ${DIR}/${TENANT_LOG}
}

create_openstack_tenant

