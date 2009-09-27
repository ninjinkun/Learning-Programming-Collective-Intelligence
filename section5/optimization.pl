#!perl
use strict;
use warnings;
use Path::Class;
use List::Util qw/min/;

my $people = [
    ['Seymour', 'BOS'],
    ['Franny', 'DAL'],
    ['Zooey', 'CAK'],
    ['Walt', 'MIA'],
    ['Buddy', 'ORD'],
    ['Les', 'OMA']
];
## ニューヨークのラガーディア空港
my $destination = 'LGA';
my $flights = {};

my $fright_file = file('schedule.txt')->slurp;
for my $line (split "\r\n", $fright_file) {
    my ($origin, $dist, $depart, $arrive, $price) = split ',', $line;
    $flights->{$origin}->{$dist} ||= [];
    push @{$flights->{$origin}->{$dist}}, [$depart, $arrive, $price];
}

sub get_minuits {
    my $time = shift;
    my ($hour, $min) = split ':', $time;
    return $hour * 60 + $min;
}

sub rand_range {
    my ($upper, $lower) = @_;
    int( rand( abs($upper - $lower) +1 ) % (abs($upper - $lower) + 1) + min($upper, $lower) );
}

sub print_schedule {
    my $res = shift;
    for my $d (0 .. $#$res / 2) {
        my $name = $people->[$d]->[0];
        my $origin = $people->[$d]->[1];
        my $out = $flights->{$origin}->{$destination}->[$res->[$d * 2]];
        my $ret = $flights->{$destination}->{$origin}->[$res->[$d * 2 + 1]];
        printf "%10s%10s %5s-%5s \$%3s %5s-%5s \$%3s\n", $name, $origin, $out->[0], $out->[1], $out->[2], $ret->[0], $ret->[1], $ret->[2];
    }
}

sub schedule_cost {
    my $sol = shift;
    my $total_price = 0;
    my $latest_arrival = 0;
    my $earliest_deperture = 24 * 60;
    
    for my $d (0 .. $#$sol / 2) {
        ## 行きと帰りのフライトを得る
        my $origin = $people->[$d]->[1];
        my $outbound = $flights->{$origin}->{$destination}->[$sol->[$d * 2]];
        my $returnf  = $flights->{$destination}->{$origin}->[$sol->[$d * 2 + 1]];
        
        ## 運賃総額total priceは出立便と北区便全ての運賃
        $total_price += $outbound->[2];
        $total_price += $returnf->[2];
        
        ## 最も遅い到着と最も早い出発を記録
        if ($latest_arrival < get_minuits($outbound->[1])) {
            $latest_arrival = get_minuits($outbound->[1]);
        }
        if ($earliest_deperture > get_minuits($returnf->[0])) {
            $earliest_deperture = get_minuits($returnf->[0]);
        }
    }
    my $total_wait = 0;
    for my $d (0 .. $#$sol / 2) {
        my $origin = $people->[$d]->[1];
        my $outbound = $flights->{$origin}->{$destination}->[$sol->[$d * 2]];
        my $returnf  = $flights->{$destination}->{$origin}->[$sol->[$d * 2 + 1]];
        $total_wait += $latest_arrival - get_minuits($outbound->[1]);
        $total_wait += get_minuits($returnf->[0]) - $earliest_deperture;
    }
    ## この階ではレンタカーの追加料金が必要か？これは50ドル！
    if ($latest_arrival < $earliest_deperture) {
        $total_price += 50;
    }
    return $total_price + $total_wait;
}

sub random_optimize {
    my ($domain, $costf) = @_;
    my $best = 999999999;
    my $bestr;
    for my $i (0..1000) {
        my $r = [];
        ## 無作為解の生成
        for my $i (0.. $#$domain) {
            my ($dom1, $dom2) = ($domain->[$i]->[0], $domain->[$i]->[1]);
            push @$r, rand_range($dom1, $dom2);
        }
        ## コストの取得
        my $cost = $costf->($r);

        ## 最良解と比較
        if ($cost < $best) {
            $best = $cost;
            $bestr = $r;
        }
    }
    return $bestr;
}

