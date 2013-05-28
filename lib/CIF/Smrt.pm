package CIF::Smrt;
use base 'Class::Accessor';

use 5.008008;
use strict;
use warnings;
use threads;

our $VERSION = '0.99_03';
$VERSION = eval $VERSION;  # see L<perlmodstyle>

# we're using ipc instead of inproc cause perl sucks
# at sharing context's with certain types of sockets (ZMQ_PUSH in particular)
use constant WORKER_CONNECTION      => 'ipc:///tmp/workers';
# this is used to return back the total sum of recs processed by the analytics
# i'm sure there's a better way to do this
use constant WORKER_SUM_CONNECTION  => 'ipc:///tmp/workers_sum';
use constant RETURN_CONNECTION      => 'ipc:///tmp/return';
use constant SENDER_CONNECTION      => 'ipc:///tmp/sender';
use constant CTRL_CONNECTION        => 'ipc:///tmp/ctrl';

# for figuring out throttle
use constant DEFAULT_THROTTLE_FACTOR => 4;

# default severity mapping
use constant DEFAULT_SEVERITY_MAP => {
    botnet      => 'high',
};

use MIME::Base64;

use Regexp::Common qw/net URI/;
use Regexp::Common::net::CIDR;
use Encode qw/encode_utf8/;
use Data::Dumper;
use File::Type;
use Module::Pluggable require => 1;
use Digest::SHA qw/sha1_hex/;
use URI::Escape;
use Try::Tiny;

use Net::SSLeay;
Net::SSLeay::SSLeay_add_ssl_algorithms();

use CIF qw/generate_uuid_url generate_uuid_random is_uuid debug normalize_timestamp/;
use CIF::Msg;
use CIF::Msg::Control;
use CIF::Msg::Support;

use Time::HiRes qw/nanosleep/;
use ZeroMQ qw/:all/;

# the lower this is, the higher the chance of 
# threading collisions resulting in a seg fault.
# the higher the thread count, the higher this number needs to be
use constant NSECS_PER_MSEC     => 1_000_000;

__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw(
    config feeds_config feeds threads 
    entries defaults feed rules load_full goback 
    client wait_for_server name instance 
    batch_control client_config postprocess apikey
    severity_map proxy
));

our @preprocessors;
our @postprocessors;

sub new {
    my $class = shift;
    my $args = shift;
    
    my $self = {};
    bless($self,$class);

    @postprocessors =  grep(/Postprocessor::[0-9a-zA-Z_]+$/,  __PACKAGE__->plugins());
    @preprocessors = grep(/Preprocessor::[0-9a-zA-Z_]+$/, __PACKAGE__->plugins());
    
    my ($err,$ret) = $self->init($args);
    return($err) if($err);

    return (undef,$self);
}

sub init {
    my $self = shift;
    my $args = shift;
    
    my ($err,$ret) = $self->init_config($args);
    return($err) if($err);
      
    ($err,$ret) = $self->init_rules($args);
    return($err) if($err);

    $self->set_threads(         $args->{'threads'}          || $self->get_config->{'threads'}           || 1);
    $self->set_goback(          $args->{'goback'}           || $self->get_config->{'goback'}            || 3);
    $self->set_load_full(       $args->{'load_full'}        || $self->get_config->{'load_full'}         || 0);
    $self->set_wait_for_server( $args->{'wait_for_server'}  || $self->get_config->{'wait_for_server'}   || 0);
    $self->set_batch_control(   $args->{'batch_control'}    || $self->get_config->{'batch_control'}     || 10000); # arbitrary
    $self->set_apikey(          $args->{'apikey'}           || $self->get_config->{'apikey'}            || return('missing apikey'));
    $self->set_proxy(           $args->{'proxy'}            || $self->get_config->{'proxy'});
   
    ($err,$ret) = $self->init_postprocessors($args);
    return($err) if($err);
    
    if($self->get_postprocess()){
        debug('postprocessing enabled...') if($::debug);
        debug('processors: '.join(',',@{$self->get_postprocess()})) if($::debug > 1);
    } else {
        debug('postprocessing disabled...') if($::debug);
    }
    
    $self->set_goback(time() - ($self->get_goback() * 84600));
    $self->set_goback(0) if($self->get_load_full());
    
    
    ## TODO -- this isnt' being passed to the plugins, the config is
    $self->set_name(        $args->{'name'}     || $self->get_config->{'name'}      || 'localhost');
    $self->set_instance(    $args->{'instance'} || $self->get_config->{'instance'}  || 'localhost');
    
    $self->init_feeds($args);
    return($err,$ret) if($err);
    return(undef,1);
}

