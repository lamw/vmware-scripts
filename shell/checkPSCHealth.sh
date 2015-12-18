#!/bin/bash
# Author: William Lam
# Site: www.virtuallyghetto.com
# Description: Poor man's script to check PSC connectivity /websso & perform automatic failover to secondary PSC
# Reference: http://www.virtuallyghetto.com/2015/12/how-to-automatically-repoint-failover-vcsa-to-another-replicated-platform-services-controller-psc.html

# IP/Hostname of Primary PSC
PRIMARY_PSC=psc-01.primp-industries.com

# IP/Hostname of Secondary PSC (must already be replicating with Primary PSC)
SECONDARY_PSC=psc-02.primp-industries.com

# Number of times to check PSC connecvitity before failing over
NUMBER_CHECKS=3

# Sleep time between checks (seconds)
SLEEP_TIME=30

# Email when failover occurs
EMAIL_ADDRESS=lamw@virtuallyghetto.com

### DO NOT MODIFY BEYOND HERE ###

CHECK_COUNT=0
WORKDIR=/root/psc-health-check

# ensure only single instance of the script runs
if mkdir ${WORKDIR}; then
  # Only run if failover has not occured before
  if [ ! -e ran-psc-failover ]; then
    for i in $(seq 0 ${NUMBER_CHECKS});
    do
      if [ ${CHECK_COUNT} == ${NUMBER_CHECKS} ]; then
        logger -t "vGhetto-PSC-HEALTH-CHECK" "Initiating failover to passive PSC ${SECONDARY_PSC}"
        # repoint to passive PSC
        /bin/cmsso-util repoint --repoint-psc ${SECONDARY_PSC} > /root/psc-failover.log

        # Ensure script no longer runs after failover
        touch /root/ran-psc-failover

        # Send an email notification regarding failover so admin is aware
        if [[ ${EMAIL_ADDRESS} ]]; then
          logger "Sending email notification to ${EMAIL_ADDRESS}"
          VC_HOSTNAME=$(/usr/lib/vmware-vmafd/bin/vmafd-cli get-pnid --server-name localhost)
          cat > /tmp/psc-email << __PSC_EMAIL__
          Subject: PSC Failover Notification

          VC ${VC_HOSTNAME} failed over to passive PSC ${SECONDARY_PSC} at $(date)
__PSC_EMAIL__
          /usr/sbin/sendmail ${EMAIL_ADDRESS} < /tmp/psc-email
        fi
        rm -rf ${WORKDIR}
        exit
      fi

      # Checking PSC's /websso endpoint as a quick method to validate if PSC is operational
      if [ $(curl --max-time 10 -s -o /dev/null -w "%{http_code}" -i -k https://${PRIMARY_PSC}/websso/) -ne 200 ]; then
        CHECK_COUNT=$((CHECK_COUNT+1))
        logger -t "vGhetto-PSC-HEALTH-CHECK" "Uanble to connect to ${PRIMARY_PSC} (Count=${CHECK_COUNT}/${NUMBER_CHECKS})"
        sleep ${SLEEP_TIME}
      else
        logger -t "vGhetto-PSC-HEALTH-CHECK" "${PRIMARY_PSC} is healthy ... "
        break
      fi
    done
  fi
  rm -rf ${WORKDIR}
fi
