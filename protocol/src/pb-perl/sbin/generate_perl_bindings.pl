#!/usr/bin/perl -w

use strict;
use Google::ProtocolBuffers;

# it's important that the 'packagename' is consistent across languages.
# Therefor, the package names you see here are the ones that are produced 
# by "protoc" for other languages like Java, Python, etc. 

my $todo = [
    #[ input filename, output filename,  packagename ] 
	[ 'submission.proto',         'lib/CIF/Msg/Submission.pm',     'CIF::Msg::Submission'   ], # includes Krenk
	[ 'feed.proto',               'lib/CIF/Msg/Feed.pm',           'CIF::Msg::Feed'         ],
#	[ 'krenk.proto',              'lib/CIF/Msg/Krenk.pm',          'CIF::Msg::Krenk'        ],
	[ 'control.proto',            'lib/CIF/Msg/Control.pm',        'CIF::Msg::Control'      ],
	[ 'profile.proto',            'lib/CIF/Msg/Profile.pm',        'CIF::Msg::Profile'      ],
	[ 'ICSG-v1_7-2007.proto',     'lib/ICSG_v1_7_2007_pb2.pm',     'ICSG_v1_7_2007_pb2'     ],
	[ 'RFC5070-IODEF-v1.proto',   'lib/RFC5070_IODEF_v1_pb2.pm',   'RFC5070_IODEF_v1_pb2'   ],
	[ 'RFC4765-IDMEF-2007.proto', 'lib/RFC4765_IDMEF_2007_pb2.pm', 'RFC4765_IDMEF_2007_pb2' ],
	[ 'MAEC-v2.proto',            'lib/MAEC_v2_pb2.pm',            'MAEC_v2_pb2'            ],
	[ 'mmdef.proto',              'lib/mmdef_pb2.pm',              'mmdef_pb2'              ]
];

foreach my $t (@$todo) {
	print "Building Perl PB2 module for: ". $t->[0] . "\n";
	Google::ProtocolBuffers->parsefile(
		"../" . $t->[0],
    	{
    		include_dir => "..",
        	generate_code => $t->[1],
        	create_accessors    => 1,
        	follow_best_practice => 1,
        	package_name => $t->[2]
    	}
	);
}

exit 0;
    