package Output::file;

use strict;
use POSIX qw(strftime);
use Data::Dumper;

sub init {
    my $cfg = shift;
	my $write_log = shift;
    if (open FILE, '>>'.$cfg->{path}) {
		$write_log->("File $cfg->{path} is writable");
		close FILE;
		return 1;
	} else {
		$write_log->("File $cfg->{path} is not writable");
		return 0;
	}
}

sub push {
    my $event = shift;
    my $cfg = shift;
    my $write_log = shift;

	my $date = strftime "%Y-%m-%d %H:%M:%S", localtime;
	if (open FILE, '>>'.$cfg->{path}) {
		print FILE $date.' '.$event->{local_ip}.':'.$event->{local_port}.' '.$event->{side}.' '.$event->{peer_ip}.':'.$event->{peer_port}.' '.$event->{task}.' '.$event->{state}."\n";
		close FILE;
	} else {
		$write_log->("Error opening file ".$cfg->{path});
	}
}


1;
