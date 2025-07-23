package Seabattle::Model::Executor;
use Mojo::Base -base;
use List::Util qw(all first shuffle);
use List::MoreUtils qw(first_index);
use Seabattle::Model::BattleState;
use Seabattle::Model::Ship;

has 'games' => sub { {} };       # { game_id => BattleState }
has 'usernames' => sub { {} };   # { user_id => username }
has 'ranks' => sub { {} };   # { user_id => rank }


sub create_game {
    my ($self, $player_id, $size) = @_;
    my $game_id = Mojo::Util::md5_sum(rand().$$.time);

    $self->games->{$game_id} = Seabattle::Model::BattleState->new(
        game_id         => $game_id,
        board_size      => $size || 10 ,
        players         => [$player_id],
        ships_positions => {},
        turn_order      => [$player_id],
        current_turn    => undef,
        boosts          => {}
    );

    return $game_id;
}

sub find_game_by_size {
    my ($self, $size) = @_;

    # Ищем первую подходящую игру
    my $game = first {
        $_->{board_size} == $size &&
        @{$_->{players}} == 1  # Ищем игры, где только один игрок (ожидающие второго)
    }
        values %{$self->{games}};

    return $game ? $game->{game_id} : undef;
}

sub join_game {
    my ($self, $game_id, $player_id) = @_;
    my $game = $self->games->{$game_id} or return undef;

    push @{$game->accessor('players')}, $player_id;
    push @{$game->accessor('turn_order')}, $player_id;

    return $game;
}

sub shoot {
    my ($self, $game_id, $player_id, $x, $y) = @_;

    my $game = $self->games->{$game_id} or warn 'shoot error => game not found';

    warn 'shoot error => not_your_turn' unless $game->accessor('current_turn') eq $player_id;
    warn 'shoot error => invalid_coordinates' unless $game->valid_coordinates($x, $y);

    my $opponent_id = $self->get_opponent($game_id, $player_id);

    my $damage_ship;

    my ($hit, $sunk) = (0, 0);
    for my $ship (@{$game->accessor('ships_positions')->{$opponent_id}}) {
        if ($ship->take_damage($x, $y)) {
            $hit = 1;
            $sunk = $ship->is_destroyed;
            $damage_ship = $ship;
            last;
        }
    }

    if ($hit == 0 && $game->has_double_shot_boost($player_id)) {
        $game->remove_double_shot_boost($player_id)
    }
    else {
        $game->next_turn unless ($hit || $game->has_double_shot_boost($player_id));
    }

    return {
        hit       => $hit,
        sunk      => $sunk,
        game_over => $self->_check_game_over($game, $opponent_id),
        ship      => $sunk ? $damage_ship : undef
    };
}

sub _check_game_over {
    my ($self, $game, $player_id) = @_;
    return all { $_->is_destroyed } @{$game->accessor('ships_positions')->{$player_id}};
}

sub get_opponent {
    my ($self, $game_id, $player_id) = @_;
    my $game = $self->games->{$game_id} or return undef;
    return ($game->accessor('players')->[0] eq $player_id)
        ? $game->accessor('players')->[1]
        : $game->accessor('players')->[0];
}

sub handle_disconnect {
    my ($self, $player_id) = @_;
    for my $game (values %{$self->games}) {
        if ($game->has_player($player_id)) {
            my $opponent_id = $self->get_opponent($game->accessor('game_id'), $player_id);
            if (my $opponent_ws = $self->app->{clients}{$opponent_id}) {
                $opponent_ws->send({
                    json => {
                        type => 'game_over',
                        payload => {
                            result => 'victory',
                            scoreChange   => 10
                        }
                }});
            }

            # Удаляем игру
            delete $self->games->{$game->accessor('game_id')};
            last;
        }
    }
}

sub can_use_boost {
    my ($self, $game_id, $player_id, $boost_type) = @_;



    # TODO: Тут проверка баланса у биллинга
    return 1;
}

# Использование буста
sub use_boost {
    my ($self, $game_id, $player_id, $boost_type, $missed_shots) = @_;

    my $game = $self->games->{$game_id} or warn 'shoot error => game not found';

    if ($boost_type eq 'extra_shot') {
        my $result = $game->activate_double_shot_boost($player_id);
        if ($result == 1) {
            # TODO: Тут списывание баланса у биллинга
        }
    }

    if ($boost_type eq 'heal') {
        my $ship = $self->try_resurrect_ship($game_id, $player_id, $missed_shots);

        return $ship;
    }

    return 1;
}

