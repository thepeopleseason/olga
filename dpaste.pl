use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use Data::Dumper;

sub dpaste {
  my ($content) = @_;

  # Create a user agent object
  my $ua = LWP::UserAgent->new;

  # Create a request
  my $req = HTTP::Request->new(POST => 'http://dpaste.com/api/v1/');
  $req->content("content=$content");

  # Pass request to the user agent and get a response back
  my $res = $ua->request($req);

  # Check the outcome of the response
  my $result;
  $result = $res->header('location')
    if ($res->code == 302);

  return $result;
}

1;
