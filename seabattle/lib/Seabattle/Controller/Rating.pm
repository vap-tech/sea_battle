package Seabattle::Controller::Rating;
use Mojo::Base 'Mojolicious::Controller';

sub index {
    my $self = shift;

    my $db = $self->app->db;

    my @players = $db->resultset('User')
        ->search(
            { 'user_stats.score' => { '!=', undef } },
            {
                join     => 'user_stats',
                select   => [ 'me.nickname', 'user_stats.score', 'user_stats.score_achieved_at' ],
                as       => [ 'nickname', 'score', 'score_achieved_at' ],
                order_by => [
                    { -desc => 'user_stats.score' },
                    { -asc  => 'user_stats.score_achieved_at' },
                    { -asc  => 'me.nickname' }
                ],
            }
        );

    my @ranking;
    my $position = 1;

    for my $player (@players) {
        my ($nickname, $score, $achieved_at) = @$player{qw/nickname score score_achieved_at/};

        my $rank = $score > 400  ? 'Адмирал' :
                   $score > 200  ? 'Капитан' :
                   $score > 100  ? 'Лейтенант' :
                                   'Матрос';

        push @ranking, {
            nickname => $nickname,
            score    => $score,
            rank     => $rank,
            position => $position++,
        };
    }

    $self->render(json => { rating => \@ranking });
}

1;
