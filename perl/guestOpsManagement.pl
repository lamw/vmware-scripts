#!/usr/bin/perl -w
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2011/07/automating-new-integrated-vixguest.html

use strict;
use warnings;
use Term::ANSIColor;
use Fcntl ':mode';
use URI::URL;
use URI::Escape;
use LWP::Simple;
use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use VMware::VILib;
use VMware::VIRuntime;

my %opts = (
        operation => {
                type => "=s",
                help => "Operation to perform [validate|ps|startprog|kill|ls|mkdir|rmdir|rm|mv|mvdir|copyfromguest|copytoguest|env]",
                required => 1,
        },
	vm => {
                type => "=s",
                help => "Name of Virtual Machine to perform guest operation on",
	        required => 1,
        },
	guestusername => {
                type => "=s",
                help => "Username for guestOS in VM",
	        required => 0,
        },
	guestpassword => {
                type => "=s",
                help => "Password for guestOS in VM",
                required => 0,
        },
	filepath_src => {
                type => "=s",
                help => "Full path to source directory/file",
	        required => 0,
        },
	recursive => {
	        type => "=s",
                help => "Perform recursive operation [true|false",
		default => 'false',
                required => 0,
        },
	filepath_dst => {
                type => "=s",
                help => "Full path to destination directory",
	        required => 0,
        },
	overwrite => {
                type => "=s",
                help => "Overwrite file [true|false]",
	        required => 0,
		default => 'false',
        },
	pid => {
                type => "=s",
                help => "PID of process",
                required => 0,
        },
	program_path => {
                type => "=s",
                help => "Absolute path to the program to start",
		required => 0,
        },
	program_args => {
                type => "=s",
                help => "Arguments to program",
	        required => 0,
        },
	working_dir => {
                type => "=s",
                help => "Working direction in which to execute program",
		required => 0,
        },
	minimize_app => {
                type => "=s",
                help => "Minimize application if guestOS is Windows [true|false]",
	        required => 0,
        },
);

# validate options, and connect to the server
Opts::add_options(%opts);

Opts::parse();
Opts::validate();
Util::connect();

my $vm = Opts::get_option('vm');
my $operation = Opts::get_option('operation');
my $guestusername = Opts::get_option('guestusername');
my $guestpassword = Opts::get_option('guestpassword');
my $filepath_src = Opts::get_option('filepath_src');
my $filepath_dst = Opts::get_option('filepath_dst');
my $recursive = Opts::get_option('recursive');
my $overwrite = Opts::get_option('overwrite');
my $pid = Opts::get_option('pid');
my $program_path = Opts::get_option('program_path');
my $program_args = Opts::get_option('program_args');
my $working_dir = Opts::get_option('working_dir');
my $minimize_app = Opts::get_option('minimize_app');

my $productSupport = "both";
my @supportedVersion = qw(5.0.0 5.1.0 5.5.0 6.0.0);
my ($authMgr,$fileMgr,$procMgr);

&validateSystem(Vim::get_service_content()->about->version,Vim::get_service_content()->about->productLineId);

