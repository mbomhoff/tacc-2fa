#!/usr/bin/env perl

use warnings;
use strict;

use Switch;
use LWP::UserAgent;
use Expect;
use Storable;

my $configFilename = "tacc2fa.cfg";

my $hostname = shift;
my $remoteCommand = join(" ", @ARGV);
unless ($hostname && $remoteCommand) {
    usage();
    exit;
}

my $conf;
if (-e $configFilename) {
    $conf = retrieve($configFilename);
}
else {
    $conf = init();
}

my $command = "ssh " . ( $conf->{username} ?  $conf->{username} . "@" : "") . $hostname . " " . $remoteCommand;
print $command, "\n";
my $exp = Expect->spawn($command)
    or die "Cannot spawn $command: $!\n";

sleep 3;

my $twilioUrl = "https://api.twilio.com/2010-04-01/Accounts/" . $conf->{twilioID} . "/SMS/Messages.csv?PageSize=1";
my $ua = new LWP::UserAgent;
my $request_ua = HTTP::Request->new( GET => $twilioUrl );
$request_ua->authorization_basic( $conf->{twilioID}, $conf->{twilioPass} );
my $response = $ua->request($request_ua);
my $entries = $response->content;

my ($code) = $entries =~ /This is an automated message from TACC\. Your 2\-factor code is (\d+)/s;

$exp->expect(10, '-ex', 'TACC Token Code:', sub { sleep 2; $exp->send("$code\n"); });
$exp->soft_close();

exit;

#------------------------------------------------------------------------------

sub init {
    print "Enter TACC username: ";
    my $username = <STDIN>; chomp $username;
    print "Enter TACC password: ";
    my $password = <STDIN>; chomp $password;
    print "Enter Twilio SID: ";
    my $twilioID = <STDIN>; chomp $twilioID;
    print "Enter Twilio Auth Token: ";
    my $twilioPass = <STDIN>; chomp $twilioPass;

    my $conf = { username => $username, password => $password, twilioID => $twilioID, twilioPass => $twilioPass };
    store($conf, $configFilename);
    chmod(0600, $configFilename);
    return $conf;
}

sub usage {
    print "usage: tacc-2fa.pl <hostname> <remote-command>\n\n";
}
