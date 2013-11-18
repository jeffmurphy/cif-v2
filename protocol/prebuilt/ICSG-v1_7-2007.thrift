enum RelationshipTypeEnum
{
	RelationshipTypeEnum_causesToInstall,
	RelationshipTypeEnum_contactedBy,
	RelationshipTypeEnum_downloadedFrom,
	RelationshipTypeEnum_downloads,
	RelationshipTypeEnum_hasAssociatedConfiguration,
	RelationshipTypeEnum_hosts,
	RelationshipTypeEnum_installed,
	RelationshipTypeEnum_isClassifiedAs,
	RelationshipTypeEnum_isNameServerOf,
	RelationshipTypeEnum_isParentOf,
	RelationshipTypeEnum_isServerOfService,
	RelationshipTypeEnum_operatedByEntity,
	RelationshipTypeEnum_relatedTo,
	RelationshipTypeEnum_resolvesTo,
	RelationshipTypeEnum_runs,
	RelationshipTypeEnum_usesCNC,
	RelationshipTypeEnum_verifiedBy,
}

enum IPTypeEnum
{
	IPTypeEnum_ipv4,
	IPTypeEnum_ipv6,
}

enum LocationTypeEnum
{
	LocationTypeEnum_city,
	LocationTypeEnum_countryCodeFIPS,
	LocationTypeEnum_countryCodeISO3166_2,
	LocationTypeEnum_countryCodeISO3166_3,
	LocationTypeEnum_isp,
	LocationTypeEnum_region,
}

enum VolumeUnitsEnum
{
	VolumeUnitsEnum_numberMachinesAffected,
	VolumeUnitsEnum_numberOfWebsitesHosting,
	VolumeUnitsEnum_numberOfWebsitesRedirecting,
	VolumeUnitsEnum_numberSeenInMalwareSamples,
	VolumeUnitsEnum_numberSeenInSpam,
	VolumeUnitsEnum_numberUsersAffected,
}

enum RegionTypeEnum
{
	RegionTypeEnum_APAC,
	RegionTypeEnum_Africa,
	RegionTypeEnum_CentralAmerica,
	RegionTypeEnum_Europe,
	RegionTypeEnum_NorthAmerica,
	RegionTypeEnum_SouthAmerica,
}

enum ClassificationTypeEnum
{
	ClassificationTypeEnum_clean,
	ClassificationTypeEnum_dirty,
	ClassificationTypeEnum_neutral,
	ClassificationTypeEnum_unknown,
	ClassificationTypeEnum_unwanted,
}

enum OriginTypeEnum
{
	OriginTypeEnum_collection,
	OriginTypeEnum_desktop,
	OriginTypeEnum_gateway,
	OriginTypeEnum_honeypot,
	OriginTypeEnum_internal,
	OriginTypeEnum_isp,
	OriginTypeEnum_lan,
	OriginTypeEnum_partner,
	OriginTypeEnum_spam,
	OriginTypeEnum_unknown,
	OriginTypeEnum_user,
	OriginTypeEnum_wan,
}

enum PropertyTypeEnum
{
	PropertyTypeEnum_adminContact,
	PropertyTypeEnum_browser,
	PropertyTypeEnum_city,
	PropertyTypeEnum_comment,
	PropertyTypeEnum_countryCodeFIPS,
	PropertyTypeEnum_countryCodeISO3166_2,
	PropertyTypeEnum_countryCodeISO3166_3,
	PropertyTypeEnum_filename,
	PropertyTypeEnum_filepath,
	PropertyTypeEnum_httpMethod,
	PropertyTypeEnum_isDamaged,
	PropertyTypeEnum_isKernel,
	PropertyTypeEnum_isNonReplicating,
	PropertyTypeEnum_isParasitic,
	PropertyTypeEnum_isPolymorphic,
	PropertyTypeEnum_isStealth,
	PropertyTypeEnum_isVirus,
	PropertyTypeEnum_isp,
	PropertyTypeEnum_locationUrl,
	PropertyTypeEnum_nameServer,
	PropertyTypeEnum_operatingSystem,
	PropertyTypeEnum_ownerAddress,
	PropertyTypeEnum_postData,
	PropertyTypeEnum_referrer,
	PropertyTypeEnum_region,
	PropertyTypeEnum_registrant,
	PropertyTypeEnum_registrationDate,
	PropertyTypeEnum_registryValueData,
	PropertyTypeEnum_technicalContact,
	PropertyTypeEnum_urlParameterString,
	PropertyTypeEnum_userAgent,
}