if($operation eq "validate") {
	my $vm_view = &getVM($vm);
	
	unless($guestusername) {
		Util::disconnect();
		&print("Operation \"$operation\" requires \"guestusername\" and/or \"guestpassword\" variables to be defined\n\n","yellow");		
		exit 1;
	}
	if(!defined($guestpassword)) {
		$guestpassword = &getPassword();
	}

	my $guestOpMgr = Vim::get_view(mo_ref => Vim::get_service_content()->guestOperationsManager);
	&acquireGuestAuth($guestOpMgr,$vm_view,$guestusername,$guestpassword);
} elsif($operation eq "ls") {
	my $vm_view = &getVM($vm);

        unless($guestusername && $filepath_src) {
                Util::disconnect();
                &print("Operation \"$operation\" requires \"guestusername\",\"filepath_src\" and/or \"guestpassword\" variables to be defined\n\n","yellow");
                exit 1;
        }
        if(!defined($guestpassword)) {
                $guestpassword = &getPassword();
        }

        my $guestOpMgr = Vim::get_view(mo_ref => Vim::get_service_content()->guestOperationsManager);
        my $guestCreds = &acquireGuestAuth($guestOpMgr,$vm_view,$guestusername,$guestpassword);

	my $fileMgr = Vim::get_view(mo_ref => $guestOpMgr->fileManager);
	my $guestFiles;

	eval {
		$guestFiles = $fileMgr->ListFilesInGuest(vm =>$vm_view, auth => $guestCreds, filePath => $filepath_src);
		if($guestFiles) {
			my ($path,$size,$type,$permissions,$accessTime,$modTime);

			format ls = 
@<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<
$type,$permissions,$size,$accessTime,$modTime,$path;
.
($type,$permissions,$size,$accessTime,$modTime,$path) = ('TYPE','ATTRIBUTES','SIZE','ACCESS TIME','MODIFICATION TIME','FILE');
$~ = 'ls';
write;

			foreach(@{$guestFiles->files}) {
				$type = $_->type;
				if($_->attributes->isa('GuestPosixFileAttributes')) {
					$permissions = "";
					$permissions .= (defined($_->attributes->permissions) ? sprintf "%04o ", S_IMODE($_->attributes->permissions) . " " : " ");
					$permissions .= (defined($_->attributes->ownerId) ? $_->attributes->ownerId . " " : " ");
					$permissions .= (defined($_->attributes->groupId) ? $_->attributes->groupId . " " : " ");
				} elsif($_->attributes->isa('GuestWindowsFileAttributes')) {
					$permissions = "";
					$permissions .= (defined($_->attributes->createTime) ? $_->attributes->createTime . " "  : " ");
					$permissions .= (defined($_->attributes->hidden) ? "HIDDEN " : " ");
					$permissions .= (defined($_->attributes->readOnly) ? "RO " : " ");
				}
				$size = &prettyPrintData($_->size,'B');
				$accessTime = $_->attributes->accessTime || "N/A";
				$modTime = $_->attributes->modificationTime || "N/A";				
				$path = $_->path;
				write;
			}
		} else {
			&print("No files listed under \"$filepath_src\"\n\n","yellow");
		}
	};
	if($@) {
                die(color("red") . "Error: " . $@ . color("reset") . "\n\n");
	}
} elsif($operation eq "mkdir") {
	my $vm_view = &getVM($vm);

        unless($guestusername && $filepath_src) {
                Util::disconnect();
                &print("Operation \"$operation\" requires \"guestusername\",\"filepath_src\" and/or \"guestpassword\" variables to be defined\n\n","yellow");
                exit 1;
        }
        if(!defined($guestpassword)) {
                $guestpassword = &getPassword();
        }

        my $guestOpMgr = Vim::get_view(mo_ref => Vim::get_service_content()->guestOperationsManager);
        my $guestCreds = &acquireGuestAuth($guestOpMgr,$vm_view,$guestusername,$guestpassword);

        my $fileMgr = Vim::get_view(mo_ref => $guestOpMgr->fileManager);

	eval {
		&print("Creating directory: \"$filepath_src\" ...\n\n","magenta");
		$fileMgr->MakeDirectoryInGuest(vm =>$vm_view, auth => $guestCreds, directoryPath => $filepath_src, createParentDirectories => 'true');
	};
	if($@) {
                die(color("red") . "Error: " . $@ . color("reset") . "\n\n");
        }
} elsif($operation eq "rmdir") {
        my $vm_view = &getVM($vm);

        unless($guestusername && $filepath_src) {
                Util::disconnect();
                &print("Operation \"$operation\" requires \"guestusername\",\"filepath_src\" and/or \"guestpassword\",\"recursive\" variables to be defined\n\n","yellow");
                exit 1;
        }
        if(!defined($guestpassword)) {
                $guestpassword = &getPassword();
        }

        my $guestOpMgr = Vim::get_view(mo_ref => Vim::get_service_content()->guestOperationsManager);
        my $guestCreds = &acquireGuestAuth($guestOpMgr,$vm_view,$guestusername,$guestpassword);

        my $fileMgr = Vim::get_view(mo_ref => $guestOpMgr->fileManager);

        eval {
		if($recursive =~ /true/i) {
			my $rsp = promptUser("Do you really want to perform a recursive delete on \"$filepath_src\"? [yes|no]");
			if($rsp !~ /yes/i) {
				Util::disconnect();
				&print("Recursive delete aborted!\n\n","red");
				exit 0;
			}
		}
		&print("Removing directory: \"$filepath_src\" with recursive $recursive ...\n\n","magenta");
                $fileMgr->DeleteDirectoryInGuest(vm =>$vm_view, auth => $guestCreds, directoryPath => $filepath_src, recursive => $recursive);
        };
        if($@) {
                die(color("red") . "Error: " . $@ . color("reset") . "\n\n");
        }
} elsif($operation eq "rm") {
        my $vm_view = &getVM($vm);

        unless($guestusername && $filepath_src) {
                Util::disconnect();
                &print("Operation \"$operation\" requires \"guestusername\",\"filepath_src\" and/or \"guestpassword\" variables to be defined\n\n","yellow");
                exit 1;
        }
        if(!defined($guestpassword)) {
                $guestpassword = &getPassword();
        }

        my $guestOpMgr = Vim::get_view(mo_ref => Vim::get_service_content()->guestOperationsManager);
        my $guestCreds = &acquireGuestAuth($guestOpMgr,$vm_view,$guestusername,$guestpassword);

        my $fileMgr = Vim::get_view(mo_ref => $guestOpMgr->fileManager);

        eval {
                my $rsp = promptUser("Do you really want to delete file \"$filepath_src\"? [yes|no]");
                if($rsp !~ /yes/i) {
                        Util::disconnect();
                        &print("Delete aborted!\n\n","red");
                	exit 0;
                }
                &print("Removing file: \"$filepath_src\" ...\n\n","magenta");
                $fileMgr->DeleteFileInGuest(vm =>$vm_view, auth => $guestCreds, filePath => $filepath_src);
        };
        if($@) {
                die(color("red") . "Error: " . $@ . color("reset") . "\n\n");
        }
} elsif($operation eq "mv") {
        my $vm_view = &getVM($vm);

        unless($guestusername && $filepath_src && $filepath_dst) {
                Util::disconnect();
                &print("Operation \"$operation\" requires \"guestusername\",\"filepath_src\",\"filepath_dst\" and/or \"guestpassword\",\"overwrite\" variables to be defined\n\n","yellow");
                exit 1;
        }
        if(!defined($guestpassword)) {
                $guestpassword = &getPassword();
        }

        my $guestOpMgr = Vim::get_view(mo_ref => Vim::get_service_content()->guestOperationsManager);
        my $guestCreds = &acquireGuestAuth($guestOpMgr,$vm_view,$guestusername,$guestpassword);

        my $fileMgr = Vim::get_view(mo_ref => $guestOpMgr->fileManager);

        eval {
                my $rsp = promptUser("Do you really want to move file \"$filepath_src\" to \"$filepath_dst\"? [yes|no]");
                if($rsp !~ /yes/i) {
                        Util::disconnect();
                        &print("Move aborted!\n\n","red");
                        exit 0;
                }
                &print("Moving file: \"$filepath_src\" to \"$filepath_dst\" ...\n\n","magenta");
                $fileMgr->MoveFileInGuest(vm =>$vm_view, auth => $guestCreds, srcFilePath => $filepath_src, dstFilePath => $filepath_dst, overwrite => $overwrite);
        };
        if($@) {
                die(color("red") . "Error: " . $@ . color("reset") . "\n\n");
        }
} elsif($operation eq "mvdir") {
        my $vm_view = &getVM($vm);

        unless($guestusername && $filepath_src && $filepath_dst) {
                Util::disconnect();
                &print("Operation \"$operation\" requires \"guestusername\",\"filepath_src\",\"filepath_dst\" and/or \"guestpassword\" variables to be defined\n\n","yellow");
                exit 1;
        }
        if(!defined($guestpassword)) {
                $guestpassword = &getPassword();
        }

        my $guestOpMgr = Vim::get_view(mo_ref => Vim::get_service_content()->guestOperationsManager);
        my $guestCreds = &acquireGuestAuth($guestOpMgr,$vm_view,$guestusername,$guestpassword);

        my $fileMgr = Vim::get_view(mo_ref => $guestOpMgr->fileManager);

        eval {
                my $rsp = promptUser("Do you really want to move directory \"$filepath_src\" to \"$filepath_dst\"? [yes|no]");
                if($rsp !~ /yes/i) {
                        Util::disconnect();
                        &print("Move aborted!\n\n","red");
                        exit 0;
                }
                &print("Moving directory: \"$filepath_src\" to \"$filepath_dst\" ...\n\n","magenta");
                $fileMgr->MoveDirectoryInGuest(vm =>$vm_view, auth => $guestCreds, srcDirectoryPath => $filepath_src, dstDirectoryPath => $filepath_dst);
        };
        if($@) {
                die(color("red") . "Error: " . $@ . color("reset") . "\n\n");
        }
} elsif($operation eq "ps") {
	my $vm_view = &getVM($vm);

        unless($guestusername) {
                Util::disconnect();
                &print("Operation \"$operation\" requires \"guestusername\" and/or \"guestpassword\" variables to be defined\n\n","yellow");
                exit 1;
        }
        if(!defined($guestpassword)) {
                $guestpassword = &getPassword();
        }

        my $guestOpMgr = Vim::get_view(mo_ref => Vim::get_service_content()->guestOperationsManager);
        my $guestCreds = &acquireGuestAuth($guestOpMgr,$vm_view,$guestusername,$guestpassword);

        my $procMgr = Vim::get_view(mo_ref => $guestOpMgr->processManager);

        eval {
		my ($owner,$pid,$startTime,$name,$cmdLine);

		format ps =
@<<<<<<<<<<<<<| @<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<| @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<|
$owner,$pid,$startTime,$name,$cmdLine
.
($owner,$pid,$startTime,$name,$cmdLine) = ('OWNER','PID','START','PROCESS NAME','CMD');
$~ = 'ps';
write;

                &print("Listing processes ...\n\n","magenta");
		my $guestProcess = $procMgr->ListProcessesInGuest(vm =>$vm_view, auth => $guestCreds);
		foreach(@$guestProcess) {
			$owner = $_->owner;
			$pid = $_->pid;
			$startTime = $_->startTime;
			$name = $_->name;
			$cmdLine = $_->cmdLine;
			write;
		}
        };
        if($@) {
                die(color("red") . "Error: " . $@ . color("reset") . "\n\n");
        }
} elsif($operation eq "kill") {
        my $vm_view = &getVM($vm);

        unless($guestusername && $pid) {
                Util::disconnect();
                &print("Operation \"$operation\" requires \"guestusername\",\"pid\" and/or \"guestpassword\" variables to be defined\n\n","yellow");
                exit 1;
        }
        if(!defined($guestpassword)) {
                $guestpassword = &getPassword();
        }

        my $guestOpMgr = Vim::get_view(mo_ref => Vim::get_service_content()->guestOperationsManager);
        my $guestCreds = &acquireGuestAuth($guestOpMgr,$vm_view,$guestusername,$guestpassword);

        my $procMgr = Vim::get_view(mo_ref => $guestOpMgr->processManager);

        eval {
                my $rsp = promptUser("Do you really want to kill PID \"$pid\"? [yes|no]");
                if($rsp !~ /yes/i) {
                        Util::disconnect();
                        &print("Kill aborted!\n\n","red");
                        exit 0;
                }
                &print("Killing PID: \"$pid\" ...\n\n","magenta");
		$procMgr->TerminateProcessInGuest(vm => $vm_view, auth => $guestCreds, pid => $pid);
        };
        if($@) {
                die(color("red") . "Error: " . $@ . color("reset") . "\n\n");
        }
} elsif($operation eq "startprog") {
	my $vm_view = &getVM($vm);

        unless($guestusername && $program_path && $program_args && $working_dir) {
                Util::disconnect();
                &print("Operation \"$operation\" requires \"guestusername\",\"program_path\",\"program_args\",\"working_dir\" and/or \"guestpassword\" variables to be defined\n\n","yellow");
                exit 1;
        }
        if(!defined($guestpassword)) {
                $guestpassword = &getPassword();
        }

        my $guestOpMgr = Vim::get_view(mo_ref => Vim::get_service_content()->guestOperationsManager);
        my $guestCreds = &acquireGuestAuth($guestOpMgr,$vm_view,$guestusername,$guestpassword);

        my $procMgr = Vim::get_view(mo_ref => $guestOpMgr->processManager);

        eval {
                &print("Starting program: \"$program_path\" with arguments \"$program_args\" in the following working directory \"$working_dir\" ...\n\n","magenta");
		my $progStartSpec;
		
		if(defined($minimize_app)) {
			$progStartSpec = GuestWindowsProgramSpec->new(programPath => $program_path, arguments => $program_args, workingDirectory => $working_dir, startMinimized => $minimize_app);
		} else {
			$progStartSpec = GuestProgramSpec->new(programPath => $program_path, arguments => $program_args, workingDirectory => $working_dir);
		}
		$pid = $procMgr->StartProgramInGuest(vm => $vm_view, auth => $guestCreds, spec => $progStartSpec);
		&print("Program started with the following PID: " . $pid . "\n\n","green");
        };
        if($@) {
                die(color("red") . "Error: " . $@ . color("reset") . "\n\n");
        }
} elsif($operation eq "copyfromguest") {
	my $vm_view = &getVM($vm);

        unless($guestusername && $filepath_src) {
                Util::disconnect();
                &print("Operation \"$operation\" requires \"guestusername\",\"filepath_src\" and/or \"guestpassword\" variables to be defined\n\n","yellow");
                exit 1;
        }
        if(!defined($guestpassword)) {
                $guestpassword = &getPassword();
        }

        my $guestOpMgr = Vim::get_view(mo_ref => Vim::get_service_content()->guestOperationsManager);
        my $guestCreds = &acquireGuestAuth($guestOpMgr,$vm_view,$guestusername,$guestpassword);

        my $fileMgr = Vim::get_view(mo_ref => $guestOpMgr->fileManager);

        eval {
                &print("Downloading file: \"$filepath_src\" from guest ...\n","magenta");
                my $fileTransferInfo = $fileMgr->InitiateFileTransferFromGuest(vm =>$vm_view, auth => $guestCreds, guestFilePath => $filepath_src);
		my $url = $fileTransferInfo->url;
		my $hostServerIp = Opts::get_option('server');
                $url =~ s/\*/$hostServerIp/;
		&print("Recieved download URL: " . $url . "\n","green");
		&downloadFile($url,$filepath_src,".");
        };
        if($@) {
                die(color("red") . "Error: " . $@ . color("reset") . "\n\n");
        }
} elsif($operation eq "copytoguest") {
        my $vm_view = &getVM($vm);

        unless($guestusername && $filepath_src) {
                Util::disconnect();
                &print("Operation \"$operation\" requires \"guestusername\",\"filepath_src\",\"filepath_dst\" and/or \"guestpassword\" variables to be defined\n\n","yellow");
                exit 1;
        }
        if(!defined($guestpassword)) {
                $guestpassword = &getPassword();
        }

	my $size;
	if(! -e $filepath_src ) {
		Util::disconnect();
                &print("Unable to locate file \"$filepath_src\"\n\n","red");
		exit 1;
	} else {
		$size = -s $filepath_src;
	}

        my $guestOpMgr = Vim::get_view(mo_ref => Vim::get_service_content()->guestOperationsManager);
        my $guestCreds = &acquireGuestAuth($guestOpMgr,$vm_view,$guestusername,$guestpassword);

        my $fileMgr = Vim::get_view(mo_ref => $guestOpMgr->fileManager);

        eval {
                &print("Uploading file: \"$filepath_src\" with size \"$size\" to guest \"$filepath_dst\" ...\n","magenta");
		my $fileAtt = GuestFileAttributes->new();
                my $url = $fileMgr->InitiateFileTransferToGuest(vm =>$vm_view, auth => $guestCreds, guestFilePath => $filepath_dst, fileAttributes => $fileAtt, fileSize => $size, overwrite => $overwrite);
		my $hostServerIp = Opts::get_option('server');
    		$url =~ s/\*/$hostServerIp/;
		&print("Recieved upload URL: " . $url . "\n","green");
                &uploadFile($url,$filepath_src,$filepath_dst);
        };
        if($@) {
                die(color("red") . "Error: " . $@ . color("reset") . "\n\n");
        }
} elsif($operation eq "env") {
	my $vm_view = &getVM($vm);

        unless($guestusername) {
                Util::disconnect();
                &print("Operation \"$operation\" requires \"guestusername\" and/or \"guestpassword\" variables to be defined\n\n","yellow");
                exit 1;
        }
        if(!defined($guestpassword)) {
                $guestpassword = &getPassword();
        }
	my $guestOpMgr = Vim::get_view(mo_ref => Vim::get_service_content()->guestOperationsManager);
        my $guestCreds = &acquireGuestAuth($guestOpMgr,$vm_view,$guestusername,$guestpassword);

	my $procMgr = Vim::get_view(mo_ref => $guestOpMgr->processManager);
	
	eval {
		my $envVars = $procMgr->ReadEnvironmentVariableInGuest(vm =>$vm_view, auth => $guestCreds);
		foreach(@$envVars) {
			print $_ . "\n";
		}
	};
        if($@) {
                die(color("red") . "Error: " . $@ . color("reset") . "\n\n");
        }
} else {
	&print("Invalid operation!\n\n","red");
}

