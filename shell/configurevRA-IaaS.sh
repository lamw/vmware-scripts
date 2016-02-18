#!/bin/bash
# Author: William Lam
# Site: www.virtuallyghetto.com
# Description: Script to configure vRA IaaS Components on Windows system
# Reference: http://www.virtuallyghetto.com/2016/02/automating-vrealize-automation-7-simple-minimal-part-4-vra-iaas-configuration.html
# Big thanks to Dora L. (vRA Engineering) for her assistance & credit to her for letting me borrow her code snippet samples

# SSO Configurations
HORIZON_SSO_PASSWORD='VMware1!'

# VRA IAAS Configurations
VRA_IAAS_HOSTNAME="vra-iaas.primp-industries.com"
# Windows credentials to VRA IAAS
VRA_IAAS_USERNAME='vra-iaas\administrator'
VRA_IAAS_PASSWORD='VMware1!'

# VRA DB Configurations
VRA_DATABASE_HOSTNAME="vra-iaas.primp-industries.com"
VRA_DATABASE_NAME="VRA"
# Windows credentials to VRA IAAS DB (assuming Windows Auth)
VRA_DATABASE_USERNAME='vra-iaas\administrator'
VRA_DATABASE_PASSWORD='VMware1!'
VRA_DATABASE_SECURITY_PASSPHRASE='VMware1!'

#########  Optional #########

# Installation Logs for debugging
VRA_INSTALL_LOG="/var/log/vra-iaas-configuration.log"

# Enable debug output
DEBUG=0

WEB_SSL_CERT_COMMON_NAME="vra-iaas.primp-industries.com"
WEB_SSL_CERT_COUNTRY="US"
WEB_SSL_CERT_STATE="CA"
WEB_SSL_CERT_CITY='Santa Barbara'
WEB_SSL_CERT_ORG_NAME="Primp-Industries"
WEB_SSL_CERT_ORG_UNIT='R&D'

MS_SSL_CERT_COMMON_NAME="vra-iaas.primp-industries.com"
MS_SSL_CERT_COUNTRY="US"
MS_SSL_CERT_STATE="CA"
MS_SSL_CERT_CITY='Santa Barbara'
MS_SSL_CERT_ORG_NAME="Primp-Industries"
MS_SSL_CERT_ORG_UNIT='R&D'

DEM_WORKER_DESCRIPTION="DEM Worker Description"
DEM_WORKER_NAME="DEM-Worker-01"

DEM_ORCH_DESCRIPTION="DEM Orchestrator Description"
DEM_ORCH_NAME="DEM-Orch-01"

AGENT_NAME="vCenter"
AGENT_TYPE="vSphere"
AGENT_ENDPOINT="vCenter"

######### DO NOT EDIT BEYOND HERE #########

HORIZON_SSO_TENANT="vsphere.local"
HORIZON_SSO_USERNAME="administrator"

CERTS_FOLDER="/root/certs"
PK_LENGTH="4096"
PK_ENCRYPTION="RSA"
CERT_SIGNATURE_ALG="sha256"
VALIDITY_PERIOD="365"
DEFAULT_DATA_LOG_PATH_FLAG=True
DB_WINDOWS_AUTH_FLAG=True
DB_USE_ENCRYPTION=False
MAX_TIMEOUT=30
SLEEP_INTERVAL=60
WEB_CERT_EXPORT_PRIV_KEY=True
MS_ACTIVE_FLAG=True
HTTPS_PORT=443

# vRA Appliance Endpoints
VRA_APPLIANCE_HOSTNAME=$(hostname)
VRA_APPLIANCE_VAMI_ENDPOINT="${VRA_APPLIANCE_HOSTNAME}:5480"

# vRA Appliance Thumbprints
VRA_APPLIANCE_THUMBPRINT=$(echo -n | openssl s_client -connect ${VRA_APPLIANCE_HOSTNAME}:443 2>/dev/null | openssl x509 -noout -fingerprint -sha1 | awk -F '=' '{print $2}' | sed 's/://g')
VRA_APPLIANCE_VAMI_THUMBPRINT=$(echo -n | openssl s_client -connect ${VRA_APPLIANCE_VAMI_ENDPOINT} 2>/dev/null | openssl x509 -noout -fingerprint -sha1 | awk -F '=' '{print $2}' | sed 's/://g')
VRA_IAAS_WEB_THUMBPRINT=""
VRA_IAAS_MS_THUMBPRINT=""

