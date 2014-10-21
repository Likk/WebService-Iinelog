use strict;
use warnings;
use utf8;
use 5.10.0;
use FindBin;
use lib "$FindBin::RealBin/../lib";
use Config::Pit;
use Encode;
use WebService::Iinelog;
use YAML;

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
my $tl  = $iine->timeline({ page => 1 }); #1ページを取得
for my $row (@$tl){
    warn YAML::Dump $row;
}
