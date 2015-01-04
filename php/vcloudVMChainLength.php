<?php
/**
 * William Lam
 * http://www.virtuallyghetto.com/
 * Modified query.php sample code
 * Product: VMware vCloud Director 1.5/5.x
 * Reference: http://www.virtuallyghetto.com/2012/04/scripts-to-extract-vcloud-director.html
 */
require_once dirname(__FILE__) . '/config.php';
require_once 'Console/Table.php';
error_reporting( E_ALL & ~( E_NOTICE | E_STRICT | E_DEPRECATED ) );

/**
 * Demonstrate using VMware vCloud Director query service for listing supported
 * query types, retrieving specified records or references.
 */
// Get parameters from command line
$shorts  = "";
$shorts .= "s:";
$shorts .= "u:";
$shorts .= "p:";


$longs  = array(
    "server:",    //-s|--server [required] vCloud Director server IP/hostname
    "user:",      //-u|--user   [required] vCloud Director login username
    "pswd:",      //-p|--pswd   [required] vCloud Director login password
);

$opts = getopt($shorts, $longs);

// Initialize parameters
$httpConfig = array('ssl_verify_peer'=>false, 'ssl_verify_host'=>false);

// loop through command arguments
foreach (array_keys($opts) as $opt) switch ($opt)
{
    case "s":
        $server = $opts['s'];
        break;
    case "server":
        $server = $opts['server'];
        break;

    case "u":
        $user = $opts['u'];
        break;
    case "user":
        $user = $opts['user'];
        break;

    case "p":
        $pswd = $opts['p'];
        break;
    case "pswd":
        $pswd = $opts['pswd'];
        break;
}

// parameters validation
if (!isset($server) || !isset($user) || !isset($pswd))
{
    echo "Error: missing required parameters\n";
    usage();
    exit(1);
}

// login
$service = VMware_VCloud_SDK_Service::getService();
$service->login($server, array('username'=>$user, 'password'=>$pswd), $httpConfig);

// create an SDK Query object
$sdkQuery = VMware_VCloud_SDK_Query::getInstance($service);

$qm = "queryRecords";
$type = "adminVM";
$params = new VMware_VCloud_SDK_Query_Params();
$params->setSortAsc('name');
$params->setPageSize(128);

$recsObj = $sdkQuery->$qm($type, $params);

// table to store output
$tbl = new Console_Table();
$tbl->setHeaders(array('VirtualMachine','vApp','vAppTemplate','vCenter Server','VM MoRef','ChainLength'));

// array to store URL pages
$pageUrls =array();
// retrieve all pages
getPages($recsObj->get_href());

foreach($pageUrls as $url) {
	// GET operation on URL
        $record = $service->get($url);
	// query all adminVM using query service
	foreach($record->getRecord() as $vm) {
		if($vm->get_status() == "UNRESOLVED") {
			continue;
		}

		// create VM SDK object based on VM href
		$adminVMSDKObj = $service->createSDKObj($vm->get_href());
		// retreive VM type
		$vmType = $adminVMSDKObj->getVm();
		// retrieve VM vCloud extensions 
		$vcloudExts = $vmType->getVCloudExtension();
		foreach($vcloudExts as $vcloudExt) {
			if($vcloudExt->getAny() != 0) {	
				$exts = $vcloudExt->getAny();
				foreach($exts as $ext) {
					// create row with VM, vApp and chain length
					$vmName = $vm->get_name();
					$vAppName = $vm->get_containerName();
					$vAppTemplate = ($vm->get_isVAppTemplate() ? "yes" : "no");
					$chainLength = $ext->getVirtualDisksMaxChainLength();
					$vmMoRef = $ext->getVmVimObjectRef()->getMoRef();
					$vCenter = $ext->getVmVimObjectRef()->getVimServerRef()->get_name();
					$tbl->addRow(array($vmName,$vAppName,$vAppTemplate,$vCenter,$vmMoRef,$chainLength));
				}
			}
		}
	}
}

// output table
echo $tbl->getTable();

// logout
$service->logout();

// method to iterate through all pages of query
function getPages($result) {
	$pageUrl = $GLOBALS['service']->get($result);
	array_push($GLOBALS['pageUrls'],$pageUrl->get_href());
	if($pageUrl->getLink()) {
		$links = $pageUrl->getLink();
		foreach($links as $link) {
			if($link->get_rel() == "nextPage") {
				getPages($link->get_href());
			}
		}
	}
}

/**
 * Print the help message of the sample.
 */
function usage()
{
    echo "Usage:\n\n";
    echo "  [Description]\n";
    echo "     This sample demonstrates VMware vCloud Director query service for\n";
    echo "     listing virtual machines and their current chain length.\n";
    echo "\n";
    echo "  [Usage]\n";
    echo "     # php query.php -s <server> -u <username> -p <password>\n";
    echo "\n";
    echo "     -s|--server <IP|hostname> [req] IP or hostname of the vCloud Director.\n";
    echo "     -u|--user <username>      [req] User name in the form user@organization\n";
    echo "                                      for the vCloud Director.\n";
    echo "     -p|--pswd <password>      [req] Password for user.\n";
    echo "\n";
}
?>
