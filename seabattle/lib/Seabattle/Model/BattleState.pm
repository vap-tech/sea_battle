package Seabattle::Model::BattleState;
use strict;
use warnings FATAL => 'all';

use List::MoreUtils qw(first_index);
use List::Util qw(shuffle first);
use JSON qw(encode_json decode_json);


=head2 new

Конструктор объекта игрового состояния.

=over 4

=item * Синтаксис

    my $game_state = Seabattle::Model::BattleState->new(
        game_id         => 'game_123',
        board_size      => {width => 10, height => 10},
        players         => ['player1', 'player2'],
        ships_positions => \%ships,
        turn_order      => \@order,
        current_turn    => 'player1',
        boosts          => \%boosts
    );

=item * Параметры

=over 8

=item C<game_id> - уникальный идентификатор игры (строка)

=item C<board_size> - хэш с размерами поля {width => X, height => Y}

=item C<players> - массив идентификаторов игроков

=item C<ships_positions> - хэш позиций кораблей (ключ - player_id)

=item C<turn_order> - массив порядка ходов

=item C<current_turn> - текущий активный игрок

=item C<boosts> - хэш активных бонусов (опционально, по умолчанию {})

=back

=item * Возвращает

Новый объект игрового состояния (blessed hashref).

=item * Особенности

=over 8

=item *

Поле C<boosts> инициализируется пустым хэшем, если не передано

=item *

Не выполняет валидацию входных параметров

=back

=back

=cut

sub new {
    my ($class, %args) = @_;
    return bless {
        game_id         => $args{game_id},  
        board_size      => $args{board_size},       # Размеры игрового поля
        players         => $args{players},          # Список игроков
        ships_positions => $args{ships_positions},  # Местоположение кораблей
        turn_order      => $args{turn_order},       # Очередность ходов
        current_turn    => $args{current_turn},     # Текущий игрок
        boosts          => $args{boosts} || {},     # Бонусы
    }, $class;
}

=head2 accessor

Универсальный метод доступа к полям объекта (getter/setter).

=over 4

=item * Синтаксис

    # Получение значения
    my $value = $obj->accessor('field_name');

    # Установка значения
    $obj->accessor('field_name', $new_value);

=item * Параметры

=over 8

=item C<$field_name>

Имя поля объекта (обязательный, строка).

=item C<$value>

Новое значение поля (опциональный). Если не указан, метод работает как геттер.

=back

=item * Возвращаемое значение

=over 8

=item *

При вызове без C<$value> - возвращает текущее значение поля.

=item *

При вызове с C<$value> - возвращает сам объект (для цепочки вызовов).

=back

=item * Примеры использования

=over 8

=item * Геттер

    my $players = $game->accessor('players');

=item * Сеттер

    $game->accessor('current_turn', 'player_1')
         ->accessor('status', 'active');

=back

=item * Особенности реализации

=over 8

=item *

Автоматически определяет режим работы (get/set) по наличию второго параметра.

=item *

Возвращает self при установке значения, позволяя объединять вызовы в цепочки.

=item *

Не выполняет валидацию типов или значений.

=item *

Прямой доступ к хэшу объекта (не использует Mojo::Base helpers).

=back

=item * Рекомендации по использованию

=over 8

=item *

Для важных полей рекомендуется создавать специализированные методы.

=item *

Не использовать для полей с сложной логикой доступа.

=back

=back

=cut

sub accessor {
    my ($self, $field_name, $value) = @_;

    if (!defined $value) {
        return $self->{$field_name};
    }
    $self->{$field_name} = $value;

    return $self;
}



=head2 has_player

Проверяет наличие игрока в текущей игровой сессии.

=over 4

=item * Синтаксис

    my $is_player = $game_state->has_player($player_id);

=item * Параметры

=over 8

=item C<$player_id>

Идентификатор игрока для проверки (строка). Должен точно соответствовать сохранённому значению.

=back

=item * Возвращаемое значение

=over 8

=item C<1>

Игрок найден в списке участников.

=item C<0>

Игрок не найден.

=back

=item * Пример использования

    if ($game->has_player('player_789')) {
        say "Игрок участвует в этой игре";
    }

=item * Особенности реализации

=over 8

=item *

Использует точное строковое сравнение (оператор C<eq>)

=item *

Чувствителен к регистру символов

=item *

Не выполняет нормализацию входных данных

=back

=back

=cut

sub has_player {
    my ($self, $player_id) = @_;

    for my $player ($self->accessor('players')) {
        if ($player eq $player_id) {
            return 1;
        }
    }

    return 0;
}

=head2 activate_double_shot_boost

Активирует буст "двойного выстрела" для указанного игрока.

=over 4

=item * Параметры

=over 8

=item C<$player_id> - идентификатор игрока (строка)

=back

=item * Логика работы

Устанавливает флаг буста в хранилище boosts с ключом "double_shot_$player_id".
При активации этого буста игрок получает право на дополнительный ход после успешного попадания.

=item * Пример использования

    $game_state->activate_double_shot_boost('player_123');

