use Mojolicious::Lite;
use Mojo::SQLite;

app->plugin('Config');
app->defaults('message' => undef);

helper sqlite => sub { state $sqlite = Mojo::SQLite->new('sqlite:tacos.db') };
helper seen_movies => sub { shift->sqlite->db->select('movies', undef, { seen => { -not => undef } }, { -asc => ['seen'] })->hashes };
helper unseen_movies => sub { shift->sqlite->db->select('movies', undef, { seen => undef }, { -desc => ['upvotes', 'id'] })->hashes };
helper upvote => sub { shift->sqlite->db->update('movies', { upvotes => \'upvotes + 1' }, { id => shift() }) };
helper seen => sub { shift->sqlite->db->update('movies', { seen => time() }, { id => shift() }) };
helper unseen => sub { shift->sqlite->db->update('movies', { seen => undef }, { id => shift() }) };

app->sqlite->migrations->name('tacos')->from_string(<<SQL)->migrate;
-- 1 up
create table movies (id integer primary key autoincrement, title text, picture text, seen integer default null, upvotes integer default 0);
-- 1 down
drop table movies;
SQL


get '/' => 'movies';
post '/' => sub {
  my $c = shift;

  my $movie = {
    title => $c->param('title'),
    picture => $c->param('picture'),
  };
  $c->sqlite->db->insert('movies', $movie);

  return $c->render('movies');
};

get '/upvote/:id' => sub {
  my $c = shift;

  $c->upvote($c->param('id'));

  return $c->redirect_to('/');
};

get '/seen/:id' => sub {
  my $c = shift;

  $c->seen($c->param('id'));

  return $c->redirect_to('/');
};

get '/unseen/:id' => sub {
  my $c = shift;

  $c->unseen($c->param('id'));

  return $c->redirect_to('/');
};

app->start;

__DATA__

@@ movies.html.ep
% layout 'main';

%= form_for '/' => (method => 'POST') => begin
    %= label_for 'title' => 'Movie title'
    %= text_field 'title', id => 'title', required => 'required', autofocus => 'autofocus'

    %= label_for 'picture' => 'Poster URL'
    %= url_field 'picture', id => 'picture', required => 'required'

    %= submit_button 'Add movie'
% end

<h3>Movies to see</h3>
<table class="movies">
% foreach my $movie (@{ unseen_movies() }) {
  <tr>
    <td class="poster"><img src="<%= $movie->{picture} %>" /></td>
    <td class="upvotes">[<%= $movie->{upvotes} // 0 %>]</td>
    <td class="title"><%= $movie->{title} %></td>
    <td class="action">
      <a href="/upvote/<%= $movie->{id} %>">+1</a><br/>
      <a href="/seen/<%= $movie->{id} %>">Seen</a>
    </td>
  </tr>
% }
</table>

<h3>History</h3>
<table class="movies">
% foreach my $movie (@{ seen_movies() }) {
  <tr>
    <td class="poster"><img src="<%= $movie->{picture} %>" /></td>
    <td class="title"><%= $movie->{title} %></td>
    <td class="action">
      <a href="/unseen/<%= $movie->{id} %>">Unseen</a>
    </td>
  </tr>
% }
</table>

@@ layouts/main.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title>Movie night</title>
    <meta charset="utf-8">
    <style>
      body { width: 900px; margin: auto; }
      table { width: 100%; font-size: 1.333433em; font-weight: bold; }
      .poster { height: 170px; width: 200px; }
      .poster img { max-height: 160px; max-width: 200px; }
      .upvotes { width: 100px; }
      .action { width: 100px; text-align: center; }
    </style>
  </head>
  <body>
    <h1>Movie night</h1>
    <%== ($message) ? "<h2>$message</h2>" : undef %>
    <%= content %>
  </body>
</html>