struct UnspecifiedType
{
	1 : required string baseObjectType,
	2 : required binary object,
}

struct entityObject
{
	1 : required string name,
	2 : required string id,
}

struct extraHashType
{
	1 : required string type,
}

struct classificationDetailsType
{
	1 : required string definitionVersion,
	2 : required i64 detectionAddedTimeStamp,
	3 : required i64 detectionShippedTimeStamp,
	4 : required string product,
	5 : required string productVersion,
}

struct locationType
{
	1 : optional LocationTypeEnum type,
}

struct domainObject
{
	1 : required string domain,
	2 : required string id,
}

struct registryObject
{
	1 : required string key,
	2 : required string valueName,
	3 : required string id,
}

struct classificationObject
{
	1 : required string classificationName,
	2 : required string companyName,
	3 : required string category,
	4 : required classificationDetailsType classificationDetails,
	5 : required ClassificationTypeEnum type,
	6 : required string id,
}

struct property
{
	1 : required PropertyTypeEnum type,
}

struct reference
{
}

struct IPAddress
{
	1 : required IPTypeEnum type,
}

struct ASNObject
{
	1 : required i16 as_number,
	2 : required i16 id,
}

struct referencesType
{
	1 : required list<reference> ref,
}

struct volumeType
{
	1 : required VolumeUnitsEnum units,
}

struct uriObject
{
	1 : required string uriString,
	2 : required string protocol,
	3 : required string hostname,
	4 : required string domain,
	5 : required i16 port,
	6 : required string path,
	7 : required string ipProtocol,
	8 : required string id,
}

struct fileObject
{
	1 : required string md5,
	2 : required string sha1,
	3 : required string sha256,
	4 : required string sha512,
	5 : required i16 size,
	6 : required string crc32,
	7 : required list<string> fileType,
	8 : required list<extraHashType> extraHash,
	9 : required string id,
}

struct objectProperty
{
	1 : required referencesType references,
	2 : required i64 timestamp,
	3 : required list<property> _property,
	4 : optional UnspecifiedType id,
}

struct targetType
{
	1 : required list<reference> ref,
}

struct sourceType
{
	1 : required list<reference> ref,
}

struct relationship
{
	1 : required sourceType source,
	2 : required targetType target,
	3 : required i64 timestamp,
	4 : required RelationshipTypeEnum type,
	5 : optional UnspecifiedType id,
}

struct IPObject
{
	1 : required IPAddress startAddress,
	2 : required IPAddress endAddress,
	3 : required string id,
}

struct fieldDataEntry
{
	1 : required referencesType references,
	2 : required i64 startDate,
	3 : required i64 endDate,
	4 : required i64 firstSeenDate,
	5 : required OriginTypeEnum origin,
	6 : required i16 commonality,
	7 : required list<volumeType> volume,
	8 : required i16 importance,
	9 : required locationType location,
}

struct relationshipsType
{
	1 : required list<relationship> _relationship,
}

struct objectPropertiesType
{
	1 : required list<objectProperty> _objectProperty,
}

struct fieldDataType
{
	1 : required list<fieldDataEntry> _fieldDataEntry,
}

struct objectsType
{
	1 : required list<fileObject> file,
	2 : required list<uriObject> uri,
	3 : required list<domainObject> domain,
	4 : required list<registryObject> registry,
	5 : required list<IPObject> ip,
	6 : required list<ASNObject> asn,
	7 : required list<entityObject> entity,
	8 : required list<classificationObject> classification,
}

struct malwareMetaDataType
{
	1 : required string company,
	2 : required string author,
	3 : required string comment,
	4 : required i64 timestamp,
	5 : required objectsType objects,
	6 : required objectPropertiesType objectProperties,
	7 : required relationshipsType relationships,
	8 : required fieldDataType fieldData,
	9 : required double version,
	10 : required string id,
}

