package Seabattle::Controller::Account;
use Mojo::Base 'Mojolicious::Controller';

# Определения звания по очкам
sub _rank_for {
    my ($score) = @_;
    return 'Адмирал'    if $score > 400;
    return 'Капитан'    if $score > 200;
    return 'Лейтенант'  if $score > 100;
    return 'Матрос';
}

# Данные профиля игрока
sub get_profile_data {
    my $c = shift;
    my $user_id = $c->param( 'user_id' ) or return $c->render(json => { error => 'user_id missing' }, status => 400);

    my $schema = $c->app->schema;

    my $user = $schema->resultset( 'User' )->find($user_id);
    return $c->render(json => { error => 'User not found' }, status => 404) unless $user;

    my $stat = $schema->resultset( 'UserStat' )->find({ user_id => $user_id });
    return $c->render(json => { error => 'Stats not found' }, status => 404) unless $stat;

    my $rank = _rank_for($stat->score);

    # Место игрока в рейтинге
    my $place = $schema->resultset( 'UserStat' )->search(
        [
            { score => { '>' => $stat->score } },
            {
                score => $stat->score,
                score_achieved_at => { '<' => $stat->score_achieved_at }
            },
            {
                score => $stat->score,
                score_achieved_at => $stat->score_achieved_at,
                user_id => { '<' => $user_id }
            }
        ],
        { rows => undef }
    )->count + 1;

    $c->render(json => {
        username => $user->username,
        score    => $stat->score,
        coins    => $stat->coins,
        rank     => $rank,
        place    => $place,
    });
}

# Топ 5 игроков
sub get_top_players {
    my $c = shift;

    my @top_players = $c->app->schema->resultset( 'UserStat' )->search(
        {},
        {
            join => 'user',
            order_by => [
                { '-desc' => 'score' },
                { '-asc'  => 'score_achieved_at' },
                { '-asc'  => 'user.username' },
            ],
            rows => 5,
        }
    )->all;

    my @result = map {
        { username => $_->user->username, score => $_->score }
    } @top_players;

    $c->render(json => { top_players => \@result });
}

# Последние 5 игр игрока
sub get_recent_games {
    my $c = shift;
    my $user_id = $c->param( 'user_id' ) or return $c->render(json => { error => 'user_id missing' }, status => 400);

    my @games = $c->app->schema->resultset( 'Game' )->search(
        { user_id => $user_id },
        { order_by => { -desc => 'played_at' }, rows => 5 }
    )->all;

    my @result = map {
        {
            id          => $_->id,
            result      => $_->result,
            score_delta => $_->score_delta,
            played_at   => $_->played_at,
        }
    } @games;

    $c->render(json => { recent_games => \@result });
}

# Последние 5 покупок игрока
sub get_recent_purchases {
    my $c = shift;
    my $user_id = $c->param( 'user_id' ) or return $c->render(json => { error => 'user_id missing' }, status => 400);

    my @purchases = $c->app->schema->resultset( 'Purchase' )->search(
        { user_id => $user_id },
        {
            join     => 'shop_item',
            order_by => { -desc => 'bought_at' },
            rows     => 5,
        }
    )->all;

    my @result = map {
        {
            name      => $_->shop_item->name,
            price     => $_->shop_item->price,
            bought_at => $_->bought_at,
        }
    } @purchases;

    $c->render(json => { recent_purchases => \@result });
}

1;
