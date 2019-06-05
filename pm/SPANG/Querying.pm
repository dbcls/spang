package SPANG::Querying;
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(submit_sparql submit_sparql_by_curl submit_sparql_insert_delete
             get_remote_file_content);

use strict;
use LWP::UserAgent;
use URI::Escape;
use SPANG::Prefix;
use SPANG::JSON;

################################################################################
### Public functions ###########################################################
################################################################################

sub submit_sparql_insert_delete {
    my ($server, $query, %opt) = @_;
    
    my $host_name = $server;
    $host_name =~ s/^http:\/\/(.*?)\/.*/$1/;

    my $agent = LWP::UserAgent->new;
    if ($opt{timeout}) {
	$agent->timeout($opt{timeout});
    }
    $agent->credentials($host_name, "SPARQL", $opt{user}, $opt{password});
    
    my $response = $agent->post("http://$host_name/sparql-auth", Content => "query=" . uri_escape($query), 'Content-Type' => 'application/x-www-form-urlencoded');
    if (! $response->is_success) {
	print STDERR $response->status_line, "\n";
	return;
    }

    my $result = $response->content;
    print $result, "\n";
}

sub submit_sparql_by_curl {
    my ($server, $query, %opt) = @_;

    my $accept_header = get_accept_header($opt{format});
    my $query_escaped = uri_escape($query);
    $query_escaped =~ s/%20/+/g;

    my $command = "curl -LsS -H 'Accept: $accept_header'";
    if ($opt{user} and $opt{password}) {
	$command .= " -u '$opt{user}:$opt{password}'";
    }
    if ($opt{timeout}) {
	$command .= " -m $opt{timeout}";
    }
    my $apikey = "";
    if ($opt{key}) {
	$apikey = "apikey=5cc7e833-a36a-451b-9250-8ec3821974b7&";
    }
    $command .= " '$server?${apikey}query=$query_escaped'";

    if ($opt{debug}) {
	print STDERR "$command\n";
	return;
    }

    my $result =  `$command`;

    if ($opt{format} eq "tsv") {
	$result = json_to_tsv($result, header => $opt{header});
    }

    return $result;
}

sub submit_sparql {
    my ($server, $query, %opt) = @_;

    my $request = HTTP::Request->new(POST => $server);

    ### Set header for the request ###
    my $accept_header;
    if ($opt{recursive}) {
	$accept_header = get_accept_header('n-triples');
    } else {
	$accept_header = get_accept_header($opt{format});
    }
    if ($accept_header) {
	$request->header('accept' => $accept_header);
    }

    $request->content_type('application/x-www-form-urlencoded');
    $request->content("query=" . uri_escape($query));
    if ($opt{user} and $opt{password}) {
	$request->authorization_basic($opt{user}, $opt{password});
    }

    my $agent = LWP::UserAgent->new;
    if ($opt{timeout}) {
	$agent->timeout($opt{timeout});
    }

    ### Submit request ###
    my $response = $agent->request($request);
    if (! $response->is_success) {
	print STDERR $response->status_line, "\n";
	print STDERR "--\n";
	print STDERR $response->content;
	return;
    }

    my $result = $response->content;

    if (! $opt{recursive}) {
	if ($opt{format} eq "tsv") {
	    $result = json_to_tsv($result, header => $opt{header});
	}
	$result =~ s/\b_:vb(\d+)\b/<nodeID:\/\/b$1>/g;
	$result =~ s/\b_:b(\d+)\b/<nodeID:\/\/b$1>/g;
	$result =~ /\n$/ or $result =~ s/$/\n/;
	return $result;
    }

    ### Recursive querying (submit query -> result=SPIN -> SPARQL -> submit query)
    my $spin_agent = LWP::UserAgent->new;
    my $spin_escaped = uri_escape($result);
    my $spin_response = $spin_agent->get("http://spinservices.org:8080/spin/sparqlmotion?id=spin2sparql&rdf=$spin_escaped&format=turtle");
    if (! $spin_response->is_success) {
	print STDERR $spin_response->status_line, "\n";
	return;
    }

    my $sparql = $spin_response->content;

    my @format_opt = ();
    $opt{format} and push(@format_opt, "-f $opt{format}");
    $opt{header} and push(@format_opt, "-v");
    $opt{a} and push(@format_opt, "-a");
    $opt{b} and push(@format_opt, "-b");

    open(PIPE, "| $opt{recursive} $server - @format_opt") || die;
    print PIPE $sparql;
    close(PIPE);
}

