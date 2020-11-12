#!/bin/bash
# William Lam
# www.virtuallyghetto.com

VSPHERE_WITH_TANZU_CONTROL_PLANE_IP=10.10.0.64
VSPHERE_WITH_TANZU_USERNAME=administrator@vsphere.local
VSPHERE_WITH_TANZU_PASSWORD=VMware1!
VSPHERE_WITH_TANZU_NAMESPACE=primp-industries

KUBECTL_VSPHERE_PATH=/Users/lamw/Desktop/bin/kubectl-vsphere
KUBECTL_PATH=/usr/local/bin/kubectl

KUBECTL_VSPHERE_LOGIN_COMMAND=$(expect -c "
spawn $KUBECTL_VSPHERE_PATH login --server=$VSPHERE_WITH_TANZU_CONTROL_PLANE_IP --vsphere-username $VSPHERE_WITH_TANZU_USERNAME --insecure-skip-tls-verify
expect \"*?assword:*\"
send -- \"$VSPHERE_WITH_TANZU_PASSWORD\r\"
expect eof
")

${KUBECTL_PATH} config use-context ${VSPHERE_WITH_TANZU_NAMESPACE}