# Перезапуск игры
sub restart_game {
    my ($self, $old_game_id, $player_id) = @_;

    # ... логика создания новой игры ...
    my $new_game_id = $old_game_id;
    return $new_game_id;
}

# Обработка сдачи
sub surrender {
    my ($self, $game_id, $player_id) = @_;
    my $game = $self->games->{$game_id} or return { error => 'game_not_found' };

    my $winner_id = ($game->{players}[0] eq $player_id)
        ? $game->{players}[1]
        : $game->{players}[0];

    return {
        success => 1,
        winner_id => $winner_id
    };
}

# Разместить корабли игрока
sub place_ships {
    my ($self, $game_id, $player_id) = @_;
    my $game = $self->games->{$game_id} or return undef;
    my $size = $game->accessor('board_size');
    my $ships = $self->generate_random_fleet($size, $size);

    $game->accessor('ships_positions')->{$player_id} = [
        map { Seabattle::Model::Ship->new(%$_) } @$ships
    ];

    return 1;
}

# Генерация данных для флота кораблей
sub generate_random_fleet {
    my ($self, $grid_width, $grid_height) = @_;

    $grid_width  ||= 10;
    $grid_height ||= 10;

    # Фиксированные типы кораблей для стандартного морского боя
    my @fleet_specs = (
        { size => 4, count => 1 },
        { size => 3, count => 2 },
        { size => 2, count => 3 },
        { size => 1, count => 4 }
    );

    # Занятые клетки
    my %occupied_cells;
    my @ships;

    foreach my $spec (@fleet_specs) {
        for (my $i = 0; $i < $spec->{count}; $i++) {
            my ($success, $ship) = $self->_place_single_ship(
                size          => $spec->{size},
                grid_width   => $grid_width,
                grid_height  => $grid_height,
                occupied_ref => \%occupied_cells,
                max_attempts => 100
            );

            push @ships, $ship;
        }
    }

    return \@ships;
}

# Основной метод восстановления корабля
sub try_resurrect_ship {
    my ($self, $game_id, $player_id, $missed_shots) = @_;
    my $game = $self->games->{$game_id} or return undef;

    # Получаем текущие корабли и занятые клетки
    my $ships = $game->accessor('ships_positions')->{$player_id};
    my %occupied = $self->_get_occupied_cells($ships, $missed_shots);
    my $size = $game->accessor('board_size');

    # Ищем самый большой уничтоженный корабль
    my $ship_to_resurrect = $self->_find_largest_destroyed_ship($player_id, $game_id);
    return undef unless $ship_to_resurrect;

    # Пробуем разместить корабль такого же размера
    my ($success, $new_ship_data) = $self->_place_single_ship(
        size         => $ship_to_resurrect->size,
        grid_width   => $size,
        grid_height  => $size,
        occupied_ref => \%occupied,
        max_attempts => 100
    );

    if ($success) {
        # Заменяем старый корабль новым
        my $index = first_index { $_ == $ship_to_resurrect } @$ships;
        $ships->[$index] = Seabattle::Model::Ship->new(%$new_ship_data);
        return $ships->[$index];
    }

    # Если не получилось, пробуем меньшие корабли
    my @destroyed = sort { $b->size <=> $a->size }
                    grep { $_->is_destroyed && $_->size < $ship_to_resurrect->size }
                    @$ships;

    foreach my $ship (@destroyed) {
        ($success, $new_ship_data) = $self->_place_single_ship(
            size         => $ship->size,
            grid_width   => $size,
            grid_height  => $size,
            occupied_ref => \%occupied,
            max_attempts => 50
        );

        if ($success) {
            my $index = first_index { $_ == $ship } @$ships;
            $ships->[$index] = Seabattle::Model::Ship->new(%$new_ship_data);
            return $ships->[$index];
        }
    }

    return undef; # Не удалось восстановить ни один корабль
}

sub _get_occupied_cells {
    my ($self, $ships, $missed_shots) = @_;
    my %occupied;

    foreach my $ship (@$ships) {

        foreach my $c (@{$ship->coordinates}) {
            $occupied{"$c->{x},$c->{y}"} = 1;
        }

        foreach my $c (@{$ship->influence_zone}) {
            $occupied{"$c->{x},$c->{y}"} = 1;
        }
    }

    foreach my $c (@{$missed_shots}) {
        $occupied{"$c->{x},$c->{y}"} = 1;
    }

    return %occupied;
}