Util::disconnect();

sub acquireGuestAuth {
	my ($gOpMgr,$vmview,$gu,$gp) = @_;
	
	my $authMgr = Vim::get_view(mo_ref => $gOpMgr->authManager);
        my $guestAuth = NamePasswordAuthentication->new(username => $gu, password => $gp, interactiveSession => 'false');

        eval {
		&print("Validating guest credentials in " . $vmview->name . " ...\n","magenta");
                $authMgr->ValidateCredentialsInGuest(vm => $vmview, auth => $guestAuth);
        };
        if($@) {
                die(color("red") . "Error: " . $@ . color("reset") . "\n\n");
        } else {
	        &print("Succesfully validated guest credentials!\n","green");
        }

	return $guestAuth;
}

sub getVM {
	my ($vm) = @_;

	my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {'name' => $vm});	
	unless($vm_view) {
		Util::disconnect();
                &print("Unable to locate VM: \"$vm\"\n\n","red");
		exit 1;
	}
	return $vm_view;
}

sub getPassword {

	my ($pass1,$pass2);
	do {
		&print("Please enter the password for the guestOS: \n","yellow");
		$pass1 = &readPassword();
		&print("Please enter the password again to confirm: \n","yellow");
		$pass2 = &readPassword();
		
		if($pass1 ne $pass2) {
			&print("\nPasswords do not match! Please try again\n\n","red");
		}
	} while $pass1 ne $pass2;
	return $pass1;
}

