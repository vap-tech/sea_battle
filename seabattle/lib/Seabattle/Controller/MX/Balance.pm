package Seabattle::Controller::MX::Balance;
use Mojo::Base qw(Mojolicious::Controller Mojo::Cookie);
use JSON qw(decode_json encode_json);
use strict;
use warnings FATAL => 'all';


use Seabattle::Controller::MX::Token;

my $config = decode_json do { local (@ARGV, $/) = ('config/config.json'); <> };
my $redis = Redis->new(server => "$config->{'redis'}{'host'}:$config->{'redis'}{'port'}");


sub deposit {
    my ($self) = @_;

    my $dbh = $self->schema->storage->dbh;

    my $user_id = $self->_verify_access_token;
    return $self->render(json => {error => 'Unauthorized'}, status => 401) unless defined $user_id;

    my $amount = $self->req->json->{amount};

    unless (defined $amount && $amount =~ /^\d+(\.\d+)?$/ && $amount > 0) {
        return $self->render(json => {error => 'Invalid amount'}, status => 400);
    }

    eval {

        my $sth = $dbh->prepare(
            "INSERT INTO mx_user_amount (user_id, amount, total_paid)
             VALUES (?, ?, ?)
             ON DUPLICATE KEY UPDATE
                amount = amount + VALUES(total_paid),
                total_paid = total_paid + VALUES(total_paid)"
        );

        $sth->execute($user_id, $amount, $amount);

        # Получаем обновленный баланс для ответа
        $sth = $dbh->prepare("SELECT amount FROM mx_user_amount WHERE user_id = ?");
        $sth->execute($user_id);
        my $row = $sth->fetchrow_hashref;

        $self->render(json => {
            success => 1,
            user_id => $user_id,
            new_balance => $row->{amount}
        });

    }
        or do {
        $dbh->rollback();
        $self->app->log->error("Database error: $@");

        return $self->render(json => {error => "Database operation failed"}, status => 500);
    };

}

sub current {
    my ($self) = @_;

    my $dbh = $self->schema->storage->dbh;

    my $user_id = $self->_verify_access_token;
    return $self->render(json => {error => 'Unauthorized'}, status => 401) unless defined $user_id;

    eval {
        my $sth = $dbh->prepare(
            "SELECT amount, total_paid FROM mx_user_amount WHERE user_id = ?"
        );

        $sth->execute($user_id);
        my $row = $sth->fetchrow_hashref;

        if ($row) {
            $self->render(json => {
                success => 1,
                user_id => $user_id,
                current_balance => $row->{amount},
                total_paid => $row->{total_paid}
            });
        } else {
            $self->render(json => {
                success => 1,
                user_id => $user_id,
                current_balance => 0,
                total_paid => 0,
                notice => 'No records found, using default values'
            });
        }
    }
        or do {
        $self->app->log->error("Database error: $@");

        return $self->render(json => {error => "Database operation failed"}, status => 500);
    };

    return;
}

sub subtract {
    my ($self) = @_;

    my $dbh = $self->schema->storage->dbh;

    my $user_id = $self->_verify_access_token;
    return $self->render(json => {error => 'Unauthorized'}, status => 401) unless defined $user_id;

    my $amount = $self->req->json->{amount};

    unless (defined $amount && $amount =~ /^\d+(\.\d+)?$/ && $amount > 0) {
        return $self->render(json => {error => 'Invalid amount'}, status => 400);
    }


    eval {
        # 1. Проверяем текущий
        my $sth = $dbh->prepare("SELECT amount FROM mx_user_amount WHERE user_id = ? FOR UPDATE");
        $sth->execute($user_id);
        my $row = $sth->fetchrow_hashref;

        unless ($row && $row->{amount} >= $amount) {
            $dbh->rollback;
            return $self->render(json => {
                error => 'Insufficient funds',
                current_balance => $row ? $row->{amount} : 0,
                required_amount => $amount
            }, status => 402); # 402 Payment Required
        }

        # 2. Списание
        $sth = $dbh->prepare(
            "UPDATE mx_user_amount SET amount = amount - ? WHERE user_id = ?"
        );
        $sth->execute($amount, $user_id);

        # 3. Обновленный баланс
        $sth = $dbh->prepare("SELECT amount FROM mx_user_amount WHERE user_id = ?");
        $sth->execute($user_id);
        $row = $sth->fetchrow_hashref;

        $dbh->commit;

        $self->render(json => {
            success => 1,
            user_id => $user_id,
            amount_subtracted => $amount,
            new_balance => $row->{amount}
        });
    }
        or do {
        $dbh->rollback;
        $self->app->log->error("Database error: $@");
        return $self->render(json => {error => "Database operation failed"}, status => 500);
    };

    return;

}

sub _verify_access_token {
    my ($self) = @_;

    my $access_token = $self->cookie('access_token');

    unless (defined $access_token) {
        $self->render(
            json => {
                error   => "token_not_found",
                message => "Access token not found, please refresh"
            },
            status => 401
        );
        return undef;
    }

    my $payload = Seabattle::Controller::MX::Token::verify_token($access_token);
    unless ($payload && $payload->{sub}) {
        $self->render(
            json => {
                error   => "token_invalid",
                message => "Invalid access token, please refresh"
            },
            status => 401
        );
        return undef;
    }

    my $user_id = $payload->{sub};

    unless ($redis->get("access_token:$user_id")) {
        $self->render(
            json => {
                error   => "token_expired",
                message => "Access token expired, please refresh"
            },
            status => 401
        );
        return undef;
    }

    return $user_id;
}

1;