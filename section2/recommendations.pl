#!/usr/bin/perl
use strict;
use warnings;
use Perl6::Say;
use My::Recommendations;
use XXX;

my $critics  = {
    'Lisa Rose'        => {
        'Lady in the Water'  => 2.5,
        'Snakes on a Plane'  => 3.5,
        'Just My Luck'       => 3.0,
        'Superman Returns'   => 3.5,
        'You, Me and Dupree' => 2.5,
        'The Night Listener' => 3.0,
    },
    'Gene Seymour'     => {
        'Lady in the Water'  => 3.0,
        'Snakes on a Plane'  => 3.5,
        'Just My Luck'       => 1.5,
        'Superman Returns'   => 5.0,
        'The Night Listener' => 3.0,
        'You, Me and Dupree' => 3.5,
    },
    'Michael Phillips' => {
        'Lady in the Water'  => 2.5,
        'Snakes on a Plane'  => 3.0,
        'Superman Returns'   => 3.5,
        'The Night Listener' => 4.0,
    },
    'Claudia Puig'     => {
        'Snakes on a Plane'  => 3.5,
        'Just My Luck'       => 3.0,
        'The Night Listener' => 4.5,
        'Superman Returns'   => 4.0,
        'You, Me and Dupree' => 2.5,
    },
    'Mick LaSalle'     => {
        'Lady in the Water'  => 3.0,
        'Snakes on a Plane'  => 4.0,
        'Just My Luck'       => 2.0,
        'Superman Returns'   => 3.0,
        'The Night Listener' => 3.0,
        'You, Me and Dupree' => 2.0,
    },
    'Jack Matthews'    => {
        'Lady in the Water'  => 3.0,
        'Snakes on a Plane'  => 4.0,
        'The Night Listener' => 3.0,
        'Superman Returns'   => 5.0,
        'You, Me and Dupree' => 3.5,
    },

    'Toby'             => {
        'Snakes on a Plane'  => 4.5,
        'You, Me and Dupree' => 1.0,
        'Superman Returns'   => 4.0,
    },
};


say "sim_distance between Lisa Rose and Gene Seymour";
say sim_distance($critics, 'Lisa Rose', 'Gene Seymour');

say "sim_pearson between Lisa Rose and Gene Seymour";
say sim_pearson($critics, 'Lisa Rose', 'Gene Seymour');

say "sim_tanimoto between Lisa Rose and Gene Seymour";
say sim_tanimoto($critics, 'Lisa Rose', 'Gene Seymour');


say;
say "topMaches in Toby";
say $_->[0] . ' : ' . $_->[1] for top_matches($critics, 'Toby', 3);
say $_->[0] . ' : ' . $_->[1] for top_matches($critics, 'Toby', 3, \&sim_tanimoto);

say "getRecommendations in Toby";
say $_->[0] . ' : ' . $_->[1] for get_recommendations($critics, 'Toby');
say $_->[0] . ' : ' . $_->[1] for get_recommendations($critics, 'Toby', \&sim_tanimoto);

say;
my $movies = transform_prefs($critics);
say "topMaches in Just My Luck";
say $_->[0] . ' : ' . $_->[1] for top_matches($movies, 'Just My Luck', 3);
say "getRecommendations in Just My Luck";
say $_->[0] . ' : ' . $_->[1] for get_recommendations($movies, 'Just My Luck');

say;
my $item_sim = calc_similar_items($critics);
say "getRecommendedItems in Toby";
say $_->[0] . ' : ' . $_->[1] for get_recommended_items($critics, $item_sim, 'Toby');
