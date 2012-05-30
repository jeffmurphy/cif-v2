enum duration_type
{
	duration_type_day,
	duration_type_ext_value,
	duration_type_hour,
	duration_type_minute,
	duration_type_month,
	duration_type_quarter,
	duration_type_second,
	duration_type_year,
}

enum restriction_type
{
	restriction_type_default,
	restriction_type_need_to_know,
	restriction_type_private,
	restriction_type_public,
}

enum Contact_role
{
	Contact_role_admin,
	Contact_role_cc,
	Contact_role_creator,
	Contact_role_ext_value,
	Contact_role_irt,
	Contact_role_tech,
}

enum System_category
{
	System_category_ext_value,
	System_category_infrastructure,
	System_category_intermediate,
	System_category_sensor,
	System_category_source,
	System_category_target,
}

enum severity_type
{
	severity_type_high,
	severity_type_low,
	severity_type_medium,
}

enum dtype_type
{
	dtype_type_boolean,
	dtype_type_byte,
	dtype_type_character,
	dtype_type_csv,
	dtype_type_date_time,
	dtype_type_ext_value,
	dtype_type_file,
	dtype_type_frame,
	dtype_type_integer,
	dtype_type_ipv4_packet,
	dtype_type_ipv6_packet,
	dtype_type_ntpstamp,
	dtype_type_packet,
	dtype_type_path,
	dtype_type_portlist,
	dtype_type_real,
	dtype_type_string,
	dtype_type_url,
	dtype_type_winreg,
	dtype_type_xml,
}

enum RecordPattern_offsetunit
{
	RecordPattern_offsetunit_byte,
	RecordPattern_offsetunit_ext_value,
	RecordPattern_offsetunit_line,
}

enum Confidence_rating
{
	Confidence_rating_high,
	Confidence_rating_low,
	Confidence_rating_medium,
	Confidence_rating_numeric,
	Confidence_rating_unknown,
}

enum Counter_type
{
	Counter_type_alert,
	Counter_type_byte,
	Counter_type_event,
	Counter_type_ext_value,
	Counter_type_flow,
	Counter_type_host,
	Counter_type_message,
	Counter_type_organization,
	Counter_type_packet,
	Counter_type_session,
	Counter_type_site,
}

enum System_spoofed
{
	System_spoofed_no,
	System_spoofed_unknown,
	System_spoofed_yes,
}

enum Impact_completion
{
	Impact_completion_failed,
	Impact_completion_succeeded,
}

enum Incident_purpose
{
	Incident_purpose_ext_value,
	Incident_purpose_mitigation,
	Incident_purpose_other,
	Incident_purpose_reporting,
	Incident_purpose_traceback,
}

enum Address_category
{
	Address_category_asn,
	Address_category_atm,
	Address_category_e_mail,
	Address_category_ext_value,
	Address_category_ipv4_addr,
	Address_category_ipv4_net,
	Address_category_ipv4_net_mask,
	Address_category_ipv6_addr,
	Address_category_ipv6_net,
	Address_category_ipv6_net_mask,
	Address_category_mac,
}

enum TimeImpact_metric
{
	TimeImpact_metric_downtime,
	TimeImpact_metric_elapsed,
	TimeImpact_metric_ext_value,
	TimeImpact_metric_labor,
}

enum Impact_type
{
	Impact_type_admin,
	Impact_type_dos,
	Impact_type_ext_value,
	Impact_type_extortion,
	Impact_type_file,
	Impact_type_info_leak,
	Impact_type_misconfiguration,
	Impact_type_policy,
	Impact_type_recon,
	Impact_type_social_engineering,
	Impact_type_unknown,
	Impact_type_user,
}

enum RegistryHandle_registry
{
	RegistryHandle_registry_afrinic,
	RegistryHandle_registry_apnic,
	RegistryHandle_registry_arin,
	RegistryHandle_registry_ext_value,
	RegistryHandle_registry_internic,
	RegistryHandle_registry_lacnic,
	RegistryHandle_registry_local,
	RegistryHandle_registry_ripe,
}

enum RecordPattern_type
{
	RecordPattern_type_binary,
	RecordPattern_type_ext_value,
	RecordPattern_type_regex,
	RecordPattern_type_xpath,
}

enum Assessment_occurrence
{
	Assessment_occurrence_actual,
	Assessment_occurrence_potential,
}

