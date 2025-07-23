package Seabattle::Model::Ship;
use strict;
use warnings FATAL => 'all';

use List::Util qw(all);
use List::MoreUtils qw(first_index);
use JSON qw(encode_json decode_json);

sub new {
    my ($class, %args) = @_;

    return bless({
        size => $args{size},
        coordinates => $args{coordinates},
        influence_zone => $args{influence_zone},
        name => $args{name},
        hit_status => [map {0} 1..$args{size}]
    }, $class);
}

# Проверка уничтожения корабля
sub is_destroyed {
    my ($self) = @_;

    return List::Util::all { $_ == 1 } @{$self->hit_status()};
}

# Воскрешения корабля
sub revive {
    my ($self) = @_;

    map { $_ = 0 } @{$self->hit_status()};
}

# Метод нанесения удара по кораблю
sub take_damage {
    my ($self, $x, $y) = @_;

    # Проверяем попадание в координаты корабля
    my $hit_index = first_index { $_->{x} == $x && $_->{y} == $y } @{$self->coordinates};

    return 0 if $hit_index == -1;  # Промах

    # Попадание - обновляем статус
    $self->hit_status->[$hit_index] = 1;

    return 1;
}

# TO JSON
sub serialize {
    my ($self) = @_;

    return encode_json({
        size => $self->size(),
        coordinates => $self->coordinates(),
        influence_zone => $self->influence_zone(),
        name => $self->name(),
        hit_status => $self->hit_status()
    });
}

# FROM JSON
sub deserialize {
    my ($class, $json_string) = @_;

    my $data = decode_json($json_string);

    return $class->new(
        size => $data->{size},
        coordinates => $data->{coordinates},
        influence_zone => $data->{influence_zone},
        name => $data->{name},
        hit_status => $data->{hit_status}
    );
}

# Геттеры и сеттеры
sub name           { $_[0]->{name} }
sub coordinates    { $_[0]->{coordinates} }
sub influence_zone { $_[0]->{influence_zone} }
sub hit_status     { $_[0]->{hit_status} }
sub size           { $_[0]->{size} }

1;