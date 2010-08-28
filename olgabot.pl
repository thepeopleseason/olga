#!/usr/bin/perl

use strict;
use IO::Socket;
use Net::IRC;
use Text::Autoformat qw(autoformat form);

use vars qw ($aol_name $aol_pass);
($aol_name, $aol_pass) = qw(OlgaBot soffian);

srand;
main();
exit 0;

sub main {
  my $irc = new Net::IRC;
  my $conn = $irc->newconn(Nick    => 'Olga',
			   Server  => 'redshift.maude.corp.loudcloud.com',
			   Port    => 6667,
			   Ircname => 'Olga');

  $conn->add_handler('endofmotd', \&on_connect);
  $conn->add_handler('nomotd'   , \&on_connect);
  $conn->add_handler('invite',    \&on_invite);
  $conn->add_handler('public',    \&on_public);
  $conn->add_handler('msg',       \&on_msg);
  $conn->add_handler('join',      \&on_join);
  $conn->add_handler('topic',     \&on_topic);
  $conn->add_global_handler('disconnect', \&on_disconnect);
  $irc->start;
}

#
# handlers defined below
#

sub on_disconnect {
  my ($self, $event) = @_;
  print "Disconnected from ", $event->from(), " (", ($event->args())[0], "). Attempting to reconnect...\n";
  sleep 1;
  $self->connect();
}

sub on_connect {
  # what to do after connecting
  my ($self, $event) = @_;
  print "Signing on to AIM\n";
  sleep 1;
  $self->privmsg('aimserv','signoffall');
  sleep 1;
  $self->privmsg('aimserv','signon '.$aol_name.' '.$aol_pass);
}

sub on_invite {
  # what to do on invite to a channel
  my ($self, $event) = @_;
  my $channel = ($event->args)[0];
  print "Joining $channel\n";
  $self->join($channel);
}

sub on_join {
  # what to do when someone joins a channel
  my ($self, $event) = @_;
  my ($nick, $my_nick) = ($event->nick, $self->nick);
  my $channel = ($event->to)[0];
  if ($nick eq $my_nick) {
    print "Joined $channel\n";
  } else {
    print "$nick has joined $channel\n";
  }
}

sub on_topic {
  # what to do when the channel topic changes
  my ($self, $event) = @_;
  my ($channel, $topic) = ($event->args)[1,2];
  print "Topic for $channel is '$topic'\n";
}