enum NodeRole_category
{
	NodeRole_category_application,
	NodeRole_category_client,
	NodeRole_category_credential,
	NodeRole_category_database,
	NodeRole_category_directory,
	NodeRole_category_ext_value,
	NodeRole_category_file,
	NodeRole_category_ftp,
	NodeRole_category_infra,
	NodeRole_category_log,
	NodeRole_category_mail,
	NodeRole_category_messaging,
	NodeRole_category_name,
	NodeRole_category_p2p,
	NodeRole_category_print,
	NodeRole_category_server_internal,
	NodeRole_category_server_public,
	NodeRole_category_streaming,
	NodeRole_category_voice,
	NodeRole_category_www,
}

enum Contact_type
{
	Contact_type_ext_value,
	Contact_type_organization,
	Contact_type_person,
}

enum action_type
{
	action_type_block_host,
	action_type_block_network,
	action_type_block_port,
	action_type_contact_sender,
	action_type_contact_source_site,
	action_type_contact_target_site,
	action_type_ext_value,
	action_type_investigate,
	action_type_nothing,
	action_type_other,
	action_type_rate_limit_host,
	action_type_rate_limit_network,
	action_type_rate_limit_port,
	action_type_remediate_other,
	action_type_status_new_info,
	action_type_status_triage,
}

struct UnspecifiedType
{
	1 : required string baseObjectType,
	2 : required binary object,
}

struct ImpactType
{
	1 : optional Impact_type type,
	2 : optional Impact_completion completion,
	3 : optional string lang,
	4 : optional string ext_type,
	5 : optional severity_type severity,
}

struct PostalAddressType
{
	1 : optional string meaning,
	2 : optional string lang,
}

struct RegistryHandleType
{
	1 : optional RegistryHandle_registry registry,
	2 : optional string ext_registry,
}

struct RecordPatternType
{
	1 : required RecordPattern_type type,
	2 : optional string ext_type,
	3 : optional i16 offset,
	4 : optional RecordPattern_offsetunit offsetunit,
	5 : optional string ext_offsetunit,
	6 : optional i16 instance,
}

struct SoftwareType
{
	1 : required UnspecifiedType URL,
	2 : optional string vendor,
	3 : optional string version,
	4 : optional string configid,
	5 : optional string name,
	6 : optional string patch,
	7 : optional string family,
	8 : optional string swid,
}

struct ConfidenceType
{
	1 : required Confidence_rating rating,
}

struct TimeImpactType
{
	1 : optional severity_type severity,
	2 : required TimeImpact_metric metric,
	3 : optional string ext_metric,
	4 : optional duration_type duration,
	5 : optional string ext_duration,
}

struct IncidentIDType
{
	1 : required string name,
	2 : optional string instance,
	3 : optional restriction_type restriction,
}

struct NodeRoleType
{
	1 : optional string lang,
	2 : optional string ext_category,
	3 : required NodeRole_category category,
}

struct MLStringType
{
	1 : optional string lang,
}

struct CounterType
{
	1 : required Counter_type type,
	2 : optional string ext_type,
	3 : optional string meaning,
	4 : optional duration_type duration,
	5 : optional string ext_duration,
}

struct ExtensionType
{
	1 : optional string ext_dtype,
	2 : optional string formatid,
	3 : optional string meaning,
	4 : required dtype_type dtype,
	5 : optional restriction_type restriction,
}

struct MonetaryImpactType
{
	1 : optional severity_type severity,
	2 : optional string currency,
}

struct ContactMeansType
{
	1 : optional string meaning,
}

struct AddressType
{
	1 : optional Address_category category,
	2 : optional string ext_category,
	3 : optional string vlan_name,
	4 : optional i16 vlan_num,
}

struct AlternativeIDType
{
	1 : required list<IncidentIDType> IncidentID,
	2 : optional restriction_type restriction,
}

struct AssessmentType
{
	1 : required ImpactType Impact,
	2 : required TimeImpactType TimeImpact,
	3 : required MonetaryImpactType MonetaryImpact,
	4 : required list<CounterType> Counter,
	5 : required ConfidenceType Confidence,
	6 : required list<ExtensionType> AdditionalData,
	7 : optional Assessment_occurrence occurrence,
	8 : optional restriction_type restriction,
}

struct ReferenceType
{
	1 : required MLStringType ReferenceName,
	2 : required list<UnspecifiedType> URL,
	3 : required list<MLStringType> Description,
}

struct ServiceType
{
	1 : required i16 Port,
	2 : required string Portlist,
	3 : required i16 ProtoType,
	4 : required i16 ProtoCode,
	5 : required i16 ProtoField,
	6 : required SoftwareType Application,
	7 : required i16 ip_protocol,
}

