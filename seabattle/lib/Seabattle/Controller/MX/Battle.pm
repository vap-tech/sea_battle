package Seabattle::Controller::MX::Battle;
use Mojo::Base 'Mojolicious::Controller';
use JSON qw(encode_json decode_json);
use Mojo::Util qw(secure_compare);


sub ws_connection {
    my $self = shift;

    # Мокируем авторизацию (временное решение)
    my $user_id = $self->_mock_auth || return;

    # Сохраняем соединение
    $self->app->{clients}{$user_id} = $self;
    $self->stash(user_id => $user_id);

    # Обработчики событий
    $self->on(json => \&_handle_json);
    $self->on(finish  => \&_handle_disconnect);

    # Таймаут неактивности (5 минут)
    $self->inactivity_timeout(3600);

    warn "user $user_id - connected";
}

sub _handle_json {
    my ($self, $json) = @_;
    $self->stash('user_id') or return;

    return $self->_send_error('invalid_format')
        unless ref $json eq 'HASH' && $json->{type} && exists $json->{payload};

    my %handlers = (
        connect   => \&_handle_connect,
        shoot     => \&_handle_shoot,
        use_boost => \&_handle_boost,
        restart   => \&_handle_restart,
        surrender => \&_handle_surrender,
        timeout   => \&_handle_timeout
    );

    if (my $handler = $handlers{$json->{type}}) {
        $self->$handler($json->{payload});
    }
    else {
        $self->_send_error('unknown_action');
    }
}

sub _handle_connect {
    my ($self, $payload) = @_;
    my $user_id = $self->stash('user_id');

    # Ищем игру для подключения
    my $game_id = $self->app->{executor}->find_game_by_size($payload->{board_size});
    $self->app->{executor}->usernames->{$user_id} = $payload->{username};
    $self->app->{executor}->ranks->{$user_id} = $payload->{rank};

    # Создаем/подключаем к игре
    if (defined $game_id) {
        $self->app->{executor}->join_game($game_id, $user_id);
        $self->_send_event('setGameId', { gameId => $game_id });

        my $opponent_id = $self->app->{executor}->get_opponent($game_id, $user_id);
        my $opponent_name = $self->app->{executor}->usernames->{$opponent_id};
        my $opponent_rank = $self->app->{executor}->ranks->{$opponent_id};

        $self->_send_event('connectToPlay', {
            success => 1,
            rivalName => $opponent_name,
            rivalRank => $opponent_rank
        });

        # Передаём меня сопернику
        $self->_send_event_to_opponent($opponent_id, 'connectToPlay', {
            success => 1,
            rivalName => $payload->{username},
            rivalRank => $payload->{rank}
        });

        # Рассылаем уведомления
        $self->_send_event('serverMessage', {
            text     => 'Вы подключены к игре',
            duration => 13000
        });

        $self->_send_event_to_opponent($opponent_id, 'serverMessage', {
            text     => 'Соперник подключён к игре',
            duration => 13000
        });

        my $game = $self->app->{executor}->games->{$game_id};
        my $current_turn = $game->next_turn();

        if ($current_turn eq $user_id) {
            $self->_send_event('setCanShoot', { canShoot  => 1 })
        }
        elsif ($current_turn eq $opponent_id) {
            $self->_send_event_to_opponent($opponent_id, 'setCanShoot', { canShoot  => 1 })
        }
        else {
            warn "такого не могло быть... но всё же случилось в самом начале.."
        };

    }
    else {
        $game_id = $self->app->{executor}->create_game($user_id, $payload->{board_size});

        $self->_send_event('serverMessage', { text => 'Создана новая игра' });
        $self->_send_event('setGameId', { gameId => $game_id });
    }

    # Размещаем корабли
    $self->app->{executor}->place_ships($game_id, $user_id);

    my $game = $self->app->{executor}->games->{$game_id};
    my $ships = $game->accessor('ships_positions')->{$user_id};

    # Корабли на фронт!
    for my $ship (@$ships) {
        $self->_send_event('addShip', {
            board => 'myBoard',
            coordinates => $ship->coordinates
        });
    }

}

sub _handle_timeout {
    my ($self, $payload) = @_;
    my $user_id = $self->stash('user_id');

    my $opponent_id = $self->app->{executor}->get_opponent($payload->{gameId}, $user_id);
    my $game = $self->app->{executor}->games->{$payload->{gameId}};

    $game->next_turn();
    $self->_send_event( 'setCanShoot', { canShoot  => 0 });
    $self->_send_event_to_opponent($opponent_id, 'setCanShoot', { canShoot  => 1 });

    $self->app->log->info("Игрок $user_id timeout!!");

}