sub init_postprocessors {
    my $self = shift;
    my $args = shift;
    my $things = $args->{'postprocess'} || $self->get_config->{'postprocess'};
    return unless($things);
    
    if($things eq '1') {
        $self->set_postprocess(\@postprocessors);
    } else {
        my $enabled;
        foreach (@$things) {
            foreach my $p (@postprocessors){
                if(lc($p) =~ /::$_$/) {
                	push(@$enabled,$p);
                	$self->set_postprocess($p);
                }
            }
        }
    }
    return(undef,1);
}

sub init_config {
    my $self = shift;
    my $args = shift;
    
    # do this here, we'll do the setup within the sender_routine (thread)
    $self->set_client_config($args->{'config'});
    
    my $err;
    try {
        $args->{'config'} = Config::Simple->new($args->{'config'});
    } catch {
        $err = shift;
    };
    
    unless($args->{'config'}){
        return('unknown or missing config: '.$self->get_client_config());
    }
    if($err){
        my @errmsg;
        push(@errmsg,'something is broken in your local config: '.$args->{'config'});
        push(@errmsg,'this is usually a syntax error problem, double check '.$args->{'config'}.' and try again');
        return(join("\n",@errmsg));
    }
    
    $self->set_config(          $args->{'config'}->param(-block => 'cif_smrt'));
    $self->set_feeds_config(    $args->{'config'}->param(-block => 'cif_feeds'));
    
    $self->init_config_severity($args);
    
    return(undef,1);
}

sub init_config_severity {
    my $self = shift;
    my $args = shift;
    
    my $map = $args->{'config'}->param(-block => 'cif_smrt_severity');
    $map = DEFAULT_SEVERITY_MAP() unless(keys %$map);
    
    $self->set_severity_map($map);
    
}

sub init_rules {
    my $self = shift;
    my $args = shift;
    
    my $rulesfile = $args->{'rules'};
    my ($err,@errmsg);
    try {
        $args->{'rules'} = Config::Simple->new($args->{'rules'});
    } catch {
        $err = shift;
    };
    
    return('missing or unknown rules configuration: '.$rulesfile) unless($args->{'rules'});
    
    if($err){
        my @errmsg;
        push(@errmsg,'there is something broken with: '.$rulesfile);
        push(@errmsg,'this is usually a syntax problem, double check '.$rulesfile.' and try again');
        return(join("\n",@errmsg));
    }
    
    unless($args->{'feed'}){
        my @sections = keys %{$args->{'rules'}->{'_DATA'}};
        @sections = map { $_ = $_ if($_ !~ /^default/) } @sections;
        my $string = "missing feed, please set (-f) one of the following for this config:\n\n";
        $string .= join("\n",@sections);
        return($string);
    }

    $self->set_feed($args->{'feed'});
    my $defaults    = $args->{'rules'}->param(-block => 'default');
    my $rules       = $args->{'rules'}->param(-block => $self->get_feed());
    
    return ('invalid feed: '.$self->get_feed().'...') unless(keys %$rules);
   
    map { $defaults->{$_} = $rules->{$_} } keys (%$rules);
    
    if($defaults->{'guid'}){
        unless(is_uuid($defaults->{'guid'})){
            $defaults->{'guid'} = generate_uuid_url($defaults->{'guid'});
        }
    }

    $self->set_rules($defaults);
    return(undef,1);
}

sub init_feeds {
    my $self = shift;
    
    my $feeds = $self->get_feeds_config->{'enabled'} || return;
    $self->set_feeds($feeds);
}

sub pull_feed { 
    my $f = shift;
    my $ret = threads->create('_pull_feed',$f)->join();
    return(undef,'') unless($ret);
    return($ret) if($ret =~ /^ERROR: /);
    
    # auto-decode the content if need be
    $ret = _decode($ret,$f);

    return(undef,$ret) if($f->{'cif'} && $f->{'cif'} eq 'true');

    # encode to utf8
    $ret = encode_utf8($ret);
    # remove any CR's
    $ret =~ s/\r//g;
    delete($f->{'feed'});
    return(undef,$ret);
}