# vRA vPostgres DB
VPOSTGRES_DB_HOSTNAME=localhost
VPOSTGRES_DB_USERNAME=vcac
VPOSTGRES_DB=vcac

generate_ssl_cert() {
	[[ -z $1 ]] && echo "vRA component required for certificate generation. Exiting." && exit 1  ||
	{
		echo "$1 is the first component selected for Certificate generation" >> "${VRA_INSTALL_LOG}" 2>&1
		CERT_PEM="$1.pem"
		CERT_CFG="$1.cfg"
		CERT_REQ="$1.csr"
		CERT_PKEY="$1.key"
		CERT_CRT="$1.crt"
		CERT_PFX="$1.pfx"
	}
	[[ -d ${CERTS_FOLDER} ]] ||
  {
    mkdir "${CERTS_FOLDER}"
	}
	echo "Selected path to store certificates: ${CERTS_FOLDER}"	>> "${VRA_INSTALL_LOG}" 2>&1

	generate_cert_cfg ${@:2}
	generate_csr
	generate_cert_pem
	convert_cert_pem_crt
	convert_cert_pfx
}

generate_cert_cfg() {
SSL_CERT_COUNTRY=$3
SSL_CERT_STATE=$4
SSL_CERT_CITY=$5
SSL_CERT_ORG_NAME=$6
SSL_CERT_ORG_UNIT=$7
SSL_CERT_COMMON_NAME=$8

cat <<EOF >${CERTS_FOLDER}/${CERT_CFG}
[ req ]
default_bits = ${PK_LENGTH}
default_keyfile = rui.key
distinguished_name = req_distinguished_name
encrypt_key = no
prompt = no
string_mask = nombstr
req_extensions = v3_req
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment, dataEncipherment, nonRepudiation
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = DNS:${1}
[ req_distinguished_name ]
countryName = ${SSL_CERT_COUNTRY}
stateOrProvinceName = ${SSL_CERT_STATE}
localityName = ${SSL_CERT_CITY}
0.organizationName = ${SSL_CERT_ORG_NAME}
organizationalUnitName = ${SSL_CERT_ORG_UNIT}
commonName = ${SSL_CERT_COMMON_NAME}
EOF

[[ $? -eq 0 ]] || {
	echo "Certificate configuration file not created. Exit configuration."
	exit 1
	}
}

generate_csr() {
  echo "Generating Certificate Signing Request" >> "${VRA_INSTALL_LOG}" 2>&1
  echo "Generating Certificate Signing Request ..."
  echo "PK_LENGTH=${PK_LENGTH}; PK_ENCRYPTION=${PK_ENCRYPTION}; CERT_SIGNATURE_ALG=${CERT_SIGNATURE_ALG}" >> "${VRA_INSTALL_LOG}" 2>&1
	openssl genrsa -out ${CERTS_FOLDER}/${CERT_PKEY} ${PK_LENGTH} >> "${VRA_INSTALL_LOG}" 2>&1
	openssl req -new -key ${CERTS_FOLDER}/${CERT_PKEY} -${CERT_SIGNATURE_ALG} -out ${CERTS_FOLDER}/${CERT_SIGNATURE_ALG}_${CERT_REQ} -config ${CERTS_FOLDER}/${CERT_CFG} -extensions v3_req >> "${VRA_INSTALL_LOG}" 2>&1

[[ $? -ne 0 ]] && {
	echo "Generate Certificate Signing Request failed."
	exit 1
	} ||
		echo "CSR generated in ${CERTS_FOLDER}/${CERT_REQ} and Private Key: ${CERTS_FOLDER}/${CERT_PKEY}" >> "${VRA_INSTALL_LOG}" 2>&1
		echo "CSR generated in ${CERTS_FOLDER}/${CERT_REQ} and Private Key: ${CERTS_FOLDER}/${CERT_PKEY}"
}

generate_cert_pem() {
  openssl x509 -fingerprint -${CERT_SIGNATURE_ALG} -in ${CERTS_FOLDER}/${CERT_SIGNATURE_ALG}_${CERT_REQ} -days ${VALIDITY_PERIOD} -req -signkey ${CERTS_FOLDER}/${CERT_PKEY}  -extensions v3_req -extfile ${CERTS_FOLDER}/${CERT_CFG} -out ${CERTS_FOLDER}/${CERT_SIGNATURE_ALG}_${CERT_PEM} >> "${VRA_INSTALL_LOG}" 2>&1
  [[ $? -ne 0 ]] && {
    echo "Generate PEM Certificate failed."
    exit 1
  } || echo "CRT certificate generated in ${CERTS_FOLDER}/${CERT_SIGNATURE_ALG}_${CERT_CRT}"
}

