#!/bin/bash
# Author: William Lam
# Description: Manually publish users into vCenter Server vIDB instance for Ext IdP w/o SCIM support

usage() {
    cat <<EOM
    Usage: ./$(basename $0) <vCenter Admin username> <vCenter Admin password> <user list>

    Example: ./$(basename $0) 'administrator@vsphere.local' 'VMware1!' external_users.txt

EOM
    exit 0
}

[ -z $1 ] && { usage; }

ADMIN_USER=$1
ADMIN_PW=$2
USERS=$3

YELLOW="\e[33m"
CYAN="\e[36m"
ENDCOLOR="\e[0m"

SESSION_ID=$(curl --silent --location -u "$ADMIN_USER:$ADMIN_PW" --request POST 'http://localhost/rest/com/vmware/cis/session' | jq -r '.value')

echo "Retrieving IDPs from Broker ..."

BROKER_IDP_OUTPUT=$(curl --silent --location --request GET 'http://localhost/api/vcenter/identity/authbrokeridp' \
    --header "vmware-api-session-id: $SESSION_ID" \
    --header 'Content-Type: application/json')

IDP_ID=$(echo $BROKER_IDP_OUTPUT | jq '.summary_list[] | select(.tenant_type=="CUSTOMER") | .idp' | tr -d '"')

echo
echo -e "${YELLOW}External IDP ID: ${CYAN}$IDP_ID${ENDCOLOR}"

echo
echo "Generating sync client token ..."

SYNC_TOKEN_OUTPUT=$(curl --silent --location --request POST "http://localhost/api/vcenter/identity/broker/tenants/customer/providers/$IDP_ID/sync-client?action=generate-result" --header "vmware-api-session-id: $SESSION_ID")
SYNC_TOKEN=$(echo $SYNC_TOKEN_OUTPUT | jq -r '.token_info.access_token')
SCIM_URL=$(echo $SYNC_TOKEN_OUTPUT | jq -r '.scim_url')

IFS=$'\n'
for i in $(cat ${USERS} | grep -v '#');
do
	USERNAME=$(echo $i | awk -F ',' '{print $1}' | sed 's/^[ \t]*//;s/[ \t]*$//')
	FIRST_NAME=$(echo $i | awk -F ',' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//')
	LAST_NAME=$(echo $i | awk -F ',' '{print $3}' | sed 's/^[ \t]*//;s/[ \t]*$//')
	EMAIL=$(echo $i | awk -F ',' '{print $4}' | sed 's/^[ \t]*//;s/[ \t]*$//')
	DOMAIN=$(echo $EMAIL | cut -d @ -f 2 | sed 's/^[ \t]*//;s/[ \t]*$//')
	EXTERNAL_ID=$(echo $i | awk -F ',' '{print $5}' | sed 's/^[ \t]*//;s/[ \t]*$//')

echo
echo -e -n "${YELLOW}Populating user ${CYAN}$EMAIL${YELLOW} in the Broker usergroup directory via $SCIM_URL ...${ENDCOLOR}"

SCIM_OUTPUT=$(curl --silent --location --insecure --request POST "$SCIM_URL/Users" \
    --header 'Content-Type: application/scim+json' \
    --header "Authorization: HZN $SYNC_TOKEN" \
    --data-raw '{
    "schemas": [
        "urn:ietf:params:scim:schemas:extension:ws1b:2.0:User",
        "urn:ietf:params:scim:schemas:core:2.0:User"
    ],
    "externalId": "'"$EXTERNAL_ID"'",
    "userName": "'"$USERNAME"'",
    "name": {
        "familyName": "'"$LAST_NAME"'",
        "givenName": "'"$FIRST_NAME"'"
    },
    "displayName": "'"$USERNAME"'",
    "active": true,
    "emails": [
        {
            "value": "'"$EMAIL"'",
            "type": "work",
            "primary": true
        }
    ],
    "urn:ietf:params:scim:schemas:extension:ws1b:2.0:User": {
        "domain": "'"$DOMAIN"'"
    }
}')

done
unset IFS


echo
echo
echo "Done"
