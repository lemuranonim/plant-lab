// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'plant_inspection.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlantInspection {

 String get id; String get inspectionCode; String get planId; String get stepId; String? get lotId; String? get lotCode; String get formTemplateId; String? get formTemplateName; String get formVersion; String get inspectedBy; String? get inspectorName; String get siteId; String? get siteName; String get status;// DRAFT | SUBMITTED | UNDER_REVIEW | APPROVED | NEED_REVISION | OOS | REJECTED
 String? get reviewedBy; String? get reviewerName; DateTime? get reviewedAt; String? get reviewNotes; Map<String, dynamic> get answers;// JSONB answers
 List<PlantEvidence> get evidences; bool? get hasOos; DateTime get inspectedAt; DateTime? get submittedAt; DateTime get createdAt; DateTime? get updatedAt;
/// Create a copy of PlantInspection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlantInspectionCopyWith<PlantInspection> get copyWith => _$PlantInspectionCopyWithImpl<PlantInspection>(this as PlantInspection, _$identity);

  /// Serializes this PlantInspection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlantInspection&&(identical(other.id, id) || other.id == id)&&(identical(other.inspectionCode, inspectionCode) || other.inspectionCode == inspectionCode)&&(identical(other.planId, planId) || other.planId == planId)&&(identical(other.stepId, stepId) || other.stepId == stepId)&&(identical(other.lotId, lotId) || other.lotId == lotId)&&(identical(other.lotCode, lotCode) || other.lotCode == lotCode)&&(identical(other.formTemplateId, formTemplateId) || other.formTemplateId == formTemplateId)&&(identical(other.formTemplateName, formTemplateName) || other.formTemplateName == formTemplateName)&&(identical(other.formVersion, formVersion) || other.formVersion == formVersion)&&(identical(other.inspectedBy, inspectedBy) || other.inspectedBy == inspectedBy)&&(identical(other.inspectorName, inspectorName) || other.inspectorName == inspectorName)&&(identical(other.siteId, siteId) || other.siteId == siteId)&&(identical(other.siteName, siteName) || other.siteName == siteName)&&(identical(other.status, status) || other.status == status)&&(identical(other.reviewedBy, reviewedBy) || other.reviewedBy == reviewedBy)&&(identical(other.reviewerName, reviewerName) || other.reviewerName == reviewerName)&&(identical(other.reviewedAt, reviewedAt) || other.reviewedAt == reviewedAt)&&(identical(other.reviewNotes, reviewNotes) || other.reviewNotes == reviewNotes)&&const DeepCollectionEquality().equals(other.answers, answers)&&const DeepCollectionEquality().equals(other.evidences, evidences)&&(identical(other.hasOos, hasOos) || other.hasOos == hasOos)&&(identical(other.inspectedAt, inspectedAt) || other.inspectedAt == inspectedAt)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,inspectionCode,planId,stepId,lotId,lotCode,formTemplateId,formTemplateName,formVersion,inspectedBy,inspectorName,siteId,siteName,status,reviewedBy,reviewerName,reviewedAt,reviewNotes,const DeepCollectionEquality().hash(answers),const DeepCollectionEquality().hash(evidences),hasOos,inspectedAt,submittedAt,createdAt,updatedAt]);