generate_cert_crt() {
  openssl req -x509 -nodes -${CERT_SIGNATURE_ALG} -key ${CERTS_FOLDER}/${CERT_PKEY} -in ${CERTS_FOLDER}/${CERT_SIGNATURE_ALG}_${CERT_REQ} -config ${CERTS_FOLDER}/${CERT_CFG} -extensions v3_req -out ${CERTS_FOLDER}/generated_${CERT_SIGNATURE_ALG}_${CERT_CRT}
  [[ $? -ne 0 ]] && {
	   echo "Generate PEM Certificate failed."
     exit 1
	} || echo "PEM certificate generated in ${CERTS_FOLDER}/${CERT_SIGNATURE_ALG}_${CERT_PEM}"
}

convert_cert_pem_crt() {
  openssl x509 -in ${CERTS_FOLDER}/${CERT_SIGNATURE_ALG}_${CERT_PEM}  -out ${CERTS_FOLDER}/${CERT_SIGNATURE_ALG}_${CERT_CRT} -text >> "${VRA_INSTALL_LOG}" 2>&1
  [[ $? -ne 0 ]] && {
    echo "Generate PEM Certificate failed."
    exit 1
  } || echo "PEM certificate generated in ${CERTS_FOLDER}/${CERT_SIGNATURE_ALG}_${CERT_PEM}"
}

convert_cert_pfx() {
  openssl pkcs12 -export -out ${CERTS_FOLDER}/${CERT_SIGNATURE_ALG}_${CERT_PFX} -in ${CERTS_FOLDER}/${CERT_SIGNATURE_ALG}_${CERT_PEM} -inkey ${CERTS_FOLDER}/${CERT_PKEY} -password pass:VMware1! >> "${VRA_INSTALL_LOG}" 2>&1
  [[ $? -ne 0 ]] && {
    echo "Export Certificate to PFX failed."
    exit 1
	} || echo "PFX certificate generated in ${CERTS_FOLDER}/${CERT_PFX}"
}

function getWebCert()
{
   web_private_key=$(cat $CERTS_FOLDER/web.key)
   web_public_key=$(cat $CERTS_FOLDER/${CERT_SIGNATURE_ALG}_web.pem)
   web_cert_pass=""
   web_cert_friendly_name=${VRA_IAAS_HOSTNAME}
   web_cert_store_names="My;TrustedPeople"
   web_cert_store_location="LocalMachine"

   #get web certificate thumbprint
   VRA_IAAS_WEB_THUMBPRINT=`openssl x509 -in $CERTS_FOLDER/${CERT_SIGNATURE_ALG}_web.pem -fingerprint -noout | sed -e 's/://g' -e 's/^.*=//'`
}

function getMSCert()
{
   ms_private_key=$(cat $CERTS_FOLDER/ms.key)
   ms_public_key=$(cat $CERTS_FOLDER/${CERT_SIGNATURE_ALG}_ms.pem)
   ms_cert_pass=""
   ms_cert_friendly_name=${VRA_IAAS_HOSTNAME}
   ms_cert_store_names="My;TrustedPeople"
   ms_cert_store_location="LocalMachine"

   #get ms certificate thumbprint
   VRA_IAAS_MS_THUMBPRINT=`echo | openssl x509 -in $CERTS_FOLDER/${CERT_SIGNATURE_ALG}_ms.pem -fingerprint -noout | sed -e 's/://g' -e 's/^.*=//'`
}

