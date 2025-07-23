#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 8;
use Seabattle::Model::Ship;

# Создаём корабль
my $ship = Seabattle::Model::Ship->new(
    size => 3,
    coordinates => [
        { x => 1, y => 1 },
        { x => 1, y => 2 },
        { x => 1, y => 3 }
    ],
    name => 'Corvette'
);

# Case 1: Тест метода is_destroyed()
ok(!$ship->is_destroyed(), 'Новый корабль не уничтожен');

# Наносим повреждения
$ship->take_damage( 1, 1);
my $hit = $ship->take_damage( 1, 2 );

# Case 2: Проверка попадания
is($hit, 1, 'Есть попадание');

# Стреляем мимо в перевёрнутые координаты
$hit = $ship->take_damage( 3, 1 );

# Case 3: Проверка промаха
is($hit, 0, 'Есть промах в перевёрнутые координаты');


# Case 4: Проверяем частично повреждённый корабль
ok(!$ship->is_destroyed(), 'Частично повреждённый корабль не считается уничтоженным');

# Наносим последний удар
$ship->take_damage( 1, 3 );

# Case 5: Проверяем полностью уничтоженный корабль
ok($ship->is_destroyed(), 'Корабль уничтожен полностью');

# Восстанавливаем корабль (для буста)
$ship->revive();

# Case 6: Проверяем возвращение жизни
ok(!$ship->is_destroyed(), 'Восставший корабль вновь жив');

# Case 7: Тест сериализации корабля
my $serialized = $ship->serialize();
like($serialized, qr/"name":"Corvette"/, 'Сериализация прошла успешно');

# Тест десериализации корабля
my $deserialized_ship = Seabattle::Model::Ship->deserialize($serialized);
is_deeply($deserialized_ship->coordinates(), $ship->coordinates(), 'Десериализация прошла успешно');

done_testing();