sub readPassword {
	my $password;

	if($^O eq "MSWin32") {
                require Term::ReadKey;
                Term::ReadKey->import(qw(ReadMode));
                Term::ReadKey->import(qw(ReadLine));
                ReadMode('noecho');
                chomp($password = ReadLine(0));
                ReadMode('normal');
        } else {
                system("stty -echo") and die "ERROR: stty failed\n";
                chomp ($password = <STDIN>);
                system("stty echo") and die "ERROR: stty failed\n";
        }
        return $password;
}

sub getStatus {
        my ($taskRef,$message) = @_;

        my $task_view = Vim::get_view(mo_ref => $taskRef);
        my $taskinfo = $task_view->info->state->val;
        my $continue = 1;
        while ($continue) {
                my $info = $task_view->info;
                if ($info->state->val eq 'success') {
                        print color("green") . $message . color("reset");
                        return $info->result;
                        $continue = 0;
                } elsif ($info->state->val eq 'error') {
                        my $soap_fault = SoapFault->new;
                        $soap_fault->name($info->error->fault);
                        $soap_fault->detail($info->error->fault);
                        $soap_fault->fault_string($info->error->localizedMessage);
			Util::disconnect();
                        die color("red") . $soap_fault . color("reset") . "\n";
                }
                sleep 5;
                $task_view->ViewBase::update_view_data();
        }
}

