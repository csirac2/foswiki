package Foswiki::Plugins::ImmediateNotifyPlugin::Jabber;

use strict;
use Net::Jabber qw(Client);

use vars qw($user $pass $server $wikiuser $web $topic $debug $warning);

# ========================
# initMethed - initializes a single notification method
# Parametrs $topic, $web, $user
#    $topic is the current topic
#    $web is the web in which the topic is stored
#    $user is the logged-in user
sub initMethod {
    ($topic, $web, $wikiuser) = @_;
    my $prefPrefix = "IMMEDIATENOTIFYPLUGIN_JABBER_";
    $user = Foswiki::Func::getPreferencesValue($prefPrefix."USERNAME");
    $pass = Foswiki::Func::getPreferencesValue($prefPrefix."PASSWORD");
    $server = Foswiki::Func::getPreferencesValue($prefPrefix."SERVER");
    $wikiuser = $_[2];
    $debug = \&Foswiki::Plugins::ImmediateNotifyPlugin::debug;
    $warning = \&Foswiki::Plugins::ImmediateNotifyPlugin::warning;
    return defined($user) && defined($pass) && defined($server);
}

# ========================
# handleNotify - handles notification for a single notification method
# Parameters: $users
#    $users is a hash reference of the form username->user topic text
sub handleNotify {
    my ($users) = @_;
    
    my $con = new Net::Jabber::Client;
    &$debug("- Jabber: Connecting to server $server...");
    $con->Connect(hostname=>$server);
    unless ($con->Connected()) {
        &$warning("- Jabber: Could not connect to Jabber server $server");
        return;
    }
    &$debug("- Jabber: Connected, logging in w/$user and $pass...");
    my @authResult = $con->AuthSend(username=>$user, password=>$pass, resource=>"foswiki");
    if ($authResult[0] ne 'ok') {
        &$warning("- Jabber: Could not log in to Jabber server $server ($user, $pass): $authResult[0] $authResult[1]");
        $con->Disconnect();
        return;
    }
    &$debug("- Jabber: Logged in OK, sending messages...");
    my $mainWeb = Foswiki::Func::getPreferencesValue("MAINWEB") || "Main";
    my $toolName = Foswiki::Func::getPreferencesValue("WIKITOOLNAME") || "Foswiki";
    foreach my $user (keys %$users) {
        # get jabber userid
	my $jabberID;
        if (${ $users->{$user} } =~ /Jabber:\s*(.+)/) {
	    $jabberID = $1;
	}
        unless (defined($jabberID) && length($jabberID) > 0) {
	    &$debug("- Jabber: User $user has no Jabber: line!");
	    next;
	}
	&$debug("- Jabber: User $user: $jabberID");
        my $message = new Net::Jabber::Message;
        my $body = "$web.$topic on $toolName has been updated by $wikiuser!";
        $message->SetMessage(to=>$jabberID, from=>"$user\@$server", body=>$body);
        $con->Send($message);
    }

    $con->Disconnect();
}

1;