@override
String toString() {
  return 'PlantInspection(id: $id, inspectionCode: $inspectionCode, planId: $planId, stepId: $stepId, lotId: $lotId, lotCode: $lotCode, formTemplateId: $formTemplateId, formTemplateName: $formTemplateName, formVersion: $formVersion, inspectedBy: $inspectedBy, inspectorName: $inspectorName, siteId: $siteId, siteName: $siteName, status: $status, reviewedBy: $reviewedBy, reviewerName: $reviewerName, reviewedAt: $reviewedAt, reviewNotes: $reviewNotes, answers: $answers, evidences: $evidences, hasOos: $hasOos, inspectedAt: $inspectedAt, submittedAt: $submittedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $PlantInspectionCopyWith<$Res>  {
  factory $PlantInspectionCopyWith(PlantInspection value, $Res Function(PlantInspection) _then) = _$PlantInspectionCopyWithImpl;
@useResult
$Res call({
 String id, String inspectionCode, String planId, String stepId, String? lotId, String? lotCode, String formTemplateId, String? formTemplateName, String formVersion, String inspectedBy, String? inspectorName, String siteId, String? siteName, String status, String? reviewedBy, String? reviewerName, DateTime? reviewedAt, String? reviewNotes, Map<String, dynamic> answers, List<PlantEvidence> evidences, bool? hasOos, DateTime inspectedAt, DateTime? submittedAt, DateTime createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$PlantInspectionCopyWithImpl<$Res>
    implements $PlantInspectionCopyWith<$Res> {
  _$PlantInspectionCopyWithImpl(this._self, this._then);

  final PlantInspection _self;
  final $Res Function(PlantInspection) _then;

/// Create a copy of PlantInspection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? inspectionCode = null,Object? planId = null,Object? stepId = null,Object? lotId = freezed,Object? lotCode = freezed,Object? formTemplateId = null,Object? formTemplateName = freezed,Object? formVersion = null,Object? inspectedBy = null,Object? inspectorName = freezed,Object? siteId = null,Object? siteName = freezed,Object? status = null,Object? reviewedBy = freezed,Object? reviewerName = freezed,Object? reviewedAt = freezed,Object? reviewNotes = freezed,Object? answers = null,Object? evidences = null,Object? hasOos = freezed,Object? inspectedAt = null,Object? submittedAt = freezed,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,inspectionCode: null == inspectionCode ? _self.inspectionCode : inspectionCode // ignore: cast_nullable_to_non_nullable
as String,planId: null == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String,stepId: null == stepId ? _self.stepId : stepId // ignore: cast_nullable_to_non_nullable
as String,lotId: freezed == lotId ? _self.lotId : lotId // ignore: cast_nullable_to_non_nullable
as String?,lotCode: freezed == lotCode ? _self.lotCode : lotCode // ignore: cast_nullable_to_non_nullable
as String?,formTemplateId: null == formTemplateId ? _self.formTemplateId : formTemplateId // ignore: cast_nullable_to_non_nullable
as String,formTemplateName: freezed == formTemplateName ? _self.formTemplateName : formTemplateName // ignore: cast_nullable_to_non_nullable
as String?,formVersion: null == formVersion ? _self.formVersion : formVersion // ignore: cast_nullable_to_non_nullable
as String,inspectedBy: null == inspectedBy ? _self.inspectedBy : inspectedBy // ignore: cast_nullable_to_non_nullable
as String,inspectorName: freezed == inspectorName ? _self.inspectorName : inspectorName // ignore: cast_nullable_to_non_nullable
as String?,siteId: null == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as String,siteName: freezed == siteName ? _self.siteName : siteName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,reviewedBy: freezed == reviewedBy ? _self.reviewedBy : reviewedBy // ignore: cast_nullable_to_non_nullable
as String?,reviewerName: freezed == reviewerName ? _self.reviewerName : reviewerName // ignore: cast_nullable_to_non_nullable
as String?,reviewedAt: freezed == reviewedAt ? _self.reviewedAt : reviewedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reviewNotes: freezed == reviewNotes ? _self.reviewNotes : reviewNotes // ignore: cast_nullable_to_non_nullable
as String?,answers: null == answers ? _self.answers : answers // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,evidences: null == evidences ? _self.evidences : evidences // ignore: cast_nullable_to_non_nullable
as List<PlantEvidence>,hasOos: freezed == hasOos ? _self.hasOos : hasOos // ignore: cast_nullable_to_non_nullable
as bool?,inspectedAt: null == inspectedAt ? _self.inspectedAt : inspectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlantInspection].
extension PlantInspectionPatterns on PlantInspection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlantInspection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlantInspection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlantInspection value)  $default,){
final _that = this;
switch (_that) {
case _PlantInspection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlantInspection value)?  $default,){
final _that = this;
switch (_that) {
case _PlantInspection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String inspectionCode,  String planId,  String stepId,  String? lotId,  String? lotCode,  String formTemplateId,  String? formTemplateName,  String formVersion,  String inspectedBy,  String? inspectorName,  String siteId,  String? siteName,  String status,  String? reviewedBy,  String? reviewerName,  DateTime? reviewedAt,  String? reviewNotes,  Map<String, dynamic> answers,  List<PlantEvidence> evidences,  bool? hasOos,  DateTime inspectedAt,  DateTime? submittedAt,  DateTime createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlantInspection() when $default != null:
return $default(_that.id,_that.inspectionCode,_that.planId,_that.stepId,_that.lotId,_that.lotCode,_that.formTemplateId,_that.formTemplateName,_that.formVersion,_that.inspectedBy,_that.inspectorName,_that.siteId,_that.siteName,_that.status,_that.reviewedBy,_that.reviewerName,_that.reviewedAt,_that.reviewNotes,_that.answers,_that.evidences,_that.hasOos,_that.inspectedAt,_that.submittedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String inspectionCode,  String planId,  String stepId,  String? lotId,  String? lotCode,  String formTemplateId,  String? formTemplateName,  String formVersion,  String inspectedBy,  String? inspectorName,  String siteId,  String? siteName,  String status,  String? reviewedBy,  String? reviewerName,  DateTime? reviewedAt,  String? reviewNotes,  Map<String, dynamic> answers,  List<PlantEvidence> evidences,  bool? hasOos,  DateTime inspectedAt,  DateTime? submittedAt,  DateTime createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _PlantInspection():
return $default(_that.id,_that.inspectionCode,_that.planId,_that.stepId,_that.lotId,_that.lotCode,_that.formTemplateId,_that.formTemplateName,_that.formVersion,_that.inspectedBy,_that.inspectorName,_that.siteId,_that.siteName,_that.status,_that.reviewedBy,_that.reviewerName,_that.reviewedAt,_that.reviewNotes,_that.answers,_that.evidences,_that.hasOos,_that.inspectedAt,_that.submittedAt,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String inspectionCode,  String planId,  String stepId,  String? lotId,  String? lotCode,  String formTemplateId,  String? formTemplateName,  String formVersion,  String inspectedBy,  String? inspectorName,  String siteId,  String? siteName,  String status,  String? reviewedBy,  String? reviewerName,  DateTime? reviewedAt,  String? reviewNotes,  Map<String, dynamic> answers,  List<PlantEvidence> evidences,  bool? hasOos,  DateTime inspectedAt,  DateTime? submittedAt,  DateTime createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _PlantInspection() when $default != null:
return $default(_that.id,_that.inspectionCode,_that.planId,_that.stepId,_that.lotId,_that.lotCode,_that.formTemplateId,_that.formTemplateName,_that.formVersion,_that.inspectedBy,_that.inspectorName,_that.siteId,_that.siteName,_that.status,_that.reviewedBy,_that.reviewerName,_that.reviewedAt,_that.reviewNotes,_that.answers,_that.evidences,_that.hasOos,_that.inspectedAt,_that.submittedAt,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlantInspection implements PlantInspection {
  const _PlantInspection({required this.id, required this.inspectionCode, required this.planId, required this.stepId, this.lotId, this.lotCode, required this.formTemplateId, this.formTemplateName, required this.formVersion, required this.inspectedBy, this.inspectorName, required this.siteId, this.siteName, required this.status, this.reviewedBy, this.reviewerName, this.reviewedAt, this.reviewNotes, required final  Map<String, dynamic> answers, required final  List<PlantEvidence> evidences, this.hasOos, required this.inspectedAt, this.submittedAt, required this.createdAt, this.updatedAt}): _answers = answers,_evidences = evidences;
  factory _PlantInspection.fromJson(Map<String, dynamic> json) => _$PlantInspectionFromJson(json);

@override final  String id;
@override final  String inspectionCode;
@override final  String planId;
@override final  String stepId;
@override final  String? lotId;
@override final  String? lotCode;
@override final  String formTemplateId;
@override final  String? formTemplateName;
@override final  String formVersion;
@override final  String inspectedBy;
@override final  String? inspectorName;
@override final  String siteId;
@override final  String? siteName;
@override final  String status;
// DRAFT | SUBMITTED | UNDER_REVIEW | APPROVED | NEED_REVISION | OOS | REJECTED
@override final  String? reviewedBy;
@override final  String? reviewerName;
@override final  DateTime? reviewedAt;
@override final  String? reviewNotes;
 final  Map<String, dynamic> _answers;
@override Map<String, dynamic> get answers {
  if (_answers is EqualUnmodifiableMapView) return _answers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_answers);
}

// JSONB answers
 final  List<PlantEvidence> _evidences;
// JSONB answers
@override List<PlantEvidence> get evidences {
  if (_evidences is EqualUnmodifiableListView) return _evidences;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_evidences);
}

@override final  bool? hasOos;
@override final  DateTime inspectedAt;
@override final  DateTime? submittedAt;
@override final  DateTime createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of PlantInspection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlantInspectionCopyWith<_PlantInspection> get copyWith => __$PlantInspectionCopyWithImpl<_PlantInspection>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlantInspectionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlantInspection&&(identical(other.id, id) || other.id == id)&&(identical(other.inspectionCode, inspectionCode) || other.inspectionCode == inspectionCode)&&(identical(other.planId, planId) || other.planId == planId)&&(identical(other.stepId, stepId) || other.stepId == stepId)&&(identical(other.lotId, lotId) || other.lotId == lotId)&&(identical(other.lotCode, lotCode) || other.lotCode == lotCode)&&(identical(other.formTemplateId, formTemplateId) || other.formTemplateId == formTemplateId)&&(identical(other.formTemplateName, formTemplateName) || other.formTemplateName == formTemplateName)&&(identical(other.formVersion, formVersion) || other.formVersion == formVersion)&&(identical(other.inspectedBy, inspectedBy) || other.inspectedBy == inspectedBy)&&(identical(other.inspectorName, inspectorName) || other.inspectorName == inspectorName)&&(identical(other.siteId, siteId) || other.siteId == siteId)&&(identical(other.siteName, siteName) || other.siteName == siteName)&&(identical(other.status, status) || other.status == status)&&(identical(other.reviewedBy, reviewedBy) || other.reviewedBy == reviewedBy)&&(identical(other.reviewerName, reviewerName) || other.reviewerName == reviewerName)&&(identical(other.reviewedAt, reviewedAt) || other.reviewedAt == reviewedAt)&&(identical(other.reviewNotes, reviewNotes) || other.reviewNotes == reviewNotes)&&const DeepCollectionEquality().equals(other._answers, _answers)&&const DeepCollectionEquality().equals(other._evidences, _evidences)&&(identical(other.hasOos, hasOos) || other.hasOos == hasOos)&&(identical(other.inspectedAt, inspectedAt) || other.inspectedAt == inspectedAt)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,inspectionCode,planId,stepId,lotId,lotCode,formTemplateId,formTemplateName,formVersion,inspectedBy,inspectorName,siteId,siteName,status,reviewedBy,reviewerName,reviewedAt,reviewNotes,const DeepCollectionEquality().hash(_answers),const DeepCollectionEquality().hash(_evidences),hasOos,inspectedAt,submittedAt,createdAt,updatedAt]);

@override
String toString() {
  return 'PlantInspection(id: $id, inspectionCode: $inspectionCode, planId: $planId, stepId: $stepId, lotId: $lotId, lotCode: $lotCode, formTemplateId: $formTemplateId, formTemplateName: $formTemplateName, formVersion: $formVersion, inspectedBy: $inspectedBy, inspectorName: $inspectorName, siteId: $siteId, siteName: $siteName, status: $status, reviewedBy: $reviewedBy, reviewerName: $reviewerName, reviewedAt: $reviewedAt, reviewNotes: $reviewNotes, answers: $answers, evidences: $evidences, hasOos: $hasOos, inspectedAt: $inspectedAt, submittedAt: $submittedAt, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$PlantInspectionCopyWith<$Res> implements $PlantInspectionCopyWith<$Res> {
  factory _$PlantInspectionCopyWith(_PlantInspection value, $Res Function(_PlantInspection) _then) = __$PlantInspectionCopyWithImpl;
@override @useResult
$Res call({
 String id, String inspectionCode, String planId, String stepId, String? lotId, String? lotCode, String formTemplateId, String? formTemplateName, String formVersion, String inspectedBy, String? inspectorName, String siteId, String? siteName, String status, String? reviewedBy, String? reviewerName, DateTime? reviewedAt, String? reviewNotes, Map<String, dynamic> answers, List<PlantEvidence> evidences, bool? hasOos, DateTime inspectedAt, DateTime? submittedAt, DateTime createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$PlantInspectionCopyWithImpl<$Res>
    implements _$PlantInspectionCopyWith<$Res> {
  __$PlantInspectionCopyWithImpl(this._self, this._then);

  final _PlantInspection _self;
  final $Res Function(_PlantInspection) _then;

/// Create a copy of PlantInspection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? inspectionCode = null,Object? planId = null,Object? stepId = null,Object? lotId = freezed,Object? lotCode = freezed,Object? formTemplateId = null,Object? formTemplateName = freezed,Object? formVersion = null,Object? inspectedBy = null,Object? inspectorName = freezed,Object? siteId = null,Object? siteName = freezed,Object? status = null,Object? reviewedBy = freezed,Object? reviewerName = freezed,Object? reviewedAt = freezed,Object? reviewNotes = freezed,Object? answers = null,Object? evidences = null,Object? hasOos = freezed,Object? inspectedAt = null,Object? submittedAt = freezed,Object? createdAt = null,Object? updatedAt = freezed,}) {
  return _then(_PlantInspection(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,inspectionCode: null == inspectionCode ? _self.inspectionCode : inspectionCode // ignore: cast_nullable_to_non_nullable
as String,planId: null == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String,stepId: null == stepId ? _self.stepId : stepId // ignore: cast_nullable_to_non_nullable
as String,lotId: freezed == lotId ? _self.lotId : lotId // ignore: cast_nullable_to_non_nullable
as String?,lotCode: freezed == lotCode ? _self.lotCode : lotCode // ignore: cast_nullable_to_non_nullable
as String?,formTemplateId: null == formTemplateId ? _self.formTemplateId : formTemplateId // ignore: cast_nullable_to_non_nullable
as String,formTemplateName: freezed == formTemplateName ? _self.formTemplateName : formTemplateName // ignore: cast_nullable_to_non_nullable
as String?,formVersion: null == formVersion ? _self.formVersion : formVersion // ignore: cast_nullable_to_non_nullable
as String,inspectedBy: null == inspectedBy ? _self.inspectedBy : inspectedBy // ignore: cast_nullable_to_non_nullable
as String,inspectorName: freezed == inspectorName ? _self.inspectorName : inspectorName // ignore: cast_nullable_to_non_nullable
as String?,siteId: null == siteId ? _self.siteId : siteId // ignore: cast_nullable_to_non_nullable
as String,siteName: freezed == siteName ? _self.siteName : siteName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,reviewedBy: freezed == reviewedBy ? _self.reviewedBy : reviewedBy // ignore: cast_nullable_to_non_nullable
as String?,reviewerName: freezed == reviewerName ? _self.reviewerName : reviewerName // ignore: cast_nullable_to_non_nullable
as String?,reviewedAt: freezed == reviewedAt ? _self.reviewedAt : reviewedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,reviewNotes: freezed == reviewNotes ? _self.reviewNotes : reviewNotes // ignore: cast_nullable_to_non_nullable
as String?,answers: null == answers ? _self._answers : answers // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,evidences: null == evidences ? _self._evidences : evidences // ignore: cast_nullable_to_non_nullable
as List<PlantEvidence>,hasOos: freezed == hasOos ? _self.hasOos : hasOos // ignore: cast_nullable_to_non_nullable
as bool?,inspectedAt: null == inspectedAt ? _self.inspectedAt : inspectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$PlantInspectionSummary {

 String get id; String get inspectionCode; String get planId; String? get lotCode; String? get formTemplateName; String? get inspectorName; String get status; bool? get hasOos; DateTime get inspectedAt; DateTime? get submittedAt;
/// Create a copy of PlantInspectionSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlantInspectionSummaryCopyWith<PlantInspectionSummary> get copyWith => _$PlantInspectionSummaryCopyWithImpl<PlantInspectionSummary>(this as PlantInspectionSummary, _$identity);

  /// Serializes this PlantInspectionSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlantInspectionSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.inspectionCode, inspectionCode) || other.inspectionCode == inspectionCode)&&(identical(other.planId, planId) || other.planId == planId)&&(identical(other.lotCode, lotCode) || other.lotCode == lotCode)&&(identical(other.formTemplateName, formTemplateName) || other.formTemplateName == formTemplateName)&&(identical(other.inspectorName, inspectorName) || other.inspectorName == inspectorName)&&(identical(other.status, status) || other.status == status)&&(identical(other.hasOos, hasOos) || other.hasOos == hasOos)&&(identical(other.inspectedAt, inspectedAt) || other.inspectedAt == inspectedAt)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,inspectionCode,planId,lotCode,formTemplateName,inspectorName,status,hasOos,inspectedAt,submittedAt);

@override
String toString() {
  return 'PlantInspectionSummary(id: $id, inspectionCode: $inspectionCode, planId: $planId, lotCode: $lotCode, formTemplateName: $formTemplateName, inspectorName: $inspectorName, status: $status, hasOos: $hasOos, inspectedAt: $inspectedAt, submittedAt: $submittedAt)';
}


}

/// @nodoc
abstract mixin class $PlantInspectionSummaryCopyWith<$Res>  {
  factory $PlantInspectionSummaryCopyWith(PlantInspectionSummary value, $Res Function(PlantInspectionSummary) _then) = _$PlantInspectionSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String inspectionCode, String planId, String? lotCode, String? formTemplateName, String? inspectorName, String status, bool? hasOos, DateTime inspectedAt, DateTime? submittedAt
});




}
/// @nodoc
class _$PlantInspectionSummaryCopyWithImpl<$Res>
    implements $PlantInspectionSummaryCopyWith<$Res> {
  _$PlantInspectionSummaryCopyWithImpl(this._self, this._then);

  final PlantInspectionSummary _self;
  final $Res Function(PlantInspectionSummary) _then;

/// Create a copy of PlantInspectionSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? inspectionCode = null,Object? planId = null,Object? lotCode = freezed,Object? formTemplateName = freezed,Object? inspectorName = freezed,Object? status = null,Object? hasOos = freezed,Object? inspectedAt = null,Object? submittedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,inspectionCode: null == inspectionCode ? _self.inspectionCode : inspectionCode // ignore: cast_nullable_to_non_nullable
as String,planId: null == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String,lotCode: freezed == lotCode ? _self.lotCode : lotCode // ignore: cast_nullable_to_non_nullable
as String?,formTemplateName: freezed == formTemplateName ? _self.formTemplateName : formTemplateName // ignore: cast_nullable_to_non_nullable
as String?,inspectorName: freezed == inspectorName ? _self.inspectorName : inspectorName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,hasOos: freezed == hasOos ? _self.hasOos : hasOos // ignore: cast_nullable_to_non_nullable
as bool?,inspectedAt: null == inspectedAt ? _self.inspectedAt : inspectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlantInspectionSummary].
extension PlantInspectionSummaryPatterns on PlantInspectionSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlantInspectionSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlantInspectionSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlantInspectionSummary value)  $default,){
final _that = this;
switch (_that) {
case _PlantInspectionSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlantInspectionSummary value)?  $default,){
final _that = this;
switch (_that) {
case _PlantInspectionSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String inspectionCode,  String planId,  String? lotCode,  String? formTemplateName,  String? inspectorName,  String status,  bool? hasOos,  DateTime inspectedAt,  DateTime? submittedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlantInspectionSummary() when $default != null:
return $default(_that.id,_that.inspectionCode,_that.planId,_that.lotCode,_that.formTemplateName,_that.inspectorName,_that.status,_that.hasOos,_that.inspectedAt,_that.submittedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String inspectionCode,  String planId,  String? lotCode,  String? formTemplateName,  String? inspectorName,  String status,  bool? hasOos,  DateTime inspectedAt,  DateTime? submittedAt)  $default,) {final _that = this;
switch (_that) {
case _PlantInspectionSummary():
return $default(_that.id,_that.inspectionCode,_that.planId,_that.lotCode,_that.formTemplateName,_that.inspectorName,_that.status,_that.hasOos,_that.inspectedAt,_that.submittedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String inspectionCode,  String planId,  String? lotCode,  String? formTemplateName,  String? inspectorName,  String status,  bool? hasOos,  DateTime inspectedAt,  DateTime? submittedAt)?  $default,) {final _that = this;
switch (_that) {
case _PlantInspectionSummary() when $default != null:
return $default(_that.id,_that.inspectionCode,_that.planId,_that.lotCode,_that.formTemplateName,_that.inspectorName,_that.status,_that.hasOos,_that.inspectedAt,_that.submittedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlantInspectionSummary implements PlantInspectionSummary {
  const _PlantInspectionSummary({required this.id, required this.inspectionCode, required this.planId, this.lotCode, this.formTemplateName, this.inspectorName, required this.status, this.hasOos, required this.inspectedAt, this.submittedAt});
  factory _PlantInspectionSummary.fromJson(Map<String, dynamic> json) => _$PlantInspectionSummaryFromJson(json);

@override final  String id;
@override final  String inspectionCode;
@override final  String planId;
@override final  String? lotCode;
@override final  String? formTemplateName;
@override final  String? inspectorName;
@override final  String status;
@override final  bool? hasOos;
@override final  DateTime inspectedAt;
@override final  DateTime? submittedAt;

/// Create a copy of PlantInspectionSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlantInspectionSummaryCopyWith<_PlantInspectionSummary> get copyWith => __$PlantInspectionSummaryCopyWithImpl<_PlantInspectionSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlantInspectionSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlantInspectionSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.inspectionCode, inspectionCode) || other.inspectionCode == inspectionCode)&&(identical(other.planId, planId) || other.planId == planId)&&(identical(other.lotCode, lotCode) || other.lotCode == lotCode)&&(identical(other.formTemplateName, formTemplateName) || other.formTemplateName == formTemplateName)&&(identical(other.inspectorName, inspectorName) || other.inspectorName == inspectorName)&&(identical(other.status, status) || other.status == status)&&(identical(other.hasOos, hasOos) || other.hasOos == hasOos)&&(identical(other.inspectedAt, inspectedAt) || other.inspectedAt == inspectedAt)&&(identical(other.submittedAt, submittedAt) || other.submittedAt == submittedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,inspectionCode,planId,lotCode,formTemplateName,inspectorName,status,hasOos,inspectedAt,submittedAt);

@override
String toString() {
  return 'PlantInspectionSummary(id: $id, inspectionCode: $inspectionCode, planId: $planId, lotCode: $lotCode, formTemplateName: $formTemplateName, inspectorName: $inspectorName, status: $status, hasOos: $hasOos, inspectedAt: $inspectedAt, submittedAt: $submittedAt)';
}


}

/// @nodoc
abstract mixin class _$PlantInspectionSummaryCopyWith<$Res> implements $PlantInspectionSummaryCopyWith<$Res> {
  factory _$PlantInspectionSummaryCopyWith(_PlantInspectionSummary value, $Res Function(_PlantInspectionSummary) _then) = __$PlantInspectionSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String inspectionCode, String planId, String? lotCode, String? formTemplateName, String? inspectorName, String status, bool? hasOos, DateTime inspectedAt, DateTime? submittedAt
});




}
/// @nodoc
class __$PlantInspectionSummaryCopyWithImpl<$Res>
    implements _$PlantInspectionSummaryCopyWith<$Res> {
  __$PlantInspectionSummaryCopyWithImpl(this._self, this._then);

  final _PlantInspectionSummary _self;
  final $Res Function(_PlantInspectionSummary) _then;

/// Create a copy of PlantInspectionSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? inspectionCode = null,Object? planId = null,Object? lotCode = freezed,Object? formTemplateName = freezed,Object? inspectorName = freezed,Object? status = null,Object? hasOos = freezed,Object? inspectedAt = null,Object? submittedAt = freezed,}) {
  return _then(_PlantInspectionSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,inspectionCode: null == inspectionCode ? _self.inspectionCode : inspectionCode // ignore: cast_nullable_to_non_nullable
as String,planId: null == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String,lotCode: freezed == lotCode ? _self.lotCode : lotCode // ignore: cast_nullable_to_non_nullable
as String?,formTemplateName: freezed == formTemplateName ? _self.formTemplateName : formTemplateName // ignore: cast_nullable_to_non_nullable
as String?,inspectorName: freezed == inspectorName ? _self.inspectorName : inspectorName // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,hasOos: freezed == hasOos ? _self.hasOos : hasOos // ignore: cast_nullable_to_non_nullable
as bool?,inspectedAt: null == inspectedAt ? _self.inspectedAt : inspectedAt // ignore: cast_nullable_to_non_nullable
as DateTime,submittedAt: freezed == submittedAt ? _self.submittedAt : submittedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$PlantEvidence {

 String get id; String get inspectionId; String get attachmentId; String? get fileName; String? get mimeType; int? get fileSizeBytes; String? get storagePath; String? get signedUrl; String? get caption; String get uploadedBy; DateTime get uploadedAt;
/// Create a copy of PlantEvidence
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlantEvidenceCopyWith<PlantEvidence> get copyWith => _$PlantEvidenceCopyWithImpl<PlantEvidence>(this as PlantEvidence, _$identity);

  /// Serializes this PlantEvidence to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlantEvidence&&(identical(other.id, id) || other.id == id)&&(identical(other.inspectionId, inspectionId) || other.inspectionId == inspectionId)&&(identical(other.attachmentId, attachmentId) || other.attachmentId == attachmentId)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes)&&(identical(other.storagePath, storagePath) || other.storagePath == storagePath)&&(identical(other.signedUrl, signedUrl) || other.signedUrl == signedUrl)&&(identical(other.caption, caption) || other.caption == caption)&&(identical(other.uploadedBy, uploadedBy) || other.uploadedBy == uploadedBy)&&(identical(other.uploadedAt, uploadedAt) || other.uploadedAt == uploadedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,inspectionId,attachmentId,fileName,mimeType,fileSizeBytes,storagePath,signedUrl,caption,uploadedBy,uploadedAt);

@override
String toString() {
  return 'PlantEvidence(id: $id, inspectionId: $inspectionId, attachmentId: $attachmentId, fileName: $fileName, mimeType: $mimeType, fileSizeBytes: $fileSizeBytes, storagePath: $storagePath, signedUrl: $signedUrl, caption: $caption, uploadedBy: $uploadedBy, uploadedAt: $uploadedAt)';
}


}

/// @nodoc
abstract mixin class $PlantEvidenceCopyWith<$Res>  {
  factory $PlantEvidenceCopyWith(PlantEvidence value, $Res Function(PlantEvidence) _then) = _$PlantEvidenceCopyWithImpl;
@useResult
$Res call({
 String id, String inspectionId, String attachmentId, String? fileName, String? mimeType, int? fileSizeBytes, String? storagePath, String? signedUrl, String? caption, String uploadedBy, DateTime uploadedAt
});




}
/// @nodoc
class _$PlantEvidenceCopyWithImpl<$Res>
    implements $PlantEvidenceCopyWith<$Res> {
  _$PlantEvidenceCopyWithImpl(this._self, this._then);

  final PlantEvidence _self;
  final $Res Function(PlantEvidence) _then;

/// Create a copy of PlantEvidence
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? inspectionId = null,Object? attachmentId = null,Object? fileName = freezed,Object? mimeType = freezed,Object? fileSizeBytes = freezed,Object? storagePath = freezed,Object? signedUrl = freezed,Object? caption = freezed,Object? uploadedBy = null,Object? uploadedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,inspectionId: null == inspectionId ? _self.inspectionId : inspectionId // ignore: cast_nullable_to_non_nullable
as String,attachmentId: null == attachmentId ? _self.attachmentId : attachmentId // ignore: cast_nullable_to_non_nullable
as String,fileName: freezed == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,fileSizeBytes: freezed == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int?,storagePath: freezed == storagePath ? _self.storagePath : storagePath // ignore: cast_nullable_to_non_nullable
as String?,signedUrl: freezed == signedUrl ? _self.signedUrl : signedUrl // ignore: cast_nullable_to_non_nullable
as String?,caption: freezed == caption ? _self.caption : caption // ignore: cast_nullable_to_non_nullable
as String?,uploadedBy: null == uploadedBy ? _self.uploadedBy : uploadedBy // ignore: cast_nullable_to_non_nullable
as String,uploadedAt: null == uploadedAt ? _self.uploadedAt : uploadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [PlantEvidence].
extension PlantEvidencePatterns on PlantEvidence {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlantEvidence value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlantEvidence() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlantEvidence value)  $default,){
final _that = this;
switch (_that) {
case _PlantEvidence():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlantEvidence value)?  $default,){
final _that = this;
switch (_that) {
case _PlantEvidence() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String inspectionId,  String attachmentId,  String? fileName,  String? mimeType,  int? fileSizeBytes,  String? storagePath,  String? signedUrl,  String? caption,  String uploadedBy,  DateTime uploadedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlantEvidence() when $default != null:
return $default(_that.id,_that.inspectionId,_that.attachmentId,_that.fileName,_that.mimeType,_that.fileSizeBytes,_that.storagePath,_that.signedUrl,_that.caption,_that.uploadedBy,_that.uploadedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String inspectionId,  String attachmentId,  String? fileName,  String? mimeType,  int? fileSizeBytes,  String? storagePath,  String? signedUrl,  String? caption,  String uploadedBy,  DateTime uploadedAt)  $default,) {final _that = this;
switch (_that) {
case _PlantEvidence():
return $default(_that.id,_that.inspectionId,_that.attachmentId,_that.fileName,_that.mimeType,_that.fileSizeBytes,_that.storagePath,_that.signedUrl,_that.caption,_that.uploadedBy,_that.uploadedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String inspectionId,  String attachmentId,  String? fileName,  String? mimeType,  int? fileSizeBytes,  String? storagePath,  String? signedUrl,  String? caption,  String uploadedBy,  DateTime uploadedAt)?  $default,) {final _that = this;
switch (_that) {
case _PlantEvidence() when $default != null:
return $default(_that.id,_that.inspectionId,_that.attachmentId,_that.fileName,_that.mimeType,_that.fileSizeBytes,_that.storagePath,_that.signedUrl,_that.caption,_that.uploadedBy,_that.uploadedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlantEvidence implements PlantEvidence {
  const _PlantEvidence({required this.id, required this.inspectionId, required this.attachmentId, this.fileName, this.mimeType, this.fileSizeBytes, this.storagePath, this.signedUrl, this.caption, required this.uploadedBy, required this.uploadedAt});
  factory _PlantEvidence.fromJson(Map<String, dynamic> json) => _$PlantEvidenceFromJson(json);

@override final  String id;
@override final  String inspectionId;
@override final  String attachmentId;
@override final  String? fileName;
@override final  String? mimeType;
@override final  int? fileSizeBytes;
@override final  String? storagePath;
@override final  String? signedUrl;
@override final  String? caption;
@override final  String uploadedBy;
@override final  DateTime uploadedAt;

/// Create a copy of PlantEvidence
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlantEvidenceCopyWith<_PlantEvidence> get copyWith => __$PlantEvidenceCopyWithImpl<_PlantEvidence>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlantEvidenceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlantEvidence&&(identical(other.id, id) || other.id == id)&&(identical(other.inspectionId, inspectionId) || other.inspectionId == inspectionId)&&(identical(other.attachmentId, attachmentId) || other.attachmentId == attachmentId)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes)&&(identical(other.storagePath, storagePath) || other.storagePath == storagePath)&&(identical(other.signedUrl, signedUrl) || other.signedUrl == signedUrl)&&(identical(other.caption, caption) || other.caption == caption)&&(identical(other.uploadedBy, uploadedBy) || other.uploadedBy == uploadedBy)&&(identical(other.uploadedAt, uploadedAt) || other.uploadedAt == uploadedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,inspectionId,attachmentId,fileName,mimeType,fileSizeBytes,storagePath,signedUrl,caption,uploadedBy,uploadedAt);

@override
String toString() {
  return 'PlantEvidence(id: $id, inspectionId: $inspectionId, attachmentId: $attachmentId, fileName: $fileName, mimeType: $mimeType, fileSizeBytes: $fileSizeBytes, storagePath: $storagePath, signedUrl: $signedUrl, caption: $caption, uploadedBy: $uploadedBy, uploadedAt: $uploadedAt)';
}


}

/// @nodoc
abstract mixin class _$PlantEvidenceCopyWith<$Res> implements $PlantEvidenceCopyWith<$Res> {
  factory _$PlantEvidenceCopyWith(_PlantEvidence value, $Res Function(_PlantEvidence) _then) = __$PlantEvidenceCopyWithImpl;
@override @useResult
$Res call({
 String id, String inspectionId, String attachmentId, String? fileName, String? mimeType, int? fileSizeBytes, String? storagePath, String? signedUrl, String? caption, String uploadedBy, DateTime uploadedAt
});




}
/// @nodoc
class __$PlantEvidenceCopyWithImpl<$Res>
    implements _$PlantEvidenceCopyWith<$Res> {
  __$PlantEvidenceCopyWithImpl(this._self, this._then);

  final _PlantEvidence _self;
  final $Res Function(_PlantEvidence) _then;

/// Create a copy of PlantEvidence
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? inspectionId = null,Object? attachmentId = null,Object? fileName = freezed,Object? mimeType = freezed,Object? fileSizeBytes = freezed,Object? storagePath = freezed,Object? signedUrl = freezed,Object? caption = freezed,Object? uploadedBy = null,Object? uploadedAt = null,}) {
  return _then(_PlantEvidence(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,inspectionId: null == inspectionId ? _self.inspectionId : inspectionId // ignore: cast_nullable_to_non_nullable
as String,attachmentId: null == attachmentId ? _self.attachmentId : attachmentId // ignore: cast_nullable_to_non_nullable
as String,fileName: freezed == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String?,mimeType: freezed == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String?,fileSizeBytes: freezed == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int?,storagePath: freezed == storagePath ? _self.storagePath : storagePath // ignore: cast_nullable_to_non_nullable
as String?,signedUrl: freezed == signedUrl ? _self.signedUrl : signedUrl // ignore: cast_nullable_to_non_nullable
as String?,caption: freezed == caption ? _self.caption : caption // ignore: cast_nullable_to_non_nullable
as String?,uploadedBy: null == uploadedBy ? _self.uploadedBy : uploadedBy // ignore: cast_nullable_to_non_nullable
as String,uploadedAt: null == uploadedAt ? _self.uploadedAt : uploadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$InspectionDraft {

 String get localId;// UUID generated offline
 String get planId; String get stepId; String get formTemplateId; String get formVersion; Map<String, dynamic> get answers; List<String> get pendingEvidencePaths;// local file paths pending upload
 DateTime get createdAt; bool get hasSyncError; String? get syncErrorMessage;
/// Create a copy of InspectionDraft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InspectionDraftCopyWith<InspectionDraft> get copyWith => _$InspectionDraftCopyWithImpl<InspectionDraft>(this as InspectionDraft, _$identity);

  /// Serializes this InspectionDraft to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InspectionDraft&&(identical(other.localId, localId) || other.localId == localId)&&(identical(other.planId, planId) || other.planId == planId)&&(identical(other.stepId, stepId) || other.stepId == stepId)&&(identical(other.formTemplateId, formTemplateId) || other.formTemplateId == formTemplateId)&&(identical(other.formVersion, formVersion) || other.formVersion == formVersion)&&const DeepCollectionEquality().equals(other.answers, answers)&&const DeepCollectionEquality().equals(other.pendingEvidencePaths, pendingEvidencePaths)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.hasSyncError, hasSyncError) || other.hasSyncError == hasSyncError)&&(identical(other.syncErrorMessage, syncErrorMessage) || other.syncErrorMessage == syncErrorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,localId,planId,stepId,formTemplateId,formVersion,const DeepCollectionEquality().hash(answers),const DeepCollectionEquality().hash(pendingEvidencePaths),createdAt,hasSyncError,syncErrorMessage);

@override
String toString() {
  return 'InspectionDraft(localId: $localId, planId: $planId, stepId: $stepId, formTemplateId: $formTemplateId, formVersion: $formVersion, answers: $answers, pendingEvidencePaths: $pendingEvidencePaths, createdAt: $createdAt, hasSyncError: $hasSyncError, syncErrorMessage: $syncErrorMessage)';
}


}

/// @nodoc
abstract mixin class $InspectionDraftCopyWith<$Res>  {
  factory $InspectionDraftCopyWith(InspectionDraft value, $Res Function(InspectionDraft) _then) = _$InspectionDraftCopyWithImpl;
@useResult
$Res call({
 String localId, String planId, String stepId, String formTemplateId, String formVersion, Map<String, dynamic> answers, List<String> pendingEvidencePaths, DateTime createdAt, bool hasSyncError, String? syncErrorMessage
});




}
/// @nodoc
class _$InspectionDraftCopyWithImpl<$Res>
    implements $InspectionDraftCopyWith<$Res> {
  _$InspectionDraftCopyWithImpl(this._self, this._then);

  final InspectionDraft _self;
  final $Res Function(InspectionDraft) _then;

/// Create a copy of InspectionDraft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? localId = null,Object? planId = null,Object? stepId = null,Object? formTemplateId = null,Object? formVersion = null,Object? answers = null,Object? pendingEvidencePaths = null,Object? createdAt = null,Object? hasSyncError = null,Object? syncErrorMessage = freezed,}) {
  return _then(_self.copyWith(
localId: null == localId ? _self.localId : localId // ignore: cast_nullable_to_non_nullable
as String,planId: null == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String,stepId: null == stepId ? _self.stepId : stepId // ignore: cast_nullable_to_non_nullable
as String,formTemplateId: null == formTemplateId ? _self.formTemplateId : formTemplateId // ignore: cast_nullable_to_non_nullable
as String,formVersion: null == formVersion ? _self.formVersion : formVersion // ignore: cast_nullable_to_non_nullable
as String,answers: null == answers ? _self.answers : answers // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,pendingEvidencePaths: null == pendingEvidencePaths ? _self.pendingEvidencePaths : pendingEvidencePaths // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,hasSyncError: null == hasSyncError ? _self.hasSyncError : hasSyncError // ignore: cast_nullable_to_non_nullable
as bool,syncErrorMessage: freezed == syncErrorMessage ? _self.syncErrorMessage : syncErrorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [InspectionDraft].
extension InspectionDraftPatterns on InspectionDraft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InspectionDraft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InspectionDraft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InspectionDraft value)  $default,){
final _that = this;
switch (_that) {
case _InspectionDraft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InspectionDraft value)?  $default,){
final _that = this;
switch (_that) {
case _InspectionDraft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String localId,  String planId,  String stepId,  String formTemplateId,  String formVersion,  Map<String, dynamic> answers,  List<String> pendingEvidencePaths,  DateTime createdAt,  bool hasSyncError,  String? syncErrorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InspectionDraft() when $default != null:
return $default(_that.localId,_that.planId,_that.stepId,_that.formTemplateId,_that.formVersion,_that.answers,_that.pendingEvidencePaths,_that.createdAt,_that.hasSyncError,_that.syncErrorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String localId,  String planId,  String stepId,  String formTemplateId,  String formVersion,  Map<String, dynamic> answers,  List<String> pendingEvidencePaths,  DateTime createdAt,  bool hasSyncError,  String? syncErrorMessage)  $default,) {final _that = this;
switch (_that) {
case _InspectionDraft():
return $default(_that.localId,_that.planId,_that.stepId,_that.formTemplateId,_that.formVersion,_that.answers,_that.pendingEvidencePaths,_that.createdAt,_that.hasSyncError,_that.syncErrorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String localId,  String planId,  String stepId,  String formTemplateId,  String formVersion,  Map<String, dynamic> answers,  List<String> pendingEvidencePaths,  DateTime createdAt,  bool hasSyncError,  String? syncErrorMessage)?  $default,) {final _that = this;
switch (_that) {
case _InspectionDraft() when $default != null:
return $default(_that.localId,_that.planId,_that.stepId,_that.formTemplateId,_that.formVersion,_that.answers,_that.pendingEvidencePaths,_that.createdAt,_that.hasSyncError,_that.syncErrorMessage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InspectionDraft implements InspectionDraft {
  const _InspectionDraft({required this.localId, required this.planId, required this.stepId, required this.formTemplateId, required this.formVersion, required final  Map<String, dynamic> answers, required final  List<String> pendingEvidencePaths, required this.createdAt, this.hasSyncError = false, this.syncErrorMessage}): _answers = answers,_pendingEvidencePaths = pendingEvidencePaths;
  factory _InspectionDraft.fromJson(Map<String, dynamic> json) => _$InspectionDraftFromJson(json);

@override final  String localId;
// UUID generated offline
@override final  String planId;
@override final  String stepId;
@override final  String formTemplateId;
@override final  String formVersion;
 final  Map<String, dynamic> _answers;
@override Map<String, dynamic> get answers {
  if (_answers is EqualUnmodifiableMapView) return _answers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_answers);
}

 final  List<String> _pendingEvidencePaths;
@override List<String> get pendingEvidencePaths {
  if (_pendingEvidencePaths is EqualUnmodifiableListView) return _pendingEvidencePaths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pendingEvidencePaths);
}

// local file paths pending upload
@override final  DateTime createdAt;
@override@JsonKey() final  bool hasSyncError;
@override final  String? syncErrorMessage;

/// Create a copy of InspectionDraft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InspectionDraftCopyWith<_InspectionDraft> get copyWith => __$InspectionDraftCopyWithImpl<_InspectionDraft>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InspectionDraftToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InspectionDraft&&(identical(other.localId, localId) || other.localId == localId)&&(identical(other.planId, planId) || other.planId == planId)&&(identical(other.stepId, stepId) || other.stepId == stepId)&&(identical(other.formTemplateId, formTemplateId) || other.formTemplateId == formTemplateId)&&(identical(other.formVersion, formVersion) || other.formVersion == formVersion)&&const DeepCollectionEquality().equals(other._answers, _answers)&&const DeepCollectionEquality().equals(other._pendingEvidencePaths, _pendingEvidencePaths)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.hasSyncError, hasSyncError) || other.hasSyncError == hasSyncError)&&(identical(other.syncErrorMessage, syncErrorMessage) || other.syncErrorMessage == syncErrorMessage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,localId,planId,stepId,formTemplateId,formVersion,const DeepCollectionEquality().hash(_answers),const DeepCollectionEquality().hash(_pendingEvidencePaths),createdAt,hasSyncError,syncErrorMessage);

@override
String toString() {
  return 'InspectionDraft(localId: $localId, planId: $planId, stepId: $stepId, formTemplateId: $formTemplateId, formVersion: $formVersion, answers: $answers, pendingEvidencePaths: $pendingEvidencePaths, createdAt: $createdAt, hasSyncError: $hasSyncError, syncErrorMessage: $syncErrorMessage)';
}


}

/// @nodoc
abstract mixin class _$InspectionDraftCopyWith<$Res> implements $InspectionDraftCopyWith<$Res> {
  factory _$InspectionDraftCopyWith(_InspectionDraft value, $Res Function(_InspectionDraft) _then) = __$InspectionDraftCopyWithImpl;
@override @useResult
$Res call({
 String localId, String planId, String stepId, String formTemplateId, String formVersion, Map<String, dynamic> answers, List<String> pendingEvidencePaths, DateTime createdAt, bool hasSyncError, String? syncErrorMessage
});




}
/// @nodoc
class __$InspectionDraftCopyWithImpl<$Res>
    implements _$InspectionDraftCopyWith<$Res> {
  __$InspectionDraftCopyWithImpl(this._self, this._then);

  final _InspectionDraft _self;
  final $Res Function(_InspectionDraft) _then;

/// Create a copy of InspectionDraft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? localId = null,Object? planId = null,Object? stepId = null,Object? formTemplateId = null,Object? formVersion = null,Object? answers = null,Object? pendingEvidencePaths = null,Object? createdAt = null,Object? hasSyncError = null,Object? syncErrorMessage = freezed,}) {
  return _then(_InspectionDraft(
localId: null == localId ? _self.localId : localId // ignore: cast_nullable_to_non_nullable
as String,planId: null == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String,stepId: null == stepId ? _self.stepId : stepId // ignore: cast_nullable_to_non_nullable
as String,formTemplateId: null == formTemplateId ? _self.formTemplateId : formTemplateId // ignore: cast_nullable_to_non_nullable
as String,formVersion: null == formVersion ? _self.formVersion : formVersion // ignore: cast_nullable_to_non_nullable
as String,answers: null == answers ? _self._answers : answers // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,pendingEvidencePaths: null == pendingEvidencePaths ? _self._pendingEvidencePaths : pendingEvidencePaths // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,hasSyncError: null == hasSyncError ? _self.hasSyncError : hasSyncError // ignore: cast_nullable_to_non_nullable
as bool,syncErrorMessage: freezed == syncErrorMessage ? _self.syncErrorMessage : syncErrorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