#http://www.bryantmcgill.com/Shazam_Perl_Module/Subroutines/utils_convert_bytes_to_optimal_unit.html
sub prettyPrintData{
        my($bytes,$type) = @_;

        return '' if ($bytes eq '' || $type eq '');
        return 0 if ($bytes <= 0);

        my($size);

        if($type eq 'B') {
                $size = $bytes . ' Bytes' if ($bytes < 1024);
                $size = sprintf("%.2f", ($bytes/1024)) . ' KB' if ($bytes >= 1024 && $bytes < 1048576);
                $size = sprintf("%.2f", ($bytes/1048576)) . ' MB' if ($bytes >= 1048576 && $bytes < 1073741824);
                $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
                $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
        }
        elsif($type eq 'M') {
                $bytes = $bytes * (1048576);
                $size = sprintf("%.2f", ($bytes/1048576)) . ' MB' if ($bytes >= 1048576 && $bytes < 1073741824);
                $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
                $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
        }

        elsif($type eq 'G') {
                $bytes = $bytes * (1073741824);
                $size = sprintf("%.2f", ($bytes/1073741824)) . ' GB' if ($bytes >= 1073741824 && $bytes < 1099511627776);
                $size = sprintf("%.2f", ($bytes/1099511627776)) . ' TB' if ($bytes >= 1099511627776);
        }
        elsif($type eq 'MHZ') {
                $size = sprintf("%.2f", ($bytes/1e-06)) . ' MHz' if ($bytes >= 1e-06 && $bytes < 0.001);
                $size = sprintf("%.2f", ($bytes*0.001)) . ' GHz' if ($bytes >= 0.001);
        }

        return $size;
}

