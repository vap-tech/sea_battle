use Modern::Perl;
use Test::Spec;
use Seabattle::Auth::Utils qw(
    is_valid_email
    is_valid_pass
);

describe "Method" => sub {
    describe 'is_valid_email' => sub {
        it 'should validate correct emails' => sub {
            ok(is_valid_email('user@example.com'));
            ok(is_valid_email('user.name@example.com'));
            ok(is_valid_email('user-name@example.com'));
            ok(is_valid_email('user_name@example.com'));
            ok(is_valid_email('user+name@sub.example.ru'));
            ok(is_valid_email('user.name@sub.example.ru'));
        };

        it 'should reject emails without @' => sub {
            ok(!is_valid_email('user.example.com'));
            ok(!is_valid_email('user'));
        };

        it 'should reject emails with multiple @' => sub {
            ok(!is_valid_email('user@@example.com'));
            ok(!is_valid_email('user@name@example.com'));
        };

        it 'should reject emails with invalid local part' => sub {
            ok(!is_valid_email('.user@example.com')); 
            ok(!is_valid_email('user.@example.com')); 
            ok(!is_valid_email('user..name@example.com')); 
            ok(!is_valid_email('user--name@example.com'));   
        };

        it 'should reject emails with invalid domain part' => sub {
            ok(!is_valid_email('user@.com'));            
            ok(!is_valid_email('user@example..com'));    
            ok(!is_valid_email('user@example-.com'));    
            ok(!is_valid_email('user@-example.com'));           
        };

        it 'should reject emails with invalid TLD' => sub {
            ok(!is_valid_email('user@example.a'));
            ok(!is_valid_email('user@example.1'));
            ok(!is_valid_email('user@example.com-'));     
      
        };

        it 'should reject emails with invalid chars' => sub {
            ok(!is_valid_email('user@ex*mple.com'));    
            ok(!is_valid_email('user@exa(mple.com'));    
            ok(!is_valid_email('user@exa\\mple.com'));   
        };
    };

    describe 'is_valid_pass' => sub {
        it 'should accept valid password' => sub {
            ok(is_valid_pass('User1!'));
        };

        it 'should reject too short passwords' => sub {
            ok(!is_valid_pass('Usr1!'));
        };

        it 'should require at least one uppercase letter' => sub {
            ok(!is_valid_pass('user1!'));
        };

        it 'should require at least one special char' => sub {
            ok(!is_valid_pass('User12'));
        };

        it 'should reject passwords with invalid char' => sub {
            ok(!is_valid_pass('User1^'));
        };

        it 'should reject undef password' => sub {
            ok(!is_valid_pass(undef));
        };

        it 'should reject empty password' => sub {
            ok(!is_valid_pass(''));
        };
    };

};

runtests unless caller;

