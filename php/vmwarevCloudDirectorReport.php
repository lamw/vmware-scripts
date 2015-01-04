<?php
/*
# Copyright (c) 2009-2012 William Lam All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. The name of the author or contributors may not be used to endorse or
#    promote products derived from this software without specific prior
#    written permission.
# 4. Written Consent from original author prior to redistribution

# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

# William Lam
# http://www.virtuallyghetto.com/
# Product: VMware vCloud Director
# Reference  http://www.virtuallyghetto.com/2012/01/vcloud-director-report-100.html
*/
require_once dirname(__FILE__) . '/config.php';

$reportVersion = "1.0.0";
$reportTitle = "VMware vCloud Director Report v$reportVersion";

$green = "#00FF00";
$red = "#FF0000";
$orange = "#FF6600";
$yellow = "#FFFF33";
$white = "#FFFFFF";
$light_green = "#66FF99";
$light_red = "#FF6666";

/**
 * Log in to vCloud Director.
 */
// Get parameters from command line
$shorts  = "";
$shorts .= "s:";
$shorts .= "u:";
$shorts .= "p:";
$shorts .= "r:";
$shorts .= "t:";

$longs  = array(
    "server:",    //-s|--server [required] vCloud Director server IP/hostname
    "user:",      //-u|--user   [required] vCloud Director login username
    "pswd:",      //-p|--pswd   [required] vCloud Director login password
    "report:",    //-r|--report [optional] vCloud Director output name
    "type:",      //-t|--type   [optional] vCloud Director System or Org report type
);

$opts = getopt($shorts, $longs);

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

    case "r":
	$report = $opts['r'];
	break;
    case "report":
	$report = $opts["report"];
	break;

    case "t":
        $type = $opts['t'];
        break;
    case "type":
        $type = $opts["type"];
        break;
}

// required parameters validation
if(!isset($server) || !isset($user) || !isset($type))
{
    echo "Error: missing required parameters\n";
    usage();
    exit(1);
}

// prompt for password if not provided
if(!isset($pswd)) {
	$pswd = prompt_silent();
}

// specify default values if not provided
if(!isset($report)) {
	$report = "vCloudDirectorReport.html";
}

// Initialize parameters
$httpConfig = array('ssl_verify_peer'=>false, 'ssl_verify_host'=>false);

// login
$service = VMware_VCloud_SDK_Service::getService();
$service->login($server, array('username'=>$user, 'password'=>$pswd), $httpConfig);

// create SDK Query object
$sdkQuery = VMware_VCloud_SDK_Query::getInstance($service);

$serverName = str_replace("https://","",$server);
$jumpTagOutput = "";
$summaryHeaderOutput = "";
$vmNetworkOutput = "";
$orgHrefToNameMapping = array();

buildHtmlHeader($reportTitle,$serverName);

echo "\nGenerating " . $reportTitle . " " . $report . "\" ...\n";
echo "Report User Type: \"" . $type . "\"\n";
echo "\nThis can take up to a few minutes depending on the size of your environment.\n";
echo "Get a cup of coffee/tea/beer and check out http://www.virtuallyghetto.com\n\n";

if($type == "system") {
	getOrganizationSummary();
	getAdminVApp();
	getAdminVAppTemplate();
	getAdminVAppNetwork();
	getAdminVM();
	getVMNetwork();
	getAdminCatalog();
	getAdminCatalogItem();
	getAdminMedia();
	getCloudResourceCell();
	getCloudResourcePvdc();
	getAdminOrgVdc();
	getCloudResourceExtNet();
	getAdminOrgNet();
	getCloudResourceNetPool();
	getVSphereResourcevCenter();
	getVSphereResourceRP();
	getVSphereResourceHost();
	getVSphereResourceDatastore();
	getVSphereResourcedVds();
	getVSphereResourcedPortgroup();
	getTask();
	getEvent();
	getBlockingTask();
	getAdminUser();
	getRole();
	getAdminGroup();
	getStrandedUser();
	buildSummary();	
} elseif($type == "orgadmin") {
	getOrganizationSummary();
	getVApp();
    	getVAppTemplate();
    	getVAppNetwork();
    	getVM();
	getVMNetwork();
    	getCatalog();
    	getCatalogItem();
    	getMedia();
    	getOrgVdc();
    	getOrgNet();
    	getTask();
    	getEvent();
    	getUser();
	getRole();
	buildSummary();
} elseif($type == "orguser") {
	getVApp();
	getVAppTemplate();
	getVAppNetwork();
	getVM();
	getVMNetwork();
	getCatalog();
	getCatalogItem();
	getMedia();
	getOrgVdc();
	getOrgNet();
	getTask();
	getEvent();
	getUser();
	buildSummary();
} else {
	$service->logout();
	echo "Invalid report type!\n";
	exit(1);
}

// log out
$service->logout();

buildHtmlFooter();

function buildSummary() {
	if($GLOBALS['SUMMARY'] != "yes") { return; }
		
	// hack way to add summary to top of report
	$GLOBALS['summaryHeaderOutput'] .= "</table>\n</br>\n";
    	$file = file_get_contents($GLOBALS['report']);
    	if($file) {
		$file = str_replace('<!-- SUMMARY_HEADER -->',$GLOBALS['summaryHeaderOutput'], $file);
	        $f = fopen($GLOBALS['report'],"w");
        	fwrite($f,$file);
        	fclose($f);
    	} else {
		echo "Failed to build summary headers!\n";
    	}

	// hack way to add jump tags to top of report
	$GLOBALS['jumpTagOutput'] .= "</div>\n</br>\n";
	$file = file_get_contents($GLOBALS['report']);
    	if($file) {
        	$file = str_replace('<!-- JUMP_TAG -->',$GLOBALS['jumpTagOutput'], $file);
	        $f = fopen($GLOBALS['report'],"w");
        	fwrite($f,$file);
	        fclose($f);
	} else {
        	echo "Failed to build jump tag headers!\n";
    	}
}

function getOrganizationSummary() {
	if($GLOBALS['ORG_SUMMARY'] != "yes") { return; }

	// query all organizations
	$orgRecords = queryRecord("organization",null,null,"a","name",null);	

	$GLOBALS['jumpTagOutput'] .= "<a href=\"#orgSummary\">Organization Summary</a></br>\n";
	$orgSummaryOutput = "<a name=\"orgSummary\"></a>\n";
	$orgSummaryOutput .= "<b>Organization Summary</b>\n<table border=1>\n";
	$orgSummaryOutput .= "<tr><th>NAME</th><th>FULL NAME</th><th>ENABLED</th><th>CAN PUBLISH</th><th>vDCS<th>CATALOGS</th><th>GROUPS</th><th>vAPPS</th><th>RUNNING VMS</th></tr>\n";
	if(count($orgRecords) != 0) {
		foreach ($orgRecords as $org) {
			$GLOBALS['orgHrefToNameMapping'][$org->get_href()] = $org->get_name();
			$orgSummaryOutput .= "<tr>\n";
			$orgSummaryOutput .= "<td>" . $org->get_name() . "</td>";
			$orgSummaryOutput .= "<td>" . $org->get_displayName() . "</td>";
			$orgSummaryOutput .= ($org->get_isEnabled() ? "<td bgcolor=\"" . $GLOBALS['light_green'] . "\">true</td>" : "<td bgcolor=\"" . $GLOBALS['red'] . "\">false</td>");
			$orgSummaryOutput .= "<td>" . ($org->get_canPublishCatalogs() ? "true" : "false") . "</td>";
			$orgSummaryOutput .= "<td>" . $org->get_numberOfVdcs() . "</td>";
			$orgSummaryOutput .= "<td>" . $org->get_numberOfCatalogs() . "</td>";
			$orgSummaryOutput .= "<td>" . $org->get_numberOfGroups() . "</td>";
			$orgSummaryOutput .= "<td>" . $org->get_numberOfVApps() . "</td>";
			$orgAtt = $org->get_anyAttributes();
			if(isset($orgAtt["numberOfRunningVMs"])) {
				$numRunVMs = $orgAtt["numberOfRunningVMs"];
			} else { $numRunVMs = 0; }
			$orgSummaryOutput .= "<td>" . $numRunVMs . "</td>"; 
			$orgSummaryOutput .= "</tr>\n";
		}
	}
	$orgSummaryOutput .= "</table></br>\n";
	$f = fopen($GLOBALS['report'],"a");
	fwrite($f,$orgSummaryOutput);
	fclose($f);
}

function getAdminVApp() {
	if($GLOBALS['ADMIN_VAPP'] != "yes") { return; }

    	// query all admin vApp
    	$vAppRecords = queryRecord("adminVApp",null,null,"a","name",null);

	$count = $deployCount = $cpuCount = $memCount = $storageCount = 0;
	$maxVMCount = $maxVAppSize = array();
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#adminVApp\">Admin vApps</a></br>\n";
	$vAppOutput = "<a name=\"adminVApp\"></a>\n";
	$vAppOutput .= "<b>Admin vApps</b>\n<table border=1>\n";
    	$vAppOutput .= "<tr><th>NAME</th><th>STATUS</th><th>ENABLED</th><th>DEPLOYED</th><th>BUSY</th><th>MAINTENANCE MODE</th><th>OWNER</th><th>VMS</th><th>CPU</th><th>MEM</th><th>STORAGE</th><th>VDC</th><th>CREATION DATE</th></tr>\n";
    	if(count($vAppRecords) != 0) {
        	foreach ($vAppRecords as $vapp) {
			$cpuCount += $vapp->get_cpuAllocationMhz();
			$memCount += str_replace("-","",$vapp->get_memoryAllocationMB() * 1048576);
			$storageCount += str_replace("-","",$vapp->get_storageKB() * 1024);
			$maxVMCount[] = $vapp->get_numberOfVms();
			$maxVAppSize[] = str_replace("-","",$vapp->get_storageKB() * 1024);
			$count++;
	            	$vAppOutput .= "<tr>\n";
        		$vAppOutput .= "<td>" . $vapp->get_name() . "</td>";
            		$vAppOutput .= "<td>" . $vapp->get_status() . "</td>";
            		$vAppOutput .= ($vapp->get_isEnabled() ? "<td bgcolor=\"" . $GLOBALS['light_green'] . "\">true</td>" : "<td bgcolor=\"" . $GLOBALS['red'] . "\">false</td>");
			if($vapp->get_isDeployed()) {
				$deployCount++;
			}
            		$vAppOutput .= "<td>" . ($vapp->get_isDeployed() ? "true" : "false") . "</td>";
            		$vAppOutput .= "<td>" . ($vapp->get_isBusy() ? "true" : "false") . "</td>";
            		$vAppOutput .= "<td>" . ($vapp->get_isInMaintenanceMode() ? "true" : "false") . "</td>";
            		$vAppOutput .= "<td>" . $vapp->get_ownerName() . "</td>";
			$vAppOutput .= "<td>" . $vapp->get_numberOfVms() . "</td>";
			$vAppOutput .= "<td>" . $vapp->get_cpuAllocationMhz() . " Mhz</td>";
			$vAppOutput .= "<td>" . bytesToSize(str_replace("-","",$vapp->get_memoryAllocationMB()) * 1048576) . "</td>";
			$vAppOutput .= "<td>" . bytesToSize(str_replace("-","",$vapp->get_storageKB()) * 1024) . "</td>";
            		$vAppOutput .= "<td>" . $vapp->get_vdcName() . "</td>";
            		$vAppOutput .= "<td>" . $vapp->get_creationDate() . "</td>";
            		$vAppOutput .= "</tr>\n";
        	}
	}
    	$vAppOutput .= "</table></br>\n";
    	$f = fopen($GLOBALS['report'],"a");
    	fwrite($f,$vAppOutput);
    	fclose($f);

	$memCountTotal = bytesToSize($memCount);
	$storageCountTotal = bytesToSize($storageCount);
	$maxVAppSizeTotal = bytesToSize(max($maxVAppSize));

	$details = "<table border=1><tr><td><b>Deployed:</b></td><td>".$deployCount."</td><td><b>CPU Total:</b></td><td>".$cpuCount." Mhz</td><td><b>Memory Total:</b></td><td>".$memCountTotal."</td><td><b>Storage Total:</b></td><td>".$storageCountTotal."</td><td><b>Largest vApp:</b></td><td>".$maxVAppSizeTotal."</td><td><b>Largest VM Count:</b></td><td>".max($maxVMCount)."</td></tr></table>";

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Admin vApp Count:</b></td><td>" . $count . "</td><td>" . $details . "</td></tr>\n";
}

function getVApp() {
	if($GLOBALS['VAPP'] != "yes") { return; }

	// query all vApp
	$vAppRecords = queryRecord("vApp",null,null,"a","name",null);

	$count = $deployCount = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#vApp\">vApps</a></br>\n";
    	$vAppOutput = "<a name=\"vApp\"></a>\n";
    	$vAppOutput .= "<b>vApps</b>\n<table border=1>\n";        
	$vAppOutput .= "<tr><th>NAME</th><th>STATUS</th><th>ENABLED</th><th>DEPLOYED</th><th>BUSY<th>MAINTENANCE MODE</th><th>PUBLIC</th><th>OWNER</th><th>VDC</th><th>CREATION DATE</th></tr>\n";
    	if(count($vAppRecords) != 0) {
        	foreach ($vAppRecords as $vapp) {
			$count++;
            		$vAppOutput .= "<tr>\n";
            		$vAppOutput .= "<td>" . $vapp->get_name() . "</td>";
            		$vAppOutput .= "<td>" . $vapp->get_status() . "</td>";
			$vAppOutput .= ($vapp->get_isEnabled() ? "<td bgcolor=\"" . $GLOBALS['light_green'] . "\">true</td>" : "<td bgcolor=\"" . $GLOBALS['red'] . "\">false</td>");
			if($vapp->get_isDeployed()) {
				$deployCount++;
			}
            		$vAppOutput .= "<td>" . ($vapp->get_isDeployed() ? "true" : "false") . "</td>";
			$vAppOutput .= "<td>" . ($vapp->get_isBusy() ? "true" : "false") . "</td>";
			$vAppOutput .= "<td>" . ($vapp->get_isInMaintenanceMode() ? "true" : "false") . "</td>";
			$vAppOutput .= "<td>" . ($vapp->get_isPublic() ? "true" : "false") . "</td>";
			$vAppOutput .= "<td>" . $vapp->get_ownerName() . "</td>";
			$vAppOutput .= "<td>" . $vapp->get_vdcName() . "</td>";
			$vAppOutput .= "<td>" . $vapp->get_creationDate() . "</td>";
            		$vAppOutput .= "</tr>\n";
        	}
	}
    	$vAppOutput .= "</table></br>\n";
    	$f = fopen($GLOBALS['report'],"a");
    	fwrite($f,$vAppOutput);
    	fclose($f);

	$details = "<table border=1><tr><td><b>Deployed:</b></td><td>".$deployCount."</td></tr></table>";

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>vApp Count:</b></td><td>" . $count . "</td><td>" . $details . "</td></tr\n";
}