sub downloadFile {
        my ($url,$src_file,$dst_file) = @_;

	my $basename = basename($src_file);
	my $contents = get($url);

	&print("Downloading file: \"$basename\" ...\n\n","green");
	open(CONTENTS,">$basename");
	print CONTENTS $contents;
	close(CONTENTS);
}

sub uploadFile {
	my ($url,$src_file,$dst_file) = @_;

	my $basename = basename($src_file);

	open(FILE, $src_file) || die("Could not open file!");
	my $content = do { local $/; <FILE> };
	close(FILE);

	my $ua = LWP::UserAgent->new();
        my $req = HTTP::Request->new(PUT => $url);
        $req->content($content);
        my $res = $ua->request($req);

	if($res->is_success()) {
		&print("Succesfully uploaded to guest!\n","green");
	} else {
		&print($res->error_as_HTML . "\n\n","red");
	}
}

sub validateSystem {
        my ($ver,$product) = @_;

        if(!grep(/$ver/,@supportedVersion)) {
                Util::disconnect();
                &print("Error: This script only supports vSphere \"@supportedVersion\" versions!\n\n","red");
                exit 1;
        }

	if($product ne $productSupport && $productSupport ne "both") {
		Util::disconnect();
                &print("Error: This script only supports vSphere $productSupport!\n\n","red");
                exit 1;
	}
}

