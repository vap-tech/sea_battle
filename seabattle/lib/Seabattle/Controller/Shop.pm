package Seabattle::Controller::Shop;
use Mojo::Base 'Mojolicious::Controller';

sub get_items {
    my $c = shift;

    my @items = $c->app->schema->resultset('ShopItem')->search(
        {},
        { order_by => 'id' }
    )->all;

    my @result = map {
        { id => $_->id, name => $_->name, price => $_->price }
    } @items;

    $c->render(json => { items => \@result });
}

sub buy_item {
    my $c = shift;

    my $user_id = $c->param('user_id') or return $c->render(json => { error => 'user_id missing' }, status => 400);
    my $item_id = $c->param('item_id') or return $c->render(json => { error => 'item_id missing' }, status => 400);

    my $schema = $c->app->schema;

    my $item = $schema->resultset('ShopItem')->find($item_id);
    return $c->render(json => { error => 'Bad item' }, status => 400) unless $item;

    my $user_stats = $schema->resultset('UserStat')->find({ user_id => $user_id });
    return $c->render(json => { error => 'User stats not found' }, status => 404) unless $user_stats;

    my $price = $item->price;
    if ($user_stats->coins < $price) {
        return $c->render(json => { error => 'Insufficient funds' }, status => 400);
    }

    $schema->txn_do(sub {
        $user_stats->update({ coins => $user_stats->coins - $price });

        $schema->resultset('Purchase')->create({
            user_id   => $user_id,
            item_id   => $item_id,
            bought_at => \"NOW()",
        });
    });

    $c->render(json => {
        success     => 1,
        new_balance => $user_stats->coins - $price,
    });
}

1;
