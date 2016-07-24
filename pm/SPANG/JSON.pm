package SPANG::JSON;
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(json_to_tsv);

use strict;
use Encode;

################################################################################
### Public functions ###########################################################
################################################################################

sub json_to_tsv {
    my ($json, %opt) = @_;

    my $tsv = "";

    my @vars = get_json_vars($json);
    if ($opt{header}) {
	# $tsv .= join("\t", @vars) . "\n";
	# $tsv .= join("\t", map {"?$_"} @vars) . "\n";
	$tsv .= join("\t", map { /^\?/ ? $_ : "?$_" } @vars) . "\n";
    }

    if ($json eq "") {
	return "";
    }

    my $hash = parse_json($json);

    if (ref($hash) ne "HASH") {
	print $json;
	die "ERROR: cannot convert results from JSON to tsv.\n";
    }

    my @array = ${$hash}{results}{bindings};
    for (my $i=0; $i<@{$array[0]}; $i++) {
	my $result = $array[0][$i];
	my @values = ();
	for my $var (@vars) {
	    if (! ${$result}{$var}) {
		push @values, "";
	    } elsif (${$result}{$var}{type} eq "uri") {
		push @values, "<${$result}{$var}{value}>";
	    } elsif (${$result}{$var}{type} eq "bnode") { # for Virtuoso
		push @values, "<${$result}{$var}{value}>";
	    } elsif (${$result}{$var}{type} eq "literal" or ${$result}{$var}{type} eq "typed-literal") {
		my $value = "\"${$result}{$var}{value}\"";
		if (${$result}{$var}{'xml:lang'}) {
		    $value .= "\@${$result}{$var}{'xml:lang'}";
		}
		if (${$result}{$var}{datatype}) {
		    $value .= "^^<${$result}{$var}{datatype}>";
		}
		push @values, $value;
	    } else {
		push @values, ${$result}{$var}{value};
	    }
	}
	$tsv .= join("\t", @values) . "\n";
    }

    return $tsv;
}

################################################################################
### Private functions ##########################################################
################################################################################

sub get_json_vars {
    my ($json) = @_;

    if ($json =~ /.*?"vars"\s*:\s*\[\s*(.*?)\s*\]/s) {
	my $vars = $1;
	my @vars = split(",", $vars);
	for (my $i=0; $i<@vars; $i++) {
	    if ($vars[$i] =~ /^\s*"(\S+)"\s*$/) {
		$vars[$i] = $1;
	    } else {
		return;
	    }
	}
	return @vars;
    } else {
	return;
    }
}

sub parse_json {
    my ($json) = @_;
    
    my %json_val = ('true'=>1, 'false'=>0, 'null'=>undef);

    # extract strings, replacing them with sequential numbers (0, 1, 2, ..)
    my @str;
    $json =~ s/[\x00-\x01]//g;
    $json =~ s/\\"/\x01/g;
    $json =~ s/"([^"]*)"/push(@str,$1),"\x00$#str\x00"/eg;
    
    # process strings
    my %esc = ('"'=>'"', "\\"=>"\\", "b"=>"\x08", "f"=>"\x0c");
    foreach(@str) {
	$_ =~ s/\\([\\bf])/$esc{$1}/g;
	$_ =~ s/\x01/"/g;
	$_ =~ s/\\u([0-9A-Za-z][0-9A-Za-z][0-9A-Za-z][0-9A-Za-z])/Encode::encode_utf8(chr(hex($1)))/eg;
    }

    my @ary = split_json($json);

    my @stack;
    my $ret = (shift(@ary) eq '{') ? {} : [];
    my $c = $ret;
    eval {
	while(@ary) {
	    my $v = shift(@ary);
	    if ($v eq '}' || $v eq ']') {
		$c = pop(@stack);
	    } elsif (ref($c) eq 'HASH') {
		my $x = index($v, ':');
		my $key = substr($v, 0, $x);
		my $val = substr($v, $x+1);
		$key =~ s/^\x00(\d+)\x00$/$str[$1]/;
		if (exists $json_val{$val}) {
		    $val = $json_val{$val};
		} else {
		    $val =~ s/^\x00(\d+)\x00$/$str[$1]/;
		}
		if ($ary[0] eq '{') {
		    shift(@ary);
		    push(@stack, $c);
		    $c = $c->{$key} = {};
		} elsif ($ary[0] eq '[') {
		    shift(@ary);
		    push(@stack, $c);
		    $c = $c->{$key} = [];
		} else {
		    $c->{$key} = $val;
		}
	    } else {
		if ($v eq '{') {
		    push(@stack, $c);
		    push(@$c, {});
		    $c = $c->[ $#$c ];
		} elsif ($v eq '[') {
		    push(@stack, $c);
		    push(@$c, []);
		    $c = $c->[ $#$c ];
		} elsif (exists $json_val{$v}) {
		    push(@$c, $json_val{$v});
		} else {
		    $v =~ s/^\x00(\d+)\x00$/$str[$1]/;
		    push(@$c, $v);
		}
	    }
	}
    };

    return $ret;
}

sub split_json {
    my ($json) = @_;

    $json =~ s/\s*//g;
    my @elem = split(/,/, $json);

    my @array;
    for my $elem (@elem) {
	while($elem =~ /^(.*?)([\[\]\{\}])(.*)$/) {
	    if ($1 ne '') {
		push(@array, $1);
	    }
	    push(@array, $2);
	    $elem = $3;
	}
	if ($elem ne '') {
	    push(@array, $elem);
	}
    }
    return @array;
}

1;