# prompt user taken from http://devdaily.com/perl/edu/articles/pl010005#comment-159
sub promptUser {
        my($prompt) = @_;
        print color("black","on_yellow") . "\t$prompt:" . color("reset") . " ";
        chomp(my $input = <STDIN>);
        return $input;
}

sub print {
	my ($msg,$color) = @_;

	print color($color) . $msg . color("reset");
}

=head1 NAME

guestOpsManagement.pl - Script to perform guest operations in virtual machines

=head1 Examples

=over 4

=item List available datastore clusters

=item 

./guestOpsManagement.pl --server [VCENTER_SERVER|ESXi_SERVER] --username [USERNAME] --operation validate

=item

=item List Process IDs (ps)

./guestOpsManagement.pl --server [VCENTER_SERVER|ESXi_SERVER] --username [USERNAME] --operation ps --guestusername [GUEST_USERNAME]

=item Start program in guestOS

./guestOpsManagement.pl --server [VCENTER_SERVER|ESXi_SERVER] --username [USERNAME] --operation startprog --guestusername [GUEST_USERNAME] --working_dir [WORKING_DIR] --program_path [FULL_PATH_TO_PROGRAM] --program_args [PROGRAM_ARGS]

=item

=item List a directory (ls)

./guestOpsManagement.pl --server [VCENTER_SERVER|ESXi_SERVER] --username [USERNAME] --operation ls --guestusername [GUEST_USERNAME] --filepath_src [PATH]

