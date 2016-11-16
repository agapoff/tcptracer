package tcptracer;

use Data::Dumper;
use POSIX qw(strftime);

my $tracing = "/sys/kernel/debug/tracing";
my $flock = "/var/tmp/.ftrace-lock";
my $kname_rtr = "tcptracer_tcp_retransmit_skb";
my $kname_tlp = "tcptracer_tcp_send_loss_probe";
my %tcp; # tcp cache
$| = 1;
my @tcpstate = ( '',
                  'ESTABLISHED',
                  'SYN_SENT',
                  'SYN_RECV',
                  'FIN_WAIT1',
                  'FIN_WAIT2',
                  'TIME_WAIT',
                  'CLOSE',
                  'CLOSE_WAIT',
                  'LAST_ACK',
                  'LISTEN',
                  'CLOSING',
                  'MAX_STATES'
              );



write_log ('TCPTracer initializing');

#my $cfg = &read_config;

#my %output = map { $_ => 1 } @{$cfg->{output}};
sub writeto;
sub create_kprobe;
sub enable_kprobe;
sub remove_kprobe;
sub ldie;
sub edie;

sub new {
	my $class = shift;
	my $self = {};
	bless $self, $class;
	write_log("Hello from new");
	$self->{cfg} = &read_config;

	# check permissions
	#chdir "$tracing" or die "ERROR: accessing tracing. Are you root? Ftrace enabled? debugfs mounted?";
	(-d "$tracing") || die "ERROR: accessing tracing. Are you root? Ftrace enabled? debugfs mounted?";

	# ftrace lock
	if (-e $flock) {
		open FLOCK, $flock; my $fpid = <FLOCK>; chomp $fpid; close FLOCK;
		die "ERROR: ftrace may be in use by PID $fpid ($flock)";
	}
	writeto "$$", $flock or die "ERROR: unable to write $flock.";

	writeto "nop", "current_tracer" or ldie "ERROR: disabling current_tracer.";
	return $self;
}

sub run {
	my $self = shift;

	my $cfg = $self->{cfg};
	foreach my $output ( @{$cfg->{output}} ) {
		print "Initializing destination $output...\n";
		write_log("Initializing destination $output...");

		my $module = "Output/$output.pm";
		if (eval { require $module; 1; }) {
			print "Module $output.pm loaded ok\n";
			write_log ("Module $output.pm loaded ok");
			unless ("Output::${output}::init"->($self->{cfg}->{$output},\&write_log)) {
				$cfg->{$output}->{disabled} = 1;
				print "Module $output init failed. Disabling...\n";
				write_log("Module $output init failed. Disabling...");
			}
		} else {
			print "Could not load $output.pm. Error Message: $@\n";
			write_log ("Could not load $output.pm. Error Message: $@");
			exit;
		}
	}

	create_kprobe $kname_rtr, "tcp_retransmit_skb sk=%di" or ldie "ERROR: creating kprobe for tcp_retransmit_skb()";
	create_kprobe $kname_tlp, "tcp_send_loss_probe sk=%di" or edie "ERROR: creating kprobe for tcp_send_loss_probe()";
	enable_kprobe $kname_rtr or edie "ERROR: enabling $kname_rtr probe";
	enable_kprobe $kname_tlp or edie "ERROR: enabling $kname_tlp probe";
    print "TCP Tracer have been initialized\n";
	write_log ("TCP Tracer have been initialized");
	my $interval = $cfg->{interval} || 5; 
	while (1) {
		sleep $interval;
		# buffer trace data
		open TPIPE, $tracing.'/trace' or edie "ERROR: opening trace_pipe";
		my @trace = ();
		while (<TPIPE>) {
			next if /^#/;
			push @trace, $_;
		}
		close TPIPE;

		next unless (scalar @trace);
		writeto "0", "trace" or edie "ERROR: clearing trace";
		# cache /proc/net/tcp state
		cache_tcp();

		for (@trace) {
			print "$_\n" if ($cfg->{debug} eq 'true');
			my ($taskpid, $rest) = split ' ', $_, 2;
			my ($task, $pid) = $taskpid =~ /(.*)-(\d+)/;

			my ($skp) = $rest =~ /sk=([0-9a-fx]*)/;
			next unless defined $skp and $skp ne "";
			$skp =~ s/^0x//;

			my ($laddr, $lport, $raddr, $rport, $state);
			if (defined $tcp{$skp}) {
				# convert /proc/net/tcp hex to dotted quads
				my ($hladdr, $hlport) = split /:/, $tcp{$skp}{laddr};
				my ($hraddr, $hrport) = split /:/, $tcp{$skp}{raddr};
				$laddr = inet_h2a($hladdr);
				$raddr = inet_h2a($hraddr);
				$lport = hex($hlport);
				$rport = hex($hrport);
				$state = $tcpstate[hex($tcp{$skp}{state})];
			} else {
				# socket closed too quickly
				($laddr, $raddr) = ("0.0.0.0", "0.0.0.0");
				($lport, $rport) = ("0", "0");
				$state = "CLOSED";
			}

			my %event = (
				side       => $rest =~ /$kname_tlp/ ? "in" : "out",
				local_ip   => $laddr,
				local_port => $lport,
				peer_ip    => $raddr,
				peer_port  => $rport,
				task       => $task,
				state      => $state
			);
			foreach my $output (@{$cfg->{output}} ) {
				next if ($cfg->{$output}->{disabled});
				my $resp = "Output::${output}::push"->(\%event, $cfg->{$output},\&write_log);
			}
		}
	}

}

