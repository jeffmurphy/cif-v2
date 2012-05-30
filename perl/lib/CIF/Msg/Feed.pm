package CIF::Msg::Feed;
##
## This file was generated by Google::ProtocolBuffers (0.08)
## on Wed May 30 16:14:02 2012
##      
use strict;
use warnings;
use Google::ProtocolBuffers;
{       
    unless (CIF::Msg::FeedType::RestrictionType->can('_pb_fields_list')) {
        Google::ProtocolBuffers->create_enum(
            'CIF::Msg::FeedType::RestrictionType',
            [
               ['restriction_type_default', 1],
               ['restriction_type_need_to_know', 2],
               ['restriction_type_private', 3],
               ['restriction_type_public', 4],

            ]
        );
    }
    
    unless (CIF::Msg::FeedType->can('_pb_fields_list')) {
        Google::ProtocolBuffers->create_message(
            'CIF::Msg::FeedType',
            [
                [
                    Google::ProtocolBuffers::Constants::LABEL_REQUIRED(), 
                    Google::ProtocolBuffers::Constants::TYPE_STRING(), 
                    'version', 1, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    Google::ProtocolBuffers::Constants::TYPE_STRING(), 
                    'guid', 2, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    Google::ProtocolBuffers::Constants::TYPE_INT32(), 
                    'confidence', 3, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_REQUIRED(), 
                    Google::ProtocolBuffers::Constants::TYPE_STRING(), 
                    'description', 4, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_REQUIRED(), 
                    Google::ProtocolBuffers::Constants::TYPE_STRING(), 
                    'ReportTime', 5, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    'CIF::Msg::FeedType::RestrictionType', 
                    'restriction', 6, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_REPEATED(), 
                    'CIF::Msg::FeedType::MapType', 
                    'restriction_map', 7, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_REPEATED(), 
                    'CIF::Msg::FeedType::MapType', 
                    'group_map', 8, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_REPEATED(), 
                    Google::ProtocolBuffers::Constants::TYPE_BYTES(), 
                    'data', 9, undef
                ],

            ],
            { 'create_accessors' => 1, 'follow_best_practice' => 1,  }
        );
    }

    unless (CIF::Msg::FeedType::MapType->can('_pb_fields_list')) {
        Google::ProtocolBuffers->create_message(
            'CIF::Msg::FeedType::MapType',
            [
                [
                    Google::ProtocolBuffers::Constants::LABEL_REQUIRED(), 
                    Google::ProtocolBuffers::Constants::TYPE_STRING(), 
                    'key', 1, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_REQUIRED(), 
                    Google::ProtocolBuffers::Constants::TYPE_STRING(), 
                    'value', 2, undef
                ],

            ],
            { 'create_accessors' => 1, 'follow_best_practice' => 1,  }
        );
    }

}
1;
