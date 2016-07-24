package SPANG::Endpoints;
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(read_endpoint_list output_endpoint_list);

use strict;

################################################################################
### Public functions ###########################################################
################################################################################

sub read_endpoint_list {
    my ($r_nickname2url, $r_nickname2method, $r_nickname_list, $r_file) = @_;

    for (my $i=0; $i<@{$r_file}; $i++) {
	if (-f ${$r_file}[$i]) {
	    open(ENDPOINT_LIST, "${$r_file}[$i]") || die;
	    while (<ENDPOINT_LIST>) {
		if (/^\s*#/ or /^\s*$/) {
		    next;
		}
		my ($nickname, $url, $method) = split;
		${$r_nickname2url}{$nickname} = $url;
		${$r_nickname2method}{$nickname} = $method;
		push @{$r_nickname_list->[$i]}, $nickname;
	    }
	    close(ENDPOINT_LIST);
	}
    }
}

sub output_endpoint_list {
    my ($r_nickname2url, $r_nickname, $r_endpoint_file) = @_;

    my $nickname2url = "SPARQL endpoints";
    # $nickname2url .= " (defined in ~/.spang/endpoints,SPANG_DIR/etc/endpoints)\n";
    $nickname2url .= "\n";
    my $maxlen = 0;
    for my $nickname (sort {$a cmp $b} keys %{$r_nickname2url}) {
	my $len = length($nickname);
	if ($len > $maxlen) {
	    $maxlen = $len;
	}
    }
    # for my $nickname (sort {$a cmp $b} keys %{$r_nickname2url}) {
    # for my $nickname (@{$r_nickname}) {
    # 	$nickname2url .= sprintf " %-${maxlen}s ${$r_nickname2url}{$nickname}\n", $nickname;
    # }
    for (my $i=0; $i<@{$r_nickname}; $i++) {
	# $nickname2url .= "(defined in $r_endpoint_file->[$i])\n";
	for my $nickname (@{$r_nickname->[$i]}) {
	    $nickname2url .= sprintf " %-${maxlen}s ${$r_nickname2url}{$nickname}\n", $nickname;
	}
	if ($i != @{$r_nickname} - 1) {
	    $nickname2url .= "\n";
	}
    }
    
    return $nickname2url;
}

1;