#log the output of the IaaS installation commands
#takes the command id as an argument
function getCommandOutput()
{
   command_id=$1
   installation_type=`echo "select type from public.cluster_commands where cmd_id='$command_id';" | /opt/vmware/vpostgres/current/bin/psql -h $VPOSTGRES_DB_HOSTNAME -U $VPOSTGRES_DB_USERNAME $VPOSTGRES_DB`
   installation_type=$(echo $installation_type | egrep -o "install-[a-z,\-]+" | head -n1)

#initially the command is in status QUEUED
   command_exec_result=1

   #timeout_counter iterates from 0 to MAX_TIMEOUT and shows how many times getting command status was attempted
   timeout_counter=0
   while (true)    #($status=="QUEUED" || $status== "PROCESSING"))
   do
      #wait for 1 minute before checking the command status giving it time to be processed further
      sleep $SLEEP_INTERVAL
      #get the status of the executed command from the postgres database
      output=`echo "select status from public.cluster_commands where cmd_id='$command_id';" | /opt/vmware/vpostgres/current/bin/psql -h $VPOSTGRES_DB_HOSTNAME -U $VPOSTGRES_DB_USERNAME $VPOSTGRES_DB`

      status=$(echo $output | egrep -o "[A-Z]+" | head -n1)
      if [ "$status" = "QUEUED" ]
      then
         command_exec_result=1
      elif [ "$status" = "PROCESSING" ]
      then
         command_exec_result=2
      fi

      #when max number of attempts are reached it is assumed that the command will not execute - no further attempts to check status will be made
      if [ $timeout_counter -eq $MAX_TIMEOUT ]
      then
         echo "== == == == == Installation of $installation_type timed out. == == == == =="
         echo "== == == == == Status of the installation command is $status == == == == =="
         echo
         return $command_exec_result
         #break
      fi

      timeout_counter=$((timeout_counter+1))
      if [ "$status" = "COMPLETED" ]
      then
         command_exec_result=0
         echo "== == == == == $installation_type INSTALLED SUCCSESSFULLY! == == == == =="
         echo
         execution_result_message=`echo "select result_msg from public.cluster_commands where cmd_id='$command_id';" | /opt/vmware/vpostgres/current/bin/psql -h $VPOSTGRES_DB_HOSTNAME -U $VPOSTGRES_DB_USERNAME $VPOSTGRES_DB`
         echo $execution_result_message
         return $command_exec_result
         #break
      elif [ "$status" = "FAILED" ]
      then
         command_exec_result=3
         echo "== == == == == $installation_type INSTALLATION FAILURE! == == == == =="
         execution_result_message=`echo "select result_msg from public.cluster_commands where cmd_id='$command_id';" | /opt/vmware/vpostgres/current/bin/psql -h $VPOSTGRES_DB_HOSTNAME -U $VPOSTGRES_DB_USERNAME $VPOSTGRES_DB`
         echo $execution_result_message
         echo

         execution_result_desc=`echo "select result_descr from public.cluster_commands where cmd_id='$command_id';" | /opt/vmware/vpostgres/current/bin/psql -h $VPOSTGRES_DB_HOSTNAME -U $VPOSTGRES_DB_USERNAME $VPOSTGRES_DB`
         echo $execution_result_desc
         echo

         output_id=`echo "select output from public.cluster_commands where cmd_id='$command_id' and output is not null;" | /opt/vmware/vpostgres/current/bin/psql -h $VRA_DATABASE_HOSTNAME -U $VPOSTGRES_DB_USERNAME $VPOSTGRES_DB`
         output_id="$(echo $output_id | egrep -o "[0-9]{2,}" | head -n1)"

         #extract the stack trace from the postgres database (if available) and print it
         if [ -n "$output_id" ]
         then
            command_failure_output_file=/tmp/"$installation_type"_failure_output
            echo "Created file $command_failure_output_file with results from the execution of $installation_type installation command."
            alter_role=`echo "alter user vcac with superuser;" | su - postgres -c /opt/vmware/vpostgres/current/bin/psql.bin`
            echo "Altered user vcac to be superuser"

            collect_stack_trace=`echo "select lo_export(cluster_commands.output, '$command_failure_output_file') from cluster_commands where output= $output_id;" | /opt/vmware/vpostgres/current/bin/psql -h $VPOSTGRES_DB_HOSTNAME -U $VPOSTGRES_DB_USERNAME $VRA_DATABASE_NAME`

            cat "$command_failure_output_file"
            echo "== == == == == == == == == =="
         fi
         return $command_exec_result
         #break
      fi
   done
}

