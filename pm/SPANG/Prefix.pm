package SPANG::Prefix;
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(read_prefix insert_prefix_declarations abbrev_prefix abbrev_result);

use strict;

################################################################################
### Public functions ###########################################################
################################################################################

sub read_prefix {
    my ($r_to_short, $r_to_long, @file) = @_;

    # If files do not exist, hash structures remain empty 

    my @line = ();
    for my $file (@file) {
	if (-f $file) {
	    my @line = `cat $file`;
	    for my $line (@line) {
		my ($prefix, $short, $expanded) = split(/\s+/, $line);
		if ($expanded and uc($prefix) eq "PREFIX" and $short =~ /^\S*:$/ and $expanded =~ /^<(\S+)>$/) {
		    ${$r_to_long}{$short} = $1;
		    ${$r_to_short}{$1} = $short;
		}
	    }
	}
    }
}

sub insert_prefix_declarations {
    my ($r_sparql, $r_to_long) = @_;

    my ($pragma_lines, $others) = separate_virtuoso_pragma_lines(${$r_sparql}, "define");

    my %found_prefix = ();
    for my $short (keys %{$r_to_long}) {
	if ($others =~ /\W$short/ or $others =~ /^$short/) {
	    $found_prefix{$short} = 1;
	}
    }

    my $declarations = "";
    for my $short (keys %found_prefix) {
	$declarations .= "PREFIX $short <${$r_to_long}{$short}>\n";
    }
    $declarations and $declarations .= "\n";

    ${$r_sparql} = $pragma_lines . $declarations . $others;
}

sub abbrev_prefix {
    my ($r_to_short_prefix, $result) = @_;
    
    ### FIND URIs to be abbreviated
    my %found = ();
    for my $long_form (sort { length($b) <=> length($a) } keys %{$r_to_short_prefix}) {
	# while ($result =~ /<${long_form}(\S+)>/g) {
	#     $result =~ s/<${long_form}(\S+)>/${$r_to_short_prefix}{$long_form}$1/;
	#     $found{$long_form} = 1;
	# }
	if ($result =~ /<${long_form}(\S+)>/) {
	    $found{$long_form} = 1;
	}
	$result =~ s/<${long_form}(\S+)>/${$r_to_short_prefix}{$long_form}$1/g;
    }

    ### Convert ###
    my $prefixes = "";
    for my $long_form (sort { length($b) <=> length($a) } keys %found) {
	$prefixes .= "\@prefix ${$r_to_short_prefix}{$long_form} <$long_form> .\n";
    }
    if ($prefixes) {
	$prefixes .= "\n";
    }
    
    ### If no prefix is declared, it returns empty string and the original result.
    return ($prefixes, $result);
}

sub abbrev_result {
    my ($result, $r_to_short_prefix, %opt) = @_;

    if ($opt{a} || $opt{b}) {
	my ($prefix, $triple) = abbrev_prefix($r_to_short_prefix, $result);
	if ($opt{b}) {
	    $result = $prefix . $triple;
	} elsif ($opt{a}) {
	    $result = $triple;
	}
    }

    return $result;
}

################################################################################
### Private functions ##########################################################
################################################################################

sub separate_virtuoso_pragma_lines {
    my ($input, $pragma) = @_;

    chomp($input);
    my @input = split("\n", $input);

    my $pragma_lines = "";
    my $others = "";
    for my $line (@input) {
	if ($line =~ /^$pragma /) {
	    $pragma_lines .= "$line\n";
	} else {
	    $others .= "$line\n";
	}
    }

    if ($pragma_lines ne "") {
	$pragma_lines .= "\n";
    }

    if ($others ne "") {
	$others .= "\n";
    }

    return ($pragma_lines, $others);
}

1;
