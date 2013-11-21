#!/bin/bash
# William Lam
# www.virtuallyghetto.com

VIN_RESULTS_DIR=/var/log/vadm/results
VIN_LOG=/var/log/vadm/engine.log
VIN_RESULTS_COPY=/root/vin-results

# remove previous copies
if [ -d "${VIN_RESULTS_COPY}" ]; then
        rm -rf "${VIN_RESULTS_COPY}"
fi

# check to see if there's data
if [ $(ls "${VIN_RESULTS_DIR}" | wc -l) -gt 0 ]; then
        echo "$(ls "${VIN_RESULTS_DIR}" | wc -l) VMs"
        # make a copy of results dirctory
        cp -rf "${VIN_RESULTS_DIR}" "${VIN_RESULTS_COPY}"

        # convert MoRef ID to VM Display Name
        for i in $(ls "${VIN_RESULTS_COPY}");
        do
                VM_MOREF=$(echo "${i}" | sed "s/.zip//g");
                VM_NAME=$(grep "Creating discovery task for ${VM_MOREF}" "${VIN_LOG}" | awk -F 'name=' '{print $2}' | tail -1);
                echo "Processing ${VM_NAME} (${VM_MOREF})"
                # rename MoRef Id to VM Display Name
                mv "${VIN_RESULTS_COPY}/${i}" "${VIN_RESULTS_COPY}/${VM_NAME}.zip" > /dev/null 2>&1
        done
else
        echo "${VIN_RESULTS_DIR} does not contain any data"
fi