struct MethodType
{
	1 : required ReferenceType Reference,
	2 : required MLStringType Description,
	3 : required list<ExtensionType> AdditionalData,
	4 : optional restriction_type restriction,
}

struct ContactType
{
	1 : required MLStringType ContactName,
	2 : required list<MLStringType> Description,
	3 : required list<RegistryHandleType> RegistryHandle,
	4 : required PostalAddressType PostalAddress,
	5 : required list<ContactMeansType> Email,
	6 : required list<ContactMeansType> Telephone,
	7 : required ContactMeansType Fax,
	8 : required string Timezone,
	9 : required list<binary> Contact,
	10 : required list<ExtensionType> AdditionalData,
	11 : required Contact_type type,
	12 : required Contact_role role,
	13 : optional restriction_type restriction,
	14 : optional string ext_type,
	15 : optional string ext_role,
}

struct RelatedActivityType
{
	1 : required list<IncidentIDType> IncidentID,
	2 : required list<UnspecifiedType> URL,
	3 : optional restriction_type restriction,
}

struct ExpectationType
{
	1 : required list<MLStringType> Description,
	2 : required i64 StartTime,
	3 : required i64 EndTime,
	4 : required ContactType Contact,
	5 : optional string ext_action,
	6 : optional action_type action,
	7 : optional restriction_type restriction,
	8 : optional severity_type severity,
}

struct RecordDataType
{
	1 : required i64 DateTime,
	2 : required list<MLStringType> Description,
	3 : required SoftwareType Application,
	4 : required list<RecordPatternType> RecordPattern,
	5 : required list<ExtensionType> RecordItem,
	6 : required list<ExtensionType> AdditionalData,
	7 : optional restriction_type restriction,
}

struct NodeType
{
	1 : required MLStringType NodeName,
	2 : required list<AddressType> Address,
	3 : required MLStringType Location,
	4 : required i64 DateTime,
	5 : required list<NodeRoleType> NodeRole,
	6 : required list<CounterType> Counter,
}

struct HistoryItemType
{
	1 : required i64 DateTime,
	2 : required IncidentIDType IncidentID,
	3 : required ContactType Contact,
	4 : required list<MLStringType> Description,
	5 : required list<ExtensionType> AdditionalData,
	6 : optional string ext_action,
	7 : required action_type action,
	8 : optional restriction_type restriction,
}

struct HistoryType
{
	1 : required list<HistoryItemType> HistoryItem,
	2 : optional restriction_type restriction,
}

struct RecordType
{
	1 : required list<RecordDataType> RecordData,
	2 : optional restriction_type restriction,
}

struct SystemType
{
	1 : required NodeType Node,
	2 : required list<ServiceType> Service,
	3 : required list<SoftwareType> OperatingSystem,
	4 : required list<CounterType> Counter,
	5 : required list<MLStringType> Description,
	6 : required list<ExtensionType> AdditionalData,
	7 : optional System_spoofed spoofed,
	8 : optional string _interface,
	9 : optional restriction_type restriction,
	10 : optional string ext_category,
	11 : optional System_category category,
}

struct FlowType
{
	1 : required list<SystemType> System,
}

struct EventDataType
{
	1 : required list<MLStringType> Description,
	2 : required i64 DetectTime,
	3 : required i64 StartTime,
	4 : required i64 EndTime,
	5 : required list<ContactType> Contact,
	6 : required AssessmentType Assessment,
	7 : required list<MethodType> Method,
	8 : required list<FlowType> Flow,
	9 : required list<ExpectationType> Expectation,
	10 : required RecordType Record,
	11 : required list<binary> EventData,
	12 : required list<ExtensionType> AdditionalData,
	13 : optional restriction_type restriction,
}

struct IncidentType
{
	1 : required IncidentIDType IncidentID,
	2 : required AlternativeIDType AlternativeID,
	3 : required RelatedActivityType RelatedActivity,
	4 : required i64 DetectTime,
	5 : required i64 StartTime,
	6 : required i64 EndTime,
	7 : required i64 ReportTime,
	8 : required list<MLStringType> Description,
	9 : required list<AssessmentType> Assessment,
	10 : required list<MethodType> Method,
	11 : required list<ContactType> Contact,
	12 : required list<EventDataType> EventData,
	13 : required HistoryType History,
	14 : required list<ExtensionType> AdditionalData,
	15 : required Incident_purpose purpose,
	16 : optional string ext_purpose,
	17 : optional string lang,
	18 : optional restriction_type restriction,
}

struct IODEF_DocumentType
{
	1 : required list<IncidentType> Incident,
	2 : optional string formatid,
	3 : optional string version,
	4 : required string lang,
}

