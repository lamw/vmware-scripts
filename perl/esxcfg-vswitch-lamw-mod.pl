#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-11800

# USAGE:
#
# vicfg-vswitch.pl [GENERAL_VIPERL_OPTIONS] [ADDITIONAL_OPTIONS]
# where acceptable ADDITIONAL_OPTIONS are the following:
#
# --list                              list vswitches and port groups
# --add <vswitch>                     add vswitch name
# --delete <vswitch>                  delete vswitch
# --link pnic <vswitch>               Sets a pnic as an uplink for the switch
# --unlink pnic <vswitch>             Removes a pnic from the uplinks for the switch
# --check <vswitch>                   check if vswitch exists (return 0 if no; 1 if yes)
# --add-pg <pgname> <vswitch>         adds port group
# --del-pg <pgname> <vswitch>         deletes port group
# --add-pg-uplink pnic --pg <pgname>  add an uplink for portgroup
# --del-pg-uplink pnic --pg <pgname>  delete an uplink for portgroup
# --mtu num <vswitch>                 sets the mtu of the vswitch
# --vlan <#> --pg <pgname> <vswitch>  Updates vlan id for port group
# --check-pg --pg <pgname>            check if port group exists (return 0 if no; 1 if yes)
# --check-pg --pg <pgname> <vswitch>  check if port group exists on a particular vswitch 
# --port <#_of_ports> <vswitch>       update the number of ports for particular vswitch
# 
# Example:
#
# vicfg-vswitch.pl --add-pg foo vSwitch0
# vicfg-vswitch.pl --mtu 9000 vSwitch0
#

use POSIX qw(ceil floor);

my @options = (
    ['list'],                               # esxcfg-vswitch --list
    ['add'],                                # esxcfg-vswitch --add vswitch
    ['delete'],                             # esxcfg-vswitch --delete vswitch
    ['link', '_default_'],                  # esxcfg-vswitch --link pnic vswitch
    ['unlink', '_default_'],                # esxcfg-vswitch --unlink pnic vswitch
    ['check'],                              # esxcfg-vswitch --check vswitch    
    ['add-pg', '_default_'],                # esxcfg-vswitch --add-pg pgname vswitch
    ['del-pg', '_default_'],                # esxcfg-vswitch --del-pg pgname vswitch
    ['add-pg-uplink', 'pg', '_default_'],   # esxcfg-vswitch --add-pg-uplink pnic pgname vswitch
    ['del-pg-uplink', 'pg', '_default_'],   # esxcfg-vswitch --del-pg-uplink pnic pgname vswitch
    ['add-dvp-uplink', 'dvp', '_default_'], # esxcfg-vswitch --add-dvp-uplink pnic dvp dvsname
    ['del-dvp-uplink', 'dvp', '_default_'], # esxcfg-vswitch --del-dvp-uplink pnic dvp dvsname    
    ['vlan', 'pg', '_default_'],            # esxcfg-vswitch --vlan n --pg name vswitch
    ['check-pg', '_default_'],              # esxcfg-vswitch --check-pg pgname vswitch 
    ['mtu', '_default_'],                   # esxcfg-vswitch --mtu num vswitch
    ['get-cdp'],                            # esxcfg-vswitch --get-cdp vswitch
    ['set-cdp', '_default_'],               # esxcfg-vswitch --set-cdp value vswitch
    ['check-pg'],                           # esxcfg-vswitch --check-pg pgname        
    ['port'],				    # esxcfg-vswitch --port vswitch
    ['promiscous', '_default_'],            # esxcfg-vswitch --promiscous vswitch
    ['forged', '_default_'],                # esxcfg-vswitch --forged vswitch
    ['mac', '_default_'],                   # esxcfg-vswitch --mac vswitch
    ['trafficshape', '_default_'],          # esxcfg-vswitch --trafficshape vswitch
    ['avgband', '_default_'],               # esxcfg-vswitch --avgband vswitch
    ['peakband', '_default_'],              # esxcfg-vswitch --peakband vswitch
    ['burstsize', '_default_'],             # esxcfg-vswitch --burstsize vswitch
    ['loadbalance', '_default_'],           # esxcfg-vswitch --loadbalance vswitch
    ['faildetect', '_default_'],            # esxcfg-vswitch --faildetect vswitch
    ['notifysw', '_default_'],              # esxcfg-vswitch --notifysw vswitch
    ['failback', '_default_'],              # esxcfg-vswitch --failback vswitch
    ['nic-active', '_default_'],            # esxcfg-vswitch --nic-active vswitch
    ['nic-standby', '_default_'],           # esxcfg-vswitch --nic-standby vswitch
);

use strict;
use warnings;
use Getopt::Long;

use VMware::VIRuntime;
use VMware::VILib;
use VMware::VIExt;

