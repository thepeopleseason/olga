use strict;
use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Response;

my (@agents) = qw(Slicey Linkovich PeteShablatch Olga Beanfield);
my (@versions) = qw(0.4b 0.28 1.3 3.9a 2.0 0.1.1);

sub title_search 
{
    my ($ua) = LWP::UserAgent->new ();
    my ($keywords) = join (' ', @_);
    my ($response, $url);

    $ua->agent ($agents[rand (@agents)] . '/' . $versions[rand (@versions)]);
    $response = $ua->request (POST 'http://us.imdb.com/Lookup',
			      ['for' => $keywords, 'type' => 'title']);

    if (!$response->is_success () && $response->code () eq '302') {
	$url = $response->header ('location');
	$url = 'http://us.imdb.com' . $url unless $url =~ m!^http://!;
	$response = fetch_page ($url);
    }
    
    return ($response);
}
    
sub movie_titles
{
    my (@query) = @_;
    my ($response) = title_search (@query);
    my ($content, $title);

    if ($response->is_success)  {
	($title) = $response->content () =~ m!<title>(.+?)</title>!is;
	if ($title =~ /imdb\s*title\s*search/) {
	    ($content) = $response->content =~ 
	      m!<h2>movies</h2>.*?(<ol>.+?</ol>)!is;
	    $content =~ s/<BR>/\n/isg;
	    $content =~ s/<.+?>//sg;
	    $content =~ s/\(.+?\)$//mg;
	}

	else {
	    $content = $title;
	}
    }

    else  {
	die $response->error_as_HTML (), "\n";
    }
    
    return ($content);
}


sub fetch_page
{
    my ($url) = shift;
    my ($ua, $response);

    $ua = LWP::UserAgent->new ();
    $ua->agent ($agents[rand (@agents)] . '/' . 
		$versions[rand (@versions)]);
    $response = $ua->request (GET $url);

    return ($response);
}

    
    
    

