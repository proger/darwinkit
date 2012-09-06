#!/usr/bin/env perl
use Term::ANSIColor qw(:constants);

$command = $ARGV[0];
$args = join ' ', @ARGV;

`rm -f dtrace.out`;
print `dtrace -q -n 'pid\$target::main: {printf("%s\\n",probename)}' -c "$args" -o dtrace.out`;
@matches = `cat dtrace.out`;

@fundump = `otool -tvV $command -p _main`;

$base = undef;

foreach $line (@fundump) {
	@parts = split /\s/, $line;
	next if $#parts < 2;


	$addr = hex $parts[0];
	$base = $addr if $base == undef;

	$match = 0;
	foreach (@matches) {
		next if /^$/;
		next if /(entry|return)/;
		$match = 1 if ($addr - $base) == hex;
	} continue {
		last if $match;
	}

	print GREEN if $match;
	print $line;
	print RESET;
}