# Размещение одного корабля
sub _place_single_ship {
    my ($self, %params) = @_;

    my $size         = $params{size};
    my $grid_width   = $params{grid_width};
    my $grid_height  = $params{grid_height};
    my $occupied_ref = $params{occupied_ref} || {};
    my $max_attempts = $params{max_attempts} || 100;

    my $is_placed = 0;
    my $attempts = $max_attempts;
    my ($ship_coords, $influence_zone);

    while (!$is_placed && $attempts--) {
        # Случайная ориентация
        my $is_vertical = rand() < 0.5 ? 1 : 0;

        # Выбор начальной позиции с учетом направления
        my $start_x = $is_vertical
            ? int(rand($grid_width))
            : int(rand($grid_width - $size + 1));
        my $start_y = $is_vertical
            ? int(rand($grid_height - $size + 1))
            : int(rand($grid_height));

        # Генерируем координаты корабля
        $ship_coords = [];
        for (my $j = 0; $j < $size; $j++) {
            my ($x, $y) = $is_vertical
                ? ($start_x, $start_y + $j)
                : ($start_x + $j, $start_y);

            push @$ship_coords, { x => $x, y => $y };
        }

        # Проверяем доступность всех координат
        next unless $self->_are_coords_available($ship_coords, $occupied_ref);

        # Генерируем зону влияния
        $influence_zone = $self->_generate_influence_zone(
            coords      => $ship_coords,
            grid_width  => $grid_width,
            grid_height => $grid_height
        );

        # Помечаем все клетки как занятые
        $self->_mark_cells_as_occupied($ship_coords, $influence_zone, $occupied_ref);
        $is_placed = 1;
    }

    my @ship_names = qw(Катер Эсминец Крейсер Линкор);

    if ($is_placed == 1) {
        return (1, {
            size          => $size,
            coordinates   => $ship_coords,
            influence_zone => $influence_zone,
            name          => $ship_names[$size - 1]
        });
    }

    return (0, undef); # Не удалось разместить

}

# Проверка доступности координат
sub _are_coords_available {
    my ($self, $coords, $occupied_ref) = @_;

    foreach my $c (@$coords) {
        return 0 if $occupied_ref->{"$c->{x},$c->{y}"};
    }
    return 1;
}

# Генерация зоны влияния вокруг корабля
sub _generate_influence_zone {
    my ($self, %params) = @_;

    my $coords      = $params{coords};
    my $grid_width  = $params{grid_width};
    my $grid_height = $params{grid_height};
    my @zone;

    foreach my $c (@$coords) {
        my $x = $c->{x};
        my $y = $c->{y};

        for my $dx (-1..1) {
            for my $dy (-1..1) {
                next if $dx == 0 && $dy == 0; # игнорируем центральный элемент

                my $check_x = $x + $dx;
                my $check_y = $y + $dy;

                # Проверка границ поля
                next if $check_x < 0 || $check_x >= $grid_width;
                next if $check_y < 0 || $check_y >= $grid_height;

                # Проверка, что точка не принадлежит самому кораблю
                next if List::Util::any { $_->{x} == $check_x && $_->{y} == $check_y } @$coords;

                # Проверка на дубли в зоне влияния
                next if List::Util::any { $_->{x} == $check_x && $_->{y} == $check_y } @zone;

                push @zone, { x => $check_x, y => $check_y };
            }
        }
    }

    return \@zone;
}

# Пометить клетки как занятые
sub _mark_cells_as_occupied {
    my ($self, $ship_coords, $influence_zone, $occupied_ref) = @_;

    foreach my $c (@$ship_coords) {
        $occupied_ref->{"$c->{x},$c->{y}"} = 1;
    }

    foreach my $c (@$influence_zone) {
        $occupied_ref->{"$c->{x},$c->{y}"} = 1;
    }
}

sub _find_largest_destroyed_ship {
    my ($self, $player_id, $game_id) = @_;
    my $game = $self->games->{$game_id} or return undef;
    my $ships = $game->accessor('ships_positions')->{$player_id} or return undef;

    my @destroyed = grep { $_->is_destroyed } @$ships;
    return undef unless @destroyed;

    my @sorted = sort { $b->size <=> $a->size } @destroyed;
    return $sorted[0];
}

1;