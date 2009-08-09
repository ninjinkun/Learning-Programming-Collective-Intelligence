package My::Recommendations;
use strict;
use warnings;
use List::Util qw/sum/;
use Perl6::Say;
use Exporter::Lite;
our @EXPORT = qw/sim_distance sim_pearson sim_tanimoto
                 top_matches get_recommendations
                 transform_prefs calc_similar_items get_recommended_items/;
use Cache::Memcached::Fast;
my $cache = Cache::Memcached::Fast->new({
    servers         => [ 'localhost:11211' ],
    compress_threshold => 500,
});

my $memo = {};

sub sim_distance {
    my ($prefs, $person1, $person2) = @_;
    my @si = grep { exists $prefs->{$person2}{$_} } keys %{$prefs->{$person1}};
    return 0 if scalar @si == 0;
    my $sum_of_squares = sum map { ($prefs->{$person1}{$_} - $prefs->{$person2}{$_}) ** 2 } @si;
    return 1 / (1 + $sum_of_squares);
}

sub sim_pearson {
    my ($prefs, $person1, $person2) = @_;
    my $si = {};
    $si->{$_} = 1 for grep { exists $prefs->{$person2}{$_} }
        keys %{$prefs->{$person1}};

    return 0 if (my $n = scalar keys %$si) == 0;
    ## 全ての嗜好を合計する

    my $sum1 = sum map { $prefs->{$person1}{$_} } keys %$si;
    my $sum2 = sum map { $prefs->{$person2}{$_} } keys %$si;

    ## 平方を合計する
    my $sum1Sq = sum map { $prefs->{$person1}{$_} ** 2 } keys %$si;
    my $sum2Sq = sum map { $prefs->{$person2}{$_} ** 2 } keys %$si;

    ## 積を合計する
    my $pSum = sum map { $prefs->{$person1}{$_} * $prefs->{$person2}{$_} } keys %$si;

    ## ピアソンによるスコアを計算する
    my $num = $pSum - ($sum1 * $sum2 / $n);

    my $den = sqrt( ($sum1Sq - $sum1 ** 2 / $n) * ($sum2Sq - $sum2 ** 2 / $n) );
    return 0 if $den == 0;

    return $num / $den;
}

sub sim_tanimoto {
    my ($prefs, $person1, $person2) = @_;
    my $si = {};
    $si->{$_} = 1 for grep { exists $prefs->{$person2}{$_} }
        keys %{$prefs->{$person1}};

    ## AとBの内積
    my $all_dot = sum map { $prefs->{$person1}{$_} * $prefs->{$person2}{$_} } keys %$si;
    ## それぞれの内積
    my $p1_dot = sum map { $_ ** 2 } values %{$prefs->{$person1}};
    my $p2_dot = sum map { $_ ** 2 } values %{$prefs->{$person2}};
    ## ORを内積の差で表現する
     my $den = $p1_dot + $p2_dot - $all_dot;

    return 0 if $den == 0;

    return $all_dot / $den;
}

sub top_matches {
    my ($prefs, $person1, $n, $similarity) = @_;
    $n ||= 5;
    $similarity ||= \&sim_pearson;
    my @sims;
    my $calc_count;
    ## 全ユーザのsimilarityを計算
    for my $person2 (keys %$prefs) {
        next if $person2 eq $person1;
        $memo->{$person2} = {} if !exists $memo->{$person2};
        my $sim = $memo->{$person2}->{$person1} ? $memo->{$person2}->{$person1} :
                  $memo->{$person1}->{$person2} ? $memo->{$person1}->{$person2} : undef;
        if (!$sim) {
            $sim = &$similarity($prefs, $person1, $person2);
            $memo->{$person2}->{$person1} = $sim;
            $calc_count++;
        }
        push @sims,  [$person2, $sim];
    }
    say "calculate similarity $calc_count times";
    ## スコア順に並び替え
    my @top_matches = sort { $b->[1] <=> $a->[1] } @sims;
    return splice(@top_matches, 0, $n);
}

sub get_recommendations {
    my ($prefs, $person, $similarity) = @_;
    $similarity ||= \&sim_pearson;

    my (%totals, %simSuns);
    for my $other (keys %$prefs) {
        ## 自分自身とは比較しない
        next if $other eq $person;

        my $sim = &$similarity($prefs, $person, $other);

        ## 0以下のスコアは無視する
        next if $sim <= 0;

        for my $item (keys %{$prefs->{$other}}) {
            ## まだ見ていない映画の特典のみを算出
            if ( !exists $prefs->{$person}{$item}
                     or $prefs->{$person}{$item} == 0 ) {
                $totals{$item}  += $prefs->{$other}{$item} * $sim;
                $simSuns{$item} += $sim;
            }
        }
    }
    return sort {$b->[1] <=> $a->[1] }
        map { [ $_, $totals{$_} / $simSuns{$_} ] } keys %totals;
}

sub transform_prefs {
    my $prefs = shift;
    my $result = {};
    for my $person (keys %$prefs) {
        for my $item (keys %{$prefs->{$person}}) {
            $result->{$item} = {} if !exists $result->{$item};
            $result->{$item}->{$person} = $prefs->{$person}->{$item};
        }
    }
    return $result;
}

sub calc_similar_items {
    my $prefs = shift;
    my $n = shift || 10;
    my $similarity = shift || \&sim_distance;
    my $result = {};
    ## 嗜好の行列をアイテム中心な形に反転させる
    my $item_prefs = transform_prefs($prefs);
    my $c = 0;
    for my $item (keys %$item_prefs) {
        my $scores = $cache->get($item.'sim');
#        my $scores;
            ## 巨大なデータセット用にステータスを表示
            say $c += 1;
            say "$c / " . scalar keys %$item_prefs if ( $c % 100 == 0 );
        if (!$scores) {
            ## このアイテムにもっとも似ているアイテムたちを探す
            my @scores = top_matches($item_prefs, $item, $n, $similarity);
            $scores = \@scores;
        }
        $result->{$item} = $scores;
        $cache->set($item.'sim', $scores);
    }
    return $result;
}

sub get_recommended_items {
    my ($prefs, $item_match, $user) = @_;
    my $user_ratings = $prefs->{$user};
    my $scores = {};
    my $total_sim = {};
    ## このユーザに評価されたアイテムをループする
    for my $item (keys %$user_ratings) {
        my $rating = $user_ratings->{$item};
        for my $match (@{$item_match->{$item}}) {
            my ($item2, $similarity) = @$match;

            ## 既にユーザが評価を行っていれば無視する
            next if $user_ratings->{$item2};

            ## 評点と類似度をかけあわせたものの合計で重み付けする
            $scores->{$item2} += $similarity * $rating;

            ## 全ての類似度の合計
            $total_sim->{$item2} += $similarity;
        }
    }
    ## 正規化のため、それぞれの重み付けしたスコアを類似度の合計で割る
    my $rankings = [];
    for my $item (keys %$scores) {
        my $score = $scores->{$item};
        push @$rankings, [$item, $score / $total_sim->{$item}];
    }
    return sort { $b->[1] <=> $a->[1] } @$rankings;
}

1;