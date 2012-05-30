enum linkage_category
{
	linkage_category_hard_link,
	linkage_category_mount_point,
	linkage_category_reparse_point,
	linkage_category_shortcut,
	linkage_category_stream,
	linkage_category_symbolic_link,
}

enum impact_completion
{
	impact_completion_failed,
	impact_completion_succeeded,
}

enum confidence_rating
{
	confidence_rating_high,
	confidence_rating_low,
	confidence_rating_medium,
	confidence_rating_numeric,
}

enum yes_no_type
{
	yes_no_type_no,
	yes_no_type_unknown,
	yes_no_type_yes,
}

enum impact_type
{
	impact_type_admin,
	impact_type_dos,
	impact_type_file,
	impact_type_other,
	impact_type_recon,
	impact_type_user,
}

enum file_permission
{
	file_permission_changePermissions,
	file_permission_delete,
	file_permission_execute,
	file_permission_executeAs,
	file_permission_noAccess,
	file_permission_read,
	file_permission_search,
	file_permission_takeOwnership,
	file_permission_write,
}

enum checksum_algorithm
{
	checksum_algorithm_CRC_32,
	checksum_algorithm_Gost,
	checksum_algorithm_Haval,
	checksum_algorithm_MD4,
	checksum_algorithm_MD5,
	checksum_algorithm_SHA1,
	checksum_algorithm_SHA2_256,
	checksum_algorithm_SHA2_384,
	checksum_algorithm_SHA2_512,
	checksum_algorithm_Tiger,
}

enum address_category
{
	address_category_atm,
	address_category_e_mail,
	address_category_ipv4_addr,
	address_category_ipv4_addr_hex,
	address_category_ipv4_net,
	address_category_ipv4_net_mask,
	address_category_ipv6_addr,
	address_category_ipv6_addr_hex,
	address_category_ipv6_net,
	address_category_ipv6_net_mask,
	address_category_lotus_notes,
	address_category_mac,
	address_category_sna,
	address_category_unknown,
	address_category_vm,
}

enum node_category
{
	node_category_ads,
	node_category_afs,
	node_category_coda,
	node_category_dfs,
	node_category_dns,
	node_category_hosts,
	node_category_kerberos,
	node_category_nds,
	node_category_nis,
	node_category_nisplus,
	node_category_nt,
	node_category_unknown,
	node_category_wfw,
}

enum id_type
{
	id_type_current_group,
	id_type_current_user,
	id_type_group_privs,
	id_type_original_user,
	id_type_other_privs,
	id_type_target_user,
	id_type_user_privs,
}

enum reference_origin
{
	reference_origin_bugtraqid,
	reference_origin_cve,
	reference_origin_osvdb,
	reference_origin_unknown,
	reference_origin_user_specific,
	reference_origin_vendor_specific,
}

enum additionaldata_type
{
	additionaldata_type_boolean,
	additionaldata_type_byte,
	additionaldata_type_byte_string,
	additionaldata_type_character,
	additionaldata_type_date_time,
	additionaldata_type_integer,
	additionaldata_type_ntpstamp,
	additionaldata_type_portlist,
	additionaldata_type_real,
	additionaldata_type_string,
	additionaldata_type_xml,
}

enum impact_severity
{
	impact_severity_high,
	impact_severity_info,
	impact_severity_low,
	impact_severity_medium,
}

enum file_category
{
	file_category_current,
	file_category_original,
}

enum action_category
{
	action_category_block_installed,
	action_category_notification_sent,
	action_category_other,
	action_category_taken_offline,
}

enum user_category
{
	user_category_application,
	user_category_os_device,
	user_category_unknown,
}

struct UnspecifiedType
{
	1 : required string baseObjectType,
	2 : required binary object,
}

struct Confidence
{
	1 : required confidence_rating rating,
}

struct Checksum
{
	1 : required string value,
	2 : required string key,
	3 : required checksum_algorithm algorithm,
}

struct SNMPService
{
	1 : required string oid,
	2 : required i16 messageProcessingModel,
	3 : required i16 securityModel,
	4 : required string securityName,
	5 : required i16 securityLevel,
	6 : required string contextName,
	7 : required string contextEngineID,
	8 : required string command,
}

struct OverflowAlert
{
	1 : required string program,
	2 : required string size,
	3 : required UnspecifiedType buffer,
}

struct TimeWithNtpstamp
{
	1 : required string ntpstamp,
}

struct Action
{
	1 : optional action_category category,
}

struct Process
{
	1 : required string name,
	2 : required i16 pid,
	3 : required string path,
	4 : required list<string> arg,
	5 : required list<string> env,
	6 : optional string ident,
}

struct WebService
{
	1 : required UnspecifiedType url,
	2 : required string cgi,
	3 : required string http_method,
	4 : required list<string> arg,
}

struct Impact
{
	1 : optional impact_severity severity,
	2 : optional impact_completion completion,
	3 : optional impact_type type,
}

struct Permission
{
	1 : required file_permission perms,
}

