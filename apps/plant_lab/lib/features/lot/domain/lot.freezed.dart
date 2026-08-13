// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Lot {

 String get id; String get lotCode; String get canonicalLotCode; BigInt get companyId; BigInt get productId; String? get productName; String? get sku; String? get stageCode; String? get cropCategoryCode; String? get seedGenerationCode; String? get fieldStatusCode; int? get cropYear; String? get seasonCode; String? get siteId; String? get siteName; String get status; String? get notes; DateTime get createdAt; DateTime? get updatedAt;
/// Create a copy of Lot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LotCopyWith<Lot> get copyWith => _$LotCopyWithImpl<Lot>(this as Lot, _$identity);

  /// Serializes this Lot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Lot&&(identical(other.id, id) || other.id == id)&&(identical(other.lotCode, lotCode) || other.lotCode == lotCode)&&(identical(other.canonicalLotCode, canonicalLotCode) || other.canonicalLotCode == canonicalLotCode)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.stageCode, stageCode) || other.stageCode == stageCode)&&(identical(other.cropCategoryCode, cropCategoryCode) || other.cropCategoryCode == cropCategoryCode)&&(identical(other.seedGenerationCode, seedGenerationCode) || other.seedGenerationCode == seedGenerationCode)&&(identical(other.fieldStatusCode, fieldStatusCode) || other.fieldStatusCode == fieldStatusCode)&&(identical(other.cropYear, cropYear) || other.cropYear == cropYear)&&(identical(other.seasonCode, seasonCode) || other.seasonCode == seasonCode)&&(identical(other.siteId, siteId) || other.siteId == siteId)&&(identical(other.siteName, siteName) || other.siteName == siteName)&&(identical(other.status, status) || other.status == status)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,lotCode,canonicalLotCode,companyId,productId,productName,sku,stageCode,cropCategoryCode,seedGenerationCode,fieldStatusCode,cropYear,seasonCode,siteId,siteName,status,notes,createdAt,updatedAt]);

