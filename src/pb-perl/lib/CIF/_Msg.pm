##
## This file was generated by Google::ProtocolBuffers (0.08_01)
## on Wed Jul 31 07:55:44 2013 from file ../msg.proto
##
package CIF::_Msg;
use strict;
use warnings;
use Google::ProtocolBuffers;
{
    unless (CIF::Msg::MessageType::MsgType->can('_pb_fields_list')) {
        Google::ProtocolBuffers->create_enum(
            'CIF::Msg::MessageType::MsgType',
            [
               ['QUERY', 1],
               ['SUBMISSION', 2],
               ['REPLY', 4],

            ]
        );
    }
    
    unless (CIF::Msg::MessageType::StatusType->can('_pb_fields_list')) {
        Google::ProtocolBuffers->create_enum(
            'CIF::Msg::MessageType::StatusType',
            [
               ['SUCCESS', 1],
               ['FAILED', 2],
               ['UNAUTHORIZED', 3],

            ]
        );
    }
    
    unless (CIF::Msg::MessageType::Reply->can('_pb_fields_list')) {
        Google::ProtocolBuffers->create_message(
            'CIF::Msg::MessageType::Reply',
            [
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    Google::ProtocolBuffers::Constants::TYPE_STRING(), 
                    'baseObjectType', 1, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    Google::ProtocolBuffers::Constants::TYPE_BYTES(), 
                    'data', 2, undef
                ],

            ],
            { 'create_accessors' => 1, 'follow_best_practice' => 1,  }
        );
    }

    unless (CIF::Msg::MessageType::QueryRequest->can('_pb_fields_list')) {
        Google::ProtocolBuffers->create_message(
            'CIF::Msg::MessageType::QueryRequest',
            [
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    Google::ProtocolBuffers::Constants::TYPE_INT32(), 
                    'limit', 1, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    Google::ProtocolBuffers::Constants::TYPE_INT32(), 
                    'confidence', 2, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_REPEATED(), 
                    'CIF::Msg::MessageType::QueryStruct', 
                    'query', 3, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    Google::ProtocolBuffers::Constants::TYPE_STRING(), 
                    'description', 4, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    Google::ProtocolBuffers::Constants::TYPE_BOOL(), 
                    'feed', 5, 0
                ],

            ],
            { 'create_accessors' => 1, 'follow_best_practice' => 1,  }
        );
    }

    unless (CIF::Msg::MessageType->can('_pb_fields_list')) {
        Google::ProtocolBuffers->create_message(
            'CIF::Msg::MessageType',
            [
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    Google::ProtocolBuffers::Constants::TYPE_DOUBLE(), 
                    'version', 1, 20120927
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    Google::ProtocolBuffers::Constants::TYPE_BYTES(), 
                    'seq', 2, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    Google::ProtocolBuffers::Constants::TYPE_STRING(), 
                    'apikey', 3, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    Google::ProtocolBuffers::Constants::TYPE_STRING(), 
                    'guid', 4, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_REQUIRED(), 
                    'CIF::Msg::MessageType::MsgType', 
                    'type', 5, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    'CIF::Msg::MessageType::StatusType', 
                    'status', 6, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_REPEATED(), 
                    'CIF::Msg::MessageType::QueryRequest', 
                    'queryRequest', 7, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_REPEATED(), 
                    'CIF::Msg::MessageType::SubmissionRequest', 
                    'submissionRequest', 8, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_REPEATED(), 
                    'CIF::Msg::MessageType::Reply', 
                    'reply', 9, undef
                ],

            ],
            { 'create_accessors' => 1, 'follow_best_practice' => 1,  }
        );
    }

    unless (CIF::Msg::MessageType::QueryStruct->can('_pb_fields_list')) {
        Google::ProtocolBuffers->create_message(
            'CIF::Msg::MessageType::QueryStruct',
            [
                [
                    Google::ProtocolBuffers::Constants::LABEL_REQUIRED(), 
                    Google::ProtocolBuffers::Constants::TYPE_STRING(), 
                    'query', 1, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    Google::ProtocolBuffers::Constants::TYPE_BOOL(), 
                    'nolog', 2, undef
                ],

            ],
            { 'create_accessors' => 1, 'follow_best_practice' => 1,  }
        );
    }

    unless (CIF::Msg::MessageType::SubmissionRequest->can('_pb_fields_list')) {
        Google::ProtocolBuffers->create_message(
            'CIF::Msg::MessageType::SubmissionRequest',
            [
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    Google::ProtocolBuffers::Constants::TYPE_STRING(), 
                    'baseObjectType', 1, undef
                ],
                [
                    Google::ProtocolBuffers::Constants::LABEL_OPTIONAL(), 
                    Google::ProtocolBuffers::Constants::TYPE_BYTES(), 
                    'data', 2, undef
                ],

            ],
            { 'create_accessors' => 1, 'follow_best_practice' => 1,  }
        );
    }

}
1;