sub on_public {
  # what to do when something is said publicly on a channel
  my ($self, $event) = @_;
  my $to = $event->to;
  my ($nick, $my_nick) = ($event->nick, $self->nick);
  my $text = ($event->args)[0];
  # XXX debug
  printf "%s: [on_public] <%s> %s\n", scalar localtime, join(',',@$to), $text;
  # handle aimirc invites
  if (grep(/^#aimirc-$aol_name$/i, @$to)) { # said on aimirc channel
     if ($text =~ /To accept, join (#aimchat-\d+)/) {
        print "Joining $1\n";
        $self->join($1);
        return;
     }
  }
  return unless $text =~ /^$my_nick,/i; # not said to me
  $text =~ s/^$my_nick,//i;
  dispatch($self, $event, $to, \$text)
}

sub on_msg {
  # what to do when a private message is sent to me
  my ($self, $event) = @_;
  my $text = ($event->args)[0];
  $text =~ s/^ *//;
  my $to = $event->nick;
  # XXX debug
  printf "%s: [on_msg] <%s> %s\n", scalar localtime, $to, $text;
  dispatch($self, $event, [$to], \$text) unless $to =~ /aimserv/i;
}

###
### dispatch and related get_* functions
###

sub dispatch {
  # dispatch function, match regexes against text said to me
  # and act upon it.
  my ($self, $event, $reply_to, $text) = @_;
 
  # cleanup the text
  $$text =~ s/^\s*//;
  $$text =~ s/\s*$//;
  $$text =~ s/\s{2,}/ /g;

  # XXX debug
  printf "%s: [dispatch] <%s> %s\n", scalar localtime, join(',',@$reply_to), $$text;

  # handlers
  my %handlers = 
    (qr/^quote (.*)/i      => sub{get_stockquotes('short', @_)},
     qr/^quotelong (.*)/i  => sub{get_stockquotes('long', @_)},
     qr/^quotejay$/i       => sub{get_rndfquote('/home/jay/code/fun/olga_db/jayquotes.txt')},
     qr/^word$/i           => sub{get_rndfquote('/usr/share/dict/words')},
     qr/^abuse$/i          => sub{get_abuse()},
     qr/^abuse (.{1,20})/i => \&get_abuse,
     qr/^drink$/i          => \&get_drink,
     qr/^help$/i           => \&get_help,
    );

  # default reply
  my $reply = ["Watchu talkin 'bout holmes? (try 'help')"];
  
  # check for a match
  my @match;
  foreach my $regex (keys %handlers) {
    if ((@match = $$text =~ $regex)) {
      eval {$reply = $handlers{$regex}->(@match)};
      if ($@) {
	warn $@;
	$reply = ["I'm having issues right now, please try again later."];
      }
      last;
    }
  }
  my $count;
  foreach (@$reply ) {
    chomp;
    printf "%s: [dispatch] <%s> %s\n", scalar localtime, $self->nick, $_;
    $self->privmsg(@$reply_to, $_."\n");
    select(undef, undef, undef, 0.25*++$count);
  }
}

sub get_help {
   my $help=<<'END_HELP';
Here's what you can ask me to do:
  * quote <ticker> [<ticker> ...]
  * quotelong <ticker> [<ticker> ...]
  * quotejay
  * word
  * abuse [<person>]
  * drink
  * help
END_HELP
  return [split(/\n/, autoformat($help, {all=>1}))];
}

sub get_rndfquote {
  my $line = randline(@_);
  return ['Not available, please try again later.'] unless $line;
  return [split(/\n/, autoformat $line)];
}

sub get_stockquotes {
  # get a stock quote using yahoo
  my $style = shift;
  my @symbols = split(' ',@_[0]);
  my $symbols = join('+', map{tr/a-zA-Z0-9//cd;$_} @symbols[0..3]);
  my $uri = "http://quote.yahoo.com/q?s=${symbols}&o=t&d=v4";
  my $page = grab_page($uri);
  return ['Not available, please try again later.'] unless $page;
  my ($quotes) = $$page =~  m{
			      ^Symbol\ Name.*?$
			      (.*?)
			      ^$
			     }smx;
  $quotes =~ s/<[^>]*>//g;              # nix html tags
  $quotes =~ s/^(.*)Chart,.*$/$1/gm;    # nix trailing links
  $quotes =~ s/No such ticker.*/No such ticker/gm;
  $quotes =~ s/ {2,}/|/g;
  my (@reply,$format);
  if ($style eq 'short') {
    @reply  = ('Tckr  Name                Last Trade  Mkt Cap');
    $format =  '[[[[[ [[[[[[[[[[[[[[[  [[[[[[ ]]].[[  ]]]]]]]';
  } else {
    @reply  = ('Tckr  Name               Last Trade  Mkt Cap Ern/Sh    P/E     52-week Range');
    $format =  '[[[[[ [[[[[[[[[[[[[[[ [[[[[[ ]]].[[  ]]]]]]] ]]].[[  ]]]]] ]]].[[[[ ]]].[[[[';
  }
  foreach my $quote (split(/\n/,$quotes)) {
    my @fields = $style eq 'short' ? (split(/\|/, $quote))[0..4] : split(/\|/, $quote);
    if ($quote =~ /No such ticker/) {
      push(@reply, sprintf "%-5s %s", @fields[0,1]);
    } else {
      push(@reply, form {numeric => 'AllPlaces', trim => 1}, $format, @fields);
    }
  }
  foreach (@reply) {
     s!^([^\n]*)!<font face=courier>$1</font>\n!;
  }
  return \@reply;
}

sub get_abuse {
  my ($insultee) = @_;
  # get an insult using upstartx.com
  my $uri = "http://www.upstartx.com/abuse/abuse.shtml";
  my $page = grab_page($uri);
  return ['Not available, please try again later.'] unless $page;
  my ($insult) = $$page =~  m{
                              ^<P\ ALIGN=CENTER><B>\s*
			      (.*?)
                              ^$
			     }smx;
  return ['Not available, please try again later.'] unless $insult;
  $insult = $insultee . ', ' . lc $insult if $insultee;
  return [split(/\n/, autoformat $insult)];
}

sub get_drink {
  # get a drink using webtender
  my $uri = "http://www.webtender.com/db/drink/RAND";
  my $page = grab_page($uri);
  return ['Not available, please try again later.'] unless $page;
  my ($drink) = $$page =~  m{
                             ^<TABLE.*?$
                             \s*(.*?)
                             ^</TABLE></TD></TR>$
			     }smx;
  return ['Not available, please try again later.'] unless $drink;
  $drink =~ s/<[^>]*>//g;         # nix html tags
  $drink =~ s/:[^\n]*\n/: /gs;
  ($drink) = $drink =~ /(.*^Mixing instructions:.*?)$/sm;
  $drink =~ s/Ingredients:\s*\n//;
  $drink =~ s/Mixing instructions: //;
  $drink =~ s/\n{2,}/\n/g;
  return [split(/\n/,$drink)];
}

###
### Utility functions
###

sub randline {
  # return a random line from a file
  my ($file) = @_;
  my $line;
  open(IN,"<$file") or return undef;
  rand($.) < 1 && ($line = $_) while <IN>;
  close IN;
  $line;
}

sub grab_page {
  # grab a URL
  my $uri = shift;
  my ($host, $url)  = $uri =~ m%^http://([^/]*)(.*)%;
  return undef unless ($host && $url);
  my ($host, $port) = split(':',$host);
  $port ||= 80;
  my $s = IO::Socket::INET->new(PeerAddr => $host, 
                                PeerPort => $port);
  return undef unless $s;
  $s->print("GET $url HTTP/1.0\r\n");
  $s->print("Host: $host\r\n\r\n");
  my $page;
  while(<$s>) {
    next if (1 .. /^\s*$/); # skip header lines
    $page .= $_;
  }
  return \$page;
}
