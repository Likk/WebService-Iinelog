package WebService::Iinelog;

=encoding utf8

=head1 NAME

  WebService::Iinelog - iinelog.com client for perl.

=head1 SYNOPSIS

  use WebService::Iinelog;
  my $iine = WebService::Iinelog->new(
    email    => 'your email',    #require if you login
    password => 'your password', #require if you login
  );

  $iine->login(); #if you login
  my $tl = $iine->timeline();
  for my $row (@$tl){
    warn YAML::Dump $row;
  }

=head1 DESCRIPTION

  WebService::Iinelog is scraping library client for perl at iinelog.com

=cut

use strict;
use warnings;
use utf8;
use Carp;
use Encode;
use HTTP::Date;
use Web::Scraper;
use WWW::Mechanize;
use YAML;

our $VERSION = '0.01';

=head1 CONSTRUCTOR AND STARTUP

=head2 new

Creates and returns a new iinelog.com object.

  my $lingr = WebService::Iinelog->new(
      email =>    q{iinelog.com login email},
      password => q{iinelog.com password},
  );

=cut

sub new {
    my $class = shift;
    my %args = @_;

    my $self = bless { %args }, $class;

    $self->{last_req} ||= time;
    $self->{interval} ||= 2;

    $self->mech();
    return $self;
}

=head1 Accessor

=over

=item B<mech>

  WWW::Mechanize object.

=cut

sub mech {
    my $self = shift;
    unless($self->{mech}){
        my $mech = WWW::Mechanize->new(
            agent      => 'Mozilla/5.0 (Windows NT 6.1; rv:28.0) Gecko/20100101 Firefox/28.0',
            cookie_jar => {},
        );
        $mech->stack_depth(10);
        $self->{mech} = $mech;
    }
    return $self->{mech};
}

=item B<interval>

sleeping time per one action by mech.

=item B<last_request_time>

request time at last;

=item B<last_content>

cache at last decoded content.

=cut

sub interval          { return shift->{interval} ||= 1    }
sub last_request_time { return shift->{last_req} ||= time }

sub last_content {
    my $self = shift;
    my $arg  = shift || '';

    if($arg){
        $self->{last_content} = $arg
    }
    return $self->{last_content} || '';
}

=item B<base_url>

=cut

sub base_url {
    my $self = shift;
    my $arg  = shift || '';

    if($arg){
        $self->{base_url} = $arg;
        $self->{conf}     = undef;
    }
    return $self->{base_url} || 'http://iinelog.com'
}

=back

=head1 METHODS

=head2 set_last_request_time

set request time

=cut

sub set_last_request_time { shift->{last_req} = time }


=head2 post

mech post with interval.

=cut

sub post {
    my $self = shift;
    $self->_sleep_interval;
    my $res = $self->mech->post(@_);
    return $self->_content($res);
}

=head2 get

mech get with interval.

=cut

sub get {
    my $self = shift;
    $self->_sleep_interval;
    my $res = $self->mech->get(@_);
    return $self->_content($res);
}

=head2 conf

  url path config

=cut

sub conf {
    my $self = shift;
    unless ($self->{conf}){
        my $base_url =  $self->base_url();
        my $conf = {
            home    =>      $base_url,
            enter   =>      sprintf("%s/users/sign_in",  $base_url),
            say     =>      sprintf("%s/items",          $base_url),
            tl      =>      sprintf("%s/items?page=",    $base_url),
            like    =>      sprintf("%s/likes?item_id=", $base_url),
            dislike =>      sprintf("%s/likes/", $base_url),
        };
        $self->{conf} = $conf;
    }
    return $self->{conf};
}

=head2 login

  sign in at http://iinelog.com/

=cut

sub login {
    my $self = shift;

    my $authenticity_token = '';
    {
        $self->get($self->conf->{enter});
        if($self->last_content() =~ m{<meta\scontent="(.*)?"\sname="csrf-token"\s/>}){
            $authenticity_token = $1;
        }
    }

    {
        my $params = {
            utf8                => '%E2%9C%93',
            authenticity_token  => $authenticity_token,
            'user[email]'       => $self->{email},
            'user[password]'    => $self->{password},
            'user[remember_me]' => 0,
            commit              => "%E3%82%B5%E3%82%A4%E3%83%B3%E3%82%A4%E3%83%B3%E3%81%99%E3%82%8B"
        };
        $self->post($self->conf->{enter}, $params);
    }
}

=head2 timeline

get timeline posts.

=cut

sub timeline {
    my $self = shift;
    my $args = shift || {};
    my $page = $args->{page} || 1;

    my $url = $self->conf->{tl} . $page;
    $self->get($url);

    $self->_parse($self->last_content);
}

=head2 say

post content to iinelog.com

=cut

