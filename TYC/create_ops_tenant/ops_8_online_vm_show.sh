#!/bin/bash

local_path=$(pwd)
tenant_project_name_list_file=${local_path}/tenant_project_name_list.log
tenant_vm_show_list_file=${local_path}/tenant_vm_show_list.log
tenant_Begin=124
tenant_End=502
vm_count=1
source /home/heat-admin/overcloudrc

if [[ -f ${tenant_project_name_list_file} ]]; then
        sudo rm ${tenant_project_name_list_file}
fi

if [[ -f ${tenant_vm_show_list_file} ]]; then
        sudo rm ${tenant_vm_show_list_file}
fi


### List Project Name
openstack project list --sort-column Name | awk -F "|" '{print $3}' | grep "_" | sed s/[[:space:]]//g > ${tenant_project_name_list_file}

for ((i=$tenant_Begin; i<=$tenant_End; i++))
do
        project_name=`cat ${tenant_project_name_list_file} | grep ${i}`
        if [[ ! -z ${project_name} ]]; then
                echo "======= Project ${project_name} Tenant ======="
                echo "======= Project ${project_name} Tenant =======" >> ${tenant_vm_show_list_file}
                tenant_vm_id_list_file=${local_path}/${project_name}_vm_id_list.log
                openstack server list --project ${project_name} -c ID | awk -F "|" '{print $2}' | sed s/[[:space:]]//g | egrep -v "^$|^ID" > ${tenant_vm_id_list_file}
                tenant_vm_count=`cat $tenant_vm_id_list_file | wc -l`
                if [[ $tenant_vm_count == 0 ]]; then
                        echo "Nothing vm in the ${project_name} tenant."
                        sudo rm ${tenant_vm_id_list_file}
                        continue
                fi

                for ((j=0; j<$tenant_vm_count; j++))
                do
                        vm_id=`cat $tenant_vm_id_list_file | head -n $(( 1 + $j )) | tail -n 1`
                        openstack server show ${vm_id} >> ${tenant_vm_show_list_file}
                        echo "[INFO] Project ${project_name} Add server count: ${vm_count}."
                        (( vm_count ++ ))
                done

                if [[ -f ${tenant_vm_id_list_file} ]]; then
                        sudo rm ${tenant_vm_id_list_file}
                fi
        fi
        project_name=""
done