function getAdminVAppTemplate() {
	if($GLOBALS['ADMIN_VAPP_TEMPLATE'] != "yes") { return; }

	// query all admin vApp template
	$vAppTemplateRecords = queryRecord("adminVAppTemplate",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#adminVAppTemplate\">Admin vApp Templates</a></br>\n";
    	$vAppTemplateOutput = "<a name=\"adminVAppTemplate\"></a>\n";
	$vAppTemplateOutput .= "<b>Admin vApp Templates</b>\n<table border=1>\n";        
	$vAppTemplateOutput .= "<tr><th>NAME</th><th>STATUS</th><th>ENABLED</th><th>DEPLOYED</th><th>BUSY</th><th>EXPIRED</th><th>GOLDMASTER</th><th>PUBLISHED</th><th>VDC ENABLED</th><th>VDC</th><th>CATALOG</th><th>CATALOG ITEM</th><th>CREATION DATE</th></tr>\n";
    	if(count($vAppTemplateRecords) != 0) {
        	foreach ($vAppTemplateRecords as $vappTemplate) {
			$count++;
            		$vAppTemplateOutput .= "<tr>\n";
            		$vAppTemplateOutput .= "<td>" . $vappTemplate->get_name() . "</td>";
            		$vAppTemplateOutput .= "<td>" . $vappTemplate->get_status() . "</td>";
            		$vAppTemplateOutput .= ($vappTemplate->get_isEnabled() ? "<td bgcolor=\"" . $GLOBALS['light_green'] . "\">true</td>" : "<td bgcolor=\"" . $GLOBALS['red'] . "\">false</td>");
            		$vAppTemplateOutput .= "<td>" . ($vappTemplate->get_isDeployed() ? "true" : "false") . "</td>";
            		$vAppTemplateOutput .= "<td>" . ($vappTemplate->get_isBusy() ? "true" : "false") . "</td>";
			$vAppTemplateOutput .= "<td>" . ($vappTemplate->get_isExpired() ? "true" : "false") . "</td>";
			$vAppTemplateOutput .= ($vappTemplate->get_isGoldMaster() ? "<td bgcolor=\"" . $GLOBALS['yellow'] . "\">true</td>" : "<td>false</td>");
			$vAppTemplateOutput .= "<td>" . ($vappTemplate->get_isPublished() ? "true" : "false") . "</td>";
			$vAppTemplateOutput .= "<td>" . ($vappTemplate->get_isVdcEnabled() ? "true" : "false") . "</td>";
			$vAppTemplateOutput .= "<td>" . $vappTemplate->get_vdcName() . "</td>";
			$vAppTemplateOutput .= "<td>" . checkVar($vappTemplate->get_catalogName(),'str') . "</td>";
			$vAppTemplateOutput .= "<td>" . checkVar($vappTemplate->get_catalogItem(),'str') . "</td>";
			$vAppTemplateOutput .= "<td>" . $vappTemplate->get_creationDate() . "</td>";
            		$vAppTemplateOutput .= "</tr>\n";
        	 }
    	}
    	$vAppTemplateOutput .= "</table></br>\n";
    	$f = fopen($GLOBALS['report'],"a");
    	fwrite($f,$vAppTemplateOutput);
    	fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Admin vApp Template Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getVAppTemplate() {
	if($GLOBALS['VAPP_TEMPLATE'] != "yes") { return; }

	// query all vApp template
        $vAppTemplateRecords = queryRecord("vAppTemplate",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#vAppTemplate\">vApp Templates</a></br>\n";
        $vAppTemplateOutput = "<a name=\"vAppTemplate\"></a>\n";
        $vAppTemplateOutput .= "<b>vApp Templates</b>\n<table border=1>\n";
        $vAppTemplateOutput .= "<tr><th>NAME</th><th>STATUS</th><th>ENABLED</th><th>DEPLOYED</th><th>BUSY</th><th>GOLDMASTER</th><th>PUBLISHED</th><th>VDC</th><th>CATALOG</th><th>CREATION DATE</th></tr>\n";
        if(count($vAppTemplateRecords) != 0) {
                foreach ($vAppTemplateRecords as $vappTemplate) {
			$count++;
                        $vAppTemplateOutput .= "<tr>\n";
                        $vAppTemplateOutput .= "<td>" . $vappTemplate->get_name() . "</td>";
                        $vAppTemplateOutput .= "<td>" . $vappTemplate->get_status() . "</td>";
                        $vAppTemplateOutput .= ($vappTemplate->get_isEnabled() ? "<td bgcolor=\"" . $GLOBALS['light_green'] . "\">true</td>" : "<td bgcolor=\"" . $GLOBALS['red'] . "\">false</td>");
                        $vAppTemplateOutput .= "<td>" . ($vappTemplate->get_isDeployed() ? "true" : "false") . "</td>";
                        $vAppTemplateOutput .= "<td>" . ($vappTemplate->get_isBusy() ? "true" : "false") . "</td>";
                        $vAppTemplateOutput .= ($vappTemplate->get_isGoldMaster() ? "<td bgcolor=\"" . $GLOBALS['yellow'] . "\">true</td>" : "<td>false</td>");
                        $vAppTemplateOutput .= "<td>" . ($vappTemplate->get_isPublished() ? "true" : "false") . "</td>";
                        $vAppTemplateOutput .= "<td>" . $vappTemplate->get_vdcName() . "</td>";
                        $vAppTemplateOutput .= "<td>" . $vappTemplate->get_catalogName() . "</td>";
                        $vAppTemplateOutput .= "<td>" . $vappTemplate->get_creationDate() . "</td>";
                        $vAppTemplateOutput .= "</tr>\n";
                }
        }
        $vAppTemplateOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$vAppTemplateOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>vApp Template Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getAdminVAppNetwork() {
	if($GLOBALS['ADMIN_VAPP_NETWORK'] != "yes") { return; }

	//query all admin vApp network
	$vAppNetRecords = queryRecord("adminVAppNetwork",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#adminVAppNetwork\">Admin vApp Networks</a></br>\n";
        $vAppNetOutput = "<a name=\"adminVAppNetwork\"></a>\n";
	$vAppNetOutput .= "<b>Admin vApp Networks</b>\n<table border=1>\n";
	$vAppNetOutput .= "<tr><th>NAME</th><th>BUSY</th><th>DNS1</th><th>DNS2</th><th>DNS SUFFIX</th><th>GATEWAY</th><th>NETMASK</th><th>vAPP</th></tr>\n";
	if(count($vAppNetRecords) != 0) {
                foreach ($vAppNetRecords as $vappNet) {
			$count++;
                        $vAppNetOutput .= "<tr>\n";
                        $vAppNetOutput .= "<td>" . $vappNet->get_name() . "</td>";
                        $vAppNetOutput .= "<td>" . ($vappNet->get_isBusy() ? "true" : "false") . "</td>";
			$vAppNetOutput .= "<td>" . checkVar($vappNet->get_dns1(),'str') . "</td>";
			$vAppNetOutput .= "<td>" . checkVar($vappNet->get_dns2(),'str') . "</td>";
			$vAppNetOutput .= "<td>" . checkVar($vappNet->get_dnsSuffix(),'str') . "</td>";
			$vAppNetOutput .= "<td>" . checkVar($vappNet->get_gateway(),'str') . "</td>";
			$vAppNetOutput .= "<td>" . $vappNet->get_netmask() . "</td>";
			$vAppNetOutput .= "<td>" . $vappNet->get_vappName() . "</td>";
                        $vAppNetOutput .= "</tr>\n";
                }
        }
        $vAppNetOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$vAppNetOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Admin vApp Network Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getvAppNetwork() {
	if($GLOBALS['VAPP_NETWORK'] != "yes") { return; }

	//query all vApp network
        $vAppNetRecords = queryRecord("vAppNetwork",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#vAppNetwork\">vApp Networks</a></br>\n";
        $vAppNetOutput = "<a name=\"vAppNetwork\"></a>\n";
        $vAppNetOutput .= "<b>vApp Networks</b>\n<table border=1>\n";
        $vAppNetOutput .= "<tr><th>NAME</th><th>BUSY</th><th>DNS1</th><th>DNS2</th><th>DNS SUFFIX</th><th>GATEWAY</th><th>NETMASK</th><th>vAPP</th></tr>\n";
        if(count($vAppNetRecords) != 0) {
                foreach ($vAppNetRecords as $vappNet) {
			$count++;
                        $vAppNetOutput .= "<tr>\n";
                        $vAppNetOutput .= "<td>" . $vappNet->get_name() . "</td>";
                        $vAppNetOutput .= "<td>" . ($vappNet->get_isBusy() ? "true" : "false") . "</td>";
                        $vAppNetOutput .= "<td>" . checkVar($vappNet->get_dns1(),'str') . "</td>";
                        $vAppNetOutput .= "<td>" . checkVar($vappNet->get_dns2(),'str') . "</td>";
			$vAppNetOutput .= "<td>" . checkVar($vappNet->get_dnsSuffix(),'str') . "</td>";
                        $vAppNetOutput .= "<td>" . checkVar($vappNet->get_gateway(),'str') . "</td>";
                        $vAppNetOutput .= "<td>" . $vappNet->get_netmask() . "</td>";
                        $vAppNetOutput .= "<td>" . $vappNet->get_vappName() . "</td>";
                        $vAppNetOutput .= "</tr>\n";
                }
        }
        $vAppNetOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$vAppNetOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>vApp Network Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getAdminVM() {
	if($GLOBALS['ADMIN_VM'] != "yes") { return; }

	// query all admin vm
	$vmRecords = queryRecord("adminVM","isVAppTemplate==false",null,"a","name",null);

	$count = $cpuCount = $memCount = $storageCount = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#adminVM\">Admin VMs</a></br>\n";
        $vmOutput = "<a name=\"adminVM\"></a>\n";
	$vmOutput .= "<b>Admin VMs</b>\n<table border=1>\n";
        $vmOutput .= "<tr><th>NAME</th><th>MOREF</th><th>STATUS</th><th>HOSTNAME</th><th>DEPLOYED</th><th>PUBLISHED</th><th>OS</th><th>vHARDWARE</th><th>VMWARE TOOLS</th><th># OF vCPU</th><th>MEM</th><th>STORAGE</th><th># OF DISKS</th><th>vAPP</th><th>CATALOG</th><th>DATASTORE</th></tr>\n";
        if(count($vmRecords) != 0) {
                foreach ($vmRecords as $vm) {
			$adminVMSDKObj = $GLOBALS['service']->createSDKObj($vm->get_href());

			$cpuCount += $vm->get_numberOfCpus();	
			$count++;
                        $vmOutput .= "<tr>\n";
                        $vmOutput .= "<td>" . $vm->get_name() . "</td>";
			$vmOutput .= "<td>" . checkVar($vm->get_moref(),'str') . "</td>";
                        $vmOutput .= "<td>" . $vm->get_status() . "</td>";
			$vmOutput .= "<td>" . checkVar($vm->get_hostName(),'str') . "</td>";
			$vmOutput .= "<td>" . ($vm->get_isDeployed() ? "true" : "false") . "</td>";
			$vmOutput .= "<td>" . ($vm->get_isPublished() ? "true" : "false") . "</td>";
			$vmOutput .= "<td>" . checkVar($vm->get_guestOS(),'str') . "</td>";
			$vmOutput .= "<td>" . $vm->get_hardwareVersion() . "</td>";
			$vmOutput .= "<td>" . checkVar($vm->get_vmToolsVersion(),'str') . "</td>";
			$vmOutput .= "<td>" . $vm->get_numberOfCpus() . "</td>";
			$vmOutput .= "<td>" . bytesToSize(str_replace("-","",$vm->get_memoryMB()) * 1048576) ."</td>";
			$vmDisks = $adminVMSDKObj->getVirtualDisks()->getItem();
                        $vmDiskCount = $vmDiskSize = 0;
                        if(count($vmDisks) != 0) {
                                foreach ($vmDisks as $disk) {
                                        if($disk->getDescription()->get_valueOf() == "Hard disk") {
                                                $vmDiskCount += 1;
                                                $vmDiskRsc = $disk->getHostResource();
                                                $vmDiskAtt = $vmDiskRsc[0]->get_anyAttributes();
                                                if(isset($vmDiskAtt["capacity"])) {
                                                        $vmDiskSize = str_replace("-","",$vmDiskAtt["capacity"] * 1048576);
                                                        $storageCount += $vmDiskSize;
                                                }
                                        }
                                }
                        }
			if($GLOBALS['ADMIN_VM_NETWORK'] == "yes") {
                                $vmNetSetting = $adminVMSDKObj->getNetworkConnectionSettings();
                                $GLOBALS['vmNetworkOutput'] .= "<tr><td>" . $vm->get_name() . "</td>";
				$GLOBALS['vmNetworkOutput'] .= "<td>" . $vm->get_containerName() . "</td>";
                                $vmNetConnections = $vmNetSetting->getNetworkConnection();
                                $GLOBALS['vmNetworkOutput'] .= "<td><table border=1><tr><th>INTEFACE</th><th>NETWORK</th><th>CONNECTED</th><th>ALLOCATION MODE</th><th>IP ADDRESS</th><th>EXT IP ADDRESS</th></tr><tr>\n";
                                if(count($vmNetConnections) != 0) {
                                        foreach ($vmNetConnections as $vmnet) {
                                                $GLOBALS['vmNetworkOutput'] .= "<tr><td>eth" . $vmnet->getNetworkConnectionIndex() . "</td>";
                                                $GLOBALS['vmNetworkOutput'] .= "<td>" . $vmnet->get_network() . "</td>";
                                                $GLOBALS['vmNetworkOutput'] .= "<td>" . ($vmnet->getIsConnected() ? "true" : "false") . "</td>";
                                                $GLOBALS['vmNetworkOutput'] .= "<td>" . $vmnet->getIpAddressAllocationmode() . "</td>";
                                                $GLOBALS['vmNetworkOutput'] .= "<td>" . checkVar($vmnet->getIpAddress(),'str') . "</td>";
                                                $GLOBALS['vmNetworkOutput'] .= "<td>" . checkVar($vmnet->getExternalIpAddress(),'str') . "</td></tr>\n";
                                        }
                                } else {
                                        $GLOBALS['vmNetworkOutput'] .= "<td colspan=6></br></td>";
                                }
                                $GLOBALS['vmNetworkOutput'] .= "</tr></table></td></tr>\n";
                        }
                        $vmOutput .= "<td>" . bytesToSize($vmDiskSize) . "</td>";
                        $vmOutput .= "<td>" . $vmDiskCount . "</td>";
			$vmOutput .= "<td>" . $vm->get_containerName() . "</td>";
			$vmOutput .= "<td>" . checkVar($vm->get_catalogName(),'str') . "</td>";
			$vmOutput .= "<td>" . $vm->get_datastoreName() . "</td>";
                        $vmOutput .= "</tr>\n";
                }
        }
        $vmOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$vmOutput);
        fclose($f);
		
	$memCountTotal = bytesToSize($memCount);
	$storageCountTotal = bytesToSize($storageCount);

	$details = "<table border=1><tr><td><b>vCPU Total:</b></td><td>".$cpuCount."</td><td><b>Mem Total:</b></td><td>".$memCountTotal."</td><td><b>Storage Total:</b></td><td>".$storageCountTotal."</td></tr></table>";

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Admin VM Count:</b></td><td>" . $count . "</td><td>" . $details . "</td></tr>\n";
}

function getVM() {
	if($GLOBALS['VM'] != "yes") { return; }

	// query all vm
	$vmRecords = queryRecord("vm","isVAppTemplate==false",null,"a","containerName",null);

	$count = $onCount = $offCount = $suspendCount = $cpuCount = $memCount = $storageCount = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#vm\">VMs</a></br>\n";
        $vmOutput = "<a name=\"vm\"></a>\n";
	$vmOutput .= "<b>VMs</b>\n<table border=1>\n";
        $vmOutput .= "<tr><th>NAME</th><th>STATUS</th><th>DEPLOYED</th><th>PUBLISHED</th><th>OS</th><th>MAINTENANCE MODE</th><th>vHARDWARE</th><th># OF vCPU</th><th>MEM</th><th>STORAGE</th><th># OF DISKS</th><th>vAPP</th><th>CATALOG</th></tr>\n";
        if(count($vmRecords) != 0) {
                foreach ($vmRecords as $vm) {
			try {
				$vmSDKObj = $GLOBALS['service']->createSDKObj($vm->get_href());
			} catch (Exception $e) {
                                echo "Warning: Unable to retrieve VM SDKObj\n";
                        }
			$cpuCount += $vm->get_numberOfCpus();
			$memCount += str_replace("-","",$vm->get_memoryMB() * 1048576);
			$count++;
                        $vmOutput .= "<tr>\n";
                        $vmOutput .= "<td>" . $vm->get_name() . "</td>";
			switch ($vm->get_status()) {
				case "POWERED_ON":
				$onCount++;
				break;
				case "POWERED_OFF":
				$offCount++;
				break;
				case "SUSPENDED":
				$suspendCount++;
				break;
				default: 
				break;
			}
                        $vmOutput .= "<td>" . $vm->get_status() . "</td>";
                        $vmOutput .= "<td>" . ($vm->get_isDeployed() ? "true" : "false") . "</td>";
                        $vmOutput .= "<td>" . ($vm->get_isPublished() ? "true" : "false") . "</td>";
                        $vmOutput .= "<td>" . checkVar($vm->get_guestOS(),'str') . "</td>";
			$vmOutput .= "<td>" . ($vm->get_isInMaintenanceMode() ? "true" : "false") . "</td>";
                        $vmOutput .= "<td>" . $vm->get_hardwareVersion() . "</td>";
                        $vmOutput .= "<td>" . $vm->get_numberOfCpus() . "</td>";
                        $vmOutput .= "<td>" . bytesToSize(str_replace("-","",$vm->get_memoryMB()) * 1048576) ."</td>";
			$vmDisks = $vmSDKObj->getVirtualDisks()->getItem();
			$vmDiskCount = $vmDiskSize = 0;
			if(count($vmDisks) != 0) {
				foreach ($vmDisks as $disk) {
					if($disk->getDescription()->get_valueOf() == "Hard disk") {
						$vmDiskCount += 1;
						$vmDiskRsc = $disk->getHostResource();
						$vmDiskAtt = $vmDiskRsc[0]->get_anyAttributes();
			                        if(isset($vmDiskAtt["capacity"])) {
                        			        $vmDiskSize = str_replace("-","",$vmDiskAtt["capacity"] * 1048576);
							$storageCount += $vmDiskSize;
						}
					}
				}
			}
			if($GLOBALS['VM_NETWORK'] == "yes") {
				$vmNetSetting = $vmSDKObj->getNetworkConnectionSettings();
				$GLOBALS['vmNetworkOutput'] .= "<tr><td>" . $vm->get_name() . "</td>";
				$GLOBALS['vmNetworkOutput'] .= "<td>" . $vm->get_containerName() . "</td>";
				$vmNetConnections = $vmNetSetting->getNetworkConnection();
				$GLOBALS['vmNetworkOutput'] .= "<td><table border=1><tr><th>INTEFACE</th><th>NETWORK</th><th>CONNECTED</th><th>ALLOCATION MODE</th><th>IP ADDRESS</th><th>EXT IP ADDRESS</th></tr><tr>\n";
	                        if(count($vmNetConnections) != 0) {
					foreach ($vmNetConnections as $vmnet) {
						$GLOBALS['vmNetworkOutput'] .= "<tr><td>eth" . $vmnet->getNetworkConnectionIndex() . "</td>";
						$GLOBALS['vmNetworkOutput'] .= "<td>" . $vmnet->get_network() . "</td>";
						$GLOBALS['vmNetworkOutput'] .= "<td>" . ($vmnet->getIsConnected() ? "true" : "false") . "</td>";
						$GLOBALS['vmNetworkOutput'] .= "<td>" . $vmnet->getIpAddressAllocationmode() . "</td>";
						$GLOBALS['vmNetworkOutput'] .= "<td>" . checkVar($vmnet->getIpAddress(),'str') . "</td>";
						$GLOBALS['vmNetworkOutput'] .= "<td>" . checkVar($vmnet->getExternalIpAddress(),'str') . "</td></tr>\n";
					}
                        	} else {
					$GLOBALS['vmNetworkOutput'] .= "<td colspan=6></br></td>";
				}
				$GLOBALS['vmNetworkOutput'] .= "</tr></table></td></tr>\n";
			}
			$vmOutput .= "<td>" . bytesToSize($vmDiskSize) . "</td>";
			$vmOutput .= "<td>" . $vmDiskCount . "</td>";
                        $vmOutput .= "<td>" . $vm->get_containerName() . "</td>";
                        $vmOutput .= "<td>" . checkVar($vm->get_catalogName(),'str') . "</td>";
                        $vmOutput .= "</tr>\n";
                }
        }
        $vmOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$vmOutput);
        fclose($f);

	$memCountTotal = bytesToSize($memCount);
	$storageCountTotal = bytesToSize($storageCount);

	$details = "<table border=1><tr><td><b>PoweredOn:</b></td><td>".$onCount."</td><td><b>PoweredOff:</b></td><td>".$offCount."</td><td><b>Suspended:</b></td><td>".$suspendCount."</td><td><b>vCPU Total:</b></td><td>".$cpuCount."</td><td><b>Mem Total:</b></td><td>".$memCountTotal."</td><td><b>Storage Total:</b></td><td>".$storageCountTotal."</td></tr></table>";

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>VM Count:</b></td><td>" . $count . "</td><td>" . $details . "</td></tr>\n";
}

function getVMNetwork() {
	if($GLOBALS['ADMIN_VM_NETWORK'] != "yes" && $GLOBALS['VM_NETWORK'] != "yes") { return; }

	$GLOBALS['jumpTagOutput'] .= "<a href=\"#vmNetwork\">VM Networks</a></br>\n";
	$GLOBALS['vmNetworkOutput'] .= "</table></br>\n";
	$f = fopen($GLOBALS['report'],"a");
        fwrite($f,$GLOBALS['vmNetworkOutput']);
        fclose($f);
}

function getAdminCatalog() {
	if($GLOBALS['ADMIN_CATALOG'] != "yes") { return; }

	// query all admin catalog
	$catRecords = queryRecord("adminCatalog",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#adminCatalog\">Admin Catalogs</a></br>\n";
        $catOutput = "<a name=\"adminCatalog\"></a>\n";
	$catOutput .= "<b>Admin Catalogs</b>\n<table border=1>\n";
	$catOutput .= "<tr><th>NAME</th><th>SHARED</th><th>PUBLISHED</th><th>OWNER</th><th>ORG</th><th>vAPP TEMPLATES</th><th>MEDIA</th><th>CREATION DATE</th></tr>\n";
	if(count($catRecords) != 0) {
                foreach ($catRecords as $cat) {
			$count++;
                        $catOutput .= "<tr>\n";
                        $catOutput .= "<td>" . $cat->get_name() . "</td>";
                        $catOutput .= "<td>" . ($cat->get_isShared() ? "true" : "false") . "</td>";
			$catOutput .= "<td>" . ($cat->get_isPublished() ? "true" : "false") . "</td>";
			$catOutput .= "<td>" . $cat->get_ownerName() . "</td>";
			$catOutput .= "<td>" . $cat->get_orgName() . "</td>";
			$catOutput .= "<td>" . $cat->get_numberOfTemplates() . "</td>";
			$catOutput .= "<td>" . $cat->get_numberOfMedia() . "</td>";
			$catOutput .= "<td>" . $cat->get_creationDate() . "</td>";
                        $catOutput .= "</tr>\n";
                }
        }
        $catOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$catOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Admin Catalog Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getCatalog() {
	if($GLOBALS['CATALOG'] != "yes") { return; }

	// query all catalog
        $catRecords = queryRecord("catalog",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#catalog\">Catalogs</a></br>\n";
        $catOutput = "<a name=\"catalog\"></a>\n";
        $catOutput .= "<b>Catalogs</b>\n<table border=1>\n";
        $catOutput .= "<tr><th>NAME</th><th>SHARED</th><th>PUBLISHED</th><th>OWNER</th><th>ORG</th><th>vAPP TEMPLATES</th><th>MEDIA</th><th>CREATION DATE</th></tr>\n";
        if(count($catRecords) != 0) {
                foreach ($catRecords as $cat) {
			$count++;
                        $catOutput .= "<tr>\n";
                        $catOutput .= "<td>" . $cat->get_name() . "</td>";
                        $catOutput .= "<td>" . ($cat->get_isShared() ? "true" : "false") . "</td>";
                        $catOutput .= "<td>" . ($cat->get_isPublished() ? "true" : "false") . "</td>";
                        $catOutput .= "<td>" . $cat->get_ownerName() . "</td>";
                        $catOutput .= "<td>" . $cat->get_orgName() . "</td>";
                        $catOutput .= "<td>" . $cat->get_numberOfVAppTemplates() . "</td>";
                        $catOutput .= "<td>" . $cat->get_numberOfMedia() . "</td>";
                        $catOutput .= "<td>" . $cat->get_creationDate() . "</td>";
                        $catOutput .= "</tr>\n";
                }
        }
        $catOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$catOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Catalog Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getAdminCatalogItem() {
	if($GLOBALS['ADMIN_CATALOG_ITEM'] != "yes") { return; }

	// query all admin catalog items
	$catItemRecords = queryRecord("adminCatalogItem",null,null,"a","name",null);

	$count = $catSize = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#adminCatalogItem\">Admin Catalog Items</a></br>\n";
        $catItemOutput = "<a name=\"adminCatalogItem\"></a>\n";
	$catItemOutput .= "<b>Admin Catalog Items</b>\n<table border=1>\n";
        $catItemOutput .= "<tr><th>NAME</th><th>TYPE</th><th>DETAILS</th><th>CATALOG</th><th>STATUS</th><th>PUBLISHED</th><th>EXPIRED</th><th>OWNER</th><th>VDC ENABLED</th><th>VDC</th><th>CREATION DATE</th></tr>\n";
        if(count($catItemRecords) != 0) {
                foreach ($catItemRecords as $catItem) {
			$count++;
                        $catItemOutput .= "<tr>\n";
                        $catItemOutput .= "<td>" . $catItem->get_name() . "</td>";
			$catItemOutput .= "<td>" . $catItem->get_entityType() . "</td>";
			$catItemAtt = $catItem->get_anyAttributes();
                        if(isset($catItemAtt["storageKB"])) {
                                $entitySize = $catItemAtt["storageKB"];
				$entitySize = bytesToSize(str_replace("-","",$entitySize) * 1024);
				$catSize += str_replace("-","",$catItemAtt["storageKB"]) * 1024;
                        } else { $entitySize = "</br>"; }
                        $catItemOutput .= "<td>" . $entitySize . "</td>";
			$catItemOutput .= "<td>" . $catItem->get_catalogName() . "</td>";
			$catItemOutput .= "<td>" . $catItem->get_status() . "</td>";
                        $catItemOutput .= "<td>" . ($catItem->get_isPublished() ? "true" : "false") . "</td>";
			$catItemOutput .= "<td>" . ($catItem->get_isExpired() ? "true" : "false") . "</td>";
                        $catItemOutput .= "<td>" . $catItem->get_ownerName() . "</td>";
			$catItemOutput .= "<td>" . ($catItem->get_isVdcEnabled() ? "true" : "false") . "</td>";
                        $catItemOutput .= "<td>" . checkVar($catItem->get_vdcName(),'str') . "</td>";
                        $catItemOutput .= "<td>" . $catItem->get_creationDate() . "</td>";
                        $catItemOutput .= "</tr>\n";
                }
        }
        $catItemOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$catItemOutput);
        fclose($f);

	$catSizeTotal = bytesToSize($catSize);
	$details = "<table border=1><tr><td><b>Total Size:</b></td><td>".$catSizeTotal."</td></tr></table>";

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Admin Catalog Item Count:</b></td><td>" . $count . "</td><td>" . $details . "</td></tr>\n";
}

function getCatalogItem() {
	if($GLOBALS['CATALOG_ITEM'] != "yes") { return; }

	// query all catalog item
        $catItemRecords = queryRecord("catalogItem",null,null,"a","name",null);

	$count = $catSize = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#catalogItem\">Catalog Items</a></br>\n";
        $catItemOutput = "<a name=\"catalogItem\"></a>\n";
        $catItemOutput .= "<b>Catalog Items</b>\n<table border=1>\n";
        $catItemOutput .= "<tr><th>NAME</th><th>TYPE</th><th>DETAILS</th><th>CATALOG</th><th>STATUS</th><th>PUBLISHED</th><th>EXPIRED</th><th>OWNER</th><th>VDC ENABLED</th><th>VDC</th><th>CREATION DATE</th></tr>\n";
        if(count($catItemRecords) != 0) {
                foreach ($catItemRecords as $catItem) {
			$count++;
                        $catItemOutput .= "<tr>\n";
                        $catItemOutput .= "<td>" . $catItem->get_name() . "</td>";
                        $catItemOutput .= "<td>" . $catItem->get_entityType() . "</td>";
                        $catItemAtt = $catItem->get_anyAttributes();
                        if(isset($catItemAtt["storageKB"])) {
                                $entitySize = $catItemAtt["storageKB"];
                                $entitySize = bytesToSize(str_replace("-","",$entitySize) * 1024);
				$catSize += (str_replace("-","",$catItemAtt["storageKB"]) * 1024);
                        } else { $entitySize = "</br>"; }
                        $catItemOutput .= "<td>" . $entitySize . "</td>";
                        $catItemOutput .= "<td>" . $catItem->get_catalogName() . "</td>";
                        $catItemOutput .= "<td>" . $catItem->get_status() . "</td>";
                        $catItemOutput .= "<td>" . ($catItem->get_isPublished() ? "true" : "false") . "</td>";
                        $catItemOutput .= "<td>" . ($catItem->get_isExpired() ? "true" : "false") . "</td>";
                        $catItemOutput .= "<td>" . $catItem->get_ownerName() . "</td>";
                        $catItemOutput .= "<td>" . ($catItem->get_isVdcEnabled() ? "true" : "false") . "</td>";
                        $catItemOutput .= "<td>" . checkVar($catItem->get_vdcName(),'str') . "</td>";
                        $catItemOutput .= "<td>" . $catItem->get_creationDate() . "</td>";
                        $catItemOutput .= "</tr>\n";
                }
        }
        $catItemOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$catItemOutput);
        fclose($f);

	$catSizeTotal = bytesToSize($catSize);
        $details = "<table border=1><tr><td><b>Total Size:</b></td><td>".$catSizeTotal."</td></tr></table>";

        $GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Catalog Item Count:</b></td><td>" . $count . "</td><td>" . $details . "</td></tr>\n";
}

function getAdminMedia() {
	if($GLOBALS['ADMIN_MEDIA'] != "yes") { return; }

	// query all admin media
	$mediaRecords = queryRecord("adminMedia",null,null,"a","name",null);

	$count = $mediaSize = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#adminMedia\">Admin Media</a></br>\n";
        $mediaOutput = "<a name=\"adminMedia\"></a>\n";
	$mediaOutput .= "<b>Admin Media</b>\n<table border=1>\n";
        $mediaOutput .= "<tr><th>NAME</th><th>STATUS</th><th>SIZE</th><th>PUBLISHED</th><th>CATALOG</th><th>IN CATALOG</th><th>OWNER</th><th>VDC ENABLED</th><th>VDC</th><th>CREATION DATE</th></tr>\n";
        if(count($mediaRecords) != 0) {
                foreach ($mediaRecords as $media) {
			$count++;
			$mediaSize += str_replace("-","",$media->get_storageB());
                        $mediaOutput .= "<tr>\n";
                        $mediaOutput .= "<td>" . $media->get_name() . "</td>";
			$mediaOutput .= "<td>" . $media->get_status() . "</td>";
			$mediaOutput .= "<td>" . bytesToSize(str_replace("-","",$media->get_storageB())) . "</td>";
			$mediaOutput .= "<td>" . ($media->get_isPublished() ? "true" : "false") . "</td>";
			$mediaOutput .= "<td>" . checkVar($media->get_catalogName(),'str') . "</td>";
			$mediaAtt = $media->get_anyAttributes();
                        if(isset($mediaAtt["isInCatalog"])) {
                                $inCatalog = $mediaAtt["isInCatalog"];
                        } else { $inCatalog = 0; }
			$mediaOutput .= "<td>" . ($inCatalog ? "true" : "false") . "</td>";
			$mediaOutput .= "<td>" . $media->get_ownerName() . "</td>";
			$mediaOutput .= "<td>" . ($media->get_isVdcEnabled() ? "true" : "false") . "</td>";
                        $mediaOutput .= "<td>" . checkVar($media->get_vdcName(),'str') . "</td>";
                        $mediaOutput .= "<td>" . checkVar($media->get_creationDate(),'str') . "</td>";
                        $mediaOutput .= "</tr>\n";
                }
        }
        $mediaOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$mediaOutput);
        fclose($f);

	$mediaSizeTotal = bytesToSize($mediaSize);

        $details = "<table border=1><tr><td><b>Total Size:</b></td><td>".$mediaSizeTotal."</td></tr></table>";
        $GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Admin Media Count:</b></td><td>" . $count . "</td><td>" . $details . "</td></tr>\n";
}

function getMedia() {
	if($GLOBALS['MEDIA'] != "yes") { return; }

	// query all media
        $mediaRecords = queryRecord("media",null,null,"a","name",null);

	$count = $mediaSize = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#media\">Media</a></br>\n";
        $mediaOutput = "<a name=\"media\"></a>\n";
        $mediaOutput .= "<b>Media</b>\n<table border=1>\n";
        $mediaOutput .= "<tr><th>NAME</th><th>STATUS</th><th>SIZE</th><th>PUBLISHED</th><th>CATALOG</th><th>IN CATALOG</th><th>OWNER</th><th>VDC</th><th>CREATION DATE</th></tr>\n";
        if(count($mediaRecords) != 0) {
                foreach ($mediaRecords as $media) {
			$count++;
			$mediaSize += str_replace("-","",$media->get_storageB());
                        $mediaOutput .= "<tr>\n";
                        $mediaOutput .= "<td>" . $media->get_name() . "</td>";
                        $mediaOutput .= "<td>" . $media->get_status() . "</td>";
                        $mediaOutput .= "<td>" . bytesToSize(str_replace("-","",$media->get_storageB())) . "</td>";
                        $mediaOutput .= "<td>" . ($media->get_isPublished() ? "true" : "false") . "</td>";
                        $mediaOutput .= "<td>" . checkVar($media->get_catalogName(),'str') . "</td>";
                        $mediaAtt = $media->get_anyAttributes();
                        if(isset($mediaAtt["isInCatalog"])) {
                                $inCatalog = $mediaAtt["isInCatalog"];
                        } else { $inCatalog = 0; }
                        $mediaOutput .= "<td>" . ($inCatalog ? "true" : "false") . "</td>";
                        $mediaOutput .= "<td>" . $media->get_ownerName() . "</td>";
                        $mediaOutput .= "<td>" . checkVar($media->get_vdcName(),'str') . "</td>";
                        $mediaOutput .= "<td>" . checkVar($media->get_creationDate(),'str') . "</td>";
                        $mediaOutput .= "</tr>\n";
                }
        }
        $mediaOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$mediaOutput);
        fclose($f);

	$mediaSizeTotal = bytesToSize($mediaSize);

	$details = "<table border=1><tr><td><b>Total Size:</b></td><td>".$mediaSizeTotal."</td></tr></table>";
	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Media Count:</b></td><td>" . $count . "</td><td>" . $details . "</td></tr>\n";
}

function getCloudResourceCell() {
	if($GLOBALS['CLOUD_CELL'] != "yes") { return; }

	// query all vCloud Cells
	$cellRecords = queryRecord("cell",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#cloudCell\">Cloud Cells</a></br>\n";
        $cellOutput = "<a name=\"cloudCell\"></a>\n";
	$cellOutput .= "<b>Cloud Cells</b>\n<table border=1>\n";
	$cellOutput .= "<tr><th>NAME</th><th>ACTIVE</th><th>VMware vCenter</th><th>PRIMARY IP</th><th>VERSION</th><th>BUILD DATE</th></tr>\n";
	if(count($cellRecords) != 0) {
		foreach ($cellRecords as $cell) {
			$count++;
			$cellOutput .= "<tr>\n";
                        $cellOutput .= "<td>" . $cell->get_name() . "</td>";
			$cellOutput .= ($cell->get_isActive() ? "<td bgcolor=\"" . $GLOBALS['light_green'] . "\">true</td>" : "<td bgcolor=\"" . $GLOBALS['red'] . "\">false</td>");
			$cellOutput .= "<td>" . ($cell->get_isVMwareVc() ? "true" : "false") . "</td>";
			$cellOutput .= "<td>" . $cell->get_primaryIp() . "</td>";
			$cellOutput .= "<td>" . $cell->get_version() . "</td>";
			$cellOutput .= "<td>" . $cell->get_buildDate() . "</td>";
			$cellOutput .= "</tr>\n";
		}
	}
	$cellOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$cellOutput);
	fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Cloud Cell Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getCloudResourcePvdc() {
	if($GLOBALS['PROVIDER_VDC'] != "yes") { return; }

	// query all pvdcs
	$pvdcRecords = queryRecord("providerVdc",null,null,"a","name",null);

	$count = $memSize = $memUsed = $memAllo = $storageSize = $storageUsed = $storageAllo = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#adminPvdc\">Provider vDCs</a></br>\n";
        $pvdcOutput = "<a name=\"adminPvdc\"></a>\n";
	$pvdcOutput .= "<b>Provider vDCs</b>\n<table border=1>\n";
	$pvdcOutput .= "<tr><th>NAME</th><th>STATUS</th><th>ENABLED</th><th>BUSY</th><th>ORG VDCS</th><th>DATASTORES</th><th>CPU ALLOCATION</th><th>CPU USED</th><th>CPU TOTAL</th><th>MEM ALLOCATION</th><th>MEM USED</th><th>MEM TOTAL</th><th>STORAGE ALLOCATION</th><th>STORAGE USED</th><th>STORAGE TOTAL</th><th>vCENTER</th></tr>\n";
	if(count($pvdcRecords) != 0) {
		foreach ($pvdcRecords as $pvdc) {
			$count++;
			$memSize += str_replace("-","",$pvdc->get_memoryLimitMB() * 1048576);
			$memUsed += str_replace("-","",$pvdc->get_memoryUsedMB() * 1048576);
			$memAllo += str_replace("-","",$pvdc->get_memoryAllocationMB() * 1048576);
			$storageSize += str_replace("-","",$pvdc->get_storageLimitMB() * 1048576);
			$storageUsed += str_replace("-","",$pvdc->get_storageUsedMB() * 1048576);
			$storageAllo += str_replace("-","",$pvdc->get_storageAllocationMB() * 1048576);
			$pvdcOutput .= "<tr>\n";
			$pvdcOutput .= "<td>" . $pvdc->get_name() . "</td>";
			$pvdcStatus = $pvdc->get_status();
			$pvdcOutput .= "<td>" . $pvdcStatus . "</td>";
			$pvdcOutput .= ($pvdc->get_isEnabled() ? "<td bgcolor=\"" . $GLOBALS['light_green'] . "\">good</td>" : "<td bgcolor=\"" . $GLOBALS['red'] . "\">bad</td>");
			$pvdcOutput .= "<td>" . ($pvdc->get_isBusy() ? "true" : "false") . "</td>";
			$pvdcOutput .= "<td>" . $pvdc->get_numberOfVdcs() . "</td>";
			$pvdcOutput .= "<td>" . $pvdc->get_numberOfDatastores() . "</td>";
			$pvdcOutput .= "<td>" . $pvdc->get_cpuAllocationMhz() . " Mhz</td>";
			$pvdcOutput .= "<td>" . $pvdc->get_cpuUsedMhz() . " Mhz</td>";
			$pvdcOutput .= "<td>" . $pvdc->get_cpuLimitMhz() . " Mhz</td>";
			$pvdcOutput .= "<td>" . bytesToSize(str_replace("-","",$pvdc->get_memoryUsedMB()) * 1048576) . "</td>";
			$pvdcOutput .= "<td>" . bytesToSize(str_replace("-","",$pvdc->get_memoryAllocationMB()) * 1048576) . "</td>";
			$pvdcOutput .= "<td>" . bytesToSize(str_replace("-","",$pvdc->get_memoryLimitMB()) * 1048576) . "</td>";
			$pvdcOutput .= "<td>" . bytesToSize(str_replace("-","",$pvdc->get_storageUsedMB()) * 1048576) . "</td>";
			$pvdcOutput .= "<td>" . bytesToSize(str_replace("-","",$pvdc->get_storageAllocationMB()) * 1048576) . "</td>";
			$pvdcOutput .= "<td>" . bytesToSize(str_replace("-","",$pvdc->get_storageLimitMB()) * 1048576) . "</td>";
			$pvdcAtt = $pvdc->get_anyAttributes();
                        if(isset($pvdcAtt["vcName"])) {
                                $vc = $pvdcAtt["vcName"];
                        } else { $vc = "N/A"; }
                        $pvdcOutput .= "<td>" . $vc . "</td>";
			$pvdcOutput .= "</tr>\n";
                }
	}
        $pvdcOutput .= "</table></br>\n";
	$f = fopen($GLOBALS['report'],"a");
        fwrite($f,$pvdcOutput);
        fclose($f);

	$memSizeTotal = bytesToSize($memSize);
	$memUsedTotal = bytesToSize($memUsed);
	$memAlloTotal = bytesToSize($memAllo);
        $storageSizeTotal = bytesToSize($storageSize);
	$storageUsedTotal = bytesToSize($storageUsed);
	$storageAlloTotal = bytesToSize($storageAllo);

        $details = "<table border=1><tr><td><b>Mem Alloc:</b></td><td>".$memAlloTotal."</td><td><b>Mem Used:</b></td><td>".$memUsedTotal."</td><td><b>Mem Total:</b></td><td>".$memSizeTotal."</td><td><b>Storage Alloc:</b></td><td>".$storageAlloTotal."</td><td><b>Storage Used:</b></td><td>".$storageUsedTotal."</td></tr><td><b>Storage Total:</b></td><td>".$storageSizeTotal."</td></table>";
	
	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Provider vDC Count:</b></td><td>" . $count . "</td><td>" . $details . "</td></tr>\n";
}

function getAdminOrgVdc() {
	if($GLOBALS['ADMIN_ORG_VDC'] != "yes") { return; }

	// query all org vdcs
        $orgVdcRecords = queryRecord("adminOrgVdc",null,null,"a","name",null);

	$count = $memSize = $storageSize = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#adminOrgVdc\">Admin Organization vDCs</a></br>\n";
        $orgVdcOutput = "<a name=\"adminOrgVdc\"></a>\n";
        $orgVdcOutput .= "<b>Admin Orgnization vDCs</b>\n<table border=1>\n";
        $orgVdcOutput .= "<tr><th>NAME</th><th>STATUS</th><th>ENABLED</th><th>BUSY</th><th>ORG</th><th>SYSTEM ORG</th><th>PVDC</th><th>CPU</th><th>MEM</th><th>STORAGE</th><th>vAPP</th><th>vAPP TEMPLATE</th><th>MEDIA</th><th>vCENTER</th></tr>\n";
	if(count($orgVdcRecords) != 0) {
                foreach ($orgVdcRecords as $org) {
			$count++;
			$memSize += str_replace("-","",$org->get_memoryAllocationMB() * 1048576);
			$storageSize += str_replace("-","",$org->get_storageAllocationMB() * 1048576);
                        $orgVdcOutput .= "<tr>\n";
                        $orgVdcOutput .= "<td>" . $org->get_name() . "</td>";
			$orgVdcStatus = $org->get_status();
			$orgVdcOutput .= "<td>" . $orgVdcStatus . "</td>";
			$orgVdcOutput .= ($org->get_isEnabled() ? "<td bgcolor=\"" . $GLOBALS['light_green'] . "\">true</td>" : "<td bgcolor=\"" . $GLOBALS['red'] . "\">false</td>");
			$orgVdcOutput .= "<td>" . ($org->get_isBusy() ? "true" : "false") . "</td>";
			$orgVdcOutput .= "<td>" . $org->get_orgName() . "</td>";
			$orgVdcOutput .= "<td>" . ($org->get_isSystemVdc() ? "true" : "false") . "</td>";
			$orgVdcOutput .= "<td>" . $org->get_providerVdcName() . "</td>";
			$orgVdcOutput .= "<td>" . $org->get_cpuAllocationMhz() . " Mhz</td>";
			$orgVdcOutput .= "<td>" . bytesToSize(str_replace("-","",$org->get_memoryAllocationMB()) * 1048576) . "</td>";
			$orgVdcOutput .= "<td>" . bytesToSize(str_replace("-","",$org->get_storageAllocationMB()) * 1048576) . "</td>";
			$orgVdcOutput .= "<td>" . $org->get_numberOfVApps() . "</td>";
			$orgVdcOutput .= "<td>" . $org->get_numberOfVAppTemplates() . "</td>";
			$orgVdcOutput .= "<td>" . $org->get_numberOfMedia() . "</td>";
			$orgVdcAtt = $org->get_anyAttributes();
                        if(isset($orgVdcAtt["vcName"])) {
				$vc = $orgVdcAtt["vcName"];
                        } else { $vc = "N/A"; }
                        $orgVdcOutput .= "<td>" . $vc . "</td>";
                        $orgVdcOutput .= "</tr>\n";
        	}
	}
        $orgVdcOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$orgVdcOutput);
        fclose($f);

	$memSizeTotal = bytesToSize($memSize);
	$storageSizeTotal = bytesToSize($storageSize);

	$details = "<table border=1><tr><td><b>Mem Total:</b></td><td>".$memSizeTotal."</td><td><b>Storage Total:</b></td><td>".$storageSizeTotal."</td></tr></table>";
	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Admin Org vDC Count:</b></td><td>" . $count . "</td><td>" . $details . "</td></tr>\n";
}

function getOrgVdc() {
	if($GLOBALS['ORG_VDC'] != "yes") { return; }

        // query all org vdcs
        $orgVdcRecords = queryRecord("orgVdc",null,null,"a","name",null);

	$count = $memAllo = $storageAllo = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#orgVdc\">Organization vDCs</a></br>\n";
        $orgVdcOutput = "<a name=\"orgVdc\"></a>\n";
        $orgVdcOutput .= "<b>Orgnization vDCs</b>\n<table border=1>\n";
        $orgVdcOutput .= "<tr><th>NAME</th><th>STATUS</th><th>ENABLED</th><th>BUSY</th><th>ORG</th><th>SYSTEM ORG</th><th>PVDC</th><th>CPU</th><th>MEM</th><th>STORAGE</th><th>vAPP</th><th>vAPP TEMPLATE</th><th>MEDIA</th><th>DATASTORE</th><th>PVDC HARDWARE VERSION</th></tr>\n";
        if(count($orgVdcRecords) != 0) {
                foreach ($orgVdcRecords as $org) {
			$count++;
			$memAllo += str_replace("-","",$org->get_memoryAllocationMB() * 1048576);
			$storageAllo += str_replace("-","",$org->get_storageAllocationMB() * 1048576);
                        $orgVdcOutput .= "<tr>\n";
                        $orgVdcOutput .= "<td>" . $org->get_name() . "</td>";
                        $orgVdcStatus = $org->get_status();
                        $orgVdcOutput .= "<td>" . $orgVdcStatus . "</td>";
                        $orgVdcOutput .= ($org->get_isEnabled() ? "<td bgcolor=\"" . $GLOBALS['light_green'] . "\">true</td>" : "<td bgcolor=\"" . $GLOBALS['red'] . "\">false</td>");
                        $orgVdcOutput .= "<td>" . ($org->get_isBusy() ? "true" : "false") . "</td>";
                        $orgVdcOutput .= "<td>" . $org->get_orgName() . "</td>";
                        $orgVdcOutput .= "<td>" . ($org->get_isSystemVdc() ? "true" : "false") . "</td>";
                        $orgVdcOutput .= "<td>" . checkVar($org->get_providerVdcName(),'str') . "</td>";
                        $orgVdcOutput .= "<td>" . $org->get_cpuAllocationMhz() . " Mhz</td>";
                        $orgVdcOutput .= "<td>" . bytesToSize(str_replace("-","",$org->get_memoryAllocationMB()) * 1048576) . "</td>";
                        $orgVdcOutput .= "<td>" . bytesToSize(str_replace("-","",$org->get_storageAllocationMB()) * 1048576) . "</td>";
                        $orgVdcOutput .= "<td>" . $org->get_numberOfVApps() . "</td>";
                        $orgVdcOutput .= "<td>" . $org->get_numberOfVAppTemplates() . "</td>";
                        $orgVdcOutput .= "<td>" . $org->get_numberOfMedia() . "</td>";
			$orgVdcOutput .= "<td>" . $org->get_numberOfDatastores() . "</td>";
                        $orgVdcAtt = $org->get_anyAttributes();
                        if(isset($orgVdcAtt["pvdcHardwareVersion"])) {
                                $pvdcHWVers = $orgVdcAtt["pvdcHardwareVersion"];
                        } else { $pvdcHWVers = "N/A"; }
                        $orgVdcOutput .= "<td>" . $pvdcHWVers . "</td>";
                        $orgVdcOutput .= "</tr>\n";
                }
        }
        $orgVdcOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$orgVdcOutput);
        fclose($f);

        $memAlloTotal = bytesToSize($memAllo);
        $storageAlloTotal = bytesToSize($storageAllo);

        $details = "<table border=1><tr><td><b>Mem Alloc:</b></td><td>".$memAlloTotal."</td></td><td><b>Storage Alloc:</b></td><td>".$storageAlloTotal."</td></table>";

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Org vDC Count:</b></td><td>" . $count . "</td><td>" . $details . "</td></tr>\n";
}

function getCloudResourceExtNet() {
	if($GLOBALS['EXT_NETWORK'] != "yes") { return; }

	// query all org vdcs
        $extNetRecords = queryRecord("externalNetwork",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#extNet\">External Networks</a></br>\n";
        $extNetOutput = "<a name=\"extNet\"></a>\n";
        $extNetOutput .= "<b>External Networks</b>\n<table border=1>\n";
	$extNetOutput .= "<tr><th>NAME</th><th>BUSY</th><th>DEFAULT GATEWAY</th><th>NETMASK</th><th>PRIMARY DNS</th><th>SECONDARY DNS</th><th>DNS SUFFIX</th><th>vCENTER</th></tr>\n";
	if(count($extNetRecords) != 0) {
                foreach ($extNetRecords as $extNet) {
			$count++;
			$extNetOutput .= "<tr>\n";
			$extNetOutput .= "<td>" . $extNet->get_name() . "</td>";
			$extNetOutput .= "<td>" . ($extNet->get_isBusy() ? "true" : "false") . "</td>";
			$extNetOutput .= "<td>" . $extNet->get_gateway() . "</td>";
			$extNetOutput .= "<td>" . $extNet->get_netmask() . "</td>";
			$extNetOutput .= "<td>" . checkVar($extNet->get_dns1(),'str') . "</td>";
			$extNetOutput .= "<td>" . checkVar($extNet->get_dns2(),'str') . "</td>";
			$extNetOutput .= "<td>" . checkVar($extNet->get_dnsSuffix(),'str') . "</td>";
			$extNetAtt = $extNet->get_anyAttributes();
                        if(isset($extNetAtt["vcName"])) {
                                $vc = $extNetAtt["vcName"];
                        } else { $vc = "N/A"; }
                        $extNetOutput .= "<td>" . $vc . "</td>";
			$extNetOutput .= "</tr>\n";
		}
	}
	$extNetOutput .= "</table></br>\n";
	$f = fopen($GLOBALS['report'],"a");
        fwrite($f,$extNetOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>External Network Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getAdminOrgNet() {
	if($GLOBALS['ADMIN_ORG_NETWORK'] != "yes") { return; }

	// query admin org net
	$orgNetRecords = queryRecord("adminOrgNetwork",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#adminOrgNet\">Admin Organization Networks</a></br>\n";
        $orgNetOutput = "<a name=\"adminOrgNet\"></a>\n";
	$orgNetOutput .= "<b>Admin Organization Networks</b>\n<table border=1>\n";
	$orgNetOutput .= "<tr><th>NAME</th><th>BUSY</th><th>DEFAULT GATEWAY</th><th>NETMASK</th><th>PRIMARY DNS</th><th>SECONDARY DNS</th><th>ORG</th><th>NETWORK POOL</th></tr>\n";
	if(count($orgNetRecords) != 0) {
		foreach ($orgNetRecords as $orgNet) {
			$count++;
			$orgNetOutput .= "<tr>\n";
			$orgNetOutput .= "<td>" . $orgNet->get_name() . "</td>";
			$orgNetOutput .= "<td>" . ($orgNet->get_isBusy() ? "true" : "false") . "</td>";
                        $orgNetOutput .= "<td>" . $orgNet->get_gateway() . "</td>";
                        $orgNetOutput .= "<td>" . $orgNet->get_netmask() . "</td>";
                        $orgNetOutput .= "<td>" . checkVar($orgNet->get_dns1(),'str') . "</td>";
                        $orgNetOutput .= "<td>" . checkVar($orgNet->get_dns2(),'str') . "</td>";
			$orgNetOutput .= "<td>" . $orgNet->get_orgName() . "</td>";
			$orgNetOutput .= "<td>" . checkVar($orgNet->get_networkPoolName(),'str') . "</td>";
			$orgNetOutput .= "</tr>\n";
		}
	}
	$orgNetOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$orgNetOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Admin Org Network Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getOrgNet() {
	if($GLOBALS['ORG_NETWORK'] != "yes") { return; }

	// query org net
        $orgNetRecords = queryRecord("orgNetwork",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#orgNetwork\">Organization Networks</a></br>\n";
        $orgNetOutput = "<a name=\"orgNetwork\"></a>\n";
        $orgNetOutput .= "<b>Organization Networks</b>\n<table border=1>\n";
        $orgNetOutput .= "<tr><th>NAME</th><th>BUSY</th><th>DEFAULT GATEWAY</th><th>NETMASK</th><th>PRIMARY DNS</th><th>SECONDARY DNS</th><th>NETWORK POOL</th></tr>\n";
        if(count($orgNetRecords) != 0) {
                foreach ($orgNetRecords as $orgNet) {
			$count++;
                        $orgNetOutput .= "<tr>\n";
                        $orgNetOutput .= "<td>" . $orgNet->get_name() . "</td>";
                        $orgNetOutput .= "<td>" . ($orgNet->get_isBusy() ? "true" : "false") . "</td>";
                        $orgNetOutput .= "<td>" . $orgNet->get_gateway() . "</td>";
                        $orgNetOutput .= "<td>" . $orgNet->get_netmask() . "</td>";
                        $orgNetOutput .= "<td>" . checkVar($orgNet->get_dns1(),'str') . "</td>";
                        $orgNetOutput .= "<td>" . checkVar($orgNet->get_dns2(),'str') . "</td>";
                        $orgNetOutput .= "<td>" . checkVar($orgNet->get_networkPoolName(),'str') . "</td>";
                        $orgNetOutput .= "</tr>\n";
                }
        }
        $orgNetOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$orgNetOutput);
        fclose($f);

	$GLOBALS['buildOrgUserSummaryOutput']["orgNetCount"] = $count;
	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Org Network Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getCloudResourceNetPool() {
	if($GLOBALS['NETWORK_POOL'] != "yes") { return; }

	// query all network pools
	$netPoolRecords = queryRecord("networkPool",null,null,"a","name",null);

	$count = $vlanCount = $vcdniCount = $pgCount = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#netPool\">Network Pools</a></br>\n";
        $netPoolOutput = "<a name=\"netPool\"></a>\n";
	$netPoolOutput .= "<b>Network Pools</b>\n<table border=1>\n";
	$netPoolOutput .= "<tr><th>NAME</th><th>TYPE</th><th>POOL USED</th><th>VLAN ID/RANGE</th><th>MTU</th><th>PROMISCUOUS MODE</th><th>vCENTER</th></tr>\n";
	if(count($netPoolRecords) != 0) {
		foreach ($netPoolRecords as $netPool) {
			try {	
				$netPoolSDKObj = $GLOBALS['service']->createSDKObj($netPool->get_href())->getVMWNetworkPool();
			} catch (Exception $e) {
                                echo "Warning: Unable to retrieve Network Pool SDKObj\n";
                        }
			$count++;
			$netPoolOutput .= "<tr>\n";
			$netPoolOutput .= "<td>" . $netPool->get_name() . "</td>";
			// 0 = VLAN
			// 2 = VCD-NI
			// 3 = PORTGROUP
			switch ($netPool->get_networkPoolType()) {
				case 0:
				$netPoolType = "VLAN";
				$vlanCount++;
				break;
				case 1:
				$netPoolType = "VCD-NI";
				$vcdniCount++;
				break;
				case 2:
				$netPoolType = "PORTGROUP";
				$pgCount++;
				break;	
			}
			$netPoolOutput .= "<td>" . $netPoolType . "</td>\n";
			$netPoolUsed = 0;
			$netPoolVlan = "N/A";
			$netPoolMtu = "N/A";
			$netPoolProm = "N/A";
			if(is_a($netPoolSDKObj,"VMware_VCloud_API_Extension_VlanPoolType")) {
				$netPoolUsed = $netPoolSDKObj->getUsedNetworksCount();
				$vlanRanges = $netPoolSDKObj->getVlanRange();
				if(count($vlanRanges) != 0) {
					$netPoolVlan = "";
					foreach ($vlanRanges as $vlan) {
						$netPoolVlan .= $vlan->getStart() . "-" . $vlan->getEnd() . "</br>";
					}
				}
				$netPoolProm = ($netPoolSDKObj->getPromiscuousMode() ? "true" : "false");
			} elseif(is_a($netPoolSDKObj,"VMware_VCloud_API_Extension_FencePoolType")) {
				$netPoolUsed = $netPoolSDKObj->getUsedNetworksCount();
                                $netPoolVlan = $netPoolSDKObj->getVlanId();
				$netPoolMtu = $netPoolSDKObj->getMtu();
				$netPoolProm = ($netPoolSDKObj->getPromiscuousMode() ? "true" : "false");
			} elseif(is_a($netPoolSDKObj,"VMware_VCloud_API_Extension_PortGroupPoolType")) {
				$netPoolUsed = $netPoolSDKObj->getUsedNetworksCount();
			}
			$netPoolOutput .= "<td>" . $netPoolUsed . "</td>";
			$netPoolOutput .= "<td>" . $netPoolVlan . "</td>";
			$netPoolOutput .= "<td>" . $netPoolMtu . "</td>";
			$netPoolOutput .= "<td>" . $netPoolProm . "</td>";
			$netPoolAtt = $netPool->get_anyAttributes();
                        if(isset($netPoolAtt["vcName"])) {
                                $vc = $netPoolAtt["vcName"];
                        } else { $vc = "N/A"; }
                        $netPoolOutput .= "<td>" . $vc . "</td>";
			$netPoolOutput .= "</tr>\n";
		}
	}
	$netPoolOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$netPoolOutput);
        fclose($f);

	$details = "<table border=1><tr><td><b># Of VLAN:</b></td><td>".$vlanCount."</td></td><td><b># Of VCD-NI:</b></td><td>".$vcdniCount."</td><td><b># Of Portgroup:</b></td><td>".$pgCount."</td></td></table>";

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Network Pool Count:</b></td><td>" . $count . "</td><td>" . $details . "</td></tr>\n";
}

function getVSphereResourcevCenter() {
	if($GLOBALS['VCENTER'] != "yes") { return; }

	// query all vCenter Servers
	$vcRecords = queryRecord("virtualCenter",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#vc\">vCenter Servers</a></br>\n";
        $vcOutput = "<a name=\"vc\"></a>\n";
	$vcOutput .= "<b>vCenter Servers</b>\n<table border=1>\n";
	$vcOutput .= "<tr><th>NAME</th><th>STATUS</th><th>ENABLED</th><th>BUSY</th><th>URL</th><th>USER</th><th>VERSION</th><th>UUID</th><th>vShield Server</th><th>vShield User</th></tr>\n";
	if(count($vcRecords) != 0) {
		foreach ($vcRecords as $vc) {
			try {	
				$vcSDKObj = $GLOBALS['service']->createSDKObj($vc->get_href())->getVimServer();
			} catch (Exception $e) {
                                echo "Warning: Unable to retrieve vCenter SDKObj\n";
                        }
			$count++;
			$vcOutput .= "<tr>\n";
			$vcOutput .= "<td>" . $vc->get_name() . "</td>";
			$vcStatus = $vc->get_status();
                        $vcOutput .= "<td>" . $vcStatus . "</td>";
			$vcOutput .= ($vc->get_isEnabled() ? "<td bgcolor=\"" . $GLOBALS['light_green'] . "\">true</td>" : "<td bgcolor=\"" . $GLOBALS['red'] . "\">false</td>");
			$vcOutput .= "<td>" . ($vc->get_isBusy() ? "true" : "false") . "</td>";
			$vcOutput .= "<td>" . $vc->get_url() . "</td>";
			$vcOutput .= "<td>" . $vc->get_username() . "</td>";
			$vcOutput .= "<td>" . $vc->get_vcVersion() . "</td>";
			$vcOutput .= "<td>" . $vc->get_uuid() . "</td>";
			try {
				$vcOutput .= "<td>" .gethostbyaddr($vc->get_vsmIP()) . "</td>";
			} catch(Exception $e) {
				$vcOutput .= "<td>" . $vc->get_vsmIP() . "</td>";
			}
			$vcOutput .= "<td>" . $vcSDKObj->getShieldManagerUserName() . "</td>";
			$vcOutput .= "</tr>\n";
		}
	}
	$vcOutput .= "</table></br>\n";
	$f = fopen($GLOBALS['report'],"a");
        fwrite($f,$vcOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>vCenter Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getVSphereResourceRP() {
	if($GLOBALS['RESOURCE_POOL'] != "yes") { return; }

	// retireve all resource pools
	$rpRecords = queryRecord("resourcePool",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#rp\">Resource Pools</a></br>\n";
        $rpOutput = "<a name=\"rp\"></a>\n";
        $rpOutput .= "<b>Resource Pools</b>\n<table border=1>\n";
        $rpOutput .= "<tr><th>NAME</th><th>MOREF</th><th>vCENTER</th></tr>\n";        
	if(count($rpRecords) != 0) {
                foreach ($rpRecords as $rp) {
			$count++;
                        $rpOutput .= "<tr>\n";
                        $rpOutput .= "<td>" . $rp->get_name() . "</td>";
                        $rpOutput .= "<td>" . $rp->get_moref() . "</td>";
			$rpOutput .= "<td>" . $rp->get_vcName() . "</td>";
                        $rpOutput .= "</tr>\n";
                }
        }
        $rpOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$rpOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Resource Pool Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getVSphereResourceHost() {
	if($GLOBALS['HOST'] != "yes") { return; }

	// query all hosts
	$hostRecords = queryRecord("host",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#host\">Hosts</a></br>\n";
        $hostOutput = "<a name=\"host\"></a>\n";
	$hostOutput .= "<b>Hosts</b>\n<table border=1>\n";
	$hostOutput .= "<tr><th>NAME</th><th>MOREF</th><th>ENABLED</th><th>BUSY</th><th>SUPPORTED</th><th>HUNG</th><th>MAINT MODE</th><th>PREPARED</th><th>PENDING UPGRADE</th><th>VCD-NI CAPABLE</th><th>VERSION</th><th>CPU TYPE</th><th>NUM SOCKET</th><th>NUM CORE</th><th>NUM OF VMS</th><th>TOTAL CPU</th><th>TOTAL MEM</th><th>MEM USED</th><th>USED BY PVDC</th><th>vCENTER</th></tr>\n";
	if(count($hostRecords) != 0) {
		foreach ($hostRecords as $host) {
			try {
				$hostSDKObj = $GLOBALS['service']->createSDKObj($host->get_href())->getHost();
				$hostMoRef = $hostSDKObj->getVmMoRef();
				$hostOSNameAndVersion = $hostSDKObj->getHostOsName() . " " . $hostSDKObj->getHostOsVersion();
				$hostCpuType = $hostSDKObj->getCpuType();
				$hostCpuSocket = $hostSDKObj->getNumOfCpusPackages();
				$hostCpuCore = $hostSDKObj->getNumOfCpusLogical();
				$hostCpuTotal = $hostSDKObj->getCpuTotal() . " Mhz";
				$hostMemTotal = $hostSDKObj->getMemTotal();
				$hostMemUsed = $hostSDKObj->getMemUsed();
			} catch(Exception $e) {
				$hostMoRef = $hostOSNameAndVersion = $hostCpuType = $hostCpuSocket = $hostCpuCore = $hostCpuTotal = $hostMemTotal = $hostMemUsed = "N/A";
			}				

			$count++;
			$hostOutput .= "<tr>\n";
                        $hostOutput .= "<td>" . $host->get_name() . "</td>";
			$hostOutput .= "<td>" . $hostMoRef . "</td>";
			$hostOutput .= ($host->get_isEnabled() ? "<td bgcolor=\"" . $GLOBALS['light_green'] . "\">true</td>" : "<td bgcolor=\"" . $GLOBALS['red'] . "\">false</td>");
			$hostOutput .= "<td>" . ($host->get_isBusy() ? "true>" : "false") . "</td>";
			$hostOutput .= "<td>" . ($host->get_isSupported() ? "true" : "false") . "</td>";
			$hostOutput .= ($host->get_isHung() ? "<td bgcolor=\"" . $GLOBALS['red'] . "\">true</td>" : "<td>false</td>");
			$hostOutput .= "<td>" . ($host->get_isInMaintenanceMode() ? "true" : "false") . "</td>";
			$hostOutput .= "<td>" . ($host->get_isPrepared() ? "true" : "false") . "</td>";
			$hostOutput .= "<td>" . ($host->get_isPendingUpgrade() ? "true" : "false") . "</td>";
			$hostOutput .= "<td>" . ($host->get_isCrossHostEnabled() ? "true" : "false") . "</td>";
			$hostOutput .= "<td>" . $hostOSNameAndVersion . "</td>";
			$hostOutput .= "<td>" . $hostCpuType . "</td>";
			$hostOutput .= "<td>" . $hostCpuSocket . "</td>";
			$hostOutput .= "<td>" . $hostCpuCore . "</td>";
			$hostOutput .= "<td>" . $host->get_numberOfVMs() . "</td>";
			$hostOutput .= "<td>" . $hostCpuTotal . "</td>";
			$hostOutput .= "<td>" . $hostMemTotal . "</td>";
                        $hostOutput .= "<td>" . $hostMemUsed . "</td>";
			$hostAtt = $host->get_anyAttributes();
                        if(isset($hostAtt["isUsedByProviderVdc"])) {
                                $usedByPvdc = $hostAtt["isUsedByProviderVdc"];
				$usedByPvdc = ($usedByPvdc ? "true" : "false");
                        } else { $usedByPvdc = "N/A"; }
                        $hostOutput .= "<td>" . $usedByPvdc . "</td>";
			$hostOutput .= "<td>" . $host->get_vcName() . "</td>";
			$hostOutput .= "</tr>\n";
		}
	}
	$hostOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$hostOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Host Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getVSphereResourceDatastore() {
	if($GLOBALS['DATASTORE'] != "yes") { return; }

	//query all datastores
	$datastoreRecords = queryRecord("datastore",null,null,"a","name",null);

	$count = $dsSize = $dsUsed = $dsReq = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#ds\">Datastores</a></br>\n";
        $dsOutput = "<a name=\"ds\"></a>\n";
	$dsOutput .= "<b>Datastores</b>\n<table border=1>\n";
        $dsOutput .= "<tr><th>NAME</th><th>MOREF</th><th>ENABLED</th><th>TYPE</th><th>PROVISIONED</th><th>USED</th><th>REQUESTED</th><th>NUM OF PVDC</th><th>vCENTER</th></tr>\n";
	if(count($datastoreRecords) != 0) {
		foreach($datastoreRecords as $ds) {
			$count++;
			$dsSize = str_replace("-","",$ds->get_provisionedStorageMB() * 1048576); 
			$dsUsed = str_replace("-","",$ds->get_storageUsedMB() * 1048576);
			$dsReq = str_replace("-","",$ds->get_requestedStorageMB() * 1048576);
			$dsOutput .= "<tr>\n";
			$dsOutput .= "<td>" . $ds->get_name() . "</td>";
			$dsOutput .= "<td>" . $ds->get_moref() . "</td>";
			$dsOutput .= ($ds->get_isEnabled() ? "<td bgcolor=\"" . $GLOBALS['light_green'] . "\">true</td>" : "<td bgcolor=\"" . $GLOBALS['red'] . "\">false</td>");
			$dsOutput .= "<td>" . $ds->get_datastoreType() . "</td>";
			$dsOutput .= "<td>" . bytesToSize(str_replace("-","",$ds->get_provisionedStorageMB()) * 1048576) . "</td>";
			$dsOutput .= "<td>" . bytesToSize(str_replace("-","",$ds->get_storageUsedMB()) * 1048576) . "</td>";
			$dsOutput .= "<td>" . bytesToSize(str_replace("-","",$ds->get_requestedStorageMB()) * 1048576) . "</td>";
			$dsOutput .= "<td>" . $ds->get_numberOfProviderVdcs() . "</td>";
			$dsOutput .= "<td>" . $ds->get_vcName() . "</td>";
			$dsOutput .= "</tr>\n";
		}
	}
        $dsOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$dsOutput);
        fclose($f);

	$dsSizeTotal = bytesToSize($dsSize);
	$dsUsedTotal = bytesToSize($dsUsed);
	$dsReqTotal = bytesToSize($dsReq);

	$details = "<table border=1><tr><td><b>Requested:</b></td><td>".$dsReqTotal."</td><td><b>Used:</b></td><td>".$dsUsedTotal."</td><td><b>Total:</b></td><td>".$dsSizeTotal."</td><td></table>";

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Datastore Count:</b></td><td>" . $count . "</td><td>" . $details . "</td></tr>\n";
}

function getVSphereResourcedVds() {
	if($GLOBALS['DVS'] != "yes") { return; }

        //query all vDS
        $dvsRecords = queryRecord("dvSwitch",null,null,"a","name",null);
	
	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#dvs\">Distributed vSwitches</a></br>\n";
        $dvsOutput = "<a name=\"dvs\"></a>\n";
        $dvsOutput .= "<b>Distributed vSwitches</b>\n<table border=1>\n";
        $dvsOutput .= "<tr><th>NAME</th><th>MOREF</th><th>vCENTER ENABLED</th><th>vCENTER</th></tr>\n";
        if(count($dvsRecords) != 0) {
                foreach($dvsRecords as $dvs) {
			$count++;
                        $dvsOutput .= "<tr>\n";
                        $dvsOutput .= "<td>" . $dvs->get_name() . "</td>";
                        $dvsOutput .= "<td>" . $dvs->get_moref() . "</td>";
                        $dvsOutput .= "<td>" . ($dvs->get_isVCEnabled() ? "true" : "false") . "</td>";
                        $dvsOutput .= "<td>" . $dvs->get_vcName() . "</td>";
                        $dvsOutput .= "</tr>\n";
                }
        }
        $dvsOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$dvsOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Distributed vSwitch Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getVSphereResourcedPortgroup() {
	if($GLOBALS['PORTGROUP'] != "yes") { return; }

        //query all portgroups
        $pgRecords = queryRecord("portgroup",null,null,"a","name",null);

	$count = $extCount = $orgCount = $vappCount = $naCount = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#pg\">Portgroups</a></br>\n";
        $pgOutput = "<a name=\"pg\"></a>\n";
        $pgOutput .= "<b>Portgroups</b>\n<table border=1>\n";
        $pgOutput .= "<tr><th>NAME</th><th>MOREF</th><th>vCENTER ENABLED</th><th>ORG NETWORK</th><th>PORTGROUP TYPE</th><th>NETWORK TYPE</th><th>vCENTER</th></tr>\n";
        if(count($pgRecords) != 0) {
                foreach($pgRecords as $pg) {
			$count++;
                        $pgOutput .= "<tr>\n";
                        $pgOutput .= "<td>" . $pg->get_name() . "</td>";
                        $pgOutput .= "<td>" . $pg->get_moref() . "</td>";
                        $pgOutput .= "<td>" . ($pg->get_isVCEnabled() ? "true" : "false") . "</td>";
			$pgOutput .= "<td>" . $pg->get_networkName() . "</td>";
			switch ($pg->get_portgroupType()) {
				case "DV_PORTGROUP":
				$pgType = "Distributed";
				break;
				case "NETWORK":
				$pgType = "Standard";
				break;
				default:
				$pgType = $pg->get_portgroupType();	
			}
			$pgOutput .= "<td>" . $pgType . "</td>";
			switch ($pg->get_scopeType()) {
				// -1 = N/A
				// 1 = External
				// 2 = Organization
				// 3 = vApp
				case "-1":
				$netType = "</br>";
				break; 
				case "1":
				$netType = "External";
				$extCount++;
				break;
				case "2":
				$netType = "Organization";
				$orgCount++;
				break;
				case "3":
				$netType = "vApp";
				$vappCount++;
				break;
				default:
				$netType = $pg->get_scopeType();
				$naCount++;
				break;
			}
			$pgOutput .= "<td>" . $netType . "</td>";
                        $pgOutput .= "<td>" . $pg->get_vcName() . "</td>";
                        $pgOutput .= "</tr>\n";
                }
        }
        $pgOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$pgOutput);
        fclose($f);

	$details = "<table border=1><tr><td><b># Of External Net:</b></td><td>".$extCount."</td><td><b># of Org Net:</b></td><td>".$orgCount."</td><td><b># Of vAPP Net:</b></td><td>".$vappCount."</td><td><b># Of N/A:</b></td><td>".$naCount."</td></tr></table>";	

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Portgroup Count:</b></td><td>" . $count . "</td><td>" . $details . "</td></tr>\n";
}

function getTask() {
	if($GLOBALS['TASK'] != "yes") { return; }

	// query last 25 tasks
	$taskRecords = queryRecord("task",null,null,'d','endDate',$GLOBALS['MAXTASKQUERY']);

	$GLOBALS['jumpTagOutput'] .= "<a href=\"#task\">Tasks</a></br>\n";
        $taskOutput = "<a name=\"task\"></a>\n";
	$taskOutput .= "<b>Tasks (recent " . $GLOBALS['MAXTASKQUERY'] . ")</b>\n<table border=1>\n";
        $taskOutput .= "<tr><th>NAME</th><th>STATUS</th><th>OBJECT NAME</th><th>OBJECT TYPE</th><th>ORG NAME</th><th>OWNER</th><th>START</th><th>END</th><th>DETAILS</th></tr>\n";
        if(count($taskRecords) != 0) {
                foreach($taskRecords as $task) {
                        $taskOutput .= "<tr>\n";
			$taskOutput .= "<td>" . $task->get_name() . "</td>";
			switch($task->get_status()) {
				case "error":
				$taskOutput .= "<td bgcolor=\"" . $GLOBALS['light_red'] . "\">" . $task->get_status() . "</td>";
				break;
				default:
				$taskOutput .= "<td>" . $task->get_status() . "</td>"; 
				break;
			}
			$taskOutput .= "<td>" . $task->get_objectName() . "</td>";
			$taskOutput .= "<td>" . $task->get_objectType() . "</td>";
			$taskOutput .= "<td>" . $task->get_orgName() . "</td>";
			$taskOutput .= "<td>" . $task->get_ownerName() . "</td>";
			$taskOutput .= "<td>" . $task->get_startDate() . "</td>";
			$taskOutput .= "<td>" . $task->get_endDate() . "</td>";
			$taskAtt = $task->get_anyAttributes();
                        if(isset($taskAtt["details"])) {
                                $taskDetails = $taskAtt["details"];
                        } else { $taskDetails = "</br>"; }
                        $taskOutput .= "<td>" . checkVar($taskDetails,'str') . "</td>";
                        $taskOutput .= "</tr>\n";
                }
        }
        $taskOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$taskOutput);
        fclose($f);
}

function getEvent() {
	if($GLOBALS['EVENT'] != "yes") { return; }

        // query last 25 events
        $eventRecords = queryRecord("event",null,null,'d','timeStamp',$GLOBALS['MAXEVENTQUERY']);

	$GLOBALS['jumpTagOutput'] .= "<a href=\"#event\">Events</a></br>\n";
        $eventOutput = "<a name=\"event\"></a>\n";
        $eventOutput .= "<b>Events (recent " . $GLOBALS['MAXEVENTQUERY'] . ")</b>\n<table border=1>\n";
        $eventOutput .= "<tr><th>NAME</th><th>STATUS</th><th>ENTITY TYPE</th><th>EVENT TYPE</th><th>OWNER</th><th>TIMESTAMP</th></tr>\n";
        if(count($eventRecords) != 0) {
                foreach($eventRecords as $event) {
                        $eventOutput .= "<tr>\n";
                        $eventOutput .= "<td>" . $event->get_entityName() . "</td>";
                        switch($event->get_eventStatus()) {
                                case "2";
                                $eventOutput .= "<td>SUCCESS</td>";
                                break;
                                case "3":
                                $eventOutput .= "<td bgcolor=\"" . $GLOBALS['light_red'] . "\">" . "FAILURE" . "</td>";
                                break;
                                default:
                                $eventOutput .= "<td>" . $event->get_eventStatus() . "</td>";
                                break;
                        }
                        $eventOutput .= "<td>" . $event->get_entityType() . "</td>";
                        $eventOutput .= "<td>" . $event->get_eventType() . "</td>";
                        $eventOutput .= "<td>" . $event->get_userName() . "</td>";
                        $eventOutput .= "<td>" . $event->get_timeStamp() . "</td>";
                        $eventOutput .= "</tr>\n";
                }
        }
        $eventOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$eventOutput);
        fclose($f);
}

function getBlockingTask() {
	if($GLOBALS['BLOCKING_TASK'] != "yes") { return; }

        // query blocking tasks
        $btRecords = queryRecord("blockingTask",null,null,"a","operationName",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#bt\">Blocking Tasks</a></br>\n";
        $btOutput = "<a name=\"bt\"></a>\n";
        $btOutput .= "<b>Blocking Tasks</b>\n<table border=1>\n";
        $btOutput .= "<tr><th>OPERATION NAME</th><th>STATUS</th><th>JOB STATUS</th><th>OWNER</th><th>ORGINATING ORG</th><th>CREATION TIME</th><th>EXPIRATION TIME</th><th>TIMEOUT ACTION</th></tr>\n";
        if(count($btRecords) != 0) {
                foreach($btRecords as $bt) {
			$count++;
                        $btOutput .= "<tr>\n";
                        $btOutput .= "<td>" . $bt->get_operationName() . "</td>";
                        switch($bt->get_status()) {
                                default:
                                $btOutput .= "<td>" . $bt->get_status() . "</td>";
                                break;
                        }
                        $btOutput .= "<td>" . $bt->get_jobStatus() . "</td>";
                        $btOutput .= "<td>" . $bt->get_ownerName() . "</td>";
                        $btOutput .= "<td>" . $bt->get_originatingOrgName() . "</td>";
                        $btOutput .= "<td>" . $bt->get_creationDate() . "</td>";
			$btOutput .= "<td>" . $bt->get_expirationTime() . "</td>";
			$btOutput .= "<td>" . $bt->get_timeoutAction() . "</td>";
                        $btOutput .= "</tr>\n";
                }
        }
        $btOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$btOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Blocking Task Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getAdminUser() {
	if($GLOBALS['ADMIN_USER'] != "yes") { return; }

        // query admin user record
        $userRecords = queryRecord("adminUser",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#adminUser\">Admin Users</a></br>\n";
        $userOutput = "<a name=\"adminUser\"></a>\n";
        $userOutput .= "<b>Admin Users</b>\n<table border=1>\n";
        $userOutput .= "<tr><th>NAME</th><th>FULL NAME</th><th>ENABLED</th><th>LDAP USER</th><th>ORG</th><th>DEPLOYED VMS</th><th>STORED VMS</th><th>VM QUOTA</th></tr>\n";
        if(count($userRecords) != 0) {
                foreach($userRecords as $user) {
			$count++;
                        $userOutput .= "<tr>\n";
                        $userOutput .= "<td>" . $user->get_name() . "</td>";
                        $userOutput .= "<td>" . checkVar($user->get_fullName(),'str') . "</td>";
                        $userOutput .= ($user->get_isEnabled() ? "<td bgcolor=\"" . $GLOBALS['light_green'] . "\">true</td>" : "<td bgcolor=\"" . $GLOBALS['red'] . "\">false</td>");
                        $userOutput .= "<td>" . ($user->get_isLdapUser() ? "true" : "false") . "</td>";
			$userOutput .= "<td>" . (isset($GLOBALS['orgHrefToNameMapping'][$user->get_org()]) ? $GLOBALS['orgHrefToNameMapping'][$user->get_org()] : $user->get_org()) . "</td>";
                        $userOutput .= "<td>" . $user->get_numberOfDeployedVMs() . "</td>";
                        $userOutput .= "<td>" . $user->get_numberOfStoredVMs() . "</td>";
                        $userOutput .= "<td>" . $user->get_storedVMQuota() . "</td>";
                        $userOutput .= "</tr>\n";
                }
        }
        $userOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$userOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Admin User Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getUser() {
	if($GLOBALS['USER'] != "yes") { return; }

	// query user record
        $userRecords = queryRecord("user",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#user\">Users</a></br>\n";
        $userOutput = "<a name=\"user\"></a>\n";
        $userOutput .= "<b>Users</b>\n<table border=1>\n";
        $userOutput .= "<tr><th>NAME</th><th>FULL NAME</th><th>ENABLED</th><th>LDAP USER</th><th>DEPLOYED VMS</th><th>STORED VMS</th><th>VM QUOTA</th></tr>\n";
        if(count($userRecords) != 0) {
                foreach($userRecords as $user) {
			$count++;
                        $userOutput .= "<tr>\n";
                        $userOutput .= "<td>" . $user->get_name() . "</td>";
			$userOutput .= "<td>" . checkVar($user->get_fullName(),'str') . "</td>";
			$userOutput .= ($user->get_isEnabled() ? "<td bgcolor=\"" . $GLOBALS['light_green'] . "\">true</td>" : "<td bgcolor=\"" . $GLOBALS['red'] . "\">false</td>");
			$userOutput .= "<td>" . ($user->get_isLdapUser() ? "true" : "false") . "</td>";	
			$userOutput .= "<td>" . $user->get_numberOfDeployedVMs() . "</td>";
			$userOutput .= "<td>" . $user->get_numberOfStoredVMs() . "</td>";
			$userOutput .= "<td>" . $user->get_storedVMQuota() . "</td>";
                        $userOutput .= "</tr>\n";
                }
        }
        $userOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$userOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>User Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getRole() {
	if($GLOBALS['ROLE'] != "yes") { return; }

        // query role record
        $roleRecords = queryRecord("role",null,null,"a","name",null);
	
	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#role\">Roles</a></br>\n";
        $roleOutput = "<a name=\"role\"></a>\n";
        $roleOutput .= "<b>Roles</b>\n<table border=1>\n";
        $roleOutput .= "<tr><th>NAME</th><th>READONLY</th></tr>\n";
        if(count($roleRecords) != 0) {
                foreach($roleRecords as $role) {
			$count++;
                        $roleOutput .= "<tr>\n";
                        $roleOutput .= "<td>" . $role->get_name() . "</td>";
			$roleOutput .= "<td>" . ($role->get_isReadOnly() ? "true" : "false") . "</td>";
                        $roleOutput .= "</tr>\n";
                }
        }
        $roleOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$roleOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Role Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getAdminGroup() {
	if($GLOBALS['ADMIN_GROUP'] != "yes") { return; }

        // query admin group record
        $groupRecords = queryRecord("adminGroup",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#adminGroup\">Admin Groups</a></br>\n";
        $groupOutput = "<a name=\"adminGroup\"></a>\n";
        $groupOutput .= "<b>Admin Groups</b>\n<table border=1>\n";
        $groupOutput .= "<tr><th>NAME</th><th>ROLE</th><th>READONLY</th></tr>\n";
        if(count($groupRecords) != 0) {
                foreach($groupRecords as $group) {
			$count++;
                        $groupOutput .= "<tr>\n";
                        $groupOutput .= "<td>" . $group->get_name() . "</td>";
			$groupOutput .= "<td>" . $group->get_roleName() . "</td>";
                        $groupOutput .= "<td>" . ($group->get_isReadOnly() ? "true" : "false") . "</td>";
                        $groupOutput .= "</tr>\n";
                }
        }
        $groupOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$groupOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Admin Group Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getGroup() {
	if($GLOBALS['GROUP'] != "yes") { return; }

	// query group record
        $groupRecords = queryRecord("group",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#group\">Groups</a></br>\n";
        $groupOutput = "<a name=\"group\"></a>\n";
        $groupOutput .= "<b>Groups</b>\n<table border=1>\n";
        $groupOutput .= "<tr><th>NAME</th><th>ROLE</th><th>READONLY</th></tr>\n";
        if(count($groupRecords) != 0) {
                foreach($groupRecords as $group) {
			$count++;
                        $groupOutput .= "<tr>\n";
                        $groupOutput .= "<td>" . $group->get_name() . "</td>";
                        $groupOutput .= "<td>" . $group->get_roleName() . "</td>";
                        $groupOutput .= "<td>" . ($group->get_isReadOnly() ? "true" : "false") . "</td>";
                        $groupOutput .= "</tr>\n";
                }
        }
        $groupOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$groupOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Group Count:</b></td><td>" . $count . "</td></tr>\n";
}

function getStrandedUser() {
	if($GLOBALS['STRANDED_USER'] != "yes") { return; }

        // query stranded user record
        $suserRecords = queryRecord("strandedUser",null,null,"a","name",null);

	$count = 0;
	$GLOBALS['jumpTagOutput'] .= "<a href=\"#suser\">Stranded Users</a></br>\n";
        $suserOutput = "<a name=\"suser\"></a>\n";
        $suserOutput .= "<b>Stranded Users</b>\n<table border=1>\n";
        $suserOutput .= "<tr><th>NAME</th><th>FULL NAME</th><th>SYNCED</th><th>DEPLOYED VMS</th><th>STORED VMS</th></tr>\n";
        if(count($suserRecords) != 0) {
                foreach($suserRecords as $suser) {
			$count++;
                        $suserOutput .= "<tr>\n";
                        $suserOutput .= "<td>" . $suser->get_name() . "</td>";
                        $suserOutput .= "<td>" . checkVar($suser->get_fullName(),'str') . "</td>";
                        $suserOutput .= "<td>" . ($suser->get_isInSync() ? "true" : "false") . "</td>";
                        $suserOutput .= "<td>" . $suser->get_numberOfDeployedVMs() . "</td>";
                        $suserOutput .= "<td>" . $suser->get_numberOfStoredVMs() . "</td>";
                        $suserOutput .= "</tr>\n";
                }
        }
        $suserOutput .= "</table></br>\n";
        $f = fopen($GLOBALS['report'],"a");
        fwrite($f,$suserOutput);
        fclose($f);

	$GLOBALS['summaryHeaderOutput'] .= "<tr><td><b>Stranded User Count:</b></td><td>" . $count . "</td></tr>\n";
}

function queryRecord($type,$filter,$field,$sortType,$sortField,$pgSize) {
	$queryParams = new VMware_VCloud_SDK_Query_Params();

	if(isset($filter)) {
		$queryParams->setFilter($filter);
	}
	if(isset($field)) {
                $queryParams->setFields($field);
	}
	if(isset($sortType)) {
		if(isset($sortField) && $sortType == "a") {
			$queryParams->setSortAsc($sortField);
		} else {
			$queryParams->setSortDesc($sortField);
		}
	}
	if(isset($pgSize)) {
                $queryParams->setPageSize($pgSize);
	} else {
        	$queryParams->setPageSize(128);		
	}

	// look for record types only
	$queryFormat = "Records";
	$qr = "query$queryFormat";

        $recObj = $GLOBALS['sdkQuery']->$qr($type, $queryParams);
        $records = $recObj->getRecord();
	return $records;
}

function checkVar($in,$type) {
        if( (!isset($in) || $in == "" || $in == " " || $in == null) && $type == "str") {
                return "</br>";
        } elseif(!isset($in) && $type == "int") {
                return null;
        } else {
                return $in;
        }
}

function buildHtmlHeader($rT,$sN) {
	$headerTitle = $GLOBALS['reportTitle'] . " (" . $sN . ") " . date("c");

	// build html header
	$htmlHeader = "<html>\n<head>\n<meta name=\"author\" content=\"William Lam\"/>\n<title>" . $headerTitle . "</title>\n<body>\n";
	$htmlHeader .= <<< _HTML_HEADER_
<style type="text/css">
<!--
body {
	background: #333333;
	margin: 0;
	padding: 0;
	font: 10px normal Verdana, Arial, Helvetica, sans-serif;
	color: #444;
}
a:link { color: blue; }
a:visited { color: blue; }
a:hover { color: blue; }
a:active { color: blue; }
.author a:link { color: white; }
.author a:visited { color: white; }
.author a:hover { color: blue; }
.author a:active { color: white; }
th { font-weight:white; background-color:#CCCCCC; }
h1 {
	font-size: 3em; 
	margin: 20px 0;
	color: white;
}
div.tabcontainer {
	width: 95%;
	height: 100%;
	margin: 10px auto;
}
ul.tabnav {
	list-style-type: none;
	margin: 0;
	padding: 0;
	width: 100%;
	overflow: hidden;
	border-top: none;
	clear: both;
	float: left; 
	width: 100%;
	-moz-border-radius-bottomright: 5px;
	-khtml-border-radius-bottomright: 5px;
	-webkit-border-bottom-right-radius: 5px;
	-moz-border-radius-bottomleft: 5px;
	-khtml-border-radius-bottomleft: 5px;
	-webkit-border-bottom-left-radius: 5px;
}

ul.tabnav li {
	float: left;
	margin: 0;
	padding: 0;
	height: 31px;
	line-height: 31px;
	border: 1px solid #999;
	border-left: none;
	margin-bottom: -1px;
	overflow: hidden;
	position: relative;
	background: #ccc;
	font-weight: bold; 
}
ul.tabnav li a {
	text-decoration: none;
	color: #000;
	display: block;
	font-size: 1.2em;
	padding: 0 20px;
	border: 1px solid #fff;
	outline: none;
}

ul.tabnav a:hover {
	background: #3E86BE;
}

div.tabcontents {
	background: #fff;
	border-top: 1px solid #011;
	padding: 20px;
	padding-bottom:30px;
}

div.tabcontents {
	float: left;
	padding: 20px;
	font-size: 1.2em;
}

div.content {
	float: left;
	overflow: -moz-scrollbars-vertical;
	overflow: auto; 
	padding: 5px;
	font: 20px normal Verdana, Arial, Helvetica, sans-serif;
}

div.tabcontents div.content h2 {
	margin-top: 3px;
	font-weight: normal;
	padding-bottom: 10px;
	border-bottom: 1px dashed #ddd;
	font-size: 1.8em;
}
div.jumptag {
	font-size: medium;
}
.author {
	font-weight: bold;
	font-size: small;
	clear: both;
	display: block;
	padding: 10px 0;
	text-align:center;
	color:white;
}
//-->
</style>
</head>
<div class="tabcontainer">
<h1>$headerTitle</h1>
<div class="tabcontents">
<div class="content">

<!-- JUMP_TAG -->

<!-- SUMMARY_HEADER -->

_HTML_HEADER_;
	$f = fopen($GLOBALS['report'],"w");
	fwrite($f,$htmlHeader);
	fclose($f);
	
// ugly, need to fix or put somewhere else to make it look pretty
$GLOBALS['summaryHeaderOutput'] = "<a name=\"summary\"></a>\n<b>Summary</b>\n<table border=1>\n<tr><th>ENTITY</th><th>COUNT</th><th>DETAILS</th></tr>\n";
if($GLOBALS['SUMMARY'] == "yes") {
	$GLOBALS['jumpTagOutput'] = "<div class=\"jumptag\"><a href=\"#summary\">Summary</a></br>\n";
} else {
	$GLOBALS['jumpTagOutput'] = "<div class=\"jumptag\">";
}

// global VM Network string needed
$GLOBALS['vmNetworkOutput'] = "<a name=\"vmNetwork\"></a>\n<b>VM Networks</b>\n<table border=1><tr><th>NAME</th><th>vAPP</th><th>DETAILS</th></tr>\n";
}
	
function buildHtmlFooter() {
	// build html footer
	$htmlFooter = <<< _HTML_FOOTER_
</div>
</div>
<div class="author"><span class="author"Author: <b><a href="http://www.linkedin.com/in/lamwilliam">William Lam</a></b><br/>
<a href="http://www.virtuallyghetto.com">http://www.virtuallyghetto.com</a><br/>
Generated using: <b><a href="http://www.virtuallyghetto.com/2012/01/vcloud-director-report-100.html">vmwarevCloudReport.php</a></b><br/>
Support us by donating <b><a href="http://www.virtuallyghetto.com/p/how-you-can-help.html">here</a></b><br/>
Primp Industries&#0153;
</span>
</div>
_HTML_FOOTER_;
	$htmlFooter .= "</body></html>\n";
	$f = fopen($GLOBALS['report'],"a");
	fwrite($f,$htmlFooter);
	fclose($f);
}

/**
 * Print the help message of the sample.
 */
function usage()
{
    echo "Usage:\n\n";
    echo "  [Script]\n";
    echo "     " . $GLOBALS['reportTitle'] . "\n\n";
    echo "  [Description]\n";
    echo "     This script provides a detail report of your VMware vCloud Director system\n";
    echo "\n";
    echo "  [Usage]\n";
    echo "     # php vCloudReport.php -s <server> -u <username> -p <password> [Options]\n";
    echo "\n";
    echo "     -s|--server <IP|hostname> [req] IP or hostname of the vCloud Director.\n";
    echo "     -u|--user <username>      [req] User name in the form user@organization for the vCloud Director instance.\n";
    echo "     -p|--pswd <password>      [req] Password for user.\n";
    echo "     -t|--type <type>          [req] Type of report [system|orgadmin|orguser].\n";
    echo "\n";
    echo "  [Options]\n";
    echo "     -r|--report <reportName>      [opt*] Name of html output file (e.g. vCloudReport.html).\n";
    echo "\n";
    echo "  [Examples]\n";
    echo "     # php query.php -s 127.0.0.1 -u admin@system -p password -t system\n";
    echo "     # php query.php -s 127.0.0.1 -u admin@coke   -p password -t orgadmin\n";
    echo "     # php query.php -s 127.0.0.1 -u admin@pepsi  -p password -t orguser\n";
    echo "\n";
}

/**
 * Burrowed from http://www.sitepoint.com/interactive-cli-password-prompt-in-php/
 * Interactively prompts for input without echoing to the terminal.
 * Requires a bash shell or Windows and won't work with
 * safe_mode settings (Uses `shell_exec`)
 */
function prompt_silent($prompt = "Enter Password:") {
  if (preg_match('/^win/i', PHP_OS)) {
    $vbscript = sys_get_temp_dir() . 'prompt_password.vbs';
    file_put_contents(
      $vbscript, 'wscript.echo(InputBox("'
      . addslashes($prompt)
      . '", "", "password here"))');
    $command = "cscript //nologo " . escapeshellarg($vbscript);
    $password = rtrim(shell_exec($command));
    unlink($vbscript);
    return $password;
  } else {
    $command = "/usr/bin/env bash -c 'echo OK'";
    if (rtrim(shell_exec($command)) !== 'OK') {
      trigger_error("Can't invoke bash");
      return;
    }
    $command = "/usr/bin/env bash -c 'read -s -p \""
      . addslashes($prompt)
      . "\" mypassword && echo \$mypassword'";
    $password = rtrim(shell_exec($command));
    echo "\n";
    return $password;
  }
}

/**
burrowed from http://codeaid.net/php/convert-size-in-bytes-to-a-human-readable-format-%28php%29
*/
function bytesToSize($bytes, $precision = 2)
{  
    $kilobyte = 1024;
    $megabyte = $kilobyte * 1024;
    $gigabyte = $megabyte * 1024;
    $terabyte = $gigabyte * 1024;
   
    if (($bytes >= 0) && ($bytes < $kilobyte)) {
        return $bytes . ' B';
 
    } elseif (($bytes >= $kilobyte) && ($bytes < $megabyte)) {
        return round($bytes / $kilobyte, $precision) . ' KB';
 
    } elseif (($bytes >= $megabyte) && ($bytes < $gigabyte)) {
        return round($bytes / $megabyte, $precision) . ' MB';
 
    } elseif (($bytes >= $gigabyte) && ($bytes < $terabyte)) {
        return round($bytes / $gigabyte, $precision) . ' GB';
 
    } elseif ($bytes >= $terabyte) {
        return round($bytes / $terabyte, $precision) . ' TB';
    } else {
        return $bytes . ' B';
    }
}
?>
