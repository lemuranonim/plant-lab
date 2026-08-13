import 'package:freezed_annotation/freezed_annotation.dart';

part 'lot.freezed.dart';
part 'lot.g.dart';

@freezed
abstract class Lot with _$Lot {
  const factory Lot({
    required String id,
    required String lotCode,
    required String canonicalLotCode,
    required BigInt companyId,
    required BigInt productId,
    String? productName,
    String? sku,
    String? stageCode,
    String? cropCategoryCode,
    String? seedGenerationCode,
    String? fieldStatusCode,
    int? cropYear,
    String? seasonCode,
    String? siteId,
    String? siteName,
    required String status,
    String? notes,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Lot;

  factory Lot.fromJson(Map<String, dynamic> json) => _$LotFromJson(json);
}

@freezed
abstract class LotSummary with _$LotSummary {
  const factory LotSummary({
    required String id,
    required String lotCode,
    required String canonicalLotCode,
    String? productName,
    String? sku,
    String? stageCode,
    String? cropCategoryCode,
    required String status,
    String? siteName,
    required DateTime createdAt,
  }) = _LotSummary;

  factory LotSummary.fromJson(Map<String, dynamic> json) =>
      _$LotSummaryFromJson(json);
}

enum LotStage {
  harvest('HARVEST', 'Panen'),
  dss('DSS', 'DSS'),
  dcs('DCS', 'DCS'),
  fg('FG', 'Final Good'),
  unknown('UNKNOWN', 'Tidak Diketahui');

  final String code;
  final String label;
  const LotStage(this.code, this.label);

  static LotStage fromCode(String? code) {
    return LotStage.values.firstWhere(
      (s) => s.code == code?.toUpperCase(),
      orElse: () => LotStage.unknown,
    );
  }
}

enum CropCategory {
  fc('FC', 'Field Corn'),
  swc('SWC', 'Sweet Corn'),
  ps('PS', 'Parent Seed'),
  vege('VEGE', 'Vegetables'),
  unknown('UNKNOWN', 'Tidak Diketahui');

  final String code;
  final String label;
  const CropCategory(this.code, this.label);

  static CropCategory fromCode(String? code) {
    return CropCategory.values.firstWhere(
      (c) => c.code == code?.toUpperCase(),
      orElse: () => CropCategory.unknown,
    );
  }
}
