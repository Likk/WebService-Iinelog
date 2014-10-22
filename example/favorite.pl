use strict;
use warnings;
use utf8;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Config::Pit;
use WebService::Iinelog;

my $iine = sub { #prepare
  local $ENV{EDITOR} = 'vi';
  my $pit = pit_get('iinelog.com', require => {
      email     => 'your email    on iinelog.com',
      password  => 'your password on iinelog.com',
    }
  );

  return WebService::Iinelog->new(
    %$pit
  );
}->();

$iine->login();
my $t = <STDIN>;
chomp $t;
$iine->like( $t );
#iine->dislike( $t );
