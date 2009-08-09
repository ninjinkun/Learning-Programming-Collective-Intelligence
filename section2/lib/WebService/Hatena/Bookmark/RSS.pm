package WebService::Hatena::Bookmark::RSS;
use strict;
use warnings;
use XML::RSS::LibXML;
use Perl6::Say;
use URI;
use Readonly;
use LWP::UserAgent;
use Encode;
use Digest::SHA1 qw(sha1_hex);

use Exporter::Lite;
our @EXPORT = qw/get_popular get_userposts get_urlposts/;
Readonly my $BASE_URL => "http://b.hatena.ne.jp";

use Cache::File;
my $cache = Cache::File->new(
    cache_root => '/var/tmp',
    default_expires => '86400 sec',
) or die;

my $ua = LWP::UserAgent->new(
    timeout => 10,
);

sub get_urlposts {
    my $url = shift;
    my $req_uri = URI->new($BASE_URL . '/entry/rss/' . $url);
    my $rss = _get_feed($req_uri);
    $rss or return [];
    return $rss->{items} || [];
}

sub get_userposts {
    my $user = shift;
    my $req_uri = URI->new($BASE_URL . '/' . $user . '/rss');
    my $rss = _get_feed($req_uri);
    $rss or return [];
    return $rss->{items} || [];
}

sub get_popular {
    my $tag = shift;
    my $req_uri;
    if ($tag) {
        $req_uri = URI->new($BASE_URL . '/t/' . $tag);
        $req_uri->query_form(
            sort => 'hot',
            mode => 'rss',
        );
    }
    else {
        $req_uri = URI->new($BASE_URL . '/hotentry.rss');
    }
    my $rss = _get_feed($req_uri);
    $rss or return [];
    return $rss->{items} || [];
}

sub _get_feed {
    my $url = shift;
    my $content;
    my $rss = $cache->thaw(_key($url));
    if (!$rss) {
        my $res;
        for (0..2) {
            say "access to $url";
            $res = $ua->get($url);
            last if ($res->is_success);
            sleep(4);
        }
        return if $res->is_error;
        say "done $url";
        $content = $res->content;
        eval {
            $rss = XML::RSS::LibXML->new->parse($content);
        };
        if ($@) {
            return;
        }
        $cache->freeze(_key($url), $rss);
    }
    else {
        say "cache hit! $url";
    }
    return $rss;
}

sub _key {
    my $key = shift;
       $key =~ s/\s//g;
       $key = sha1_hex(Encode::is_utf8($key) ? Encode::encode('utf8', $key) : $key);
       $key;
}


1;