# we do this sep cause it's in a thread
# this gets around memory leak issues and TLS threading issues with Crypt::SSLeay, etc
sub _pull_feed {
    my $f = shift;
    return unless($f->{'feed'});

    foreach my $key (keys %$f){
        foreach my $key2 (keys %$f){
            if($f->{$key} =~ /<$key2>/){
                $f->{$key} =~ s/<$key2>/$f->{$key2}/g;
            }
        }
    }
    my @pulls = __PACKAGE__->plugins();
    @pulls = sort grep(/::Pull::/,@pulls);
    foreach(@pulls){
        my ($err,$ret) = $_->pull($f);
        return('ERROR: '.$err) if($err);
        
        # we don't want to error out if there's just no content
        next unless(defined($ret));
        return($ret);
    }
    return('ERROR: could not pull feed');
}


## TODO -- turn this into plugins
sub parse {
    my $self = shift;
    my $f = $self->get_rules();
    
    if($self->get_proxy()){
        $f->{'proxy'} = $self->get_proxy();
    }
    
    return 'feed does not exist' unless($f->{'feed'});
    debug('pulling feed: '.$f->{'feed'}) if($::debug);
    if($self->get_client_config()){
        $f->{'client_config'} = $self->get_client_config();
    }

    my ($err,$content) = pull_feed($f);
    return($err) if($err);
    
    my $return;
    try {
        # see if we designate a delimiter
        if($content =~ /^application\/cif/){
            require CIF::Smrt::ParseCifFeed;
            $return = CIF::Smrt::ParseCifFeed::parse($f,$content);
        } elsif(my $d = $f->{'delimiter'}){
            require CIF::Smrt::ParseDelim;
            $return = CIF::Smrt::ParseDelim::parse($f,$content,$d);
        } else {
            # try to auto-detect the file
            debug('testing...');
            ## todo -- very hard to detect iodef-pb strings
            # might have to rely on base64 encoding decode first?
            if($content =~ /^application\/base64\+snappy\+pb\+iodef\n([\S\n]+)\n$/){
                require CIF::Smrt::ParsePbIodef;
                $return = CIF::Smrt::ParsePbIodef::parse($f,$content);
            } elsif(($f->{'driver'} && $f->{'driver'} eq 'xml') || $content =~ /^(<\?xml version=|<rss version=)/){
                if($content =~ /<rss version=/ && !$f->{'nodes'}){
                    require CIF::Smrt::ParseRss;
                    $return = CIF::Smrt::ParseRss::parse($f,$content);
                } else {
                    require CIF::Smrt::ParseXml;
                    $return = CIF::Smrt::ParseXml::parse($f,$content);
                }
            } elsif($content =~ /^\[?{/){
                if($content =~ /urn:ietf:params:xmls:schema:iodef-1.0/) {
                    require CIF::Smrt::ParseJsonIodef;
                    $return = CIF::Smrt::ParseJsonIodef::parse($f,$content);
                } else {
                    require CIF::Smrt::ParseJson;
                    $return = CIF::Smrt::ParseJson::parse($f,$content);
                }
            ## TODO -- fix this; double check it
            } elsif($content =~ /^#?\s?"\S+","\S+"/ && !$f->{'regex'}){
                # ParseCSV only works on strictly formated CSV files
                # o/w you should be using ParseDelim and specifying the "delimiter" field
                # in your config
                require CIF::Smrt::ParseCsv;
                $return = CIF::Smrt::ParseCsv::parse($f,$content);
            } else {
                require CIF::Smrt::ParseTxt;
                $return = CIF::Smrt::ParseTxt::parse($f,$content);
            }
        }
    } catch {
        $err = shift;
    };
    if($err){
        my @errmsg;
        if($err =~ /parser error/){
            push(@errmsg,'it appears that the format of this feed is broken and might need fixing on the authors end');
            if($::debug > 1){
                push(@errmsg,"\n\n".$err);
            } else {
                push(@errmsg,'a debug level > 1 will print the error if you wish to investigate');
            }
        } else {
            push(@errmsg,"\n\n".$err);
        }
        return(join("\n",@errmsg));
    }

    return(undef,$return);
}

sub _decode {
    my $data = shift;
    my $f = shift;

    my $ft = File::Type->new();
    my $t = $ft->mime_type($data);
    my @plugs = __PACKAGE__->plugins();
    @plugs = grep(/Decode/,@plugs);
    foreach(@plugs){
        if(my $ret = $_->decode($data,$t,$f)){
            return($ret);
        }
    }
    return $data;
}

sub _sort_timestamp {
    my $recs    = shift;
    my $rules   = shift;
    
    my $refresh = $rules->{'refresh'} || 0;

    debug('setting up sort...');
    my $x = 0;
    my $now = DateTime->from_epoch(epoch => time());
    ## TODO -- walk throught this again
    foreach my $rec (@{$recs}){
        my $dt = $rec->{'detecttime'} || $now;
        my $rt = $rec->{'reporttime'} || $now;

        $dt = normalize_timestamp($dt,$now);

        if($refresh){
            $rt = $now;
            $rec->{'timestamp_epoch'} = $now->epoch();
        } else {
            $rt = normalize_timestamp($rt,$now);
            $rec->{'timestamp_epoch'} = $dt->epoch();
        }
       
        $rec->{'detecttime'}        = $dt->ymd().'T'.$dt->hms().'Z';
        $rec->{'reporttime'}        = $rt->ymd().'T'.$rt->hms().'Z';
    }
    debug('sorting...');
    if($refresh){
        $recs = [ sort { $b->{'reporttime'} cmp $a->{'reporttime'} } @$recs ];
    } else {
        $recs = [ sort { $b->{'detecttime'} cmp $a->{'detecttime'} } @$recs ];
    }
    debug('done...');
    return($recs);
}

sub preprocess_routine {
    my $self = shift;

    debug('parsing...') if($::debug);
    my ($err,$recs) = $self->parse();
    return($err) if($err);
    
    debug('parsed records: '."\n".Dumper($recs)) if($::debug > 9);
    
    return unless($#{$recs} > -1);
    
    if($self->get_goback()){
        debug('sorting '.($#{$recs}+1).' recs...') if($::debug);
        $recs = _sort_timestamp($recs,$self->get_rules());
    }
    ## TODO -- move this to the threads?
    ## test with alienvault scan's feed
    debug('mapping...') if($::debug);
    
    my @array;
    foreach my $r (@$recs){
        foreach my $key (keys %$r){
            next unless($r->{$key});
            if($r->{$key} =~ /<(\S+)>/){
                my $x = $r->{$1};
                if($x){
                    $r->{$key} =~ s/<\S+>/$x/;
                }
            }
        }
             
        foreach my $p (@preprocessors){
            $r = $p->process($self->get_rules(),$r);
        }
        
        # TODO -- work-around, make this more configurable
        unless($r->{'severity'}){
            $r->{'severity'} = ($self->get_severity_map->{$r->{'assessment'}}) ? $self->get_severity_map->{$r->{'assessment'}} : 'medium';
        }
            
        ## TODO -- if we do this, we need to degrade the count somehow...
        last if($r->{'timestamp_epoch'} < $self->get_goback());
        push(@array,$r);
    }
    debug('done mapping...') if($::debug);
    debug('records to be processed: '.($#array+1)) if($::debug);
    if($#array == -1){
        debug('your goback is too small, if you want records, increase the goback time') if($::debug);
    }

    return(undef,\@array);
}

sub process {
    my $self = shift;
    my $args = shift;
    
    # do this first so the threads don't copy the recs into their mem
    debug('setting up zmq interfaces') if($::debug);
   
    my $context = ZeroMQ::Context->new();
    my $workers = $context->socket(ZMQ_PUSH);
    debug('setting up zmq interfaces: workers->bind') if($::debug);
    
    $workers->bind(WORKER_CONNECTION());
    
    debug('setting up zmq interfaces: ZMQ_PUB') if($::debug);
    
    my $ctrl = $context->socket(ZMQ_PUB);
    $ctrl->bind(CTRL_CONNECTION());
    
    # feature of zmq, pub/sub's need a warm up msg
    debug('sending ctrl warm-up msg...');
    $ctrl->send('WARMING_UP');
    
    my $return = $context->socket(ZMQ_PULL);
    $return->bind(RETURN_CONNECTION());
    
    my $workers_sum = $context->socket(ZMQ_PULL);
    $workers_sum->bind(WORKER_SUM_CONNECTION());
    
    # this needs to be started first
    debug('starting sender thread...');
    threads->create('sender_routine',$self)->detach();
    # thread/zmq safety requirement
    # if the workers start too fast, this gets messed up, give it a 'tick' head-start
    # if we still see a race condition, send a warmup message to the sender either here
    # or through the workers as a 'checkin'
    nanosleep NSECS_PER_MSEC;
    
    ## TODO -- req/reply checkins?
    debug('creating '.$self->get_threads().' worker threads...');
    for (1 ... $self->get_threads()) {
        threads->create('worker_routine', $self)->detach();
    }
       
    debug('done...') if($::debug);
    
    debug('running preprocessor routine...') if($::debug);
    ## TODO -- figure out if this really needs to be threaded out or not
    # there are implications with how we return errors
    #my ($err,$array) = threads->create('preprocess_routine',$self)->join();
    my ($err,$array) = $self->preprocess_routine();
    return($err) if($err);

    return (undef,'no records') unless($#{$array} > -1);
    
    my $master_count = ($#{$array} + 1);
    debug('processing: '.$master_count.' records...');

    debug('master count: '.$master_count);

    ## TODO -- batch this out a little
    debug('sending to workers...') if($::debug);
    $workers->send_as(json => $_) foreach(@$array);
    
    my $poller = ZeroMQ::Poller->new(
        {
            name    => 'workers_sum',
            socket  => $workers_sum,
            events  => ZMQ_POLLIN,
        },
        {
            name    => 'return',
            socket  => $return,
            events  => ZMQ_POLLIN,
        },
    );
    
    my $done = 0;
    my $total_recs = $master_count;
    my $sent_recs = 0;
    do {
        debug('waiting on message...') if($::debug && $::debug > 1);
        
        debug('polling...') if($::debug > 5);
        $poller->poll();
        debug('found msg') if($::debug && $::debug > 1);
        if($poller->has_event('workers_sum')){
            my $msg = $workers_sum->recv()->data();
            for($msg){
                if(/^COMPLETED:(\d+)$/){
                    $master_count -= $1; 
                    last;
                }
                if(/^ADDED:(\d+)$/){
                    $total_recs += $1;
                    last;
                }
            }
        }
        
        ## TODO -- should this be after the return check?
        debug('master count: '.$master_count) if($::debug && $::debug > 1);
        if($master_count == 0){
            debug('sending total: '.$total_recs) if($::debug && $::debug > 1);
            $ctrl->send('TOTAL:'.$total_recs);
            $ctrl->send('WRK_DONE');
        }
        # waiting for sender
        if($poller->has_event('return')){
            debug('return msg received') if($::debug && $::debug > 1);
            my $msg = $return->recv();

            if($msg->data() =~ /^ERROR: /){
		$err = $msg->data();
                $sent_recs = -1;
            } else {
		#$msg = MessageType->decode($msg->data());
                # size of the array returned +1
		#$sent_recs += ($#{$msg->get_data()} + 1);
                $sent_recs += $msg->data();
            }
        }
        nanosleep NSECS_PER_MSEC;
        # total_recs is based on 0 ... X not -1 ... X
        debug('sent recs: '.$sent_recs);
        debug('total recs: '.$total_recs);
    } while($sent_recs != -1 && $sent_recs < $total_recs);

    $ctrl->send('WRK_DONE');
    
    $workers->close();
    $workers_sum->close();
    $ctrl->close();
    $return->close();
    $context->term();

    return $err unless($sent_recs > -1);
    return(undef,1);
}

sub worker_routine {
    my $self = shift;
   
    require Iodef::Pb::Simple;
    my $context = ZeroMQ::Context->new();
    
    debug('starting worker: '.threads->tid()) if($::debug > 1);
    
    my $receiver = $context->socket(ZMQ_PULL);
    $receiver->connect(WORKER_CONNECTION());
    
    my $sender = $context->socket(ZMQ_PUSH);
    $sender->connect(SENDER_CONNECTION());
    
    my $ctrl = $context->socket(ZMQ_SUB);
    $ctrl->setsockopt(ZMQ_SUBSCRIBE,''); 
    $ctrl->connect(CTRL_CONNECTION());
    
    my $workers_sum = $context->socket(ZMQ_PUSH);
    $workers_sum->connect(WORKER_SUM_CONNECTION());
    
     my $poller = ZeroMQ::Poller->new(
        {
            name    => 'worker',
            socket  => $receiver,
            events  => ZMQ_POLLIN,
        },
        {
            name    => 'ctrl',
            socket  => $ctrl,
            events  => ZMQ_POLLIN,
        },
    ); 
       
    my $done = 0;
    my $recs = 0;
    while(!$done){
        debug('polling...') if($::debug > 5);
        $poller->poll();
        debug('checking control...') if($::debug > 5);
        if($poller->has_event('ctrl')){
            my $msg = $ctrl->recv()->data();
            debug('ctrl sig received: '.$msg) if($::debug > 5 && $msg eq 'WRK_DONE');
            $done = 1 if($msg eq 'WRK_DONE');
        }
        debug('checking event...') if($::debug > 4);
        if($poller->has_event('worker')){
            debug('receiving event...') if($::debug > 4);
            my $msg = $receiver->recv_as('json');
            debug('processing message...') if($::debug > 4);
            
            debug('generating uuid...') if($::debug > 4);
            $msg->{'id'} = generate_uuid_random();
            
            if($::debug > 1){
                my $thing = $msg->{'address'} || $msg->{'malware_md5'} || $msg->{'malware_sha1'};
                debug('uuid: '.$msg->{'id'}.' - '.$msg->{'reporttime'}.' - '.$thing.' - '.$msg->{'assessment'}.' - '.$msg->{'description'});
            }
    
            debug('generating iodef...') if($::debug > 3);

            my $iodef = Iodef::Pb::Simple->new($msg);

            $iodef = [ $iodef ] unless(ref($iodef) eq 'ARRAY');
            if($#{$iodef} > 0){
                debug('ADDING:'.($#{$iodef}));
                $workers_sum->send('ADDED:'.($#{$iodef}));
                nanosleep NSECS_PER_MSEC;
            }
            
            my @results;
            if($self->get_postprocess()) {
            	my $_pp = $self->get_postprocess;

            	my @_pp;
            	if (ref($_pp) eq "ARRAY") {
            		@_pp = @$_pp;
            	}
            	else {
            		push @_pp, $_pp;
            	}
            	
            	debug("in get_postprocess section with processors: ". join(',', @_pp)) if ($::debug > 3);
            	
                foreach my $p (@_pp) {
                    my ($err,$array);
				    foreach my $i (@$iodef){
		                    	try {
		                    	    $array = $p->process($self,$iodef);
		                    	} catch {
		                    	    $err = shift;
		                    	};
		                    	debug($err) if($::debug && $err);
		                    	push @results, @$array if ($array && @$array);
				    }
                }

                # we don't do +1 here cause the parent already knows about the
                # original record
             
                if($#results > -1){
                    @results = map { encode_base64(IODEFDocumentType->new({ lang => 'EN', Incident => $_ })->encode()) } @results;
                    # sometimes the $sender->send_as will get there faster
                    # than the $workers_sum will make it up and over to the sender
                    # it's possible we'll have to re-work this with the sender thread, but it works for now
                    #$workers_sum->send(($#results+1));
                    $workers_sum->send('ADDED:'.($#results+1));
                    nanosleep NSECS_PER_MSEC;
                }
            }
            #print "IODEF ", Dumper($iodef) . "\n";            
            # pass base64 bc send_as converts to utf8 which throws off PB decoding later on
            
            if (ref($iodef) eq "ARRAY") {
            	for my $i (@$iodef) {
            		push @results, encode_base64($i->encode());
            	}	
            } else {
            	push(@results, encode_base64($iodef->encode()));
            }
            
            debug('sending message...') if($::debug > 3);

            $sender->send_as('json' => \@results);
            debug('message sent...') if($::debug > 3);
            $workers_sum->send('COMPLETED:1');
        }
        # thread/zmq safety requirement
        nanosleep NSECS_PER_MSEC;
    }
    debug('sender->close') if($::debug > 2);
    $sender->close();
    debug('ctrl->close') if($::debug > 2);
    
    $ctrl->close();
    debug('receiver->close') if($::debug > 2);
    
    $receiver->close();
    debug('workers_sum->close') if($::debug > 2);
    
    $workers_sum->close();
    debug('context->term') if($::debug > 2);
    
    $context->term();
}

sub sender_routine {
    my $self        = shift;
    #my $total_recs  = shift;
      
    # do this within the thread
    require CIF::Client;
    my ($err,$client) = CIF::Client->new({
        config  => $self->get_client_config(),
        apikey  => $self->get_apikey(),
    });
    $self->set_client($client);
    
    my $batch_control = $self->get_batch_control();
    
    my $context = ZeroMQ::Context->new();
    
    debug('starting sender thread...') if($::debug > 1);
       
    my $sender = $context->socket(ZMQ_PULL);
    $sender->bind(SENDER_CONNECTION());
    
    my $ctrl = $context->socket(ZMQ_SUB);
    $ctrl->setsockopt(ZMQ_SUBSCRIBE,'');
    $ctrl->connect(CTRL_CONNECTION());
    
    my $return = $context->socket(ZMQ_PUSH);
    $return->connect(RETURN_CONNECTION());
    
    my $poller = ZeroMQ::Poller->new(
        {
            name    => 'sender',
            socket  => $sender,
            events  => ZMQ_POLLIN,
        },
        {
            name    => 'ctrl',
            socket  => $ctrl,
            events  => ZMQ_POLLIN,
        },
    ); 
                 
    my $queue; 
    my $done = 0;
    my ($total_recs,$sent_recs) = (0,0);
    do {
        debug('polling...') if($::debug > 4);
        $poller->poll();
        
        # we wanna check this one first, since it'll come in later
        if($poller->has_event('ctrl')) {
            my $msg = $ctrl->recv()->data();
            debug('ctrl sig received: '.$msg) if($::debug > 2);
            for($msg){
                if(/^TOTAL:(\d+)$/){
                    $total_recs = $1;
                    debug('total received: '.$total_recs) if($::debug > 2);
                    last;
                }
            }
        }
        # we need to move this out of the if/then incase we're waiting on a kill
        if($poller->has_event('sender')){
            debug('found event...') if($::debug > 2);
            my $msg = $sender->recv_as('json');
            
            my $num_msgs = ($#{$msg}+1);
            debug('msgs received: '.$num_msgs) if($::debug > 2);
            foreach (@$msg) {
            	push @$queue, decode_base64($_);
            }

            debug('msgs in queue: '.($#{$queue}+1)) if($::debug > 2);
        }
        
        debug("batch $batch_control tot_recs $total_recs send_recs $sent_recs in_queue  ". @$queue);
        
        # we're not done till we at-least have a total from the 
        # master thread
        # if what's in the queue is the difference between sent and total
        # we're done
        if($total_recs && ($sent_recs + (($#{$queue}+1)) == $total_recs)){
            $done = 1;
            debug("apparently we're done") if ($::debug > 2);
        }
        # if we have a total number and it's equal to our sent number
        # we're done
        if($total_recs && ($sent_recs == $total_recs)){
            $done = 1;
            debug("apparently we're done") if ($::debug > 2);
        }

        if($#{$queue} > $batch_control || $done){
            debug('sending data to router: '.($#{$queue}+1)) if($::debug > 2);
            my ($err,$ret) = $self->send($queue);
            debug('returning answer from router...') if($::debug > 2);
            
            # if the answers was 'success' then send the number of messages we submitted
            # back to process()
            
            my $status = $ret->get_status();
            
            if($status != CIF::Msg::ControlType::StatusType::SUCCESS()) {
                $return->send("ERROR: " . ($ret->{statusMsg} || "none"));
            } else {
                $return->send($ret->{statusMsg}); # this contains the # of items submitted
            }
            $sent_recs += ($#{$queue}+1);
            $queue = [];
        }
        nanosleep NSECS_PER_MSEC;

    } while (!$done);
    
    debug('sender done: sender->close') if($::debug > 1);;
    $sender->close();
    debug('sender done: return->close') if($::debug > 1);;
    $return->close();
    debug('sender done: ctrl->close') if($::debug > 1);;
    $ctrl->close();
    debug('sender done: context->term') if($::debug > 1);;
    $context->term();
}

sub send {
    my $self = shift;
    my $data = shift;

    debug('creating new submission') if($::debug);
  
    my $ret = $self->get_client->new_submission({
        guid    => $self->get_rules->{'guid'},
        data    => $data,
    });
    
    debug('submitting...') if($::debug);
    return $self->get_client->submit($ret);    
}

sub throttle {
    my $throttle = shift;

    require Linux::Cpuinfo;
    my $cpu = Linux::Cpuinfo->new();
    return(DEFAULT_THROTTLE_FACTOR()) unless($cpu);
    
    my $cores = $cpu->num_cpus();
    return(DEFAULT_THROTTLE_FACTOR()) unless($cores && $cores =~ /^\d$/);
    return(DEFAULT_THROTTLE_FACTOR()) if($cores eq 1);
    
    return($cores * (DEFAULT_THROTTLE_FACTOR() * 2))  if($throttle eq 'high');
    return($cores * DEFAULT_THROTTLE_FACTOR())  if($throttle eq 'medium');
}

1;