function executeCommand()
{
#at the beginning of each installation it is assumed that it will not complete successfully
   successfulComponentInstallation=0

   #the command_type transforms the component name to the actual value that can be inserted into the public.cluster_commands.type field
   #cut the last char for dems and change ms to manager-service
   if [ $1 == "ms" ]
   then
      command_type="install-manager-service"
   elif [ $1 == "demw" ] || [ $1 == "demo" ]
   then
      command_type="install-dem"
   else
      command_type="install-$1"
   fi

#   exec_command="install_$1_command"
   case $1 in
   certificate)
      echo "Executing Web certificate installation command:" >> "${VRA_INSTALL_LOG}" 2>&1
      echo "Executing Web certificate installation command:"
      install_web_certificate_command='vcac-config -v -e command-start --command install-certificate --do-not-override --node "${VRA_IAAS_NODE_ID}" --parameter CertificateBase64String="$web_public_key" --parameter PrivateKeyBase64String="$web_private_key" --parameter CertificatePassword="" --parameter CertificateFriendlyName="$web_cert_friendly_name" --parameter StoreNames="$web_cert_store_names" --parameter StoreLocation="$web_cert_store_location" --parameter PrivateKeyExportable="$WEB_CERT_EXPORT_PRIV_KEY"'
      if [ ${DEBUG} -eq 1 ]; then
        eval echo $install_web_certificate_command
      fi
      eval echo $install_web_certificate_command >> "${VRA_INSTALL_LOG}" 2>&1
      eval $install_web_certificate_command >> "${VRA_INSTALL_LOG}" 2>&1
      command_exit_code=$?

      echo "Executing Manager Service certificate installation command:" >> "${VRA_INSTALL_LOG}" 2>&1
      echo "Executing Manager Service certificate installation command:"
      install_ms_certificate_command='vcac-config -v -e command-start --command install-certificate --do-not-override --node "${VRA_IAAS_NODE_ID}" --parameter CertificateBase64String="$ms_public_key" --parameter PrivateKeyBase64String="$ms_private_key" --parameter CertificatePassword="" --parameter CertificateFriendlyName="$ms_cert_friendly_name" --parameter StoreNames="$ms_cert_store_names" --parameter StoreLocation="$ms_cert_store_location" --parameter PrivateKeyExportable="$WEB_CERT_EXPORT_PRIV_KEY"'
      if [ ${DEBUG} -eq 1 ]; then
        eval echo $install_ms_certificate_command
      fi
      eval echo $install_ms_certificate_command >> "${VRA_INSTALL_LOG}" 2>&1
      eval $install_ms_certificate_command >> "${VRA_INSTALL_LOG}" 2>&1
      command_exit_code=$?
      ;;
   db)
      echo "Executing DB installation command:" >> "${VRA_INSTALL_LOG}" 2>&1
      echo "Executing DB installation command:"
      install_db_command='vcac-config -v -e command-start --command install-db --node "${VRA_IAAS_NODE_ID}" --parameter DATABASE_INSTANCE="${VRA_DATABASE_HOSTNAME}" --parameter DATABASE_NAME="${VRA_DATABASE_NAME}" --parameter DEFAULT_DATA_LOG_PATH_FLAG=$DEFAULT_DATA_LOG_PATH_FLAG --parameter WINDOWS_AUTHEN_DATABASE_INSTALL_FLAG=$DB_WINDOWS_AUTH_FLAG  --parameter PRECREATED_DATABASE_FLAG=False --parameter DATABASE_USE_ENCRYPTION=$DB_USE_ENCRYPTION --parameter DATABASE_INSTALL_SQL_USER="${VRA_DATABASE_USERNAME}" --parameter DATABASE_INSTALL_SQL_USER_PASSWORD="${VRA_DATABASE_PASSWORD}"'
      if [ ${DEBUG} -eq 1 ]; then
        eval echo $install_db_command
      fi
      eval echo $install_db_command >> "${VRA_INSTALL_LOG}" 2>&1
      eval $install_db_command >> "${VRA_INSTALL_LOG}" 2>&1
      command_exit_code=$?
      ;;
   web)
      echo "Executing Web installation command:" >> "${VRA_INSTALL_LOG}" 2>&1
      echo "Executing Web installation command:"
      install_web_command='vcac-config -v -e command-start --command install-web --do-not-override --node "${VRA_IAAS_NODE_ID}" --parameter DATABASE_INSTANCE="${VRA_DATABASE_HOSTNAME}" --parameter DATABASE_NAME="${VRA_DATABASE_NAME}" --parameter DEFAULT_DATA_LOG_PATH_FLAG=$DEFAULT_DATA_LOG_PATH_FLAG --parameter WINDOWS_AUTHEN_DATABASE_INSTALL_FLAG=$DB_WINDOWS_AUTH_FLAG --parameter DATABASE_INSTALL_SQL_USER="${VRA_DATABASE_USERNAME}" --parameter DATABASE_INSTALL_SQL_USER_PASSWORD="${VRA_DATABASE_PASSWORD}" --parameter PRECREATED_DATABASE_FLAG=True --parameter VAThumbprint="${VRA_APPLIANCE_THUMBPRINT}" --parameter DATABASE_USE_ENCRYPTION=$DB_USE_ENCRYPTION --parameter WEBSITE_NAME="Default Web Site" --parameter HTTPS_PORT=${HTTPS_PORT} --parameter SUPPRESS_CERTIFICATE_MISMATCH_FLAG=False --parameter IAAS_SERVER_LOCALIP="${VRA_IAAS_HOSTNAME}" --parameter SECURITY_PASSPHRASE="${VRA_DATABASE_SECURITY_PASSPHRASE}" --parameter TENANT="${HORIZON_SSO_TENANT}" --parameter SSO_ADMIN_USERNAME="${HORIZON_SSO_USERNAME}" --parameter SSO_ADMIN_PASSWORD="${HORIZON_SSO_PASSWORD}" --parameter USERNAME="${VRA_IAAS_USERNAME}" --parameter PASSWORD="${VRA_IAAS_PASSWORD}" --parameter WebCertificate="${VRA_IAAS_WEB_THUMBPRINT}" --parameter COMPONENT_REGISTRY_SERVER="${VRA_APPLIANCE_HOSTNAME}"'
      if [ ${DEBUG} -eq 1 ]; then
        eval echo $install_web_command
      fi
      eval echo $install_web_command >> "${VRA_INSTALL_LOG}" 2>&1
      eval $install_web_command >> "${VRA_INSTALL_LOG}" 2>&1
      command_exit_code=$?
      ;;
   ms)
      echo "Executing Manager Service installation command:" >> "${VRA_INSTALL_LOG}" 2>&1
      echo "Executing Manager Service installation command:"
      install_ms_command='vcac-config -v -e command-start --command install-manager-service --do-not-override --node "${VRA_IAAS_NODE_ID}" --parameter DATABASE_INSTANCE="${VRA_DATABASE_HOSTNAME}" --parameter DATABASE_NAME="${VRA_DATABASE_NAME}" --parameter DEFAULT_DATA_LOG_PATH_FLAG=$DEFAULT_DATA_LOG_PATH_FLAG --parameter WINDOWS_AUTHEN_DATABASE_INSTALL_FLAG=$DB_WINDOWS_AUTH_FLAG --parameter DATABASE_INSTALL_SQL_USER="${VRA_DATABASE_USERNAME}" --parameter DATABASE_INSTALL_SQL_USER_PASSWORD="${VRA_DATABASE_PASSWORD}" --parameter PRECREATED_DATABASE_FLAG=True --parameter DATABASE_USE_ENCRYPTION=$DB_USE_ENCRYPTION --parameter WEBSITE_NAME="Default Web Site" --parameter HTTPS_PORT=${HTTPS_PORT}  --parameter IAAS_SERVER_LOCALIP="${VRA_IAAS_HOSTNAME}" --parameter SECURITY_PASSPHRASE="${VRA_DATABASE_SECURITY_PASSPHRASE}" --parameter USERNAME="${VRA_IAAS_USERNAME}" --parameter PASSWORD="${VRA_IAAS_PASSWORD}" --parameter MANAGER_SERVICE_SERVICESTART_FLAG=$MS_ACTIVE_FLAG --parameter ManagerServiceCertificate="${VRA_IAAS_MS_THUMBPRINT}" --parameter COMPONENT_REGISTRY_SERVER="${VRA_APPLIANCE_HOSTNAME}"'
      if [ ${DEBUG} -eq 1 ]; then
        eval echo $install_ms_command
      fi
      eval echo $install_ms_command >> "${VRA_INSTALL_LOG}" 2>&1
      eval $install_ms_command >> "${VRA_INSTALL_LOG}" 2>&1
      command_exit_code=$?
      ;;
   demo)
      echo "Executing DEM Orchestrator installation command:" >> "${VRA_INSTALL_LOG}" 2>&1
      echo "Executing DEM Orchestrator installation command:"
      install_demo_command='vcac-config -v -e command-start --command install-dem --do-not-override --node "${VRA_IAAS_NODE_ID}" --parameter SERVICE_USER_NAME="${VRA_IAAS_USERNAME}" --parameter SERVICE_USER_PASSWORD="${VRA_IAAS_PASSWORD}" --parameter DEM_NAME="${DEM_ORCH_NAME}" --parameter DEM_DESCRIPTION="${DEM_ORCH_DESCRIPTION}" --parameter DEM_ROLE=Orchestrator --parameter MANAGERSERVICE_HOSTNAME="${VRA_IAAS_HOSTNAME}" --parameter REPOSITORY_HOSTNAME="${VRA_IAAS_HOSTNAME}" --parameter REPOSITORY_USER="${VRA_IAAS_USERNAME}" --parameter REPOSITORY_USER_PASSWORD="${VRA_IAAS_PASSWORD}" --parameter COMPONENT_REGISTRY_SERVER="${VRA_APPLIANCE_HOSTNAME}" --parameter VAThumbprint="${VRA_APPLIANCE_THUMBPRINT}"'
      if [ ${DEBUG} -eq 1 ]; then
        eval echo $install_demo_command
      fi
      eval echo $install_demo_command >> "${VRA_INSTALL_LOG}" 2>&1
      eval $install_demo_command >> "${VRA_INSTALL_LOG}" 2>&1
      command_exit_code=$?
      ;;
   demw)
      echo "Executing DEM Worker installation command:" >> "${VRA_INSTALL_LOG}" 2>&1
      echo "Executing DEM Worker installation command:"
      install_demw_command='vcac-config -v -e command-start --command install-dem --do-not-override --node "${VRA_IAAS_NODE_ID}" --parameter SERVICE_USER_NAME="${VRA_IAAS_USERNAME}" --parameter SERVICE_USER_PASSWORD="${VRA_IAAS_PASSWORD}" --parameter DEM_NAME="${DEM_WORKER_NAME}" --parameter DEM_DESCRIPTION="${DEM_WORKER_DESCRIPTION}" --parameter DEM_ROLE=Worker --parameter MANAGERSERVICE_HOSTNAME="${VRA_IAAS_HOSTNAME}" --parameter REPOSITORY_HOSTNAME="${VRA_IAAS_HOSTNAME}" --parameter REPOSITORY_USER="${VRA_IAAS_USERNAME}" --parameter REPOSITORY_USER_PASSWORD="${VRA_IAAS_PASSWORD}" --parameter COMPONENT_REGISTRY_SERVER="${VRA_APPLIANCE_HOSTNAME}" --parameter VAThumbprint="${VRA_APPLIANCE_THUMBPRINT}"'
      if [ ${DEBUG} -eq 1 ]; then
        eval echo $install_demw_command
      fi
      eval echo $install_demw_command >> "${VRA_INSTALL_LOG}" 2>&1
      eval $install_demw_command >> "${VRA_INSTALL_LOG}" 2>&1
      command_exit_code=$?
      ;;
   agent)
      echo "Executing vCenter Server agent installation command:" >> "${VRA_INSTALL_LOG}" 2>&1
      echo "Executing vCenter Server agent installation command:"
      install_agent_command='vcac-config -v -e command-start --command install-agent --do-not-override --node "${VRA_IAAS_NODE_ID}" --parameter AGENT_NAME="${AGENT_NAME}" --parameter AgentType="${AGENT_TYPE}" --parameter VSPHERE_AGENT_ENDPOINT="${AGENT_ENDPOINT}" --parameter MANAGERSERVICE_HOSTNAME="${VRA_IAAS_HOSTNAME}" --parameter REPOSITORY_HOSTNAME="${VRA_IAAS_HOSTNAME}" --parameter SERVICE_USER_NAME="${VRA_IAAS_USERNAME}" --parameter SERVICE_USER_PASSWORD="${VRA_IAAS_PASSWORD}"'
      if [ ${DEBUG} -eq 1 ]; then
        eval echo $install_agent_command
      fi
      eval echo $install_agent_command >> "${VRA_INSTALL_LOG}" 2>&1
      eval $install_agent_command >> "${VRA_INSTALL_LOG}" 2>&1
      command_exit_code=$?
      ;;
   *)
      echo "Not a valid component name - IaaS component will not be installed!"
      command_exit_code=1
      ;;
   esac

   #installation command was not executed properly and installation should not proceed
   if [ $command_exit_code != 0 ]
   then
      echo "== == == == == Command install-$1 was not queued for execution == == == == =="
      return $command_exit_code
   #command is queued for execution
   else
      echo "== == == == == Command install-$1 is queued for execution == == == == =="

      output=`echo "select cmd_id from cluster_commands where node_id='${VRA_IAAS_NODE_ID}' and type='$command_type' and parent_id is not null order by update_on desc fetch first 1 rows only;" | /opt/vmware/vpostgres/current/bin/psql -h $VPOSTGRES_DB_HOSTNAME -U $VPOSTGRES_DB_USERNAME $VPOSTGRES_DB`
      cmd_id=$(echo $output | egrep -o "[a-z,A-Z,0-9]{8}-[a-z,A-Z,0-9]{4}-[a-z,A-Z,0-9]{4}-[a-z,A-Z,0-9]{4}-[a-z,A-Z,0-9]{12}" | head -n1)

      getCommandOutput $cmd_id
   fi

   return $command_exec_result
}

