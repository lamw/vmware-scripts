#!/bin/bash
# Modified script from (@fabiorapposelli) to mirror TKG 1.0 (GA) containers into local Harbor Registry

REGISTRY_URL=registry.williamlam.com
TKG_CLI_PATH=/usr/local/bin/tkg

if [ ! -e ${TKG_CLI_PATH} ]; then
    echo "Unable to find tkg binary in ${TKG_CLI_PATH} ... exiting"
    exit 1
fi

LIST=(
registry.tkg.vmware.run/kind/node:v1.17.3_vmware.2
registry.tkg.vmware.run/cluster-api/cluster-api-aws-controller:v0.5.2_vmware.1
registry.tkg.vmware.run/cluster-api/kubeadm-control-plane-controller:v0.3.3_vmware.1
registry.tkg.vmware.run/cluster-api/kubeadm-bootstrap-controller:v0.3.3_vmware.1
registry.tkg.vmware.run/cluster-api/cluster-api-controller:v0.3.3_vmware.1
registry.tkg.vmware.run/cluster-api/cluster-api-vsphere-controller:v0.6.3_vmware.1
registry.tkg.vmware.run/csi/volume-metadata-syncer:v1.0.2_vmware.1
registry.tkg.vmware.run/ccm/manager:v1.1.0_vmware.2
registry.tkg.vmware.run/csi/vsphere-block-csi-driver:v1.0.2_vmware.1
registry.tkg.vmware.run/csi/csi-provisioner:v1.4.0_vmware.2
registry.tkg.vmware.run/csi/csi-attacher:v1.1.1_vmware.7
registry.tkg.vmware.run/csi/csi-node-driver-registrar:v1.1.0_vmware.7
registry.tkg.vmware.run/csi/csi-livenessprobe:v1.1.0_vmware.7
registry.tkg.vmware.run/calico-all/node:v3.11.2_vmware.1
registry.tkg.vmware.run/calico-all/pod2daemon:v3.11.2_vmware.1
registry.tkg.vmware.run/calico-all/cni-plugin:v3.11.2_vmware.1
registry.tkg.vmware.run/calico-all/kube-controllers:v3.11.2_vmware.1
registry.tkg.vmware.run/cluster-api/kube-rbac-proxy:v0.4.1_vmware.2
registry.tkg.vmware.run/cert-manager/cert-manager-controller:v0.11.0_vmware.1
registry.tkg.vmware.run/cert-manager/cert-manager-cainjector:v0.11.0_vmware.1
registry.tkg.vmware.run/cert-manager/cert-manager-webhook:v0.11.0_vmware.1
)

newImageRepo="${REGISTRY_URL}\/library"
sourceDir="/root/.tkg"

${TKG_CLI_PATH} get mc

echo '> Start mirroring process'
for image in "${LIST[@]}"
do
    :
    image=${image//[$'\t\r\n ']}
    origImageRepo=$(echo "$image" | awk -F/ '{ print $1 }')
    imageDestination=$(echo -n "$image" | sed "s/$origImageRepo/$newImageRepo/g")
    echo "> Pulling $image"
    docker pull "$image"
    # Do not push KIND container into Harbor as this is only used locally
    if [ "$image" != "registry.tkg.vmware.run/kind/node:v1.17.3_vmware.2" ]; then
        echo "> Tagging $image -> $imageDestination"
        docker tag "$image" "$imageDestination"
        echo "> Pushing $imageDestination"
        docker push "$imageDestination"
        docker rmi "$image"
    fi
    # Leaving these containers cached in Photon to speed up KIND deployment
    if [[ "$imageDestination" != "${REGISTRY_URL}/library/cert-manager/cert-manager-webhook:v0.11.0_vmware.1" ]] && [[ "$imageDestination" != "${REGISTRY_URL}/library/cert-manager/cert-manager-cainjector:v0.11.0_vmware.1" ]] && [[ "$imageDestination" != "${REGISTRY_URL}/library/cert-manager/cert-manager-controller:v0.11.0_vmware.1" ]]; then
        docker rmi "$imageDestination"
    fi
done

echo "> Pointing all image repos to $newImageRepo"
grep -RiIl 'mage: ' "$sourceDir" | xargs perl -i -pe "s/mage: .*?\/(.*)/mage: ${newImageRepo//./\\.}\/\1/"