sub say {
    my $self = shift;
    my $args = shift;

    my $authenticity_token = '';
    {
        $self->get($self->conf->{say});
        if($self->last_content() =~ m{<meta\scontent="(.*)?"\sname="csrf-token"\s/>}){
            $authenticity_token = $1;
        }
    }
    {
        my $content = {
            utf8                => "%E2%9C%9",
            authenticity_token  => $authenticity_token,
            'item[content]'     => Encode::decode_utf8($args->{content}),
            commit              => "%E3%82%A4%E3%82%A4%E3%83%8D%E3%82%92%E6%8A%95%E7%A8%BF%E3%81%99%E3%82%8B"
        };
        $self->post($self->conf->{say}, $content);
    }
}

=head2 like

favor a description.

=cut

sub like {
    my $self    = shift;
    my $post_id = shift;
    die 'require post_id' unless $post_id;

    my $authenticity_token = $self->_get_authenticity_token();

    my $headers = {
        'X-CSRF-Token'     => $authenticity_token,
        'Accept'           => "*/*;q=0.5, text/javascript, application/javascript, application/ecmascript, application/x-ecmascript",
        'Host'             => 'iinelog.com',
        'X-Requested-With' => 'XMLHttpRequest',
    };

    for my $key (keys %$headers ){
        $self->mech->add_header($key => $headers->{$key});
    }

    my $url = $self->conf->{like} . $post_id;
    $self->mech->post($url);

    for my $key (keys %$headers ){
        $self->mech->delete_header($key);
    }

}

=head2 dislike

reset to favor a description.

=cut

sub dislike {
    my $self    = shift;
    my $post_id = shift;
    die 'require favor_id' unless $post_id;

    my $authenticity_token = $self->_get_authenticity_token();

    my $headers = {
        'X-CSRF-Token'     => $authenticity_token,
        'Accept'           => "*/*;q=0.5, text/javascript, application/javascript, application/ecmascript, application/x-ecmascript",
        'Host'             => 'iinelog.com',
        'X-Requested-With' => 'XMLHttpRequest',
    };

    for my $key (keys %$headers ){
        $self->mech->add_header($key => $headers->{$key});
    }

    my $url = $self->conf->{dislike} . $post_id;
    $self->mech->delete($url);

    for my $key (keys %$headers ){
        $self->mech->delete_header($key);
    }
}

=head1 PRIVATE METHODS.

=over

=item get_authenticity_token

parse authenticity_token

=cut

sub _get_authenticity_token {
    my $self = shift;
    my $authenticity_token = '';

    $self->get($self->conf->{home});
    if($self->last_content() =~ m{<meta\scontent="(.*)?"\sname="csrf-token"\s/>}){
        $authenticity_token = $1;
    }
    else {
        die 'cant get authenticity_token';
    }
    return $authenticity_token;
}

=item B<_parse>

parse for timeline

=cut

sub _parse {
    my $self = shift;
    my $html = shift;
    my $tl = [];

    my $scraper = scraper {
        process '//div[@class="item"]', 'data[]'=> scraper {
            process '//div[@class="like-button-unpressed"]/a',                post_id     => '@href';
            process '//div[@class="item-content"]',                           description => 'TEXT';
            process '//ul[@class="item-info"]/li[@class="item-created-at"]',  timestamp   => '@title';
            process '//ul[@class="item-info"]/li[2]/a',                       user_name   => 'TEXT',
                                                                              user_id     => '@href';
            process '//div[@class="liked-users"]/a', 'favorites[]' => scraper{
                process '//*', user_name => '@title',
                               user_id   => '@href';
           };
        };
        result qw/data/;
    };
    my $result = $scraper->scrape($html);

    for my $row (@$result){
        my $line = {
            user_id     => [ split m{/}, $row->{user_id}  ]->[-1],
            description => $row->{description},
            user_name   => [split /\s/,  $row->{user_name} ]->[0],
            timestamp   => HTTP::Date::str2time($row->{timestamp}),
            post_id     => [split /=/, $row->{post_id},   ]->[-1],
        };
        if(my $favorites = $row->{favorites}){
            $favorites = [
                map {
                    {
                        user_name => [ split /\s/, $_->{user_name} ]->[0],
                        user_id   => [ split m{/}, $_->{user_id}  ]->[-1],
                    };
                } @{ $favorites }
            ];
            $line->{favorites} = $favorites;
        }
        push @$tl, $line;
    }
    return $tl;
}

=item B<_sleep_interval>

アタックにならないように前回のリクエストよりinterval秒待つ。

=cut

sub _sleep_interval {
    my $self = shift;
    my $wait = $self->interval - (time - $self->last_request_time);
    sleep $wait if $wait > 0;
    $self->set_last_request_time();
}

=item b<_content>

decode content with mech.

=cut

sub _content {
  my $self = shift;
  my $res  = shift;
  my $content = $res->decoded_content();
  $self->last_content($content);
  return $content;
}

=back


1;


__END__

=head1 AUTHOR

likkradyus E<lt>perl {at} li.que.jpE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
