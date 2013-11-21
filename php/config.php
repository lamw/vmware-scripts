<?php
/**
 * VMware vCloud SDK for PHP
 *
 * PHP version 5
 *
 * Copyright VMware, Inc. 2009-2011.  All Rights Reserved.
 *
 * @category   VMware
 * @package    VMware_VCloud_SDK
 * @subpackage Samples
 * @author     Kimberly Wang (kwang@vmware.com)
 * @copyright  Copyright VMware, Inc. 2009-2011.  All Rights Reserved.
 * @version    1.5.0
 */

// add library to the include_path
set_include_path(implode(PATH_SEPARATOR, array('.','../library',
                         get_include_path(),)));

require_once 'VMware/VCloud/Helper.php';

/**
 * HTTP connection parameters
 */

// IP or hostname of the vCloud Director.
// Format is 'IP/hostname[:port]'
// For example, the following settings are allowed:
// $server = '127.0.0.1';         (using default port 443)
// $server = '127.0.0.1:8443';    (using port 8443)
$server = null;

// User name for login request, in the form user@organization
// System administrator must log in as a member of the System organization
$user = null;

// Password for user
$pswd = null;

// proxy host, optional
$phost = null;

// proxy port, optional
$pport = null;

// proxy username, optional
$puser = null;

// proxy password, optional
$ppswd = null;

// CA certificate file name with full directory path. To turn on certification
// verification, set ssl_verify_peer to true in the $httpConfig parameter.
$cert = null;

/**
 * Create $httpConfig as HTTP connection parameters used by HTTP_Request2
 * library. Please refer to HTTP_Request2 documentation $config variable
 * for details.
 */
$httpConfig = array('proxy_host'=>$phost,
                    'proxy_port'=>$pport,
                    'proxy_user'=>$puser,
                    'proxy_password'=>$ppswd,
                    'ssl_verify_peer'=>false,
                    'ssl_verify_host'=>false,
                    'ssl_cafile' => $cert
                   );

/** vCloud Director Report Script Config Variables **/

$MAXTASKQUERY = 25; //max 128
$MAXEVENTQUERY = 25; //max 128
$SUMMARY = "yes";

// system, orgadmin, useradmin
$ROLE = "yes";
$EVENT = "yes";

// system 
$ADMIN_VAPP = "yes";
$ADMIN_VAPP_TEMPLATE = "yes";
$ADMIN_VAPP_NETWORK = "yes";
$ADMIN_VM = "yes";
$ADMIN_VM_NETWORK = "yes";
$ADMIN_CATALOG = "yes";
$ADMIN_CATALOG_ITEM = "yes";
$ADMIN_MEDIA = "yes";
$CLOUD_CELL = "yes";
$PROVIDER_VDC = "yes";
$ADMIN_ORG_VDC = "yes";
$EXT_NETWORK = "yes";
$ADMIN_ORG_NETWORK = "yes";
$NETWORK_POOL = "yes";
$VCENTER = "yes";
$RESOURCE_POOL = "yes";
$HOST = "yes";
$DATASTORE = "yes";
$DVS = "yes";
$PORTGROUP = "yes";
$ADMIN_TASK = "yes";
$BLOCKING_TASK = "yes";
$ADMIN_USER = "yes";
$ADMIN_GROUP = "yes";
$STRANDED_USER = "yes";

// system + orgadmin
$ORG_SUMMARY = "yes";

// orgadmin, useradmin
$VAPP = "yes";
$VAPP_TEMPLATE = "yes";
$VAPP_NETWORK = "yes";
$VM = "yes";
$VM_NETWORK = "yes";
$CATALOG = "yes";
$CATALOG_ITEM = "yes";
$MEDIA = "yes";
$ORG_VDC = "yes";
$ORG_NETWORK = "yes";
$TASK = "yes";
$USER = "yes";
$GROUP = "yes";
?>
