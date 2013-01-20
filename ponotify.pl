### IRSSI Pushover.net Notification Script

# DO NOT EDIT ANYTHING BELOW THIS LINE

use strict;
use warnings;
use Irssi;
use Irssi::Irc;
use LWP::UserAgent;
use vars qw($VERSION %config);

$VERSION = '1.0';

$config{awayreason} = 'Auto-away: Screen Disconnected.';
$config{clientcount} = 0;
$config{away_level} = 0;

Irssi::settings_add_bool('PONotify', 'ponotify_debug', 0);
Irssi::settings_add_str('PONotify', 'ponotify_user_key', '');


sub debug
{
  return unless Irssi::settings_get_bool('ponotify_debug');

  my $text = shift;
  my $caller = caller;
  Irssi::print('From '.$caller.':'."\n".$text."\n");
}

sub send_notification
{
  debug('Sending notification.');

  my $po_user_key = Irssi::settings_get_str('ponotify_user_key');
  if (!$po_user_key) {
    debug('Missing credentials. You must set before this will work.');
    return;
  }

  my ($event, $text) = @_;

  my $req = LWP::UserAgent->new()->post(
    "https://api.pushover.net/1/messages.json", [
    "token" => "jLnTeNCfnt9bukrjIEf30iqnTEuNpb",
    "user" => $po_user_key,
    "message" => $text
#    "message" => "From irssi: '.$event.':'."\n".$text."\n",
    ]
  );
}

sub client_connect
{
  my (@servers) = Irssi::servers;
  $config{clientcount}++;
  debug('Client connected to session.');

  foreach my $server (@servers) {
    if ($server->{usermode_away} == 1) {
      $server->send_raw('AWAY :');
    }
  }
}

sub client_disconnect
{
  my (@servers) = Irssi::servers;
  debug('Client disconnected from session.');
  $config{clientcount}-- unless $config{clientcount} == 0;

  if ($config{clientcount} <= $config{away_level}) {
    foreach my $server (@servers) {
      if ($server->{usermode_away} == '0') {
        $server->send_raw('AWAY :' . $config{awayreason});
      }
    }
  }
}

sub public_msg
{
  my ($server, $data, $nick, $channel) = @_;
  my $safeNick = quotemeta($server->{nick});
  if ($server->{usermode_away} == '1' && $data =~ /$safeNick/i) {
    debug('Public mention received.');
   send_notification('Public Mention', 'PUBMSG from '.$nick.' in '.$channel.': '.strip_formatting($data));
  }
}

sub private_msg
{
  my ($server, $data, $nick) = @_;
  if ($server->{usermode_away} == '1') {
    debug('Private message received.');
    send_notification('Private Message', 'PRIVMSG from '.$nick.': '.strip_formatting($data));
  }
}

sub strip_formatting
{
  my ($msg) = @_;
  $msg =~ s/\x03[0-9]{0,2}(,[0-9]{1,2})?//g;
  $msg =~ s/[^\x20-\xFF]//g;
  $msg =~ s/\xa0/ /g;
  return $msg;
}

Irssi::signal_add_last('screen connected', 'client_connect');
Irssi::signal_add_last('screen disconnected', 'client_disconnect');
Irssi::signal_add_last('message public', 'public_msg');
Irssi::signal_add_last('message private', 'private_msg');

Irssi::print('PONotify '.$VERSION.' loaded.');
if (!Irssi::settings_get_str('ponotify_user_key')) {
  Irssi::print('PONotify: User key is not set. Set it with /set ponotify_user_key <key>.');
}

