#!/usr/bin/env perl

use Mojolicious::Lite;
use DBI;
use File::Slurp;


# Documentation browser under "/perldoc" (this plugin requires Perl 5.10)
plugin 'tt_renderer';
my $config = plugin 'json_config';
my $flash;

sub set_flash {
    my $message = shift;

    $flash = $message;
}

sub get_flash {

    my $msg = $flash;
    $flash = "";

    return $msg;
}

sub connect_db {
    my $dbh = DBI->connect("dbi:SQLite:dbname=".$config->{database}) or
    die $DBI::errstr;

    return $dbh;
}

sub init_db {
    my $db = connect_db();
    my $schema = read_file('./schema.sql');
    $db->do($schema) or die $db->errstr;
}

app->defaults( 
    css_url =>  app->url_for('/css/style.css'),
    login_url => app->url_for('login'),
    logout_url => app->url_for('logout'),
    layout =>'main',
);

get '/' => sub {
       my $self=shift;
       my $db = connect_db();
       my $sql = 'select id, title, text from entries order by id desc';
       my $sth = $db->prepare($sql) or die $db->errstr;
       $sth->execute or die $sth->errstr;
       $self->render( 
           template =>'show_entries',
            msg     => get_flash(),
            add_entry_url => $self->url_for('/add'),
            entries => $sth->fetchall_hashref('id'),
       );
};

post '/add' => sub {
    my $self=shift;
    if ( not $self->session('logged_in') ) {
        return self->render(text=>"Not logged in", status=>401);
    }

    my $db = connect_db();
    my $sql = 'insert into entries (title, text) values (?, ?)';
    my $sth = $db->prepare($sql) or die $db->errstr;
    $sth->execute($self->param('title'), $self->param('text')) or die $sth->errstr;

    set_flash('New entry posted!');
    $self->redirect_to('/');
};

any [qw/get post/] => '/login' => sub {
    my $self=shift;
    my $err;

    if ( $self->req->method eq "POST" ) {
        # process form input
        if ( $self->param('username') ne $config->{username} ) {
            $err = "Invalid username";
        }
        elsif ( $self->param('password') ne $config->{password} ) {
            $err = "Invalid password";
        }
        else {
            $self->session( 'logged_in' => 1 );
            set_flash('You are logged in.');
            return $self->redirect_to('/');
        }
    }

    # display login form
    $self->render( 'login', 'err' => $err, );
};

get '/logout' => sub {
    my $self=shift;
    $self->session(expires => 1);
    set_flash('You are logged out.');
    $self->redirect_to('/');
};

init_db();

app->start;
