#!/bin/bash
# William Lam
# www.williamlam.com
# Script to automatically replace AppCatalyst's default PhotonOS VMDK w/VMDK that includes Docker 1.9

COLOR_ON="\x1b[36;01m"
COLOR_OFF="\x1b[39;49;00m"

APPCATALYST_HOME="/opt/vmware/appcatalyst"
PHOTONVM_TEMPLATE_HOME="${APPCATALYST_HOME}/photonvm"
PHOTONVM_TEMPLATE_VMDK="${PHOTONVM_TEMPLATE_HOME}/photon-disk1-cl1.vmdk"
TEMP_PHOTON_VM="PHOTON-DOCKER-1.9"

checkRunSudo() {
  # store original user's home dir
  APPCATALYST_VM_DIR="${HOME}/Documents/AppCatalyst"
  ORIG_USER=$(echo "${HOME#/*/*}")
  COLOR_ERR="\x1b[31;01m"

  if [ "${EUID}" -ne 0 ]; then
    echo -e "\n${COLOR_ERR} Please run the script with sudo${COLOR_OFF}\n"
    exit 1
  fi
}

CreateTempPhotonVM() {
  echo -e "\n${COLOR_ON} Creating Temp PhotonVM ${TEMP_PHOTON_VM} to install Docker 1.9 ...${COLOR_OFF}"
  sudo -u "${ORIG_USER}" "${APPCATALYST_HOME}/bin/appcatalyst" vm create "${TEMP_PHOTON_VM}"
}

PowerOnTempPhotonVM() {
  echo -e "${COLOR_ON} Powering on Temp PhotonVM ${TEMP_PHOTON_VM} ...${COLOR_OFF}"
  sudo -u "${ORIG_USER}" "${APPCATALYST_HOME}/bin/appcatalyst" vmpower on "${TEMP_PHOTON_VM}"

  echo -e "${COLOR_ON} Sleeping for 120 seconds until IP Address is available for Temp PhotonVM ${TEMP_PHOTON_VM} ...${COLOR_OFF}"
  sleep 120
}

GetTempPhotonVMIp() {
  echo -e "Retrieving Temp PhotonVM ${TEMP_PHOTON_VM} IP Address ....${COLOR_OFF}"
  TEMP_PHOTON_VM_IP=$(sudo -u "${ORIG_USER}" "${APPCATALYST_HOME}/bin/appcatalyst" guest getip "${TEMP_PHOTON_VM}")
  echo -e "${COLOR_ON} Temp PhotonVM ${TEMP_PHOTON_VM} IP Address is ${TEMP_PHOTON_VM_IP} ...${COLOR_OFF}"
}

InstallDocker19InTempVM() {
  UPDATE_DOCKER19_CLIENT_COMMAND="sudo tdnf -y install tar;curl -O https://get.docker.com/builds/Linux/x86_64/docker-1.9.1.tgz;tar -zxvf docker-1.9.1.tgz;sudo systemctl stop docker;sudo cp usr/local/bin/docker /usr/bin/docker;sudo systemctl start docker;rm -rf usr/;rm -f docker-1.9.1.tgz;sudo shutdown"

  echo -e "${COLOR_ON} SSH'ing into Temp PhotonVM ${TEMP_PHOTON_VM} to install Docker 1.9 ...${COLOR_OFF}"
  # SSH keys permissions are too open for root, will change back to original settings after SSH session
  chmod 600 "${APPCATALYST_HOME}/etc/appcatalyst_insecure_ssh_key"
  ssh -i "${APPCATALYST_HOME}/etc/appcatalyst_insecure_ssh_key" photon@${TEMP_PHOTON_VM_IP} "${UPDATE_DOCKER19_CLIENT_COMMAND}"
  chmod 644 "${APPCATALYST_HOME}/etc/appcatalyst_insecure_ssh_key"
}

ShutdownTempPhotonVM() {
  echo -e "${COLOR_ON} Shutting down Temp PhotonVM ${TEMP_PHOTON_VM}, this may take few seconds ...${COLOR_OFF}"
  sudo -u "${ORIG_USER}" "${APPCATALYST_HOME}/bin/appcatalyst" vmpower shutdown "${TEMP_PHOTON_VM}"
  sleep 20
}

BackupOriginalPhotonVMDK() {
  echo -e "${COLOR_ON} Backing up AppCatalyst's original PhotonVM Template to ${PHOTONVM_TEMPLATE_VMDK}.bak ...${COLOR_OFF}"
  mv "${PHOTONVM_TEMPLATE_VMDK}" "${PHOTONVM_TEMPLATE_VMDK}.bak"
}

ReplaceOriginalPhotonVMDK() {
  echo -e "${COLOR_ON} Replacing AppCatalyst's original PhotonVM VMDK w/new Temp PhotonVM ${TEMP_PHOTON_VM} VMDK w/Docker 1.9 ...${COLOR_OFF}"
  TEMP_PHONE_VM_VMDK=$(find "${HOME}/Documents/AppCatalyst/${TEMP_PHOTON_VM}" -name '*.vmdk')
  cp "${TEMP_PHONE_VM_VMDK}" "${PHOTONVM_TEMPLATE_VMDK}"
  chmod 644 "${PHOTONVM_TEMPLATE_VMDK}"
}

profit() {
  COLOR_ON="\x1b[32;01m"
  echo -e "\n\t${COLOR_ON} You are now ready to deploy more AppCatalyst VMs which includes Docker 1.9!!!${COLOR_OFF}\n"
}

main() {
  checkRunSudo
  CreateTempPhotonVM
  PowerOnTempPhotonVM
  GetTempPhotonVMIp
  InstallDocker19InTempVM
  ShutdownTempPhotonVM
  BackupOriginalPhotonVMDK
  ReplaceOriginalPhotonVMDK
  profit
}

main
