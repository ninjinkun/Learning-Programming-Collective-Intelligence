#!perl
use strict;
use warnings;
use Perl6::Say;
use My::Bookmark;
use My::Recommendations;
use Getopt::Long;

my $use_cache;
my $tag;
my $user;
GetOptions(
    'tag=s'   => \$tag,
    'user=s',  => \$user,
);
my $b_users = init_user_dict($tag);
## オレも参加するぜ!
for my $user (qw/ninjinkun naoya motemen chris4403 birdie7 r_kurain cho45 onishi nmy nagayama riko wakabatan satzz/) {
    $b_users->{$user} = {};
}
fill_items($b_users);
my $item_match = calc_similar_items($b_users);
#say "topMaches in $user";
#say $_->[0] . ' : ' . $_->[1] for  top_matches($b_users, $user, 5, \&sim_pearson);
say "getRecommendations for $user";
my @recommendations = get_recommended_items($b_users, $item_match, $user);
#my @recommendations = get_recommendations($b_users, $user);
say $_->[0] . ' : ' . $_->[1] for @recommendations[0..4];
