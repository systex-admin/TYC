#!/bin/bash

ANSIBLE_HOST="$1"
ANSIBLE_PATH="$2"
TENANT_LOG="$3"
F5_PATH="$4"

function getTenant(){
    scp -o StrictHostKeyChecking=no root@${ANSIBLE_HOST}:${ANSIBLE_PATH}/${TENANT_LOG} ${F5_PATH}/
}

getTenant