=item * Взаимодействие с другими методами

Метод влияет на поведение:
- shoot (проверка буста перед сменой хода)

=back

=cut


sub activate_double_shot_boost {
    my ($self, $player_id) = @_;
    $self->accessor('boosts')->{"double_shot_$player_id"} = 1;
    return 1;
}

=head2 has_double_shot_boost

Проверяет наличие активного буста "двойного выстрела" для указанного игрока.

=over 4

=item * Синтаксис

    my $has_boost = $game_state->has_double_shot_boost($player_id);

=item * Параметры

=over 8

=item C<$player_id>

Идентификатор игрока (строка), для которого проверяется наличие буста. Должен соответствовать идентификатору,
использованному при активации буста.

=back

=item * Возвращаемое значение

=over 8

=item C<1>

Буст активен для указанного игрока.

=item C<0>

Буст не активен или отсутствует.

=back

=item * Логика работы

Проверяет наличие ключа "double_shot_$player_id" в хранилище бустов игры.
Ключ создается методом activate_double_shot_boost() и удаляется методом remove_double_shot_boost().

=item * Пример использования

    if ($game->has_double_shot_boost($current_player)) {
        $game->process_extra_shot();
    }

=item * Взаимодействие с другими методами

=over 8

=item *

Используется вместе с activate_double_shot_boost() и remove_double_shot_boost()

=item *

Влияет на поведение метода process_turn()

=back

=item * Особенности

=over 8

=item *

Не изменяет состояние игры, только проверяет его

=item *

Быстрая проверка через exists (O(1) сложность)

=back

=back

=cut

sub has_double_shot_boost {
    my ($self, $player_id) = @_;

    return exists $self->accessor('boosts')->{"double_shot_$player_id"};
}

=head2 remove_double_shot_boost

Деактивирует буст "двойного выстрела" для указанного игрока.

=over 4

=item * Параметры

=over 8

=item C<$player_id> - идентификатор игрока (строка)

=back

=item * Логика работы

Удаляет запись о бусте из хранилища boosts. Обычно вызывается:
1. После использования дополнительного хода
2. При завершении игры
3. При принудительном сбросе бустов

=item * Пример использования

    $game_state->remove_double_shot_boost('player_123');

=back

=cut

sub remove_double_shot_boost {
    my ($self, $player_id) = @_;
    delete $self->accessor('boosts')->{"double_shot_$player_id"};
}

=head2 next_turn

Определяет и устанавливает следующего игрока для хода в соответствии с правилами:

=over 4

=item * Если текущий игрок не установлен (первый ход в игре) - выбирает случайного игрока

=item * Для последующих ходов переключает на следующего игрока по кругу

=item * Если текущий игрок не найден в списке - начинает с первого игрока

=back

Возвращает идентификатор игрока, который должен ходить следующим.

=cut

sub next_turn {
    my ($self) = @_;

    my $players = $self->accessor('players');

    unless ($self->accessor('current_turn')) {
        $self->accessor('current_turn', $players->[rand @$players]);
        return $self->accessor('current_turn');
    }

    my $current_idx = first { $players->[$_] eq $self->accessor('current_turn') } 0..$#$players;
    $current_idx //= 0;

    my $next_player = $players->[($current_idx + 1) % @$players];

    $self->accessor('current_turn', $next_player);

    return $self->accessor('current_turn');;
}

# Проверка попадания в диапазон доски
sub valid_coordinates {
    my ($self, $x, $y) = @_;

    my $size = $self->accessor('board_size');

    return $x >= 0 && $x < $size && $y >= 0 && $y < $size;
}

# Сериализация состояния в JSON
sub serialize {
    my ($self) = @_;
    return encode_json({
        game_id         => $self->accessor('game_id'),
        board_size      => $self->accessor('board_size'),
        players         => $self->accessor('players'),
        ships_positions => $self->accessor('ships_positions'),
        turn_order      => $self->accessor('turn_order'),
        current_turn    => $self->accessor('current_turn'),
        boosts          => $self->accessor('boosts'),
    });
}

# Десериализация из JSON
sub deserialize {
    my ($class, $serialized) = @_;
    my $data = decode_json($serialized);
    return $class->new(%$data);
}

# Загрузка состояния из БД (реализуйте по своей схеме)
sub load_json_from_db {
    my ($class, $game_id) = @_;
    die "load_json_from_db not implemented";
}

# Сохранение состояния в БД (реализуйте по своей схеме)
sub save_json_to_db {
    my ($class, $game_id, $json) = @_;
    die "save_json_to_db not implemented";
}

# Оппонент текущего игрока
sub opponent_of {
    my ($self, $player) = @_;
    for my $p (@{ $self->accessor('players') }) {
        return $p if $p ne $player;
    }
    return;
}

# Проверка окончания игры: все корабли оппонента уничтожены?
sub all_ships_destroyed {
    my ($self, $player) = @_;
    # TODO: проверка флагов попаданий по ships_positions и истории выстрелов
    return 0;
}

1;