echo "Installation logs will be stored at ${VRA_INSTALL_LOG}"

# Extract VRA Database password (required to query command execution status)
VRA_DB_PASS_STRING=$(grep "password=" /etc/vcac/server.xml | egrep -o "password=\"(\S)*" | head -n1)
VRA_DB_PASS=${VRA_DB_PASS_STRING:10:50}
PGPASSWORD=$(vcac-config prop-util -d --p $VRA_DB_PASS)
if [ -z "${PGPASSWORD}" ]; then
  echo "Unable to extract vRA vPostgres Database credentials, vRA Appliance may not have been properly configured"
  exit 1
fi
export PGPASSWORD=$(vcac-config prop-util -d --p $VRA_DB_PASS)

# Extract the vRA IaaS Windows Node ID
# Check Node 0 first to see if it matches vRA Appliance
VRA_IAAS_NODE_ID=$(vcac-config cluster-config -list | sed -e '1d' -e '$d' | python -m json.tool | python -c 'import json,sys;obj=json.load(sys.stdin);print obj[0]["nodeId"]')
echo ${VRA_IAAS_NODE_ID} | grep cafe > /dev/null 2>&1
if [ $? -eq 0 ]; then
    # if so, then Node 1 is vRA IaaS System (crappy way, but kept getting error for running for loop w/python)
    VRA_IAAS_NODE_ID=$(vcac-config cluster-config -list | sed -e '1d' -e '$d' | python -m json.tool | python -c 'import json,sys;obj=json.load(sys.stdin);print obj[1]["nodeId"]')
