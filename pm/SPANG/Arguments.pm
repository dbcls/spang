package SPANG::Arguments;
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(embed_parameters embed_values_stdin extract_default_parameters extract_default_values);

use strict;

################################################################################
### Public functions ###########################################################
################################################################################

sub embed_parameters {
    my ($r_input, $r_missing, $r_embedded, @parameter) = @_;

    ${$r_missing}{parameter} = 0;
    ${$r_missing}{ARGS} = 0;

    my $tmp_input = ${$r_input};
    while ($tmp_input =~ /\$(\d+)/g) {
	my $n = $1;
	my $i = $n - 1;
	if ($parameter[$i]) {
	    $tmp_input =~ s/\$$n/$parameter[$i]/;
	    ${$r_embedded}[$i] = 1;
	} else {
	    ${$r_missing}{parameter} = 1;
	}
    }

    my $param_with_paren = "(@parameter)";
    while ($tmp_input =~ /\$ARGS/g) {
	if (@parameter) {
	    $tmp_input =~ s/\$ARGS/$param_with_paren/;
	    for (my $i=0; $i<@parameter; $i++) {
		${$r_embedded}[$i] = 1;
	    }
	} else {
	    ${$r_missing}{ARGS} = 1;
	}
    }

    ${$r_input} = $tmp_input;
}

sub embed_values_stdin {
    my ($r_input, $values_stdin, $n_stdin_col, $r_missing) = @_;

    ${$r_missing}{STDIN} = 0;

    # format values from stdin
    my @line = ();
    my @col = ();
    my @line_with_paren = ();
    my @col_with_paren = ();
    if ($n_stdin_col) {
	chomp($values_stdin);
	@line = split("\n", $values_stdin);
	for (my $i=0; $i<@line; $i++) {
	    if ($line[$i] =~/\S/) {
		$line_with_paren[$i] = "($line[$i])";
		my @x = split(/\t/, $line[$i]);
		for (my $j=0; $j<@x; $j++) {
		    $col[$j][$i] = $x[$j];
		    $col_with_paren[$j][$i] = "($x[$j])";
		}
	    }
	}
    }

    my @input = split("\n", ${$r_input});

    # For VALUES keyword
    for (my $i=0; $i<@input; $i++) {
	if ($input[$i] =~ /^\s*#/) {
	    next;
	}
	while ($input[$i] =~ /^(.*)\$STDIN/g) {
	    my $padding = $1;
	    my $len = length($padding);
	    if (@line_with_paren) {
		my $lines_with_paren = join("\n" . " " x $len, @line_with_paren);
		$input[$i] =~ s/\$(STDIN)/$lines_with_paren/;
	    } else {
		${$r_missing}{STDIN} = 1;
	    }
	}
	while ($input[$i] =~ /\$V(\d+)/g) {
	    my $n = $1;
	    my $j = $n - 1;
	    if ($col_with_paren[$j]) {
		my $cols_with_paren = join(" ", @{$col_with_paren[$j]});
		$input[$i] =~ s/\$V$n/$cols_with_paren/;
	    } else {
		${$r_missing}{STDIN} = 1;
	    }
	}
    }

    # For FILTER function
    for (my $i=0; $i<@input; $i++) {
	if ($input[$i] =~ /^\s*#/) {
	    next;
	}
	while ($input[$i] =~ /\$stdin/g) {
	    if (@line) {
		my $lines = join(", ", @line);
		$input[$i] =~ s/\$stdin/$lines/;
	    } else {
		${$r_missing}{STDIN} = 1;
	    }
	}
	while ($input[$i] =~ /\$v(\d+)/g) {
	    my $n = $1;
	    my $j = $n - 1;
	    if (@{$col_with_paren[$j]}) {
		my $cols = join(", ", @{$col[$j]});
		$input[$i] =~ s/\$v$n/$cols/;
	    } else {
		${$r_missing}{STDIN} = 1;
	    }
	}
    }

    ${$r_input} = join("\n", @input);

    return "@line_with_paren";
}

sub extract_default_parameters {
    my ($input) = @_;

    chomp($input);

    my @parameter = ();
    my @line = split("\n", $input);
    for my $line (@line) {
	if ($line =~ /^#(param|args|ARGS)\s/) {
	    @parameter = split(/\s+/, $line);
	    shift @parameter;
	}
    }

    return @parameter;
}

sub extract_default_values {
    my ($input) = @_;

    chomp($input);

    my $values = "";
    my $n_col = 0;

    my @line = split("\n", $input);
    for my $line (@line) {
	if ($line =~ /^#(STDIN|stdin|in|input)\s(.*)/) {
	    my $line = $2;
	    my @f = split(/\t/, $line);
	    $n_col = @f;
	    $values .= "$line\n";
	}
    }

    return ($values, $n_col);
}

### obsolete ###
sub embed_stdin {
    my ($input, $data_stdin) = @_;

    chomp($data_stdin);
    my @line = split("\n", $data_stdin);
    my @line_with_paren = ();
    for my $line (@line) {
	if ($line =~/\S/) {
	    push @line_with_paren, "($line)";
	}
    }

    # For VALUES keyword
    my $lines_with_paren = join(" ", @line_with_paren);
    $input =~ s/^#.*\n//mg;
    $input =~ s/\$STDIN/$lines_with_paren/g;

    # For FILTER function
    my $lines = join(", ", @line);
    $input =~ s/\$stdin/$lines/g;

    return $input;
}

1;