sub hill_climb {
    my ($domain, $costf) = @_;
    ## 無作為解の生成
    my $sol = [];
    ## 無作為解の生成
    for my $i (0.. $#$domain) {
        my ($dom1, $dom2) = ($domain->[$i]->[0], $domain->[$i]->[1]);
        push @$sol, rand_range($dom1, $dom2);
    }
    while (1) {
        ## 近傍解リストの生成
        my $neighbours = [];
        for my $j (0 .. $#$domain) {
            ## 各方向に1ずつずらす
            if ($sol->[$j] > $domain->[$j]->[0]) {
                push @$neighbours, [(@$sol[0 .. $j-1], $sol->[$j] - 1,  @$sol[($j + 1) .. $#$sol])];
            }
            if ($sol->[$j] < $domain->[$j]->[1]) {
                push @$neighbours, [(@$sol[0 .. $j-1], $sol->[$j] + 1,  @$sol[($j + 1) .. $#$sol])];
            }
        }
        ## 近傍解中のベストを探す
        my $current = $costf->($sol);
        my $best = $current;
        for my $j (0..$#$neighbours) {
            my $cost = $costf->($neighbours->[$j]);
            if ($cost < $best) {
                $best = $cost;
                $sol = $neighbours->[$j];
            }
        }
        ## 改善が見られなければそれが最高
        last if $best == $current;
    }
    return $sol;
}

sub annealing_ptimize {
    my ($domain, $costf, $opt) = @_;
    my $T    = $opt->{T} || 10000;
    my $cool = $opt->{cool} || 0.95;
    my $step = $opt->{step} || 1;

    my $vec = [];
    for my $i (0..$#$domain) {
        my ($dom1, $dom2) = ($domain->[$i]->[0], $domain->[$i]->[1]);
        push @$vec, rand_range($dom1, $dom2);
    }

    while ( $T > 0.1 ) {
        ## インデックスを一つ選ぶ
        my $i = int(rand $#$domain);

        ## インデックスの値に加える変更の方向を選ぶ
        my $dir = rand_range(1, -1);
        ## 値を変更したリストを生成
        my $vecb = [@$vec];
        $vecb->[$i] = $dir;
        if ($vecb->[$i] < $domain->[$i]->[0]) {
            $vecb->[$i] = $domain->[$i]->[0];
        }
        elsif ($vecb->[$i] > $domain->[$i]->[1]) {
            $vecb->[$i] = $domain->[$i]->[1];
        }
        
        #　#現在解と生成解のコストを計算
        my $ea = $costf->($vec);
        my $eb = $costf->($vecb);
        my $p = exp( -abs($ea - $eb) ) / $T;
        
        ## 生成解がベタ-? または確率的に採用?
        if ($eb < $ea or rand() < $p) {
            $vec = $vecb;
        }
        ## 温度を下げる
        $T *= $cool;
    }
    return $vec;
}

sub genetic_optimize {
    my ($domain, $costf, $opt) = @_;
    my $pop_size = $opt->{pop_size}  || 50;
    my $step     = $opt->{step}     || 1;
    my $mut_porb = $opt->{mut_porb} || 0.2;
    my $elite    = $opt->{elite}    || 0.2;
    my $max_iter = $opt->{max_iter} || 100;

    my $pop = [];
    for (0..$pop_size-1) {
        push @$pop, [ map { rand_range($domain->[$_]->[0], $domain->[$_]->[1]) } (0.. $#$domain)];
    }
    ## 各世代の勝者数は?
    my $top_elite = int( $elite * $pop_size );

    my $scores = [];
    ## Main Loop
    for my $i (0.. $max_iter-1) {
        $scores = [map {[$costf->($_), $_]} @$pop];
        @$scores = sort { $a->[0] <=> $b->[0] } @$scores;
        my $ranked = [map {$_->[1]} @$scores];
        ## まず純粋な勝者
        $pop = [@$ranked[0..$top_elite-1]];
        
        ## 勝者に突然変異や交配を行ったものを追加
        while ($#$pop  < $pop_size - 1) {

            if (rand() < $mut_porb) {
                ## 突然変異
                my $c = int rand($top_elite + 1);
                my $list = mutate($domain, $ranked->[$c], $step);
                push @$pop, $list if $list;
            }
            else {
                ## 交配
                my $c1 = int rand($top_elite + 1);
                my $c2 = int rand($top_elite + 1);
                push @$pop, crossover($domain, $ranked->[$c1], $ranked->[$c2]);

            }
        }
        ## 現在のベストスコアを出力
#        print $scores->[0]->[0] . "\n";
    }
    return $scores->[0]->[1];
}

sub mutate {
    my ($domain, $vec, $step) = @_;
    my $i = int rand($#$domain);
    if (rand() < 0.5 and $vec->[$i] > $domain->[$i]->[0]) {
        return [@$vec[0..$i-1], $vec->[$i] - $step, @$vec[$i+1..$#$vec]];
    }
    elsif ($vec->[$i] < $domain->[$i]->[1]) {
        return [@$vec[0..$i-1], $vec->[$i] + $step, @$vec[$i+1..$#$vec]];
    }
}

sub crossover {
    my ($domain, $r1, $r2) = @_;
    my $i = int rand($#$domain-1) + 1;
    return [@$r1[0 .. $i-1], @$r2[$i..$#$r2]];
}

use Benchmark qw/:all/;


my $domain = [ map { [0, 8] } ( 1 .. (@$people * 2) ) ];


cmpthese(1000, {
    'random' => sub {
        random_optimize($domain, \&schedule_cost);
    },
    'hill_climb' => sub {
        hill_climb($domain, \&schedule_cost);
    },
    'annealing_ptimize' => sub {
        annealing_ptimize($domain, \&schedule_cost);
    },
    'genetic_optimize' => sub {
        genetic_optimize($domain, \&schedule_cost);
    }
});



#my $s = random_optimize($domain, \&schedule_cost);
##my $s = hill_climb($domain, \&schedule_cost);
#my $s = annealing_ptimize($domain, \&schedule_cost);
# my $s = genetic_optimize($domain, \&schedule_cost);
# print schedule_cost($s) . "\n";
# print_schedule($s);