fi

if [ -z "${VRA_IAAS_NODE_ID}" ]; then
  echo "Unable to extract vRA IaaS Windows Node ID, vRA Mgmt Agent may not have been installed and registered with vRA Appliance"
  exit 1
fi

# Generating Web & MS Certificate
generate_ssl_cert "web" "${VRA_DATABASE_HOSTNAME}" "${WEB_SSL_CERT_COUNTRY}" "${WEB_SSL_CERT_STATE}" "${WEB_SSL_CERT_CITY}" "${WEB_SSL_CERT_ORG_NAME}" "${WEB_SSL_CERT_ORG_UNIT}" "${WEB_SSL_CERT_COMMON_NAME}"
generate_ssl_cert "ms" "${VRA_DATABASE_HOSTNAME}" "${MS_SSL_CERT_COUNTRY}" "${MS_SSL_CERT_STATE}" "${MS_SSL_CERT_CITY}" "${MS_SSL_CERT_ORG_NAME}" "${MS_SSL_CERT_ORG_UNIT}" "${MS_SSL_CERT_COMMON_NAME}"

# Extract Web & MS Certificate Thumbprints
getWebCert
getMSCert

# Install Web & MS Certificate to vRA IaaS Windows System
executeCommand "certificate"

# Install vRA IaaS DB Component
executeCommand "db"

# Install vRA IaaS Web Component
executeCommand "web"

# Install vRA IaaS Web Component
executeCommand "ms"

# Install vRA IaaS DEM Orchestrator Component
executeCommand "demo"

# Install vRA IaaS DEM Worker Component
executeCommand "demw"

# Install vRA IaaS vSphere Agent Component
executeCommand "agent"
