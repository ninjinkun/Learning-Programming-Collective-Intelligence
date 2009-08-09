package My::Bookmark;
use strict;
use warnings;
use Coro;
use Coro::LWP;
use WebService::Hatena::Bookmark::RSS;
use Exporter::Lite;
our @EXPORT = qw/init_user_dict fill_items/;
use Readonly;
Readonly my $MAX_CONNECTIONS => 100;

## データセットを作る
sub init_user_dict {
    my $tag = shift;
    my $count = shift || 5;
    my $user_dict = {};
    my $popular_list = get_popular($tag);
    my $i = 0;
    my $connection_count = 0;
    my @coros;
    for my $p1 (@$popular_list) {
        last if $count <= $i;
        push @coros, async {
            my $url_posts = get_urlposts($p1->{link});
            for my $p2 (@$url_posts) {
                my $user = $p2->{title};
                next if exists $user_dict->{$user};
                $user_dict->{$user} = {};
            }
        };
        $connection_count++;
        if ($connection_count > $MAX_CONNECTIONS) {
            $_->join for @coros;
            $connection_count = 0;
        }
        $i++;
    }
    $_->join for @coros;
    return $user_dict;
}

sub fill_items {
    my $user_dict = shift;
    my $all_items = {};
    my @coros;
    ## すべてのユーザによって投稿されたリンクを取得
    my $connection_count = 0;
    for my $user (keys %$user_dict) {
        push @coros, async {
            my $posts = get_userposts($user);
            for my $post (@$posts) {
                my $url = $post->{link};
                $user_dict->{$user}->{$url} = 1.0;
                $all_items->{$url} = 1;
            }
        };
        $connection_count++;
        if ($connection_count > $MAX_CONNECTIONS) {
            $_->join for @coros;
            $connection_count = 0;
        }
    }
    $_->join for @coros;
    ## 空のアイテムを0で埋める
    for my $ratings (values %$user_dict) {
        for my $item (keys %$all_items) {
            if (!defined $ratings->{$item}) {
                $ratings->{$item} = 0.0;
            }
        }
    }
}

1;