sub get_remote_file_content {
    my ($remote_file_name, $r_get_short_prefix, $r_get_long_prefix, $r_nickname2url, $spang_dir, %opt) = @_;

    my @alias_file = ("$spang_dir/etc/locations", "$ENV{HOME}/.spang/locations");
    my %get_uri = ();
    read_aliases(\%get_uri, @alias_file);

    ### Get full URI ###
    if ($remote_file_name !~ /^(http|https|ftp):\/\//) {
	if ($remote_file_name =~ /^(\S+?:)(.*)$/) {
	    my ($short_prefix, $name) = ($1, $2);
	    if (${$r_get_long_prefix}{$short_prefix}) {
		$remote_file_name = ${$r_get_long_prefix}{$short_prefix} . $name;
	    } else {
		die "unknown prefix $short_prefix\n";
	    }
	} else {
	    if ($get_uri{$remote_file_name}) {
		$remote_file_name = $get_uri{$remote_file_name};
	    } elsif (${$r_nickname2url}{$remote_file_name}) {
		$remote_file_name = ${$r_nickname2url}{$remote_file_name};
	    } elsif (${$r_get_long_prefix}{"${remote_file_name}:"}) {
		$remote_file_name = ${$r_get_long_prefix}{"${remote_file_name}:"};
	    } else {
		die "unknown remote file '$remote_file_name'\n";
	    }
	}
    }

    ### Output ###
    my $header = "";
    if ($opt{format} and $opt{format} =~ /^rdf\/xml|rdfxml$/) {
	$header = "-H 'Accept: application/rdf+xml'";
    } elsif ($opt{format} and $opt{format} =~ /^turtle|ttl$/) {
	$header = "-H 'Accept: text/turtle'";
    }

    my $command = "curl $header -LsSf $remote_file_name";
    if ($opt{w}) {
	$command = "wget $remote_file_name";
    } elsif ($opt{client}) {
	$command = "$opt{client} $remote_file_name";
    }

    # if ($opt{format} and $opt{format} =~ /^turtle|ttl$/) {
    # 	$command .= " | $spang_dir/bin/rdf2ttl";
    # }

    if ($opt{debug}) {
	print STDERR "$command\n";
	exit;
    }

    my $result = `$command`;
    $result = abbrev_result($result, $r_get_short_prefix, %opt);
    $result =~ /\n$/ or $result =~ s/$/\n/;
    return $result;
}

################################################################################
### Private functions ##########################################################
################################################################################
sub get_accept_header {
    my ($format) = @_;

    my %ACCEPT_HEADER = (
	"xml"      => "application/sparql-results+xml",
	"json"     => "application/sparql-results+json",
	"tsv"      => "application/sparql-results+json",
	"rdf/xml"  => "application/rdf+xml",
	"rdfxml"   => "application/rdf+xml",
	"turtle"   => "application/x-turtle",
	"ttl"      => "application/x-turtle",
	"n3"       => "text/rdf+n3",
	"n-triples"=> "text/plain",
	"nt"       => "text/plain",
	"html"     => "text/html",

	"rdfjson"  => "application/rdf+json",
	"rdfbin"   => "application/x-binary-rdf",
	"rdfbint"  => "application/x-binary-rdf-results-table",
	"js"       => "application/javascript",
	"bool"     => "text/boolean",
	);

    if ($ACCEPT_HEADER{$format}) {
	return $ACCEPT_HEADER{$format};
    } else {
	return $format;
    }
}

sub read_aliases {
    my ($r_get_uri, @file) = @_;

    # If files do not exist, the hash remains empty 

    my @line = ();
    for my $file (@file) {
	if (-f $file) {
	    my @line = `cat $file`;
	    for my $line (@line) {
		my ($alias, $uri) = split(/\s+/, $line);
		if ($alias and $uri) {
		    ${$r_get_uri}{$alias} = $uri;
		}
	    }
	}
    }
}

1;
