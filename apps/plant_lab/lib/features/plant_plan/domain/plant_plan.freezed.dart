// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plant_plan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlantPlan {

 String get id; String get planCode; String get lotId; String? get lotCode; String? get productName; BigInt get siteId; String? get siteName; BigInt get companyId; String get processTypeId; String? get processTypeName; String get status; int get totalSteps; int get completedSteps; String? get currentStepName; String? get notes; String get createdBy; DateTime get createdAt; DateTime? get updatedAt; DateTime? get completedAt;
/// Create a copy of PlantPlan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlantPlanCopyWith<PlantPlan> get copyWith => _$PlantPlanCopyWithImpl<PlantPlan>(this as PlantPlan, _$identity);

  /// Serializes this PlantPlan to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlantPlan&&(identical(other.id, id) || other.id == id)&&(identical(other.planCode, planCode) || other.planCode == planCode)&&(identical(other.lotId, lotId) || other.lotId == lotId)&&(identical(other.lotCode, lotCode) || other.lotCode == lotCode)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.siteId, siteId) || other.siteId == siteId)&&(identical(other.siteName, siteName) || other.siteName == siteName)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.processTypeId, processTypeId) || other.processTypeId == processTypeId)&&(identical(other.processTypeName, processTypeName) || other.processTypeName == processTypeName)&&(identical(other.status, status) || other.status == status)&&(identical(other.totalSteps, totalSteps) || other.totalSteps == totalSteps)&&(identical(other.completedSteps, completedSteps) || other.completedSteps == completedSteps)&&(identical(other.currentStepName, currentStepName) || other.currentStepName == currentStepName)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,planCode,lotId,lotCode,productName,siteId,siteName,companyId,processTypeId,processTypeName,status,totalSteps,completedSteps,currentStepName,notes,createdBy,createdAt,updatedAt,completedAt]);