=item

=item Create a directory (mkdir)

./guestOpsManagement.pl --server [VCENTER_SERVER|ESXi_SERVER] --username [USERNAME] --operation mkdir --guestusername [GUEST_USERNAME] --filepath_src [DIR}

=item

=item Remove a directory (rmdir)

./guestOpsManagement.pl --server [VCENTER_SERVER|ESXi_SERVER] --username [USERNAME] --operation rmdir --guestusername [GUEST_USERNAME] --filepath_src [DIR}

=item

=item Remove a file (rm)

./guestOpsManagement.pl --server [VCENTER_SERVER|ESXi_SERVER] --username [USERNAME] --operation rm --guestusername [GUEST_USERNAME] --filepath_src [FILEPATH]

=item

=item Move a file (mv)

./guestOpsManagement.pl --server [VCENTER_SERVER|ESXi_SERVER] --username [USERNAME] --operation mv --guestusername [GUEST_USERNAME] --filepath_src [FILEPATH_SRC] --filepath_dst [FILEPATH_DST]

=item

=item Move a directory (mvdir)

./guestOpsManagement.pl --server [VCENTER_SERVER|ESXi_SERVER] --username [USERNAME] --operation mvdir --guestusername [GUEST_USERNAME] --filepath_src [DIR_SRC] --filepath_dst [DIR_DST]

=item Copy a file from guestOS

./guestOpsManagement.pl --server [VCENTER_SERVER|ESXi_SERVER] --username [USERNAME] --operation copyfromguest --guestusername [GUEST_USERNAME] --filepath_src [SRC_FILE] 
	
=item

=item Upload a file to guestOS

./guestOpsManagement.pl --server [VCENTER_SERVER|ESXi_SERVER] --username [USERNAME] --operation uploadtoguest --guestusername [GUEST_USERNAME] --filepath_src [SRC_FILE] --filepath_dst [DST_FILE]

=item 

=back

=head1 SUPPORT

vSphere 5.0

=head1 AUTHORS

William Lam, http://www.williamlam.com/

=cut