@override
String toString() {
  return 'Lot(id: $id, lotCode: $lotCode, canonicalLotCode: $canonicalLotCode, companyId: $companyId, productId: $productId, productName: $productName, sku: $sku, stageCode: $stageCode, cropCategoryCode: $cropCategoryCode, seedGenerationCode: $seedGenerationCode, fieldStatusCode: $fieldStatusCode, cropYear: $cropYear, seasonCode: $seasonCode, siteId: $siteId, siteName: $siteName, status: $status, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $LotCopyWith<$Res>  {
  factory $LotCopyWith(Lot value, $Res Function(Lot) _then) = _$LotCopyWithImpl;
@useResult
$Res call({
 String id, String lotCode, String canonicalLotCode, BigInt companyId, BigInt productId, String? productName, String? sku, String? stageCode, String? cropCategoryCode, String? seedGenerationCode, String? fieldStatusCode, int? cropYear, String? seasonCode, String? siteId, String? siteName, String status, String? notes, DateTime createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$LotCopyWithImpl<$Res>
    implements $LotCopyWith<$Res> {
  _$LotCopyWithImpl(this._self, this._then);

  final Lot _self;
  final $Res Function(Lot) _then;

/// Create a copy of Lot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? lotCode = null,Object? canonicalLotCode = null,Object? companyId = null,Object? productId = null,Object? productName = freezed,Object? sku = freezed,Object? stageCode = freezed,Object? cropCategoryCode = freezed,Object? seedGenerationCode = freezed,Object? fieldStatusCode = freezed,Object? cropYear = freezed,Object? seasonCode = freezed,Object? siteId = freezed,Object? siteName = freezed,Object? status = null,Object? notes = freezed,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,lotCode: null == lotCode ? _self.lotCode : lotCode // ignore: cast_nullable_to_non_nullable
as String,canonicalLotCode: null == canonicalLotCode ? _self.canonicalLotCode : canonicalLotCode // ignore: cast_nullable_to_non_nullable
as String,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as BigInt,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as BigInt,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,stageCode: freezed == stageCode ? _self.stageCode : stageCode // ignore: cast_nullable_to_non_nullable
as String?,cropCategoryCode: freezed == cropCategoryCode ? _self.cropCategoryCode : cropCategoryCode // ignore: cast_nullable_to_non_nullable
as String?,seedGenerationCode: freezed == seedGenerationCode ? _self.seedGenerationCode : seedGenerationCode // ignore: cast_nullable_to_non_nullable
as String?,fieldStatusCode: freezed == fieldStatusCode ? _self.fieldStatusCode : fieldStatusCode // ignore: cast_nullable_to_non_nullable
as String?,cropYear: freezed == cropYear ? _self.cropYear : cropYear // ignore: cast_nullable_to_non_nullable
as int?,seasonCode: freezed == seasonCode ? _self.seasonCode : seasonCode // ignore: cast_nullable_to_non_nullable
as String?,siteId: freezed == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as String?,siteName: freezed == siteName ? _self.siteName : siteName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Lot].
extension LotPatterns on Lot {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Lot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Lot() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Lot value)  $default,){
final _that = this;
switch (_that) {
case _Lot():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Lot value)?  $default,){
final _that = this;
switch (_that) {
case _Lot() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String lotCode,  String canonicalLotCode,  BigInt companyId,  BigInt productId,  String? productName,  String? sku,  String? stageCode,  String? cropCategoryCode,  String? seedGenerationCode,  String? fieldStatusCode,  int? cropYear,  String? seasonCode,  String? siteId,  String? siteName,  String status,  String? notes,  DateTime createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Lot() when $default != null:
return $default(_that.id,_that.lotCode,_that.canonicalLotCode,_that.companyId,_that.productId,_that.productName,_that.sku,_that.stageCode,_that.cropCategoryCode,_that.seedGenerationCode,_that.fieldStatusCode,_that.cropYear,_that.seasonCode,_that.siteId,_that.siteName,_that.status,_that.notes,_that.createdAt,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String lotCode,  String canonicalLotCode,  BigInt companyId,  BigInt productId,  String? productName,  String? sku,  String? stageCode,  String? cropCategoryCode,  String? seedGenerationCode,  String? fieldStatusCode,  int? cropYear,  String? seasonCode,  String? siteId,  String? siteName,  String status,  String? notes,  DateTime createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Lot():
return $default(_that.id,_that.lotCode,_that.canonicalLotCode,_that.companyId,_that.productId,_that.productName,_that.sku,_that.stageCode,_that.cropCategoryCode,_that.seedGenerationCode,_that.fieldStatusCode,_that.cropYear,_that.seasonCode,_that.siteId,_that.siteName,_that.status,_that.notes,_that.createdAt,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String lotCode,  String canonicalLotCode,  BigInt companyId,  BigInt productId,  String? productName,  String? sku,  String? stageCode,  String? cropCategoryCode,  String? seedGenerationCode,  String? fieldStatusCode,  int? cropYear,  String? seasonCode,  String? siteId,  String? siteName,  String status,  String? notes,  DateTime createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Lot() when $default != null:
return $default(_that.id,_that.lotCode,_that.canonicalLotCode,_that.companyId,_that.productId,_that.productName,_that.sku,_that.stageCode,_that.cropCategoryCode,_that.seedGenerationCode,_that.fieldStatusCode,_that.cropYear,_that.seasonCode,_that.siteId,_that.siteName,_that.status,_that.notes,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Lot implements Lot {
  const _Lot({required this.id, required this.lotCode, required this.canonicalLotCode, required this.companyId, required this.productId, this.productName, this.sku, this.stageCode, this.cropCategoryCode, this.seedGenerationCode, this.fieldStatusCode, this.cropYear, this.seasonCode, this.siteId, this.siteName, required this.status, this.notes, required this.createdAt, this.updatedAt});
  factory _Lot.fromJson(Map<String, dynamic> json) => _$LotFromJson(json);

@override final  String id;
@override final  String lotCode;
@override final  String canonicalLotCode;
@override final  BigInt companyId;
@override final  BigInt productId;
@override final  String? productName;
@override final  String? sku;
@override final  String? stageCode;
@override final  String? cropCategoryCode;
@override final  String? seedGenerationCode;
@override final  String? fieldStatusCode;
@override final  int? cropYear;
@override final  String? seasonCode;
@override final  String? siteId;
@override final  String? siteName;
@override final  String status;
@override final  String? notes;
@override final  DateTime createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of Lot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LotCopyWith<_Lot> get copyWith => __$LotCopyWithImpl<_Lot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Lot&&(identical(other.id, id) || other.id == id)&&(identical(other.lotCode, lotCode) || other.lotCode == lotCode)&&(identical(other.canonicalLotCode, canonicalLotCode) || other.canonicalLotCode == canonicalLotCode)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.stageCode, stageCode) || other.stageCode == stageCode)&&(identical(other.cropCategoryCode, cropCategoryCode) || other.cropCategoryCode == cropCategoryCode)&&(identical(other.seedGenerationCode, seedGenerationCode) || other.seedGenerationCode == seedGenerationCode)&&(identical(other.fieldStatusCode, fieldStatusCode) || other.fieldStatusCode == fieldStatusCode)&&(identical(other.cropYear, cropYear) || other.cropYear == cropYear)&&(identical(other.seasonCode, seasonCode) || other.seasonCode == seasonCode)&&(identical(other.siteId, siteId) || other.siteId == siteId)&&(identical(other.siteName, siteName) || other.siteName == siteName)&&(identical(other.status, status) || other.status == status)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,lotCode,canonicalLotCode,companyId,productId,productName,sku,stageCode,cropCategoryCode,seedGenerationCode,fieldStatusCode,cropYear,seasonCode,siteId,siteName,status,notes,createdAt,updatedAt]);

@override
String toString() {
  return 'Lot(id: $id, lotCode: $lotCode, canonicalLotCode: $canonicalLotCode, companyId: $companyId, productId: $productId, productName: $productName, sku: $sku, stageCode: $stageCode, cropCategoryCode: $cropCategoryCode, seedGenerationCode: $seedGenerationCode, fieldStatusCode: $fieldStatusCode, cropYear: $cropYear, seasonCode: $seasonCode, siteId: $siteId, siteName: $siteName, status: $status, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$LotCopyWith<$Res> implements $LotCopyWith<$Res> {
  factory _$LotCopyWith(_Lot value, $Res Function(_Lot) _then) = __$LotCopyWithImpl;
@override @useResult
$Res call({
 String id, String lotCode, String canonicalLotCode, BigInt companyId, BigInt productId, String? productName, String? sku, String? stageCode, String? cropCategoryCode, String? seedGenerationCode, String? fieldStatusCode, int? cropYear, String? seasonCode, String? siteId, String? siteName, String status, String? notes, DateTime createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$LotCopyWithImpl<$Res>
    implements _$LotCopyWith<$Res> {
  __$LotCopyWithImpl(this._self, this._then);

  final _Lot _self;
  final $Res Function(_Lot) _then;

/// Create a copy of Lot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? lotCode = null,Object? canonicalLotCode = null,Object? companyId = null,Object? productId = null,Object? productName = freezed,Object? sku = freezed,Object? stageCode = freezed,Object? cropCategoryCode = freezed,Object? seedGenerationCode = freezed,Object? fieldStatusCode = freezed,Object? cropYear = freezed,Object? seasonCode = freezed,Object? siteId = freezed,Object? siteName = freezed,Object? status = null,Object? notes = freezed,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(_Lot(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,lotCode: null == lotCode ? _self.lotCode : lotCode // ignore: cast_nullable_to_non_nullable
as String,canonicalLotCode: null == canonicalLotCode ? _self.canonicalLotCode : canonicalLotCode // ignore: cast_nullable_to_non_nullable
as String,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as BigInt,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as BigInt,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,stageCode: freezed == stageCode ? _self.stageCode : stageCode // ignore: cast_nullable_to_non_nullable
as String?,cropCategoryCode: freezed == cropCategoryCode ? _self.cropCategoryCode : cropCategoryCode // ignore: cast_nullable_to_non_nullable
as String?,seedGenerationCode: freezed == seedGenerationCode ? _self.seedGenerationCode : seedGenerationCode // ignore: cast_nullable_to_non_nullable
as String?,fieldStatusCode: freezed == fieldStatusCode ? _self.fieldStatusCode : fieldStatusCode // ignore: cast_nullable_to_non_nullable
as String?,cropYear: freezed == cropYear ? _self.cropYear : cropYear // ignore: cast_nullable_to_non_nullable
as int?,seasonCode: freezed == seasonCode ? _self.seasonCode : seasonCode // ignore: cast_nullable_to_non_nullable
as String?,siteId: freezed == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as String?,siteName: freezed == siteName ? _self.siteName : siteName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$LotSummary {

 String get id; String get lotCode; String get canonicalLotCode; String? get productName; String? get sku; String? get stageCode; String? get cropCategoryCode; String get status; String? get siteName; DateTime get createdAt;
/// Create a copy of LotSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LotSummaryCopyWith<LotSummary> get copyWith => _$LotSummaryCopyWithImpl<LotSummary>(this as LotSummary, _$identity);

  /// Serializes this LotSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LotSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.lotCode, lotCode) || other.lotCode == lotCode)&&(identical(other.canonicalLotCode, canonicalLotCode) || other.canonicalLotCode == canonicalLotCode)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.stageCode, stageCode) || other.stageCode == stageCode)&&(identical(other.cropCategoryCode, cropCategoryCode) || other.cropCategoryCode == cropCategoryCode)&&(identical(other.status, status) || other.status == status)&&(identical(other.siteName, siteName) || other.siteName == siteName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,lotCode,canonicalLotCode,productName,sku,stageCode,cropCategoryCode,status,siteName,createdAt);

@override
String toString() {
  return 'LotSummary(id: $id, lotCode: $lotCode, canonicalLotCode: $canonicalLotCode, productName: $productName, sku: $sku, stageCode: $stageCode, cropCategoryCode: $cropCategoryCode, status: $status, siteName: $siteName, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $LotSummaryCopyWith<$Res>  {
  factory $LotSummaryCopyWith(LotSummary value, $Res Function(LotSummary) _then) = _$LotSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String lotCode, String canonicalLotCode, String? productName, String? sku, String? stageCode, String? cropCategoryCode, String status, String? siteName, DateTime createdAt
});




}
/// @nodoc
class _$LotSummaryCopyWithImpl<$Res>
    implements $LotSummaryCopyWith<$Res> {
  _$LotSummaryCopyWithImpl(this._self, this._then);

  final LotSummary _self;
  final $Res Function(LotSummary) _then;

/// Create a copy of LotSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? lotCode = null,Object? canonicalLotCode = null,Object? productName = freezed,Object? sku = freezed,Object? stageCode = freezed,Object? cropCategoryCode = freezed,Object? status = null,Object? siteName = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,lotCode: null == lotCode ? _self.lotCode : lotCode // ignore: cast_nullable_to_non_nullable
as String,canonicalLotCode: null == canonicalLotCode ? _self.canonicalLotCode : canonicalLotCode // ignore: cast_nullable_to_non_nullable
as String,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,stageCode: freezed == stageCode ? _self.stageCode : stageCode // ignore: cast_nullable_to_non_nullable
as String?,cropCategoryCode: freezed == cropCategoryCode ? _self.cropCategoryCode : cropCategoryCode // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,siteName: freezed == siteName ? _self.siteName : siteName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [LotSummary].
extension LotSummaryPatterns on LotSummary {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LotSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LotSummary() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LotSummary value)  $default,){
final _that = this;
switch (_that) {
case _LotSummary():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LotSummary value)?  $default,){
final _that = this;
switch (_that) {
case _LotSummary() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String lotCode,  String canonicalLotCode,  String? productName,  String? sku,  String? stageCode,  String? cropCategoryCode,  String status,  String? siteName,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LotSummary() when $default != null:
return $default(_that.id,_that.lotCode,_that.canonicalLotCode,_that.productName,_that.sku,_that.stageCode,_that.cropCategoryCode,_that.status,_that.siteName,_that.createdAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String lotCode,  String canonicalLotCode,  String? productName,  String? sku,  String? stageCode,  String? cropCategoryCode,  String status,  String? siteName,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _LotSummary():
return $default(_that.id,_that.lotCode,_that.canonicalLotCode,_that.productName,_that.sku,_that.stageCode,_that.cropCategoryCode,_that.status,_that.siteName,_that.createdAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String lotCode,  String canonicalLotCode,  String? productName,  String? sku,  String? stageCode,  String? cropCategoryCode,  String status,  String? siteName,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _LotSummary() when $default != null:
return $default(_that.id,_that.lotCode,_that.canonicalLotCode,_that.productName,_that.sku,_that.stageCode,_that.cropCategoryCode,_that.status,_that.siteName,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LotSummary implements LotSummary {
  const _LotSummary({required this.id, required this.lotCode, required this.canonicalLotCode, this.productName, this.sku, this.stageCode, this.cropCategoryCode, required this.status, this.siteName, required this.createdAt});
  factory _LotSummary.fromJson(Map<String, dynamic> json) => _$LotSummaryFromJson(json);

@override final  String id;
@override final  String lotCode;
@override final  String canonicalLotCode;
@override final  String? productName;
@override final  String? sku;
@override final  String? stageCode;
@override final  String? cropCategoryCode;
@override final  String status;
@override final  String? siteName;
@override final  DateTime createdAt;

/// Create a copy of LotSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LotSummaryCopyWith<_LotSummary> get copyWith => __$LotSummaryCopyWithImpl<_LotSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LotSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LotSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.lotCode, lotCode) || other.lotCode == lotCode)&&(identical(other.canonicalLotCode, canonicalLotCode) || other.canonicalLotCode == canonicalLotCode)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.sku, sku) || other.sku == sku)&&(identical(other.stageCode, stageCode) || other.stageCode == stageCode)&&(identical(other.cropCategoryCode, cropCategoryCode) || other.cropCategoryCode == cropCategoryCode)&&(identical(other.status, status) || other.status == status)&&(identical(other.siteName, siteName) || other.siteName == siteName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,lotCode,canonicalLotCode,productName,sku,stageCode,cropCategoryCode,status,siteName,createdAt);

@override
String toString() {
  return 'LotSummary(id: $id, lotCode: $lotCode, canonicalLotCode: $canonicalLotCode, productName: $productName, sku: $sku, stageCode: $stageCode, cropCategoryCode: $cropCategoryCode, status: $status, siteName: $siteName, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LotSummaryCopyWith<$Res> implements $LotSummaryCopyWith<$Res> {
  factory _$LotSummaryCopyWith(_LotSummary value, $Res Function(_LotSummary) _then) = __$LotSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String lotCode, String canonicalLotCode, String? productName, String? sku, String? stageCode, String? cropCategoryCode, String status, String? siteName, DateTime createdAt
});




}
/// @nodoc
class __$LotSummaryCopyWithImpl<$Res>
    implements _$LotSummaryCopyWith<$Res> {
  __$LotSummaryCopyWithImpl(this._self, this._then);

  final _LotSummary _self;
  final $Res Function(_LotSummary) _then;

/// Create a copy of LotSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? lotCode = null,Object? canonicalLotCode = null,Object? productName = freezed,Object? sku = freezed,Object? stageCode = freezed,Object? cropCategoryCode = freezed,Object? status = null,Object? siteName = freezed,Object? createdAt = null,}) {
  return _then(_LotSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,lotCode: null == lotCode ? _self.lotCode : lotCode // ignore: cast_nullable_to_non_nullable
as String,canonicalLotCode: null == canonicalLotCode ? _self.canonicalLotCode : canonicalLotCode // ignore: cast_nullable_to_non_nullable
as String,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,sku: freezed == sku ? _self.sku : sku // ignore: cast_nullable_to_non_nullable
as String?,stageCode: freezed == stageCode ? _self.stageCode : stageCode // ignore: cast_nullable_to_non_nullable
as String?,cropCategoryCode: freezed == cropCategoryCode ? _self.cropCategoryCode : cropCategoryCode // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,siteName: freezed == siteName ? _self.siteName : siteName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
