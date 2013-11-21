#!/usr/bin/perl -w
# Copyright (c) 2009-2010 William Lam All rights reserved.

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
# 4. Consent from original author prior to redistribution

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
# 12/10/2009
# http://communities.vmware.com/docs/DOC-11623
# http://engineering.ucsb.edu/~duonglt/vmware/
# http://communities.vmware.com/docs/DOC-9852

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
