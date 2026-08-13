// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Lot _$LotFromJson(Map<String, dynamic> json) => _Lot(
  id: json['id'] as String,
  lotCode: json['lotCode'] as String,
  canonicalLotCode: json['canonicalLotCode'] as String,
  companyId: BigInt.parse(json['companyId'] as String),
  productId: BigInt.parse(json['productId'] as String),
  productName: json['productName'] as String?,
  sku: json['sku'] as String?,
  stageCode: json['stageCode'] as String?,
  cropCategoryCode: json['cropCategoryCode'] as String?,
  seedGenerationCode: json['seedGenerationCode'] as String?,
  fieldStatusCode: json['fieldStatusCode'] as String?,
  cropYear: (json['cropYear'] as num?)?.toInt(),
  seasonCode: json['seasonCode'] as String?,
  siteId: json['siteId'] as String?,
  siteName: json['siteName'] as String?,
  status: json['status'] as String,
  notes: json['notes'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$LotToJson(_Lot instance) => <String, dynamic>{
  'id': instance.id,
  'lotCode': instance.lotCode,
  'canonicalLotCode': instance.canonicalLotCode,
  'companyId': instance.companyId.toString(),
  'productId': instance.productId.toString(),
  'productName': instance.productName,
  'sku': instance.sku,
  'stageCode': instance.stageCode,
  'cropCategoryCode': instance.cropCategoryCode,
  'seedGenerationCode': instance.seedGenerationCode,
  'fieldStatusCode': instance.fieldStatusCode,
  'cropYear': instance.cropYear,
  'seasonCode': instance.seasonCode,
  'siteId': instance.siteId,
  'siteName': instance.siteName,
  'status': instance.status,
  'notes': instance.notes,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};

_LotSummary _$LotSummaryFromJson(Map<String, dynamic> json) => _LotSummary(
  id: json['id'] as String,
  lotCode: json['lotCode'] as String,
  canonicalLotCode: json['canonicalLotCode'] as String,
  productName: json['productName'] as String?,
  sku: json['sku'] as String?,
  stageCode: json['stageCode'] as String?,
  cropCategoryCode: json['cropCategoryCode'] as String?,
  status: json['status'] as String,
  siteName: json['siteName'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$LotSummaryToJson(_LotSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lotCode': instance.lotCode,
      'canonicalLotCode': instance.canonicalLotCode,
      'productName': instance.productName,
      'sku': instance.sku,
      'stageCode': instance.stageCode,
      'cropCategoryCode': instance.cropCategoryCode,
      'status': instance.status,
      'siteName': instance.siteName,
      'createdAt': instance.createdAt.toIso8601String(),
    };
