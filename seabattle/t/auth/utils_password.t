use strict;
use warnings;
use Test::More;
use FindBin;
use List::Util 'any';
BEGIN { unshift @INC, "$FindBin::Bin/../lib" };

# Подключаем модуль с нашей функцией
use Seabattle::Auth::Utils 'generate_secure_password';

# Тест 1: Проверка минимальной длины
sub test_password_length_range {
    for my $i (1..20) {
        my $pass = generate_secure_password();
        my $len = length $pass;
        ok($len >= 6 && $len <= 10, "Password length $len is between 6-10")
            or diag("Got password: '$pass' with length $len");
    }
}

# Тест 2: Проверка наличия заглавной буквы
sub test_has_uppercase {
    for (1..20) {
        my $pass = generate_secure_password();
        ok($pass =~ /[A-Z]/, "Contains uppercase (try $_)")
            or diag("Password: $pass");
    }
}

# Тест 3: Проверка наличия строчной буквы
sub test_has_lowercase {
    for my $i (1..20) {
        my $pass = generate_secure_password();
        ok($pass =~ /[a-z]/, "Contains lowercase (try $i)")
            or diag("Password: $pass");
    }
}

# Тест 4: Проверка наличия спецсимвола
sub test_has_special_char {
    my @special = split //, '%*?@#$!';

    for (1..20) {
        my $pass = generate_secure_password();
        my $has_special = any { index($pass, $_) >= 0 } @special;
        ok($has_special, "Contains special char (try $_)")
            or diag("Password: $pass");
    }
}

# Тест 5: Проверка допустимых символов
sub test_valid_chars {
    for my $i (1..20) {
        my $pass = generate_secure_password();
        ok($pass =~ /^[A-Za-z%*?@#\$!]+$/,
           "Only allowed chars (try $i)")
            or diag("Invalid chars in: $pass");
    }
}

# Запуск тестов
test_password_length_range();
test_has_uppercase();
test_has_special_char();
test_valid_chars();

done_testing();