struct Inode
{
	1 : required string change_time,
	2 : required string number,
	3 : required string major_device,
	4 : required string minor_device,
	5 : required string c_major_device,
	6 : required string c_minor_device,
}

struct UserId
{
	1 : required string name,
	2 : required i16 number,
	3 : optional id_type type,
	4 : optional string tty,
	5 : optional string ident,
}

struct xmltext
{
}

struct AdditionalData
{
	1 : required bool _boolean,
	2 : required byte _byte,
	3 : required string character,
	4 : required i64 date_time,
	5 : required i16 _integer,
	6 : required string ntpstamp,
	7 : required UnspecifiedType portlist,
	8 : required double real,
	9 : required string _string,
	10 : required UnspecifiedType byte_string,
	11 : required xmltext xml,
	12 : optional additionaldata_type type,
	13 : optional string meaning,
}

struct Alertident
{
	1 : optional string analyzerid,
}

struct Address
{
	1 : required string address,
	2 : required string netmask,
	3 : optional string vlan_num,
	4 : optional string ident,
	5 : optional string vlan_name,
	6 : optional address_category category,
}

struct Reference
{
	1 : required string name,
	2 : required string url,
	3 : optional reference_origin origin,
	4 : optional string meaning,
}

struct Assessment
{
	1 : required Impact _Impact,
	2 : required list<Action> _Action,
	3 : required Confidence _Confidence,
}

struct User
{
	1 : required list<UserId> _UserId,
	2 : optional string ident,
	3 : optional user_category category,
}

struct Service
{
	1 : required string name,
	2 : required i16 port,
	3 : required UnspecifiedType portlist,
	4 : required string protocol,
	5 : required SNMPService _SNMPService,
	6 : required WebService _WebService,
	7 : optional i16 ip_version,
	8 : optional string ident,
	9 : optional i16 iana_protocol_number,
	10 : optional string iana_protocol_name,
}

struct ToolAlert
{
	1 : required string name,
	2 : required string command,
	3 : required list<Alertident> alertident,
}

struct CorrelationAlert
{
	1 : required string name,
	2 : required list<Alertident> alertident,
}

struct Classification
{
	1 : required list<Reference> _Reference,
	2 : required string text,
	3 : optional string ident,
}

struct FileAccess
{
	1 : required UserId _UserId,
	2 : required list<Permission> permission,
}

struct Node
{
	1 : required string location,
	2 : required string name,
	3 : required Address _Address,
	4 : optional string ident,
	5 : optional node_category category,
}

struct Analyzer
{
	1 : required Node _Node,
	2 : required Process _Process,
	3 : required binary Analyzer,
	4 : optional string version,
	5 : optional string ostype,
	6 : optional string name,
	7 : optional string analyzerid,
	8 : optional string model,
	9 : optional string manufacturer,
	10 : optional string _class,
	11 : optional string osversion,
}

struct Heartbeat
{
	1 : required Analyzer _Analyzer,
	2 : required TimeWithNtpstamp CreateTime,
	3 : required i16 HeartbeatInterval,
	4 : required TimeWithNtpstamp AnalyzerTime,
	5 : required list<AdditionalData> _AdditionalData,
	6 : optional string messageid,
}

struct Source
{
	1 : required Node _Node,
	2 : required User _User,
	3 : required Process _Process,
	4 : required Service _Service,
	5 : optional string ident,
	6 : optional yes_no_type spoofed,
	7 : optional string _interface,
}

struct File
{
	1 : required string name,
	2 : required string path,
	3 : required i64 create_time,
	4 : required i64 modify_time,
	5 : required i64 access_time,
	6 : required i16 data_size,
	7 : required i16 disk_size,
	8 : required list<FileAccess> _FileAccess,
	9 : required list<Linkage> _Linkage,
	10 : required Inode _Inode,
	11 : required list<Checksum> _Checksum,
	12 : required string fstype,
	13 : optional string ident,
	14 : optional string file_type,
	15 : required file_category category,
}

struct Linkage
{
	1 : required string name,
	2 : required string path,
	3 : required File _File,
	4 : required linkage_category category,
}

struct Alert
{
	1 : required Analyzer _Analyzer,
	2 : required TimeWithNtpstamp CreateTime,
	3 : required TimeWithNtpstamp DetectTime,
	4 : required TimeWithNtpstamp AnalyzerTime,
	5 : required list<Source> _Source,
	6 : required list<Target> _Target,
	7 : required Classification _Classification,
	8 : required Assessment _Assessment,
	9 : required ToolAlert _ToolAlert,
	10 : required OverflowAlert _OverflowAlert,
	11 : required CorrelationAlert _CorrelationAlert,
	12 : required list<AdditionalData> _AdditionalData,
	13 : optional string messageid,
}

struct IDMEF_Message
{
	1 : required Alert _Alert,
	2 : required Heartbeat _Heartbeat,
	3 : optional double version,
}

struct Target
{
	1 : required Node _Node,
	2 : required User _User,
	3 : required Process _Process,
	4 : required Service _Service,
	5 : required list<File> _File,
	6 : optional yes_no_type decoy,
	7 : optional string ident,
	8 : optional string _interface,
}

