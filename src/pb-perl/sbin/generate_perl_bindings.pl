#!/usr/bin/perl -w

use strict;
use Google::ProtocolBuffers;

# it's important that the final portional of 'packagename' (the part after
# the final ::) is consistent across languages. Therefor, the package names
# you see here are the ones that are produced by "protoc" for other languages
# like Java, Python, etc. They are prefixed by "CIF::" but that will be stripped
# when creating the message. 

my $todo = [
    #[ input filename, output filename,  packagename ] 
	[ 'msg.proto',                'lib/CIF/_Msg.pm',               'CIF::_Msg'              ],
	[ 'feed.proto',               'lib/CIF/Msg/Feed.pm',           'CIF::Msg::Feed'         ],
	[ 'ICSG-v1_7-2007.proto',     'lib/ICSG_v1_7_2007_pb2.pm',     'ICSG_v1_7_2007_pb2'     ],
	[ 'RFC5070-IODEF-v1.proto',   'lib/RFC5070_IODEF_v1_pb2.pm',   'RFC5070_IODEF_v1_pb2'   ],
	[ 'RFC4765-IDMEF-2007.proto', 'lib/RFC4765_IDMEF_2007_pb2.pm', 'RFC4765_IDMEF_2007_pb2' ],
	[ 'MAEC-v2.proto',            'lib/MAEC_v2_pb2.pm',            'MAEC_v2_pb2'            ]
];

foreach my $t (@$todo) {
	print "Building Perl PB2 module for: ". $t->[0] . "\n";
	Google::ProtocolBuffers->parsefile(
		"../" . $t->[0],
    	{
        generate_code => $t->[1],
        create_accessors    => 1,
        follow_best_practice => 1,
        package_name => $t->[2]
    	}
	);
}

exit 0;
     
