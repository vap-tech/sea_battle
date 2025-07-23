use strict;
use warnings;
use Test::More tests => 10;
use Seabattle::Model::BattleState;


# Тест 1: создание объекта состояния игры
my $battle_state = Seabattle::Model::BattleState->new(
    game_id => 'GAME1',
    board_size => { width => 10, height => 10 },
    players => ['Player1', 'Player2'],
    ships_positions => {
        Player1 => [2, 3, 5],
        Player2 => [3, 3, 'test']
    },
    turn_order => ['Player1', 'Player2'],
    current_turn => 'Player1'
);

ok(ref $battle_state eq 'Seabattle::Model::BattleState', 'Объект состояния игры создан');

# Тест 2,3: проверка размеров поля
is($battle_state->accessor('board_size')->{width}, 10, 'Ширина поля равна 10');
is($battle_state->accessor('board_size')->{height}, 10, 'Высота поля равна 10');

# Тест 4: проверка игроков
is_deeply($battle_state->accessor('players'), ['Player1', 'Player2'], 'Список игроков верный');

# Тест 5: проверка очереди ходов
is_deeply($battle_state->accessor('turn_order'), ['Player1', 'Player2'], 'Очередь ходов правильная');

# Тест 6: проверка текущего игрока
is($battle_state->accessor('current_turn'), 'Player1', 'Первый ход принадлежит Player1');

# Тест 7: проверка активированного буста
$battle_state->activate_double_shot_boost('Player1');
ok($battle_state->has_double_shot_boost('Player1'), 'Буст двойного выстрела активирован');

# Тест 8: удаление буста
$battle_state->remove_double_shot_boost('Player1');
ok(! $battle_state->has_double_shot_boost('Player1'), 'Буст удалён');

# Тест 9: сериализация объекта состояния игры
my $serialized = $battle_state->serialize();
like($serialized, qr/"game_id":"GAME1"/, 'Объект корректно сериализован');

# Тест 10: десериализация объекта состояния игры
my $deserialized_state = Seabattle::Model::BattleState->deserialize($serialized);
is_deeply($deserialized_state, $battle_state, 'Объект корректно десериализован');

done_testing();
