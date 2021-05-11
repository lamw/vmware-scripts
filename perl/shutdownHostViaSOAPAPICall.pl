#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://communities.vmware.com/docs/DOC-11623

use strict;
use warnings;
use Term::ANSIColor;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Cookies;
use Data::Dumper;

# Please fill out the 
# username and password 
# for your ESX(i) host
my $host_username = 'fillmein';
my $host_password = 'fillmein';

#### DO NOT EDIT PAST HERE ####

my @hostlist;
my ($file,$request,$message,$response,$retval,$cookie);

&verifyUserInput();
&processFile($file);

foreach my $hostname(@hostlist) {

	########################
	# intial hello message
	########################
	$message = &createHelloMessage($host_username,$host_password);
	$response = &sendRequest($hostname,$message);
	$retval = checkReponse($response);

	if($retval eq 1) {
		########################
		# grab cookie
		########################
		my $cookie = &extractCookie($response);

		########################
		# shutdown message
		########################
		$message = createShutdownMessage();

		########################
		# hasta la vista ESX(i)
		########################
		print color("yellow") . "Creating and sending shutdown command to $hostname ...\n" . color("reset");
		$response = &sendRequest($hostname,$message,$cookie);
		$retval = checkReponse($response);
		if($retval eq 1) {
			print "\t" . color("green") . "Succesfully initiated shutdown of $hostname\n\n" . color("reset");
		} else {
			print "\t" . color("red") . "Sent shutdown message but did not get confirmation back from $hostname\n\n" . color("reset");
		}	
	} else {
		print color("red") . "Failed to issue shutdown command to $hostname\n\n" . color("reset");	
	}
}

#####################
#
# HELP FUNCTIONS
#
#####################

sub sendRequest {
	my ($host,$msg,$cookie) = @_;
	my $host_to_connect = "https://" . $host . "/sdk";

	my $userAgent = LWP::UserAgent->new(agent => 'VMware VI Client/4.0.0');
	my $request = HTTP::Request->new(POST => $host_to_connect);
	$request->header(SOAPAction => '"urn:internalvim25/4.0"');
	$request->content($msg);
	$request->content_type("text/xml; charset=utf-8");
	
	if(defined($cookie)) {
		$cookie->add_cookie_header($request);
	}	
	my $rsp = $userAgent->request($request);
}

sub createHelloMessage {
	my ($user,$pass) = @_;
	my $msg = <<SOAP_HELLO_MESSAGE;
<soap:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <Login xmlns="urn:internalvim25">
      <_this xsi:type="SessionManager" type="SessionManager"
serverGuid="">ha-sessionmgr</_this>
      <userName>$user</userName>
      <password>$pass</password>
      <locale>en_US</locale>
    </Login>
  </soap:Body>
</soap:Envelope>
SOAP_HELLO_MESSAGE

	return $msg;
}

sub createShutdownMessage {
	my $msg = <<SOAP_SHUTDOWN_MESSAGE;
<soap:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <ShutdownHost_Task xmlns="urn:internalvim25">
      <_this xsi:type="HostSystem" type="HostSystem" serverGuid="">ha-host</_this>
      <force>true</force>
    </ShutdownHost_Task>
  </soap:Body>
</soap:Envelope>
SOAP_SHUTDOWN_MESSAGE

	return $msg;
}

sub extractCookie {
	my ($rsp) = @_;
	my $cookie_jar = HTTP::Cookies->new;
        $cookie_jar->extract_cookies($rsp);

	return $cookie_jar;
}

sub checkReponse {
	my ($resp) = @_;
	my $ret = -1;	

	if($resp->code == 200) {
		#print $resp->as_string;
		return 1;
	} else {
		print "\n" . color("red") . $resp->error_as_HTML . color("reset") . "\n";;	
		return $ret;
	}
}

# Subroutine to process the input file
sub processFile {
        my ($hostlist) =  @_;
        my $HANDLE;
        open (HANDLE, $hostlist) or die("ERROR: Can not locate \"$hostlist\" input file!\n");
        my @lines = <HANDLE>;
        my @errorArray;
        my $line_no = 0;

        close(HANDLE);
        foreach my $line (@lines) {
                $line_no++;
                &TrimSpaces($line);

                if($line) {
                        if($line =~ /^\s*:|:\s*$/){
                                print "Error in Parsing File at line: $line_no\n";
                                print "Continuing to the next line\n";
                                next;
                        }
                        my $host = $line;
                        &TrimSpaces($host);
                        push @hostlist,$host;
                }
        }
}

sub TrimSpaces {
        foreach (@_) {
                s/^\s+|\s*$//g
        }
}

sub verifyUserInput {
	if(@ARGV != 1 ) {
	        print color("magenta") . "\nUsage: $0 [HOST_FILE]\n\n" . color("reset");
        	exit;
	} else {
        	$file = $ARGV[0];
	}

	if($host_username eq 'fillmein' || $host_password eq 'fillmein') {
		print color("red") . "Please fill in \$host_username & \$host_password information in the script prior to starting!\n\n" . color("reset");
		exit
	}
}