@override
String toString() {
  return 'PlantPlan(id: $id, planCode: $planCode, lotId: $lotId, lotCode: $lotCode, productName: $productName, siteId: $siteId, siteName: $siteName, companyId: $companyId, processTypeId: $processTypeId, processTypeName: $processTypeName, status: $status, totalSteps: $totalSteps, completedSteps: $completedSteps, currentStepName: $currentStepName, notes: $notes, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class $PlantPlanCopyWith<$Res>  {
  factory $PlantPlanCopyWith(PlantPlan value, $Res Function(PlantPlan) _then) = _$PlantPlanCopyWithImpl;
@useResult
$Res call({
 String id, String planCode, String lotId, String? lotCode, String? productName, BigInt siteId, String? siteName, BigInt companyId, String processTypeId, String? processTypeName, String status, int totalSteps, int completedSteps, String? currentStepName, String? notes, String createdBy, DateTime createdAt, DateTime? updatedAt, DateTime? completedAt
});




}
/// @nodoc
class _$PlantPlanCopyWithImpl<$Res>
    implements $PlantPlanCopyWith<$Res> {
  _$PlantPlanCopyWithImpl(this._self, this._then);

  final PlantPlan _self;
  final $Res Function(PlantPlan) _then;

/// Create a copy of PlantPlan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? planCode = null,Object? lotId = null,Object? lotCode = freezed,Object? productName = freezed,Object? siteId = null,Object? siteName = freezed,Object? companyId = null,Object? processTypeId = null,Object? processTypeName = freezed,Object? status = null,Object? totalSteps = null,Object? completedSteps = null,Object? currentStepName = freezed,Object? notes = freezed,Object? createdBy = null,Object? createdAt = null,Object? updatedAt = freezed,Object? completedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,planCode: null == planCode ? _self.planCode : planCode // ignore: cast_nullable_to_non_nullable
as String,lotId: null == lotId ? _self.lotId : lotId // ignore: cast_nullable_to_non_nullable
as String,lotCode: freezed == lotCode ? _self.lotCode : lotCode // ignore: cast_nullable_to_non_nullable
as String?,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,siteId: null == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as BigInt,siteName: freezed == siteName ? _self.siteName : siteName // ignore: cast_nullable_to_non_nullable
as String?,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as BigInt,processTypeId: null == processTypeId ? _self.processTypeId : processTypeId // ignore: cast_nullable_to_non_nullable
as String,processTypeName: freezed == processTypeName ? _self.processTypeName : processTypeName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,totalSteps: null == totalSteps ? _self.totalSteps : totalSteps // ignore: cast_nullable_to_non_nullable
as int,completedSteps: null == completedSteps ? _self.completedSteps : completedSteps // ignore: cast_nullable_to_non_nullable
as int,currentStepName: freezed == currentStepName ? _self.currentStepName : currentStepName // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlantPlan].
extension PlantPlanPatterns on PlantPlan {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlantPlan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlantPlan() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlantPlan value)  $default,){
final _that = this;
switch (_that) {
case _PlantPlan():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlantPlan value)?  $default,){
final _that = this;
switch (_that) {
case _PlantPlan() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String planCode,  String lotId,  String? lotCode,  String? productName,  BigInt siteId,  String? siteName,  BigInt companyId,  String processTypeId,  String? processTypeName,  String status,  int totalSteps,  int completedSteps,  String? currentStepName,  String? notes,  String createdBy,  DateTime createdAt,  DateTime? updatedAt,  DateTime? completedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlantPlan() when $default != null:
return $default(_that.id,_that.planCode,_that.lotId,_that.lotCode,_that.productName,_that.siteId,_that.siteName,_that.companyId,_that.processTypeId,_that.processTypeName,_that.status,_that.totalSteps,_that.completedSteps,_that.currentStepName,_that.notes,_that.createdBy,_that.createdAt,_that.updatedAt,_that.completedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String planCode,  String lotId,  String? lotCode,  String? productName,  BigInt siteId,  String? siteName,  BigInt companyId,  String processTypeId,  String? processTypeName,  String status,  int totalSteps,  int completedSteps,  String? currentStepName,  String? notes,  String createdBy,  DateTime createdAt,  DateTime? updatedAt,  DateTime? completedAt)  $default,) {final _that = this;
switch (_that) {
case _PlantPlan():
return $default(_that.id,_that.planCode,_that.lotId,_that.lotCode,_that.productName,_that.siteId,_that.siteName,_that.companyId,_that.processTypeId,_that.processTypeName,_that.status,_that.totalSteps,_that.completedSteps,_that.currentStepName,_that.notes,_that.createdBy,_that.createdAt,_that.updatedAt,_that.completedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String planCode,  String lotId,  String? lotCode,  String? productName,  BigInt siteId,  String? siteName,  BigInt companyId,  String processTypeId,  String? processTypeName,  String status,  int totalSteps,  int completedSteps,  String? currentStepName,  String? notes,  String createdBy,  DateTime createdAt,  DateTime? updatedAt,  DateTime? completedAt)?  $default,) {final _that = this;
switch (_that) {
case _PlantPlan() when $default != null:
return $default(_that.id,_that.planCode,_that.lotId,_that.lotCode,_that.productName,_that.siteId,_that.siteName,_that.companyId,_that.processTypeId,_that.processTypeName,_that.status,_that.totalSteps,_that.completedSteps,_that.currentStepName,_that.notes,_that.createdBy,_that.createdAt,_that.updatedAt,_that.completedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlantPlan implements PlantPlan {
  const _PlantPlan({required this.id, required this.planCode, required this.lotId, this.lotCode, this.productName, required this.siteId, this.siteName, required this.companyId, required this.processTypeId, this.processTypeName, required this.status, required this.totalSteps, required this.completedSteps, this.currentStepName, this.notes, required this.createdBy, required this.createdAt, this.updatedAt, this.completedAt});
  factory _PlantPlan.fromJson(Map<String, dynamic> json) => _$PlantPlanFromJson(json);

@override final  String id;
@override final  String planCode;
@override final  String lotId;
@override final  String? lotCode;
@override final  String? productName;
@override final  BigInt siteId;
@override final  String? siteName;
@override final  BigInt companyId;
@override final  String processTypeId;
@override final  String? processTypeName;
@override final  String status;
@override final  int totalSteps;
@override final  int completedSteps;
@override final  String? currentStepName;
@override final  String? notes;
@override final  String createdBy;
@override final  DateTime createdAt;
@override final  DateTime? updatedAt;
@override final  DateTime? completedAt;

/// Create a copy of PlantPlan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlantPlanCopyWith<_PlantPlan> get copyWith => __$PlantPlanCopyWithImpl<_PlantPlan>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlantPlanToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlantPlan&&(identical(other.id, id) || other.id == id)&&(identical(other.planCode, planCode) || other.planCode == planCode)&&(identical(other.lotId, lotId) || other.lotId == lotId)&&(identical(other.lotCode, lotCode) || other.lotCode == lotCode)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.siteId, siteId) || other.siteId == siteId)&&(identical(other.siteName, siteName) || other.siteName == siteName)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.processTypeId, processTypeId) || other.processTypeId == processTypeId)&&(identical(other.processTypeName, processTypeName) || other.processTypeName == processTypeName)&&(identical(other.status, status) || other.status == status)&&(identical(other.totalSteps, totalSteps) || other.totalSteps == totalSteps)&&(identical(other.completedSteps, completedSteps) || other.completedSteps == completedSteps)&&(identical(other.currentStepName, currentStepName) || other.currentStepName == currentStepName)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,planCode,lotId,lotCode,productName,siteId,siteName,companyId,processTypeId,processTypeName,status,totalSteps,completedSteps,currentStepName,notes,createdBy,createdAt,updatedAt,completedAt]);

@override
String toString() {
  return 'PlantPlan(id: $id, planCode: $planCode, lotId: $lotId, lotCode: $lotCode, productName: $productName, siteId: $siteId, siteName: $siteName, companyId: $companyId, processTypeId: $processTypeId, processTypeName: $processTypeName, status: $status, totalSteps: $totalSteps, completedSteps: $completedSteps, currentStepName: $currentStepName, notes: $notes, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt, completedAt: $completedAt)';
}


}

/// @nodoc
abstract mixin class _$PlantPlanCopyWith<$Res> implements $PlantPlanCopyWith<$Res> {
  factory _$PlantPlanCopyWith(_PlantPlan value, $Res Function(_PlantPlan) _then) = __$PlantPlanCopyWithImpl;
@override @useResult
$Res call({
 String id, String planCode, String lotId, String? lotCode, String? productName, BigInt siteId, String? siteName, BigInt companyId, String processTypeId, String? processTypeName, String status, int totalSteps, int completedSteps, String? currentStepName, String? notes, String createdBy, DateTime createdAt, DateTime? updatedAt, DateTime? completedAt
});




}
/// @nodoc
class __$PlantPlanCopyWithImpl<$Res>
    implements _$PlantPlanCopyWith<$Res> {
  __$PlantPlanCopyWithImpl(this._self, this._then);

  final _PlantPlan _self;
  final $Res Function(_PlantPlan) _then;

/// Create a copy of PlantPlan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? planCode = null,Object? lotId = null,Object? lotCode = freezed,Object? productName = freezed,Object? siteId = null,Object? siteName = freezed,Object? companyId = null,Object? processTypeId = null,Object? processTypeName = freezed,Object? status = null,Object? totalSteps = null,Object? completedSteps = null,Object? currentStepName = freezed,Object? notes = freezed,Object? createdBy = null,Object? createdAt = null,Object? updatedAt = freezed,Object? completedAt = freezed,}) {
  return _then(_PlantPlan(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,planCode: null == planCode ? _self.planCode : planCode // ignore: cast_nullable_to_non_nullable
as String,lotId: null == lotId ? _self.lotId : lotId // ignore: cast_nullable_to_non_nullable
as String,lotCode: freezed == lotCode ? _self.lotCode : lotCode // ignore: cast_nullable_to_non_nullable
as String?,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,siteId: null == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as BigInt,siteName: freezed == siteName ? _self.siteName : siteName // ignore: cast_nullable_to_non_nullable
as String?,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as BigInt,processTypeId: null == processTypeId ? _self.processTypeId : processTypeId // ignore: cast_nullable_to_non_nullable
as String,processTypeName: freezed == processTypeName ? _self.processTypeName : processTypeName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,totalSteps: null == totalSteps ? _self.totalSteps : totalSteps // ignore: cast_nullable_to_non_nullable
as int,completedSteps: null == completedSteps ? _self.completedSteps : completedSteps // ignore: cast_nullable_to_non_nullable
as int,currentStepName: freezed == currentStepName ? _self.currentStepName : currentStepName // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$PlantPlanSummary {

 String get id; String get planCode; String get lotId; String? get lotCode; String? get productName; String? get siteName; String get status; int get totalSteps; int get completedSteps; String? get currentStepName; DateTime get createdAt;
/// Create a copy of PlantPlanSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlantPlanSummaryCopyWith<PlantPlanSummary> get copyWith => _$PlantPlanSummaryCopyWithImpl<PlantPlanSummary>(this as PlantPlanSummary, _$identity);

  /// Serializes this PlantPlanSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlantPlanSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.planCode, planCode) || other.planCode == planCode)&&(identical(other.lotId, lotId) || other.lotId == lotId)&&(identical(other.lotCode, lotCode) || other.lotCode == lotCode)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.siteName, siteName) || other.siteName == siteName)&&(identical(other.status, status) || other.status == status)&&(identical(other.totalSteps, totalSteps) || other.totalSteps == totalSteps)&&(identical(other.completedSteps, completedSteps) || other.completedSteps == completedSteps)&&(identical(other.currentStepName, currentStepName) || other.currentStepName == currentStepName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,planCode,lotId,lotCode,productName,siteName,status,totalSteps,completedSteps,currentStepName,createdAt);

@override
String toString() {
  return 'PlantPlanSummary(id: $id, planCode: $planCode, lotId: $lotId, lotCode: $lotCode, productName: $productName, siteName: $siteName, status: $status, totalSteps: $totalSteps, completedSteps: $completedSteps, currentStepName: $currentStepName, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $PlantPlanSummaryCopyWith<$Res>  {
  factory $PlantPlanSummaryCopyWith(PlantPlanSummary value, $Res Function(PlantPlanSummary) _then) = _$PlantPlanSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String planCode, String lotId, String? lotCode, String? productName, String? siteName, String status, int totalSteps, int completedSteps, String? currentStepName, DateTime createdAt
});




}
/// @nodoc
class _$PlantPlanSummaryCopyWithImpl<$Res>
    implements $PlantPlanSummaryCopyWith<$Res> {
  _$PlantPlanSummaryCopyWithImpl(this._self, this._then);

  final PlantPlanSummary _self;
  final $Res Function(PlantPlanSummary) _then;

/// Create a copy of PlantPlanSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? planCode = null,Object? lotId = null,Object? lotCode = freezed,Object? productName = freezed,Object? siteName = freezed,Object? status = null,Object? totalSteps = null,Object? completedSteps = null,Object? currentStepName = freezed,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,planCode: null == planCode ? _self.planCode : planCode // ignore: cast_nullable_to_non_nullable
as String,lotId: null == lotId ? _self.lotId : lotId // ignore: cast_nullable_to_non_nullable
as String,lotCode: freezed == lotCode ? _self.lotCode : lotCode // ignore: cast_nullable_to_non_nullable
as String?,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,siteName: freezed == siteName ? _self.siteName : siteName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,totalSteps: null == totalSteps ? _self.totalSteps : totalSteps // ignore: cast_nullable_to_non_nullable
as int,completedSteps: null == completedSteps ? _self.completedSteps : completedSteps // ignore: cast_nullable_to_non_nullable
as int,currentStepName: freezed == currentStepName ? _self.currentStepName : currentStepName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [PlantPlanSummary].
extension PlantPlanSummaryPatterns on PlantPlanSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlantPlanSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlantPlanSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlantPlanSummary value)  $default,){
final _that = this;
switch (_that) {
case _PlantPlanSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlantPlanSummary value)?  $default,){
final _that = this;
switch (_that) {
case _PlantPlanSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String planCode,  String lotId,  String? lotCode,  String? productName,  String? siteName,  String status,  int totalSteps,  int completedSteps,  String? currentStepName,  DateTime createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlantPlanSummary() when $default != null:
return $default(_that.id,_that.planCode,_that.lotId,_that.lotCode,_that.productName,_that.siteName,_that.status,_that.totalSteps,_that.completedSteps,_that.currentStepName,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String planCode,  String lotId,  String? lotCode,  String? productName,  String? siteName,  String status,  int totalSteps,  int completedSteps,  String? currentStepName,  DateTime createdAt)  $default,) {final _that = this;
switch (_that) {
case _PlantPlanSummary():
return $default(_that.id,_that.planCode,_that.lotId,_that.lotCode,_that.productName,_that.siteName,_that.status,_that.totalSteps,_that.completedSteps,_that.currentStepName,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String planCode,  String lotId,  String? lotCode,  String? productName,  String? siteName,  String status,  int totalSteps,  int completedSteps,  String? currentStepName,  DateTime createdAt)?  $default,) {final _that = this;
switch (_that) {
case _PlantPlanSummary() when $default != null:
return $default(_that.id,_that.planCode,_that.lotId,_that.lotCode,_that.productName,_that.siteName,_that.status,_that.totalSteps,_that.completedSteps,_that.currentStepName,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlantPlanSummary implements PlantPlanSummary {
  const _PlantPlanSummary({required this.id, required this.planCode, required this.lotId, this.lotCode, this.productName, this.siteName, required this.status, required this.totalSteps, required this.completedSteps, this.currentStepName, required this.createdAt});
  factory _PlantPlanSummary.fromJson(Map<String, dynamic> json) => _$PlantPlanSummaryFromJson(json);

@override final  String id;
@override final  String planCode;
@override final  String lotId;
@override final  String? lotCode;
@override final  String? productName;
@override final  String? siteName;
@override final  String status;
@override final  int totalSteps;
@override final  int completedSteps;
@override final  String? currentStepName;
@override final  DateTime createdAt;

/// Create a copy of PlantPlanSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlantPlanSummaryCopyWith<_PlantPlanSummary> get copyWith => __$PlantPlanSummaryCopyWithImpl<_PlantPlanSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlantPlanSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlantPlanSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.planCode, planCode) || other.planCode == planCode)&&(identical(other.lotId, lotId) || other.lotId == lotId)&&(identical(other.lotCode, lotCode) || other.lotCode == lotCode)&&(identical(other.productName, productName) || other.productName == productName)&&(identical(other.siteName, siteName) || other.siteName == siteName)&&(identical(other.status, status) || other.status == status)&&(identical(other.totalSteps, totalSteps) || other.totalSteps == totalSteps)&&(identical(other.completedSteps, completedSteps) || other.completedSteps == completedSteps)&&(identical(other.currentStepName, currentStepName) || other.currentStepName == currentStepName)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,planCode,lotId,lotCode,productName,siteName,status,totalSteps,completedSteps,currentStepName,createdAt);

@override
String toString() {
  return 'PlantPlanSummary(id: $id, planCode: $planCode, lotId: $lotId, lotCode: $lotCode, productName: $productName, siteName: $siteName, status: $status, totalSteps: $totalSteps, completedSteps: $completedSteps, currentStepName: $currentStepName, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$PlantPlanSummaryCopyWith<$Res> implements $PlantPlanSummaryCopyWith<$Res> {
  factory _$PlantPlanSummaryCopyWith(_PlantPlanSummary value, $Res Function(_PlantPlanSummary) _then) = __$PlantPlanSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String planCode, String lotId, String? lotCode, String? productName, String? siteName, String status, int totalSteps, int completedSteps, String? currentStepName, DateTime createdAt
});




}
/// @nodoc
class __$PlantPlanSummaryCopyWithImpl<$Res>
    implements _$PlantPlanSummaryCopyWith<$Res> {
  __$PlantPlanSummaryCopyWithImpl(this._self, this._then);

  final _PlantPlanSummary _self;
  final $Res Function(_PlantPlanSummary) _then;

/// Create a copy of PlantPlanSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? planCode = null,Object? lotId = null,Object? lotCode = freezed,Object? productName = freezed,Object? siteName = freezed,Object? status = null,Object? totalSteps = null,Object? completedSteps = null,Object? currentStepName = freezed,Object? createdAt = null,}) {
  return _then(_PlantPlanSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,planCode: null == planCode ? _self.planCode : planCode // ignore: cast_nullable_to_non_nullable
as String,lotId: null == lotId ? _self.lotId : lotId // ignore: cast_nullable_to_non_nullable
as String,lotCode: freezed == lotCode ? _self.lotCode : lotCode // ignore: cast_nullable_to_non_nullable
as String?,productName: freezed == productName ? _self.productName : productName // ignore: cast_nullable_to_non_nullable
as String?,siteName: freezed == siteName ? _self.siteName : siteName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,totalSteps: null == totalSteps ? _self.totalSteps : totalSteps // ignore: cast_nullable_to_non_nullable
as int,completedSteps: null == completedSteps ? _self.completedSteps : completedSteps // ignore: cast_nullable_to_non_nullable
as int,currentStepName: freezed == currentStepName ? _self.currentStepName : currentStepName // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$PlantProcessStep {

 String get id; String get planId; String get stepCode; String get stepName; int get stepOrder; String get status; String? get formTemplateId; bool get requiresEvidence; int get evidenceCount; DateTime? get startedAt; DateTime? get completedAt; DateTime? get dueAt;
/// Create a copy of PlantProcessStep
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlantProcessStepCopyWith<PlantProcessStep> get copyWith => _$PlantProcessStepCopyWithImpl<PlantProcessStep>(this as PlantProcessStep, _$identity);

  /// Serializes this PlantProcessStep to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlantProcessStep&&(identical(other.id, id) || other.id == id)&&(identical(other.planId, planId) || other.planId == planId)&&(identical(other.stepCode, stepCode) || other.stepCode == stepCode)&&(identical(other.stepName, stepName) || other.stepName == stepName)&&(identical(other.stepOrder, stepOrder) || other.stepOrder == stepOrder)&&(identical(other.status, status) || other.status == status)&&(identical(other.formTemplateId, formTemplateId) || other.formTemplateId == formTemplateId)&&(identical(other.requiresEvidence, requiresEvidence) || other.requiresEvidence == requiresEvidence)&&(identical(other.evidenceCount, evidenceCount) || other.evidenceCount == evidenceCount)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.dueAt, dueAt) || other.dueAt == dueAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,planId,stepCode,stepName,stepOrder,status,formTemplateId,requiresEvidence,evidenceCount,startedAt,completedAt,dueAt);

@override
String toString() {
  return 'PlantProcessStep(id: $id, planId: $planId, stepCode: $stepCode, stepName: $stepName, stepOrder: $stepOrder, status: $status, formTemplateId: $formTemplateId, requiresEvidence: $requiresEvidence, evidenceCount: $evidenceCount, startedAt: $startedAt, completedAt: $completedAt, dueAt: $dueAt)';
}


}

/// @nodoc
abstract mixin class $PlantProcessStepCopyWith<$Res>  {
  factory $PlantProcessStepCopyWith(PlantProcessStep value, $Res Function(PlantProcessStep) _then) = _$PlantProcessStepCopyWithImpl;
@useResult
$Res call({
 String id, String planId, String stepCode, String stepName, int stepOrder, String status, String? formTemplateId, bool requiresEvidence, int evidenceCount, DateTime? startedAt, DateTime? completedAt, DateTime? dueAt
});




}
/// @nodoc
class _$PlantProcessStepCopyWithImpl<$Res>
    implements $PlantProcessStepCopyWith<$Res> {
  _$PlantProcessStepCopyWithImpl(this._self, this._then);

  final PlantProcessStep _self;
  final $Res Function(PlantProcessStep) _then;

/// Create a copy of PlantProcessStep
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? planId = null,Object? stepCode = null,Object? stepName = null,Object? stepOrder = null,Object? status = null,Object? formTemplateId = freezed,Object? requiresEvidence = null,Object? evidenceCount = null,Object? startedAt = freezed,Object? completedAt = freezed,Object? dueAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,planId: null == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String,stepCode: null == stepCode ? _self.stepCode : stepCode // ignore: cast_nullable_to_non_nullable
as String,stepName: null == stepName ? _self.stepName : stepName // ignore: cast_nullable_to_non_nullable
as String,stepOrder: null == stepOrder ? _self.stepOrder : stepOrder // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,formTemplateId: freezed == formTemplateId ? _self.formTemplateId : formTemplateId // ignore: cast_nullable_to_non_nullable
as String?,requiresEvidence: null == requiresEvidence ? _self.requiresEvidence : requiresEvidence // ignore: cast_nullable_to_non_nullable
as bool,evidenceCount: null == evidenceCount ? _self.evidenceCount : evidenceCount // ignore: cast_nullable_to_non_nullable
as int,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,dueAt: freezed == dueAt ? _self.dueAt : dueAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlantProcessStep].
extension PlantProcessStepPatterns on PlantProcessStep {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlantProcessStep value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlantProcessStep() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlantProcessStep value)  $default,){
final _that = this;
switch (_that) {
case _PlantProcessStep():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlantProcessStep value)?  $default,){
final _that = this;
switch (_that) {
case _PlantProcessStep() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String planId,  String stepCode,  String stepName,  int stepOrder,  String status,  String? formTemplateId,  bool requiresEvidence,  int evidenceCount,  DateTime? startedAt,  DateTime? completedAt,  DateTime? dueAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlantProcessStep() when $default != null:
return $default(_that.id,_that.planId,_that.stepCode,_that.stepName,_that.stepOrder,_that.status,_that.formTemplateId,_that.requiresEvidence,_that.evidenceCount,_that.startedAt,_that.completedAt,_that.dueAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String planId,  String stepCode,  String stepName,  int stepOrder,  String status,  String? formTemplateId,  bool requiresEvidence,  int evidenceCount,  DateTime? startedAt,  DateTime? completedAt,  DateTime? dueAt)  $default,) {final _that = this;
switch (_that) {
case _PlantProcessStep():
return $default(_that.id,_that.planId,_that.stepCode,_that.stepName,_that.stepOrder,_that.status,_that.formTemplateId,_that.requiresEvidence,_that.evidenceCount,_that.startedAt,_that.completedAt,_that.dueAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String planId,  String stepCode,  String stepName,  int stepOrder,  String status,  String? formTemplateId,  bool requiresEvidence,  int evidenceCount,  DateTime? startedAt,  DateTime? completedAt,  DateTime? dueAt)?  $default,) {final _that = this;
switch (_that) {
case _PlantProcessStep() when $default != null:
return $default(_that.id,_that.planId,_that.stepCode,_that.stepName,_that.stepOrder,_that.status,_that.formTemplateId,_that.requiresEvidence,_that.evidenceCount,_that.startedAt,_that.completedAt,_that.dueAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlantProcessStep implements PlantProcessStep {
  const _PlantProcessStep({required this.id, required this.planId, required this.stepCode, required this.stepName, required this.stepOrder, required this.status, this.formTemplateId, required this.requiresEvidence, required this.evidenceCount, this.startedAt, this.completedAt, this.dueAt});
  factory _PlantProcessStep.fromJson(Map<String, dynamic> json) => _$PlantProcessStepFromJson(json);

@override final  String id;
@override final  String planId;
@override final  String stepCode;
@override final  String stepName;
@override final  int stepOrder;
@override final  String status;
@override final  String? formTemplateId;
@override final  bool requiresEvidence;
@override final  int evidenceCount;
@override final  DateTime? startedAt;
@override final  DateTime? completedAt;
@override final  DateTime? dueAt;

/// Create a copy of PlantProcessStep
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlantProcessStepCopyWith<_PlantProcessStep> get copyWith => __$PlantProcessStepCopyWithImpl<_PlantProcessStep>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlantProcessStepToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlantProcessStep&&(identical(other.id, id) || other.id == id)&&(identical(other.planId, planId) || other.planId == planId)&&(identical(other.stepCode, stepCode) || other.stepCode == stepCode)&&(identical(other.stepName, stepName) || other.stepName == stepName)&&(identical(other.stepOrder, stepOrder) || other.stepOrder == stepOrder)&&(identical(other.status, status) || other.status == status)&&(identical(other.formTemplateId, formTemplateId) || other.formTemplateId == formTemplateId)&&(identical(other.requiresEvidence, requiresEvidence) || other.requiresEvidence == requiresEvidence)&&(identical(other.evidenceCount, evidenceCount) || other.evidenceCount == evidenceCount)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.dueAt, dueAt) || other.dueAt == dueAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,planId,stepCode,stepName,stepOrder,status,formTemplateId,requiresEvidence,evidenceCount,startedAt,completedAt,dueAt);

@override
String toString() {
  return 'PlantProcessStep(id: $id, planId: $planId, stepCode: $stepCode, stepName: $stepName, stepOrder: $stepOrder, status: $status, formTemplateId: $formTemplateId, requiresEvidence: $requiresEvidence, evidenceCount: $evidenceCount, startedAt: $startedAt, completedAt: $completedAt, dueAt: $dueAt)';
}


}

/// @nodoc
abstract mixin class _$PlantProcessStepCopyWith<$Res> implements $PlantProcessStepCopyWith<$Res> {
  factory _$PlantProcessStepCopyWith(_PlantProcessStep value, $Res Function(_PlantProcessStep) _then) = __$PlantProcessStepCopyWithImpl;
@override @useResult
$Res call({
 String id, String planId, String stepCode, String stepName, int stepOrder, String status, String? formTemplateId, bool requiresEvidence, int evidenceCount, DateTime? startedAt, DateTime? completedAt, DateTime? dueAt
});




}
/// @nodoc
class __$PlantProcessStepCopyWithImpl<$Res>
    implements _$PlantProcessStepCopyWith<$Res> {
  __$PlantProcessStepCopyWithImpl(this._self, this._then);

  final _PlantProcessStep _self;
  final $Res Function(_PlantProcessStep) _then;

/// Create a copy of PlantProcessStep
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? planId = null,Object? stepCode = null,Object? stepName = null,Object? stepOrder = null,Object? status = null,Object? formTemplateId = freezed,Object? requiresEvidence = null,Object? evidenceCount = null,Object? startedAt = freezed,Object? completedAt = freezed,Object? dueAt = freezed,}) {
  return _then(_PlantProcessStep(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,planId: null == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String,stepCode: null == stepCode ? _self.stepCode : stepCode // ignore: cast_nullable_to_non_nullable
as String,stepName: null == stepName ? _self.stepName : stepName // ignore: cast_nullable_to_non_nullable
as String,stepOrder: null == stepOrder ? _self.stepOrder : stepOrder // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,formTemplateId: freezed == formTemplateId ? _self.formTemplateId : formTemplateId // ignore: cast_nullable_to_non_nullable
as String?,requiresEvidence: null == requiresEvidence ? _self.requiresEvidence : requiresEvidence // ignore: cast_nullable_to_non_nullable
as bool,evidenceCount: null == evidenceCount ? _self.evidenceCount : evidenceCount // ignore: cast_nullable_to_non_nullable
as int,startedAt: freezed == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,dueAt: freezed == dueAt ? _self.dueAt : dueAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
