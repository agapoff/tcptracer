package Output::elasticsearch;

use strict;
use LWP::UserAgent;
use Data::Dumper;
use JSON;
use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday);

our %EStemplate = (
	template => "tcptracer-*",
	settings => { number_of_shards => 1 },
	mappings => {
		tcpretr => {
			properties => {
				"\@timestamp" => { type => "date" },
				local_ip => { type => "ip" },
				peer_ip => { type => "ip" },
				local_port => { type => "integer" },
				peer_port => { type => "integer" },
				side => { type => "string" },
				task => { type => "string" },
				state => { type => "string" },
				hostname => { type => "string" }
			}
		}
	}
);

our $ua = LWP::UserAgent->new;
$ua->timeout(3);
our $hostname;

sub init {
    my $cfg = shift;
    my $write_log = shift;

	$hostname=`hostname -s` || 'localhost';
	chomp $hostname;

	my $response = $ua->get($cfg->{url}.'/_template/tcptracer');
	if ($response->{_rc} == 200) {
		$write_log->("ES is accessible. Index template is in place");
		return 1
	} 
	elsif ($response->{_rc} == 404) {
		$write_log->("ES is accessible. Template is absent. Let's create it");
		my $response = $ua->put($cfg->{url}.'/_template/tcptracer', 'Content' => encode_json \%EStemplate);
		if ($response->is_success) {
			$write_log->("Index template created successfully");
			return 1;
		} else {
			$write_log->("Failed creating index template");
			$write_log->($response->decoded_content);
			return 0;
		}
	} 
	else {
		$write_log->($response->status_line);
		return 0;
	}
}


sub push {
    my $event = shift;
    my $cfg = shift;
    my $write_log = shift;
	my $index = "tcptracer-".strftime("%Y.%m.%d", gmtime);
	$event->{"\@timestamp"} = int (gettimeofday * 1000);
	$event->{hostname} = $hostname;
	my $data;
	eval {
		$data = encode_json($event);
	};
	if ($@) {
		$write_log->("Error encoding json [$@]");
		return 0;
	}
	print "Sending to ".$cfg->{url}."/$index/tcpretr"." : ".$data."\n" if ($cfg->{debug} eq 'true');
	my $response = $ua->post($cfg->{url}."/$index/tcpretr", 'Content' => $data);
	if ($response->is_success) {
		$write_log->("Successfully sent event to ES") if ($cfg->{debug} eq 'true');
        return 1;
    } else {
        $write_log->("Failed writing event to index");
        $write_log->($response->decoded_content);
        return 0;
    }
}

1;