my %opts = (
   vihost => {
      alias => "h",
      type => "=s",
      help => qq!    The host to use when connecting via Virtual Center!,
      required => 0,
   },
   'list' => {
      alias => "l",
      type => "",
      help => qq!    List vswitches and port groups!,
      required => 0,
   },
   'add' => {
      alias => "a",
      type => "=s",
      help => qq!    Add a new virtual switch!,
      required => 0,
   },
   'delete' => {
      alias => "d",
      type => "=s",
      help => qq!    Delete the virtual switch!,
      required => 0,
   },
   'link' => {
      alias => "L",
      type => "=s",
      help => qq!    Sets a pnic as an uplink for the virtual switch!,
      required => 0,
   },
   'unlink' => {
      alias => "U",
      type => "=s",
      help => qq!    Removes a pnic from the uplinks for the virtual switch!,
      required => 0,
   },
   'check' => {
      alias => "c",
      type => "=s",
      help => qq!    Check to see if virtual switch exists!,
      required => 0,
   },
   'add-pg' => {
      alias => "A",
      type => "=s",
      help => qq!    Add a portgroup to a virtual switch!,
      required => 0,
   },
   'del-pg' => {
      alias => "D",
      type => "=s",
      help => qq!    Delete the portgroup from the virtual switch!,
      required => 0,
   },
   'add-pg-uplink' => {
      alias => "M",
      type => "=s",
      help => qq!    Add an uplink adapter (pnic) to a portgroup (valid for vSphere 4.0 and later)!,
      required => 0,
   },
   'del-pg-uplink' => {
      alias => "N",
      type => "=s",
      help => qq!    Delete an uplink adapter from a portgroup (valid for vSphere 4.0 and later)!,
      required => 0,
   },   
   'add-dvp-uplink' => {
      alias => "P",
      type => "=s",
      help => qq!    Add an uplink adapter (pnic) to a DVPort (valid for vSphere 4.0 and later)!,
      required => 0,
   },
   'del-dvp-uplink' => {
      alias => "Q",
      type => "=s",
      help => qq!    Delete an uplink adapter from a DVPort (valid for vSphere 4.0 and later)!,
      required => 0,
   },      
   'vlan' => {
      alias => "v",
      type => "=s",
      help => qq!    Set vlan id for portgroup specified by -p!,
      required => 0,
   },
   'check-pg' => {
      alias => "C",
      type => "=s",
      help => qq!    Check to see if a portgroup exists!,
      required => 0,
   },
   'mtu' => {
      alias => "m",
      type => "=i",
      help => qq!    Set MTU for the virtual switch!,
      required => 0,
   },
   'get-cdp' => {
      alias => "b",
      type => "=s",
      help => qq!    Print the current CDP setting for this virtual switch (valid for vSphere 4.0 and later)!,
      required => 0,
   },
   'set-cdp' => {
      alias => "B",
      type => "=s",
      help => qq!    Set the CDP status for a given virtual switch (valid for vSphere 4.0 and later).  
          To set pass "down", "listen", "advertise", or "both"!,
      required => 0,
   },   
   'pg' => {
      alias => "p",
      type => "=s",
      help => qq!    The name of the portgroup!,
      required => 0,
   },
   'dvp' => {
      alias => "V",
      type => "=s",
      help => qq!    The name of the DVPort (valid for vSphere 4.0 and later)!,
      required => 0,
   },         
   '_default_' => {
      type => "=s",
      argval => "vswitch",
      help => qq!    The name of the vswitch!,
      required => 0,
   },
   'port' => {
      type => "=s",
      argval => "vswitch",
      help => qq!    The number of ports to vSwitch [8|24|56|120|248|504|1016|2040|4088]!,
      required => 0,
   },
   'promiscuous' => {
      type => "=s",
      argval => "vswitch",
      help => qq!    Enable or disable promiscous mode [accept|reject]!,
      required => 0,
   },
   'mac' => {
      type => "=s",
      argval => "vswitch",
      help => qq!    Enable or disable promiscous mode [accept|reject]!,
      required => 0,
   },
   'forged' => {
      type => "=s",
      argval => "vswitch",
      help => qq!    Enable or disable promiscous mode [accept|reject]!,
      required => 0,
   },
   'trafficshape' => {
      type => "=s",
      argval => "vswitch",
      help => qq!    Enable or or disable promiscous mode [true|false]!,
      required => 0,
   },
   'avgband' => {
      type => "=s",
      argval => "vswitch",
      help => qq!    Average Bandwidth (Kbits/sec)!,
      required => 0,
   },
   'peakband' => {
      type => "=s",
      argval => "vswitch",
      help => qq!    Peak Bandwidth (Kbits/sec!,
      required => 0,
   },
   'burstsize' => {
      type => "=s",
      argval => "vswitch",
      help => qq!    Burst Size (Kbytes)!,
      required => 0,
   },
   'loadbalance' => {
      type => "=s",
      argval => "vswitch",
      help => qq!    Load Balancing policy [PORTID|IPHASH|MACHASH|FAILOVER]!,
      required => 0,
   },
   'faildetect' => {
      type => "=s",
      argval => "vswitch",
      help => qq!    Network Failover Detection [LINK|BEACON]!,
      required => 0,
   },
   'notifysw' => {
      type => "=s",
      argval => "vswitch",
      help => qq!    Notify Switches [yes|no]!,
      required => 0,
   },
   'failback' => {
      type => "=s",
      argval => "vswitch",
      help => qq!    Failback [yes|no]!,
      required => 0,
   },
   'nic-active' => {
      type => "=s",
      argval => "vswitch",
      help => qq!    List of linked vmnics to be set as active network adapters used for load balancing!,
      required => 0,
   },
   'nic-standby' => {
      type => "=s",
      argval => "vswitch",
      help => qq!    List of linked vmnics to be set as standby network adapters used for failover!,
      required => 0,
   }, 
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();

my $login = 0;

CheckValues();
Util::connect();

$login = 1;
my $exitStatus = 1;                     # assume success

my $host_view = VIExt::get_host_view(1);
Opts::assert_usage(defined($host_view), "Invalid host.");

#
# find the host
#

my $network_system = Vim::get_view (mo_ref => $host_view->configManager->networkSystem);

   #
   # cycle through various operations
   #
   if (defined OptVal('list')) {
      ListVirtualSwitch ($network_system);
   }
   elsif (defined OptVal('add')) {
      eval {
	if(defined OptVal('port')) {
		my $vswitchSpec = HostVirtualSwitchSpec->new(numPorts => OptVal('port'));
		$network_system->AddVirtualSwitch ('vswitchName' => OptVal('add'), 'spec' => $vswitchSpec);
	} else {
		$network_system->AddVirtualSwitch ('vswitchName' => OptVal('add'));
	}
      };
      if ($@) {
         VIExt::fail($@->fault_string);
      }
   }
   elsif (defined OptVal('delete')) {
      eval { $network_system->RemoveVirtualSwitch ('vswitchName' => OptVal('delete')); };
      if ($@) {
         VIExt::fail($@->fault_string);
      }
   }
   elsif (defined OptVal('link')) {
      UpdateUplinks ($network_system, OptVal('_default_'), OptVal('link'), 1);
   }
   elsif (defined OptVal('unlink')) {
      UpdateUplinks ($network_system, OptVal('_default_'), OptVal('unlink'), 0);
   }
   elsif (defined OptVal('vlan')) {
      UpdatePortGroupVlan ($network_system, OptVal('_default_'), OptVal('pg'), OptVal('vlan'));
   }
   elsif (defined OptVal('add-pg-uplink')) {
      UpdatePortGroupAddUplink ($network_system, OptVal('_default_'), OptVal('pg'), OptVal('add-pg-uplink'));
   }
   elsif (defined OptVal('del-pg-uplink')) {
      UpdatePortGroupDelUplink ($network_system, OptVal('_default_'), OptVal('pg'), OptVal('del-pg-uplink'));
   } 
   elsif (defined OptVal('add-dvp-uplink')) {
      UpdateDVPAddUplink ($network_system, OptVal('_default_'), OptVal('add-dvp-uplink'), OptVal('dvp'));
   }
   elsif (defined OptVal('del-dvp-uplink')) {
      UpdateDVPDelUplink ($network_system, OptVal('_default_'), OptVal('del-dvp-uplink'), OptVal('dvp'));
   }
   elsif (defined OptVal('check')) {
      $exitStatus = (defined FindVSwitchbyName ($network_system, OptVal('check'))) ? 1 : 0; 
      print "$exitStatus\n";
   }
   elsif (defined OptVal('add-pg')) {
      AddPortGroup ($network_system, OptVal('add-pg'), OptVal('_default_'), OptVal('vlan'));
   }
   elsif (defined OptVal('del-pg')) {
      RemovePortGroup ($network_system, OptVal('del-pg'));
   }
   elsif (defined OptVal('check-pg')) {
      $exitStatus = (defined FindPortGroupbyName ($network_system, OptVal('_default_'), 
                                                  OptVal('check-pg'))) ? 1 : 0;
      print "$exitStatus\n";
   }
   elsif (defined OptVal('mtu')) {
      UpdateMTU ($network_system, OptVal('_default_'), OptVal('mtu'));
   }
   elsif (defined OptVal('get-cdp')) {
      GetCDP ($network_system, OptVal('get-cdp'));      
   }
   elsif (defined OptVal('set-cdp')) {
      SetCDP ($network_system, OptVal('_default_'), OptVal('set-cdp'));      
   }
   if(defined OptVal('promiscuous') || defined OptVal('mac') || defined OptVal('forged')) {
      UpdateSecurity($network_system, OptVal('_default_'));
   }
   if(defined OptVal('trafficshape') || defined OptVal('avgband') || defined OptVal('peakband') || defined OptVal('burstsize')) {
      UpdateTrafficShapping($network_system, OptVal('_default_'));
   }
   if(defined OptVal('loadbalance') || defined OptVal('faildetect') || defined OptVal('notifysw') || defined OptVal('failback')) {
      UpdateNICTeaming($network_system, OptVal('_default_'));
   }
   if(defined OptVal('nic-active') || defined OptVal('nic-standby')) {
      UpdateNicOrder($network_system, OptVal('_default_'));
   }

Util::disconnect();

sub UpdateNicOrder {
        my ($network, $vswitchName) = @_;;
        my $vs = FindVSwitchbyName($network, $vswitchName);
	my $nicDevice = undef;
	my $bridge = $vs->spec->bridge;
	if($bridge->isa('HostVirtualSwitchBondBridge') || $bridge->isa('HostVirtualSwitchSimpleBridge')) {
		$nicDevice = $bridge->nicDevice;
	}
	
	my $currentActive = $vs->{spec}->{policy}->{nicTeaming}->{nicOrder}->{activeNic};
	my $currentStandby = $vs->{spec}->{policy}->{nicTeaming}->{nicOrder}->{standbyNic};

	my @vmnics = ();
        if ($vs && $nicDevice) {
		if(defined OptVal('nic-active')) {
			@vmnics = split(',',OptVal('nic-active'));
			foreach my $vmnic (@$nicDevice) {
				if(grep( /^$vmnic/,@vmnics) && !grep( /^$vmnic/,@$currentActive)) {
					push (@{$vs->{spec}->{policy}->{nicTeaming}->{nicOrder}->{activeNic}},$vmnic);
					@{$vs->{spec}->{policy}->{nicTeaming}->{nicOrder}->{standbyNic}} = grep {$_ ne $vmnic} @{$vs->{spec}->{policy}->{nicTeaming}->{nicOrder}->{standbyNic}};
				}
			}
		}
		if(defined OptVal('nic-standby')) {
			@vmnics = split(',',OptVal('nic-standby'));
			foreach my $vmnic (@$nicDevice) {
                                if(grep( /^$vmnic/,@vmnics) && !grep( /^$vmnic/,@$currentStandby)) {
					push (@{$vs->{spec}->{policy}->{nicTeaming}->{nicOrder}->{standbyNic}},$vmnic);
					@{$vs->{spec}->{policy}->{nicTeaming}->{nicOrder}->{activeNic}} = grep {$_ ne $vmnic} @{$vs->{spec}->{policy}->{nicTeaming}->{nicOrder}->{activeNic}};
                                }
                        }
                }
		eval {
                        $network->UpdateVirtualSwitch(vswitchName => $vswitchName, spec => $vs->spec);
                };
                if ($@) {
                        VIExt::fail($@->fault_string);
                }
        } else {
                print "No such virtual switch : $vswitchName\n";
        }
}

sub UpdateNICTeaming {
        my ($network, $vswitchName) = @_;;
        my $vs = FindVSwitchbyName($network, $vswitchName);
        if ($vs) {
                if(defined OptVal('loadbalance')) {
                        $vs->{spec}->{policy}->{nicTeaming}->{policy} = &convertPolicy(OptVal('loadbalance'));
                }
                if(defined OptVal('faildetect')) {
                        $vs->{spec}->{policy}->{nicTeaming}->{failureCriteria}->{checkBeacon} = &convertBeacon(OptVal('faildetect'));
                }
                if( defined OptVal('notifysw')) {
                        $vs->{spec}->{policy}->{nicTeaming}->{notifySwitches} = &convertString(OptVal('notifysw'));
                }
		if( defined OptVal('failback')) {
                        $vs->{spec}->{policy}->{nicTeaming}->{rollingOrder} = !&convertString(OptVal('failback'));
                }

                eval {
                        $network->UpdateVirtualSwitch(vswitchName => $vswitchName, spec => $vs->spec);
                };
                if ($@) {
                        VIExt::fail($@->fault_string);
                }
        } else {
                print "No such virtual switch : $vswitchName\n";
        }
}

sub UpdateSecurity {
	my ($network, $vswitchName) = @_;;
   	my $vs = FindVSwitchbyName($network, $vswitchName);
   	if ($vs) {
		if(defined OptVal('promiscuous')) {
			$vs->{spec}->{policy}->{security}->{allowPromiscuous} = &convertString(OptVal('promiscuous'));
		}	
		if(defined OptVal('forged')) {
			$vs->{spec}->{policy}->{security}->{forgedTransmits} = &convertString(OptVal('forged'));
		}	
		if( defined OptVal('mac')) {
			$vs->{spec}->{policy}->{security}->{macChanges} = &convertString(OptVal('mac'));
		}
	
      		eval {
         		$network->UpdateVirtualSwitch(vswitchName => $vswitchName, spec => $vs->spec);
      		};
      		if ($@) {
         		VIExt::fail($@->fault_string);
      		}
   	} else {
      		print "No such virtual switch : $vswitchName\n";
   	}
}

sub UpdateTrafficShapping {
        my ($network, $vswitchName) = @_;;
        my $vs = FindVSwitchbyName($network, $vswitchName);
	my $shappingTurnOn = 0;
        if ($vs) {
		if(defined OptVal('trafficshape')) {
			$shappingTurnOn = 1;
			$vs->{spec}->{policy}->{shapingPolicy}->{enabled} = OptVal('trafficshape');
			$vs->{spec}->{policy}->{shapingPolicy}->{averageBandwidth} = 100000;
			$vs->{spec}->{policy}->{shapingPolicy}->{peakBandwidth} = 100000;
			$vs->{spec}->{policy}->{shapingPolicy}->{burstSize} = 102400;
		}

		if($vs->{spec}->{policy}->{shapingPolicy}->{enabled} || $shappingTurnOn eq 1) {
	                if(defined OptVal('avgband')) {
        	                $vs->{spec}->{policy}->{shapingPolicy}->{averageBandwidth} = &convertLong(OptVal('avgband'));
                	}
	                if(defined OptVal('peakband')) {
        	                $vs->{spec}->{policy}->{shapingPolicy}->{peakBandwidth} = &convertLong(OptVal('peakband'));
                	}
	                if( defined OptVal('burstsize')) {
        	                $vs->{spec}->{policy}->{shapingPolicy}->{burstSize} = &convertLong(OptVal('burstsize'));
                	}
		}
                eval {
                        $network->UpdateVirtualSwitch(vswitchName => $vswitchName, spec => $vs->spec);
                };
                if ($@) {
                        VIExt::fail($@->fault_string);
                }
        } else {
                print "No such virtual switch : $vswitchName\n";
        }
}

sub convertBeacon {
	my ($string) = @_;

	#LINK|BEACON

	if($string =~ m/BEACON/) {
		return 1;
	} else {
		return 0;
	}
}
 
sub convertPolicy {
	my ($string) = @_;

	#PORTID|IPHASH|MACHASH|FAILOVER

	if($string =~ m/PORTID/) {
		return "loadbalance_srcid";
	}elsif($string =~ m/IPHASH/) {
		return "loadbalance_ip";
	}elsif($string =~ m/MACHASH/) {
		return "loadbalance_srcmac";
	}elsif($string =~ m/FAILOVER/) {
		return "failover_explicit";
	}else {
		return "loadbalance_srcid";
	}
}

sub convertLong {
	my ($string) = @_;

	return ceil($string * 1000);
}

sub convertString {
	my ($string) = @_;

	if($string =~ m/accept/ || $string =~ m/yes/) {
		return 1;
	} else {
		return 0;
	}
}

sub OptVal {
  my $opt = shift;
  return Opts::get_option($opt);
}

# Retrieve the set of non viperl-common options for further validation
sub GetSuppliedOptions {
  my @optsToCheck = 
     qw(list add check delete link unlink add-pg del-pg add-pg-uplink del-pg-uplink check-pg vlan pg mtu add-dvp-uplink del-dvp-uplink get-cdp set-cdp dvp _default_);
  my %supplied = ();

  foreach (@optsToCheck) {
     if (defined(Opts::get_option($_))) {
        $supplied{$_} = 1;
     }
  }

  return %supplied;
}

use Data::Dumper;

sub getPnicName {
   my ($network_system, $pNics) = @_;
   
   my $pNicName = "";            
   my $pNicKey = "";
   foreach (@$pNics) {
      $pNicKey = $_; 

      if ($pNicKey ne "") {
         $pNics = $network_system->networkInfo->pnic;
         foreach my $pNic (@$pNics) {
            if ($pNic->key eq $pNicKey) {
               $pNicName = $pNicName ? ("$pNicName," . $pNic->device) : $pNic->device;
            }
         }
      }
   }
   return $pNicName;
}

sub ListVirtualSwitch {
   my ($network_system) = @_;
   my $vSwitches = $network_system->networkInfo->vswitch;
   my $pSwitches = undef;
   
   # eval to support pre-K/L version
   eval {
      $pSwitches = $network_system->networkInfo->proxySwitch;
   };
   
   foreach my $vSwitch (@$vSwitches) {
      my $mtu = "";
      my $pNicName = getPnicName($network_system, $vSwitch->pnic);
      my $sNicName = $pNicName;
      
      $mtu = $vSwitch->{mtu} if defined($vSwitch->{mtu});
 
      print "Switch Name     Num Ports       Used Ports      Configured Ports    MTU     Uplinks\n";

      printf("%-16s%-16s%-16s%-20s%-8s%-16s\n\n", 
             $vSwitch->name, 
             $vSwitch->numPorts, 
             $vSwitch->numPorts - $vSwitch->numPortsAvailable,
             $vSwitch->numPorts,
             $mtu, 
             $pNicName);
             
      my $portGroups = $vSwitch->portgroup;
      print "   PortGroup Name                VLAN ID   Used Ports      Uplinks\n";
      foreach my $port (@$portGroups) {         
         my $pg = FindPortGroupbyKey ($network_system, $vSwitch->key, $port);
         next unless (defined $pg);
         my $usedPorts = (defined $pg->port) ? $#{$pg->port} + 1 : 0;         
          
         if (defined($pg->spec->policy->nicTeaming) &&
             defined($pg->spec->policy->nicTeaming->nicOrder)) {
            $pNicName = "";
            my $pNics = $pg->spec->policy->nicTeaming->nicOrder->activeNic;
            foreach my $pNic (@$pNics) {
               $pNicName = $pNicName ? ("$pNicName," . $pNic) : $pNic;
            }
         } else {
            $pNicName = $sNicName;
         }
         printf("   %-30s%-10s%-16s%-16s\n", 
                $pg->spec->name, 
                $pg->spec->vlanId, 
                $usedPorts, 
                $pNicName);
      }
      print "\n";
   }
   
   if (defined($pSwitches)) {
      print "DVS Name                 Num Ports   Used Ports  Configured Ports  Uplinks\n";
      
      foreach my $pSwitch (@$pSwitches) {
         my $pNicName = getPnicName($network_system, $pSwitch->pnic);
         
         printf("%-25s%-12s%-12s%-18s%-16s\n\n",
                $pSwitch->dvsName,
                $pSwitch->numPorts,
                $pSwitch->numPorts - $pSwitch->numPortsAvailable,
                $pSwitch->numPorts,
                $pNicName);
         
         my $upLinks = $pSwitch->uplinkPort;
         print "   DVPort ID           In Use      Client\n";
         foreach my $upLink (@$upLinks) {
            my $pnicDevice = undef;
            if (defined($pSwitch->spec)) {
               if (defined($pSwitch->spec->backing)) {
                  if (defined($pSwitch->spec->backing->pnicSpec)) {
                     my $pnicSpecs = $pSwitch->spec->backing->pnicSpec;
                     foreach my $pnicSpec (@$pnicSpecs) {
                        if ($upLink->key eq $pnicSpec->uplinkPortKey) {
                           $pnicDevice = $pnicSpec->pnicDevice;
                        }
                     }
                  }
               }
            }
            printf("   %-20s%-12s%-16s\n",
                   $upLink->key, $pnicDevice ? "1" : 0, $pnicDevice ? $pnicDevice : "");
         }
      }
   }
   
}

sub UpdateVirtualSwitch {
   my ($network, $vSwitch, $pgName, $vlan) = @_;
   my $hostNetPolicy = new HostNetworkPolicy();
   my $hostPGSpec = new HostPortGroupSpec (name => $pgName, 
                                           policy => $hostNetPolicy,
                                           vlanId => $vlan, 
                                           vswitchName => $vSwitch);
   eval {
       $network->AddPortGroup (_this => $network->networkInfo, portgrp => $hostPGSpec);};
       if ($@) {
          VIExt::fail($@->fault_string);
       }
   return;
}
        
sub UpdateMTU { 
   my ($network, $vswitchName, $mtu) = @_;;
   my $vs = FindVSwitchbyName($network, $vswitchName);
   if ($vs) {
      my $numPorts = $vs->{numPorts};
      $numPorts = 64 unless (defined($numPorts));

      $vs->{spec}->{mtu} = $mtu; 
      eval {
         $network->UpdateVirtualSwitch(vswitchName => $vswitchName, spec => $vs->spec);
      };
      if ($@) {
         VIExt::fail($@->fault_string);
      }
   } else {
      print "No such virtual switch : $vswitchName\n";
   }
}

sub UpdateUplinks { 
   my ($network, $vswitchName, $pnic, $add) = @_;;
   my $vs = FindVSwitchbyName($network, $vswitchName);
   if ($vs) {
      # Create a new bridge when configuring a vswitch that
      # currently has zero uplinks.
      unless (defined($vs->spec->bridge)) {
         if ($add) {
            $vs->{spec}->{bridge} = new HostVirtualSwitchBondBridge();
         } else {
            print "No such uplink : $pnic\n";
            return;
         }
      }

      my $bridge = $vs->spec->bridge;

      # Not setting policy 
      #   => retains existing settings, except adjusting the bridge changes.
      delete $vs->{spec}->{policy};

      if ($bridge->isa('HostVirtualSwitchBondBridge')) {
         if ($add) {
            push (@{$bridge->{nicDevice}}, $pnic);
         } else {
            my $size = @{$bridge->{nicDevice}};
            for (my $i=0; $i<$size; $i++) {
               if ($bridge->{nicDevice}->[$i] eq "$pnic") {
                  splice(@{$bridge->{nicDevice}}, $i, 1);
                  last;
               }
            }
            if (@{$bridge->{nicDevice}} == 0) {
               delete $vs->{spec}->{bridge};
            }
         }
      } elsif ($bridge->isa('HostVirtualSwitchSimpleBridge')) {
         if ($add) {
            $bridge->{nicDevice} = $pnic;
         } else {
            $bridge->{nicDevice} = undef;
         }
      } else {
         print "Operation not valid for this vswitch.\n";
      }
      eval {
         $network->UpdateVirtualSwitch(vswitchName => $vswitchName, spec => $vs->spec);
         print "Update uplinks : " . join(", ", @{$bridge->{nicDevice}}) . "\n";
      };
      if ($@) {
         VIExt::fail($@->fault_string);
      }
   } else {
      print "No such virtual switch : $vswitchName\n";
   }
}

sub AddPortGroup {
   my ($network, $pgName, $vSwitch, $vlan) = @_;
   my $hostNetPolicy = new HostNetworkPolicy();
   $vlan = 0 unless (defined $vlan);
   my $hostPGSpec = new HostPortGroupSpec (name => $pgName, 
      policy => $hostNetPolicy,
      vlanId => $vlan, 
      vswitchName => $vSwitch);
   eval {$network->AddPortGroup (_this => $network, portgrp => $hostPGSpec); };
   if ($@) {
      VIExt::fail($@->fault_string);
   }
   return;
}

sub UpdatePortGroupVlan {
   my ($network, $vSwitch, $pgName, $vlan) = @_;
   my $pg = FindPortGroupbyName ($network, $vSwitch, $pgName);
   VIExt::fail("Port Group $pgName on VSwitch $vSwitch is not found") unless (defined $pg);
   my $hostPGSpec = new HostPortGroupSpec (name => $pgName, 
                                           policy => $pg->spec->policy,
                                           vlanId => $vlan, 
                                           vswitchName => $vSwitch);
   eval {
      $network->UpdatePortGroup (pgName => $pgName, portgrp => $hostPGSpec);
   };
   if ($@) {
      VIExt::fail($@->fault_string);
   }
   return;
}

sub UpdatePortGroupAddUplink {
   my ($network, $vSwitchName, $pgName, $vnic) = @_;
   my $pg = FindPortGroupbyName ($network, $vSwitchName, $pgName);
   VIExt::fail("Port Group $pgName on VSwitch $vSwitchName is not found") unless (defined $pg);
   
   if (defined($pg->spec->policy->nicTeaming) &&
       defined($pg->spec->policy->nicTeaming->nicOrder)) {
      my $found = 0;
      my @newNics = ();
      my $activeNics = $pg->spec->policy->nicTeaming->nicOrder->activeNic;
      
      foreach (@$activeNics) {
         if ($_ eq $vnic) {
            $found = 1;
         }
         push @newNics, $_;
      }
      
      if (! $found) {
         push @newNics, $vnic;
         if (!defined($pg->spec->policy->nicTeaming)) {
            $pg->spec->policy->nicTeaming(new HostNicTeamingPolicy());
         }
         if (!defined($pg->spec->policy->nicTeaming->nicOrder)) {
            $pg->spec->policy->nicTeaming->nicOrder(new HostNicOrderPolicy(activeNic => \@newNics));
         } else {
            $pg->spec->policy->nicTeaming->nicOrder->activeNic(\@newNics);
         }
      
         my $hostPGSpec = new HostPortGroupSpec (name => $pgName, 
                                                 policy => $pg->spec->policy,
                                                 vlanId => $pg->spec->vlanId, 
                                                 vswitchName => $vSwitchName);
         eval {
            $network->UpdatePortGroup (pgName => $pgName, portgrp => $hostPGSpec);
            print "Added uplink adapter successfully\n";
         };
         if ($@) {
            VIExt::fail($@->fault_string);
         }
      }
   }
   return;
}

sub UpdatePortGroupDelUplink {
   my ($network, $vSwitchName, $pgName, $vnic) = @_;
   my $pg = FindPortGroupbyName ($network, $vSwitchName, $pgName);
   VIExt::fail("Port Group $pgName on VSwitch $vSwitchName is not found") unless (defined $pg);
   
   my $activeNics;
   if (defined($pg->spec->policy->nicTeaming) && 
       defined($pg->spec->policy->nicTeaming->nicOrder)) {
       $activeNics = $pg->spec->policy->nicTeaming->nicOrder->activeNic;
   } else {
       my $vSwitch = FindVSwitchbyName($network, $vSwitchName);
       my $pNicName = getPnicName($network, $vSwitch->pnic);
       @$activeNics = split(/,/, $pNicName);
   }

   my $found = 0;
   my @newNics = (); 
      
   foreach (@$activeNics) {
      if ($_ ne $vnic) {
         push @newNics, $_;
      } else {
         $found = 1;
      }
   }
      
   if ($found) {
      if (!defined($pg->spec->policy->nicTeaming)) {
         $pg->spec->policy->nicTeaming(new HostNicTeamingPolicy());
      }
      if (!defined($pg->spec->policy->nicTeaming->nicOrder)) {
         $pg->spec->policy->nicTeaming->nicOrder(new HostNicOrderPolicy(activeNic => \@newNics));
      } else {
         $pg->spec->policy->nicTeaming->nicOrder->activeNic(\@newNics);
      }
      my $hostPGSpec = new HostPortGroupSpec (name => $pgName, 
                                              policy => $pg->spec->policy,
                                              vlanId => $pg->spec->vlanId, 
                                              vswitchName => $vSwitchName);
      eval {
         $network->UpdatePortGroup (pgName => $pgName, portgrp => $hostPGSpec);
         print "Deleted uplink adapter successfully\n";
      };
      if ($@) {
         VIExt::fail($@->fault_string);
      }
   } else {
      print "No such uplink adapter : $vnic\n";
   }
   return;
}


sub UpdateDVPDelUplink {
   my ($network, $dvSwitch, $vnic, $portKey) = @_;
   my $pSwitch = FindPSwitchbyName($network, $dvSwitch);
   VIExt::fail("DVSwitch $dvSwitch is not found") unless (defined $pSwitch);

   my $found = 0;
   my @newPnicSpecs = ();
   my $pnicSpecs = $pSwitch->spec->backing->pnicSpec;
   
   foreach (@$pnicSpecs) {
      if ($_->pnicDevice ne $vnic && $_->uplinkPortKey ne $portKey) {
         push @newPnicSpecs, $_;
      } else {
         if ($_->pnicDevice eq $vnic && $_->uplinkPortKey eq $portKey) {
            $found = 1;
         }
      }
   }
   
   if ($found) {
      $pSwitch->spec->backing->pnicSpec(\@newPnicSpecs);
   
      my $pSwitchConfig = new HostProxySwitchConfig(changeOperation => "edit",
                                                    spec => $pSwitch->spec,
                                                    uuid => $pSwitch->dvsUuid);
      my $config = new HostNetworkConfig(proxySwitch => [$pSwitchConfig]);
      eval {
         $network->UpdateNetworkConfig (changeMode => "modify",
                                        config => $config);
         print "Deleted uplink adapter successfully\n";
      };
      if ($@) {
         VIExt::fail($@->fault_string);
      }
   } else {
      print "No such uplink adapter : $vnic\n";
   }
   return;
}

sub UpdateDVPAddUplink {
   my ($network, $dvSwitch, $vnic, $portKey) = @_;
   my $pSwitch = FindPSwitchbyName($network, $dvSwitch);
   VIExt::fail("DVSwitch $dvSwitch is not found") unless (defined $pSwitch);
   
   my $pnicSpecs = $pSwitch->spec->backing->pnicSpec;
   my $newSpec = new DistributedVirtualSwitchHostMemberPnicSpec(pnicDevice => $vnic,
                                                                uplinkPortKey => $portKey);
   push @$pnicSpecs, $newSpec;
   $pSwitch->spec->backing->pnicSpec($pnicSpecs);
   
   my $pSwitchConfig = new HostProxySwitchConfig(changeOperation => "edit",
                                                 spec => $pSwitch->spec,
                                                 uuid => $pSwitch->dvsUuid);
   my $config = new HostNetworkConfig(proxySwitch => [$pSwitchConfig]);
   eval {
      $network->UpdateNetworkConfig (changeMode => "modify",
                                     config => $config);
      print "Added uplink adapter successfully\n";                               
   };
   if ($@) {
      VIExt::fail($@->fault_string);
   }
   return;
}

sub GetCDP {
   my ($network, $vswitchName) = @_;;
   my $vs = FindVSwitchbyName($network, $vswitchName);
   if ($vs) {
      eval {
         my $value = $vs->spec->bridge->linkDiscoveryProtocolConfig->operation;
         if ($value eq "none") {
            # map to match with COS CLI
            $value = "down";
         }
         print $value . "\n";
      }
   } else {
      print "No such virtual switch : $vswitchName\n";
   }
}

sub SetCDP {
   my ($network, $vswitchName, $value) = @_;;
   my $vs = FindVSwitchbyName($network, $vswitchName);
   if ($vs) {
      eval {
         if ($value eq "down") {
            # map to match with COS CLI
            $value = "none";
         }
         
         eval {
            my $linkConfig = new LinkDiscoveryProtocolConfig(protocol => "cdp",
                                                             operation => $value);
            $vs->spec->bridge->linkDiscoveryProtocolConfig($linkConfig);
         };
         if ($@) {
            print "Setting of link protocol is not supported on this platform.";
         } else {
            $network->UpdateVirtualSwitch(vswitchName => $vswitchName, spec => $vs->spec);
         }
      };
      if ($@) {
         print "Error: Invalid CDP status string $value";
      }
   } else {
      print "No such virtual switch : $vswitchName\n";
   }
}

sub RemovePortGroup {
   my ($network, $pgName) = @_;
   eval {$network->RemovePortGroup (pgName => $pgName);};
   if ($@) {
      VIExt::fail($@->fault_string);
   }
}

sub FindVSwitchbyName {
   my ($network, $name) = @_;
   my $vSwitches = $network->networkInfo->vswitch;
   foreach my $vSwitch (@$vSwitches) {
      return $vSwitch if ($name eq $vSwitch->name);
   }
   return undef;
}

sub FindPSwitchbyName {
   my ($network, $name) = @_;
   my $pSwitches = $network->networkInfo->proxySwitch;
   foreach my $pSwitch (@$pSwitches) {
      return $pSwitch if ($name eq $pSwitch->dvsName);
   }
   return undef;
}

sub FindPortGroupbyName {
   my ($network, $vSwitch, $pgName) = @_;
   my $name = $vSwitch;
   my $portGroups = $network->networkInfo->portgroup;

   foreach my $pg (@$portGroups) {
      my $spec = $pg->spec;
      #
      # handle the case where any switch name will do
      #
      $name = (defined $vSwitch) ? $vSwitch : $spec->vswitchName;		
      return $pg if (($spec->vswitchName eq $name) && ($spec->name eq $pgName));
   }
   return undef;
}

sub FindPortGroupbyKey {
   my ($network, $vSwitch, $key) = @_;
   my $portGroups = $network->networkInfo->portgroup;
   foreach my $pg (@$portGroups) {
      return $pg if (($pg->vswitch eq $vSwitch) && ($key eq $pg->key));
   }
   return undef;
}

sub CheckValues {
   my %locals = GetSuppliedOptions();
   my $masterMap = BuildBits (keys %locals);	# build the master list

   foreach (@options) {
      my $bitmap = BuildBits ( @$_);
      return 1 if ($bitmap == $masterMap);
   }
   
   print "The options are invalid.\n\n";
   Opts::usage();
   exit(1);
}

sub BuildBits {
   my (@arr) = @_;
   my %list;
   foreach (@arr) {
      $list{$_}++; 
   } 
   my $bit = 0;
   foreach (sort keys %opts) {
      $bit = ($bit | 1) if (defined $list{$_}); 
      $bit = $bit << 1;
   }
   return $bit;
}

__END__

=head1 NAME

vicfg-vswitch - create and configure virtual switches and port groups

=head1 SYNOPSIS

 vicfg-vswitch [OPTIONS] <vswitch>

=head1 DESCRIPTION

vicfg-vswitch provides an interface to create and configure virtual 
switches and port groups for ESX Server networking.

=head1 OPTIONS

=over

=item B<--help>

Optional. Print the documentation which you are currently reading.
Calling the script with no arguments or with --help has the same effect.

=item B<--list | -l>

Optional. List virtual switches and port groups.

=item B<--add | -a>

Optional. Add a new virtual switch.

=item B<--delete | -d>

Optional. Delete an existing virtual switch.

=item B<--link | -L>

Optional. Add an uplink adapter (pnic) to a virtual switch. Executing the 
command with this option attaches a new unused physical network adapter 
to a virtual switch.

=item B<--unlink | -U>

Optional. Remove an uplink adapter from a virtual switch. An uplink adapter 
is a physical Ethernet adapter to which the virtual switch is connected. If you 
remove the last uplink, physical network connectivity for that switch is lost.

=item B<--check | -c>

Optional. Check whether a virtual switch exists or not.

=item B<--add-pg | -A>

Optional. Add a port group to a virtual switch.

=item B<--del-pg | -D>

Optional. Delete a port group from the virtual switch.

=item B<--add-pg-uplink | -M>

Optional. Add an uplink adapter (pnic) to a port group (valid for vSphere 4.0 and later).

=item B<--del-pg-uplink | -N>

Optional. Delete an uplink adapter from a port group (valid for vSphere 4.0 and later).

=item B<--add-dvp-uplink | -P>

Optional. Add an uplink adapter (pnic) to a DVPort (valid for vSphere 4.0 and later).

=item B<--del-dvp-uplink | -Q>

Optional. Delete an uplink adapter from a DVPort (valid for vSphere 4.0 and later).

=item B<--vlan | -v>

Optional. Set the VLAN ID for a  port group specified by -p.  
Setting the option to 0 disables the VLAN for this port group.

=item B<--check-pg | -C>

Optional. Check whether a portgroup exists or not.

=item B<--mtu | -m>

Optional. Set MTU (maximum transmission unit) for a virtual switch.

=item B<--pg | -p>

Optional. Provide the name of the port group.

=item B<--dvp | -V>

Optional. Provide the name of the DVPort (valid for vSphere 4.0 and later).

=item B<--get-cdp | -b>

Optional. Print the current CDP setting for this virtual switch (valid for vSphere 4.0 and later).

=item B<--set-cdp | -B>

Optional. Set the CDP status for a given virtual switch (valid for vSphere 4.0 and later).  
To set pass "down", "listen", "advertise", or "both.

=item B<--vihost | -h>

Optional. When you execute a Remote CLI with the --server option pointing 
to a VirtualCenter Server host, you can use --vihost to specify the ESX 
Server host to execute the command on.

=back

=head1 EXAMPLES

Add a new virtual switch:

 perl vicfg-vswitch --server <host name> --username <user name> 
    --password <password> -a <vswitch name>

Delete the virtual switch. This will fail if any ports on the 
virtual switch are still in use by VMkernel networks, vswifs, or virtual machines:

 perl vicfg-vswitch --server <hostname> --username <user name> 
    --password <password> -d <vswitch name>

List all virtual switches and their portgroups:

 perl vicfg-vswitch --server <host name> --username <user name> 
    --password <password> -l

Add an uplink adapter to a virtual switch:

 perl vicfg-vswitch --server <host name> --username <user name> 
    --password <password> -L <physical adapter name> <vswitch name>

Remove an uplink adapter from a virtual switch:

 perl vicfg-vswitch --server <host name> --username <user name> 
    --password <password> -U <physical adapter name> <vswitch name>

Check whether a virtual switch exists:

 perl vicfg-vswitch --server <host name> --username <user name> 
    --password <password> --check <vswitch name>

Add a new portgroup to the virtual switch:

 perl vicfg-vswitch --server <host name> --username <user name> 
    --password <password> -A <port group name> <vswitch name>

Delete a portgroup from the virtual switch:

 perl vicfg-vswitch --server <host name> --username <user name> 
    --password <password> -D <port group name> <vswitch name>

Check whether a port group exists:

 perl vicfg-vswitch --server <host name> --username <user name> 
    --password <password> -C <valid portgroup name> <vswitch name>
    
Add an uplink adapter to a port group:

 perl vicfg-vswitch --server <host name> --username <user name> 
    --password <password> -M <physical adapter name> -p <port group name> <vswitch name>

Remove an uplink adapter from a port group:

 perl vicfg-vswitch --server <host name> --username <user name> 
    --password <password> -N <physical adapter name> -p <port group name> <vswitch name>

Print the current CDP setting for the virtual switch.:

 perl vicfg-vswitch --server <host name> --username <user name> 
    --password <password> --get-cdp <vswitch name>    

=head1 SUPPORTED PLATFORMS

This operation is supported on ESX 3.0.x, ESX 3.5, ESX 3i, ESX 4.0, ESXi 4.0, VC 2.0.x, VC 2.5, VC 4.0.
