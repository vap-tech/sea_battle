use strict;
use warnings;
use Test::More;
use Test::Mojo;

# Запускаем приложение
use FindBin;
use lib "$FindBin::Bin/../lib";
use Seabattle;

my $t = Test::Mojo->new('Seabattle');

# 1. Проверка что API /game/rating возвращает 200 OK
$t->get('/game/rating')->status_is(200);

# 2. Проверка структуры JSON
$t->get('/game/rating')
  ->status_is(200)
  ->json_is('/rating/0/nickname' => qr/.+/)
  ->json_is('/rating/0/score'    => qr/^\d+$/)
  ->json_is('/rating/0/rank'     => qr/^(Матрос|Лейтенант|Капитан|Адмирал)$/)
  ->json_is('/rating/0/position' => 1);

done_testing;