sub _handle_shoot {
    my ($self, $payload) = @_;
    my $user_id = $self->stash('user_id');

    my $result = $self->app->{executor}->shoot(
        $payload->{gameId},
        $user_id,
        $payload->{x},
        $payload->{y}
    );

    # Результат стрелявшему
    $self->_send_event('afterShoot', {
        isMyBoard => 0,
        x         => $payload->{x},
        y         => $payload->{y},
        hit       => $result->{hit}
    });

    my $opponent_id = $self->app->{executor}->get_opponent($payload->{gameId}, $user_id);

    # Результат сопернику
    $self->_send_event_to_opponent( $opponent_id, 'afterShoot', {
        isMyBoard => 1,
        x         => $payload->{x},
        y         => $payload->{y},
        hit       => $result->{hit}
    });

    # Корабль убит
    if ($result->{sunk} && !$result->{game_over} ) {
        my $coordinates = $result->{ship}->influence_zone;

        for my $c (@$coordinates) {

            $self->_send_event('afterShoot', {
                isMyBoard => 0,
                x         => $c->{x},
                y         => $c->{y},
                hit       => 0
            });

            $self->_send_event_to_opponent( $opponent_id, 'afterShoot', {
                isMyBoard => 1,
                x         => $c->{x},
                y         => $c->{y},
                hit       => 0
            });

        }

        $self->_send_event('serverMessage', {
            text     => 'Убит',
            duration => 1000
        });

        $self->_send_event_to_opponent( $opponent_id, 'serverMessage', {
            text     => 'Ваш корабль убит!',
            duration => 1000
        });

    }

    # Конец игры
    if ($result->{game_over}) {

        # Выигрыш
        $self->_send_event('gameOver', {
            result        => 'victory',
            scoreChange   => 10
        });

        # Проигрыш
        $self->_send_event_to_opponent( $opponent_id, 'gameOver', {
            result        => 'defeat',
            scoreChange   => -5
        });
    }

    my $game = $self->app->{executor}->games->{$payload->{gameId}};

    if ($game->accessor('current_turn') eq $user_id) {
        $self->_send_event('setCanShoot', { canShoot  => 1 })
    }
    elsif ($game->accessor('current_turn') eq $opponent_id) {
        $self->_send_event_to_opponent($opponent_id, 'setCanShoot', { canShoot  => 1 })
    }
    else {
        warn "такого не могло быть... но всё же случилось..."
    };

}

sub _handle_boost {
    my ($self, $payload) = @_;
    my $user_id = $self->stash('user_id');

    unless ($self->app->{executor}->can_use_boost(
        $payload->{gameId},
        $user_id,
        $payload->{boostType}
    )) {
        return $self->_send_error('boost_not_available');
    }

    # Применяем буст
    my $result = $self->app->{executor}->use_boost(
        $payload->{gameId},
        $user_id,
        $payload->{boostType},
        $payload->{missedShots}
    );

    if (defined $result) {
        $self->_send_event('serverMessage', { text => 'Буст применён успешно!' });

        if ($payload->{boostType} eq 'heal') {
            $self->_send_event('addShip', {
                board => 'myBoard',
                coordinates => $result->coordinates
            });
        }

        my $opponent_id = $self->app->{executor}->get_opponent($payload->{gameId}, $user_id);
        $self->_send_event_to_opponent($opponent_id, 'serverMessage', { text => 'Противник применил Буст!' })
    }
}

sub _handle_restart {
    my ($self, $payload) = @_;
    my $user_id = $self->stash('user_id');

    # Создаем новую игру с теми же игроками
    my $new_game_id = $self->app->{executor}->restart_game(
        $payload->{gameId},
        $user_id
    );

    if (defined $new_game_id) {
        # Уведомляем обоих игроков
        my $players = $self->app->{executor}->get_game_players($new_game_id);

        foreach my $player_id (@$players) {
            if (my $ws = $self->app->{clients}{$player_id}) {
                $ws->_send_event('game_restarted', {
                    gameId => $new_game_id,
                    rivalName => ($players->[0] eq $player_id ? $players->[1] : $players->[0])
                });
            }
        }
    } else {
        $self->_send_error('restart_failed');
    }
};

sub _handle_surrender {
    my ($self, $payload) = @_;
    my $user_id = $self->stash('user_id');

    # Фиксируем сдачу
    my $result = $self->app->{executor}->surrender(
        $payload->{gameId},
        $user_id
    );

    if ($result->{success}) {
        $self->_send_event('gameOver', {
            result        => 'defeat',
            scoreChange   => -5
        });

        # Уведомляем победителя
        $self->_send_event_to_opponent($result->{winner_id}, 'gameOver', {
            result        => 'victory',
            scoreChange   => 10
        });
    }
}

# --- Вспомогательные методы ---
sub _handle_disconnect {
    my $self = shift;
    my $user_id = $self->stash('user_id') or return;

    # Удаляем соединение
    delete $self->app->{clients}{$user_id};

    warn("user $user_id - disconnected");

    # Уведомляем Executor об отключении
    $self->app->{executor}->handle_disconnect($user_id);
}

sub _send_event {
    my ($self, $type, $payload) = @_;
    $self->send({
        json => {
            type    => $type,
            payload => $payload
        }
    });
}

sub _send_event_to_opponent {
    my ($self, $opponent_id, $type, $payload) = @_;

    # Получаем WebSocket соединение оппонента
    if (my $opponent_ws = $self->app->{clients}{$opponent_id}) {

        # Отправляем сообщение
        $opponent_ws->send(
            { json => { type => $type, payload => $payload } }
        );
    }
    else {
        warn 'error => opponent_offline';
    }
}

sub _send_error {
    my ($self, $error_code) = @_;
    $self->send({
        json => {
            type    => 'error',
            payload => {
                code    => $error_code,
                message => $self->_get_error_message($error_code) || 'Unknown error'
            }
        }
    });
}

# Временная заглушка авторизации
sub _mock_auth {
    my $self = shift;
    return $self->param('user_id') || 'mock_user_' . Mojo::Util::md5_sum(rand() . $$ . time);
}

sub _get_error_message{
    my ($self, $error_code) = @_;

    # Коды ошибок
    my %ERROR_MESSAGES = (
        invalid_json   => 'Invalid JSON format',
        invalid_format => 'Message must contain type and payload',
        not_your_turn  => 'Wait for your turn',
        # ...
    );

    return($ERROR_MESSAGES{$error_code});
}

1;