sub read_config {
	use File::Basename;
	my $myPath = dirname(__FILE__);
	my %var;
	my $cf = $myPath."/config.ini"; 
	my $block;
	if (-s $cf and open(CONF, "<$cf")) {
		while (<CONF>) {
			chomp;
			next if /^\s*(#.*)*$/o; # skip comments and empty lines
			if (/^\[(.+)\]\s*$/) {
				$block = $1;
			}
			next unless /^(\S+)\s*=\s*([^#]*)/o;

			my ($key, $val) = ($1, $2);
			if ($val =~ /,/o) {
				if ($block) {
					$var{$block}->{$key} = [ split(/,\s/, $val) ];
				} else {
					$var{$key} = [ split(/,\s?/, $val) ];
				}
				next;
			}
			elsif ($val =~ /^'(.*)'$/o) {
				$val = $1;
			}
			elsif ($val =~ /^"(.*)"$/o) {
				$val = $1;
			}
			if ($block) {
				$var{$block}->{$key} = $val;
			} else {
				$var{$key} = $val;
			}
		}
		close(CONF);
	}
	return \%var;
}

sub open_log ($;$) {
	my $filename = shift;
	my $lock = shift;
	my $tmpfh;
	defined($filename) or croak("no filename given to open_log()");
	open $tmpfh, ">>$filename" or die(3, "Error: failed to open file '$filename': $!");
	if($lock){
		flock($tmpfh, LOCK_EX | LOCK_NB) or quit(3, "Failed to aquire a lock on file '$filename', another instance of this code may be running?");
	}
	return $tmpfh;
}

sub write_log {
	my $text = shift;
	my $logfh = open_log("/var/log/tcptracer/tcptracer.log");
	my $date = strftime "%Y-%m-%d %H:%M:%S", localtime;
	print $logfh $date.' '.$text."\n";
	close $logfh;
	return;
}

sub writeto {
	my ($string, $file) = @_;
	if ($file !~ /^[\/\.]/) { $file = $tracing.'/'.$file; }
	open FILE, ">$file" or return 0;
	print FILE $string or return 0;
	close FILE or return 0;
}

sub appendto {
	my ($string, $file) = @_;
	if ($file !~ /^[\/\.]/) { $file = $tracing.'/'.$file; }
	open FILE, ">>$file" or return 0;
	print FILE $string or return 0;
	close FILE or return 0;
}

# tcp socket cache
sub cache_tcp {
	undef %tcp;
	open(TCP, "/proc/net/tcp") or ldie "ERROR: reading /proc/net/tcp.";
	while (<TCP>) {
		next if /^ *sl/;
		my ($sl, $local_address, $rem_address, $st, $tx_rx, $tr_tm,
			$retrnsmt, $uid, $timeout, $inode, $jf, $sk) = split;
		$sk =~ s/^0x//;
		$tcp{$sk}{laddr} = $local_address;
		$tcp{$sk}{raddr} = $rem_address;
		$tcp{$sk}{state} = $st;
	}
	close TCP;
}

# kprobe functions
sub create_kprobe {
	my $kname = shift;
	my $kval = shift;
	appendto "p:$kname $kval", "kprobe_events" or return 0;
}

sub enable_kprobe {
	my $kname = shift;
	writeto "1", "events/kprobes/$kname/enable" or return 0;
}

sub remove_kprobe {
	my $kname = shift;
	writeto "0", "events/kprobes/$kname/enable" or return 0;
	appendto "-:$kname", "kprobe_events" or return 0;
}

# /proc/net/tcp hex addr to dotted quad decimal
sub inet_h2a {
	my ($haddr) = @_;

	my @addr = ();
	for my $num ($haddr =~ /(..)(..)(..)(..)/) {
		unshift @addr, hex($num);
	}
	return join(".", @addr);
}

# delete lock and die
sub ldie {
	unlink $flock;
	die @_;
}

# end tracing (silently) and die
sub edie {
	print STDERR "@_\n";
	close STDOUT;
	close STDERR;
	cleanup();
}

sub cleanup {
	print "Finishing tracing...\n";
	write_log("Finishing tracing...");
	close TPIPE;
	remove_kprobe $kname_rtr || print STDERR "ERROR: removing kprobe $kname_rtr\n";
	remove_kprobe $kname_tlp || print STDERR "ERROR: removing kprobe $kname_tlp\n";
	writeto "", "trace";
	unlink $flock;
	exit;
}

1;

__END__
