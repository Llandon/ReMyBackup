#!/usr/bin/perl

## Copyright (c) 2010-2011, Andreas Schwarz andreas.schwarz@uni-erlangen.de
##
## Permission to use, copy, modify, and/or distribute this software for any
## purpose with or without fee is hereby granted, provided that the above
## copyright notice and this permission notice appear in all copies.
##
## THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
## WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
## MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
## ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
## WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
## ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
## OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

## Remote MySQL backup skript 0.1.2

use warnings;
use strict;

use DBI;
use POSIX qw(strftime);
use Config::Simple;
use Term::ANSIColor;
use Getopt::Long;
use Data::Dumper;
use Net::OpenSSH;

sub buildPathStr;
sub pLogErrExit($);

my $debug  = undef;
my $client = undef;

# read command line arguments #################################################

GetOptions (
	'debug'    => \$debug, # flag
	'client=s' => \$client # string
) or do {
	pLogErrExit("MySQL backup failed, error while getting options from cmd.");
};

# build config paths ##########################################################

my $cfgPath       = '/etc/mysql-backup/';
my $mainCfgFile   = $cfgPath . 'main.cfg';

my $clientCfgPath = $cfgPath . 'clients/';
my $clientCfgFile = $clientCfgPath . $client;

# get configuration ###########################################################
                                                           # import main config
my %mainCfg;
Config::Simple->import_from($mainCfgFile, \%mainCfg) or do {
	pLogErrExit(Config::Simple->error());
};
                                                         # import client config
my %clientCfg;
Config::Simple->import_from($clientCfgFile, \%clientCfg) or do {
	pLogErrExit(Config::Simple->error());
};
                                            # assign variables from main config
my $mysqlClient = $mainCfg{mysqlClient};
my $mysqldump   = $mainCfg{mysqldump};
my $backupvault = $mainCfg{backupvault};
my @dbexcludes  = @{$mainCfg{dbexcludes}};
my @sepdumpopt;
my @alldumpopt;
                                           # check if compatibility mode is set
if($clientCfg{compmode}) {
	@sepdumpopt  = @{$mainCfg{sepdumpoptcomp}};
	@alldumpopt  = @{$mainCfg{alldumpoptcomp}};
}else{
	@sepdumpopt  = @{$mainCfg{sepdumpopt}};
	@alldumpopt  = @{$mainCfg{alldumpopt}};
}
                                           # assign variables from [client].cfg
my $dbuser = $clientCfg{dbuser};
my $dbpass = $clientCfg{dbpass};
my $dbhost = $clientCfg{dbhost};
my $ruser  = $clientCfg{ruser};
my $rhost  = $clientCfg{rhost};
my $rport  = $clientCfg{rport};
   $rport  = "22" if !$rport or $rport eq "";
my $rname  = $clientCfg{rname};

# create backup directory if necessary ########################################
                                                     # build backup path string
my $date      = strftime("%A", localtime);
my $backupdir = buildPathStr($backupvault,$rname,$date);

# get all remote databases ####################################################
                                                          # open ssh connection
my $ssh = Net::OpenSSH->new("$ruser\@$rhost:$rport");
$ssh->error and pLogErrExit("Can't ssh to $rhost: " . $ssh->error);
                                          # build database query command string
my $showDbStr = "$mysqlClient ".
	"--user='$dbuser' --password='$dbpass' --host='$dbhost' ".
	"--raw --batch --skip-column-names --execute 'SHOW DATABASES'";
                                                      # execute command via ssh
my @databases = $ssh->capture($showDbStr);
if($ssh->error) {
	pLogErrExit("remote $mysqlClient failed on $rhost: " . $ssh->error);
}

# separate files backup #######################################################
                                                   # iterate over all databases
foreach my $db (@databases) {
	$db =~ s/\R//g; # remove every kind of line break
	next if grep(/$db/, @dbexcludes);
                                                             # build dumpstring
	my $dumpstr = "$mysqldump " .
		"--user='$dbuser' --password='$dbpass' --host='$dbhost' ".
		"--databases '$db' @sepdumpopt";

	print colored("[Backup ($db)]\n", 'bold green');
	if($debug) {
		print "$dumpstr\n";
	}else{
		if(!open(my $fh, ">", $backupdir . $db . ".sql")) {   # open filehandle
			my $errmsg = 
				"Warning: can't dump database $db from $rname ($rhost). " .
				"Error opening filehandle: " . $! . "\n";
			print $errmsg;
		}else{                                        # execute command via ssh
			$ssh->system({stdout_fh => $fh}, $dumpstr);       # and write to fh
			if($ssh->error) {
				my $errmsg = 
					"Warning: can't dump database $db from $rname ($rhost). " .
					"Error while SSH command: " . $ssh->error . "\n";
				print $errmsg;
}
			close($fh);
		}
	}
}

# all in one backup ###########################################################
                                                             # build dumpstring
my $dumpstr = "$mysqldump " .
	"--user='$dbuser' --password='$dbpass' --host='$dbhost' @alldumpopt";

print colored("[Backup all databases]\n", 'bold green');
if($debug) {
	print "$dumpstr\n";
}else{
	if(!open(my $fh, ">", $backupdir."all-databases.sql")) {  # open filehandle
		my $errmsg =
			"Warning: can't dump databases from $rname ($rhost) . " . 
			"Error opening filehandle: " . $! . "\n";
		print $errmsg;
	}else{                                            # execute command via ssh
		$ssh->system({stdout_fh => $fh}, $dumpstr);           # and write to fh
		if($ssh->error) {
			my $errmsg = 
				"Warning: can't dump databases from $rname ($rhost). " . 
				"Error while SSH command: " . $ssh->error . "\n";
			print $errmsg;
}
		close($fh);
	}
}


exit 0;

# Subroutines #################################################################

sub buildPathStr {
	my $pathStr = '';
	foreach my $pathElem (@_) {
		$pathStr .= $pathElem;
		$pathStr .= '/' if(substr $pathStr, -1) ne '/';
	}
	return $pathStr;
}
                                            # print message (on debug) and exit
sub pLogErrExit($) {
	my $message = shift;
	
	print $message if $debug;

	exit 1;
}
