#!/usr/bin/perl
# William Lam
# www.virtuallyghetto.com
# Script to extract data from VIN (vSphere Infrastructure Navigator)

use strict;
use JSON;
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;

# command line args
if($#ARGV != 1) {
        print "\n\tUsage: $0 [VIN_HOST] [VM_NAME]\n\n";
        exit 1;
}

# global vars
my $vin_host = $ARGV[0];
my $vmname = $ARGV[1];
my ($jmx,$request,$response,$vm,$ret);

# connect to VIN jmx
$jmx = new JMX::Jmx4Perl(url => "http://$vin_host:8080/jolokia");

# query vCenter Server that VIN is connected to
$request = new JMX::Jmx4Perl::Request({type => READ,
                                            mbean => "com.vmware.vadm:name=inceptionConfigurationMBean,type=ConfigurationMBean",
                                            attribute => "vc.credentials.host"});
$response = $jmx->request($request);

print "\nVIN is connected to vCenter Server: " . $response->value() . "\n";

# query the VM given using getVmByName() given by the user
$vm = $jmx->execute("com.vmware.vadm:name=vcInventory,type=VcConnector","getVmByName",$vmname);

if(!defined($vm)) {
        print "Unable to locate VM: " . $vmname . "\n\n";
        exit 1;
}

# VM info
print "\nVM Hostname: " . $vm->{'vm_hostname'} . "\n";
print "IP Addresses: " . $vm->{'vm_all_ips'} . "\n";
print "Power State: " . $vm->{'vm_power_state'} . "\n";
print "OS: " . $vm->{'vm_os_name'} . "\n";
print "MoRef ID: " . $vm->{'vm_moid'} . "\n";

# input to other methods require JSON format for VM's moref
my %moref = ("moid" => $vm->{'vm_moid'});
my $moref_array = [ {"moid" => $vm->{'vm_moid'}} ];

print "\nApplications\n\n";

# query applications running on VM using findApplicationComponentsByInfrastructureElementBusinessKeys() & moref input
$ret = $jmx->execute("com.vmware.vadm:name=ApplicationService,type=ApplicationService","findApplicationComponentsByInfrastructureElementBusinessKeys",to_json($moref_array));

# loop through each application
foreach(@$ret) {
        if(defined($_->{'parentBusinessKey'})) {
                if($_->{'parentBusinessKey'} eq $vm->{'vm_moid'}) {
                        if(defined($_->{'servicePort'})) {
                                print "Product Name: " . $_->{'productName'} . "\n";
                                print "Category: " . $_->{'category'} . "\n";
                                print "Vendor: " . $_->{'vendor'} . "\n";
                                print "Version: " . $_->{'version'} . "\n";
                                print "Process Name: " . $_->{'processName'} . "\n";
                                print "Install Path: " . $_->{'installPath'} . "\n";
                                print "Ports: " . join(',',@{$_->{'servicePort'}}) . "\n\n";
                        }
                }
        }
}

print "Dependencies\n\n";

# query outgoing dependencies using of VM using findOutgoingDependentInfrastructureElements() & moref input
$ret = $jmx->execute("com.vmware.vadm:name=ApplicationService,type=ApplicationService","findOutgoingDependentInfrastructureElements",to_json(\%moref),to_json($moref_array));

# loop through each dependency
foreach(@$ret) {
        my $vmObj = getVmByMoid($_->{'businessKey'});
        if($vmObj ne "N/A") {
                print "VM: " . $vmObj->{'vm_name'} . "\t Hostname: " . $vmObj->{'vm_hostname'} . "\t MoRef: " . $vmObj->{'vm_moid'} . "\n";
        }
}
print "\n";

# helper method to query VM based on moref using getVmByMoid()
sub getVmByMoid {
        my ($moref) = @_;

        my $name = $jmx->execute("com.vmware.vadm:name=vcInventory,type=VcConnector","getVmByMoid",$moref);
        if(!defined($name)) {
                $name = "N/A";
        }
        return $name;
}

