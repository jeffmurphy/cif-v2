#!/usr/bin/perl -w 
use strict;
use lib '.';
use CIF::Foundation;

# { apikey => , myip => , cifrouter => , controlport => , publisherport => , myid => , routerid => }

my $cf = new CIF::Foundation(
	{
		apikey => '12345-abcdef',
		myip => '10.10.0.1',
		cifrouter => 'sdev.nickelsoft.com:5555',
		controlport => 15556,
		publisherport => 15557,
		myid => 'foundation-test',
		routerid => 'cif-router',
		debug => 10
	}
);

$cf->setdebug(10);
$cf->requestsocket();
$cf->register();

exit 0;
