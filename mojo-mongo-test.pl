#!/usr/bin/env perl

use Mojolicious::Lite;
use MongoDB::Connection;
use File::Slurp;

plugin 'tt_renderer';
my $config = {
    database => "dancr",
    username => "admin",
    password => "password"
};

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
    my $db = MongoDB::Connection->new(host=>'localhost')
      ->get_database($config->{database})
      ->get_collection('posts');

    return $db;
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
       my $items=$db->find();
       $self->render( 
           template =>'show_entries',
            msg     => get_flash(),
            add_entry_url => $self->url_for('/add'),
            entries => [$items->all],
       );
};

post '/add' => sub {
    my $self=shift;
    if ( not $self->session('logged_in') ) {
        return self->render(text=>"Not logged in", status=>401);
    }

    my $db = connect_db();
    $db->insert({ title => $self->param('title'), text=> $self->param('text')});

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


app->start;
