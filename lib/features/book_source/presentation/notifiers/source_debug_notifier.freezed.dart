// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_debug_notifier.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SourceDebugState {

/// The target the next run uses.
 SourceDebugTarget get target;/// The query the next run sends; its meaning depends on [target].
 String get query;/// Where the last run stands; [SourceDebugStatus.idle] until one has been started.
 SourceDebugStatus get status;/// The event stream, oldest first, capped at [maxSourceDebugEvents].
 List<SourceDebugEvent> get events;
/// Create a copy of SourceDebugState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourceDebugStateCopyWith<SourceDebugState> get copyWith => _$SourceDebugStateCopyWithImpl<SourceDebugState>(this as SourceDebugState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SourceDebugState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceDebugState&&(identical(other.target, _this.target) || other.target == _this.target)&&(identical(other.query, _this.query) || other.query == _this.query)&&(identical(other.status, _this.status) || other.status == _this.status)&&const DeepCollectionEquality().equals(other.events, _this.events));
}


@override
int get hashCode {
  final _this = this as SourceDebugState;
  return Object.hash(runtimeType,_this.target,_this.query,_this.status,const DeepCollectionEquality().hash(_this.events));
}

@override
String toString() {
  final _this = this as SourceDebugState;
  return 'SourceDebugState(target: ${_this.target}, query: ${_this.query}, status: ${_this.status}, events: ${_this.events})';
}


}

/// @nodoc
abstract mixin class $SourceDebugStateCopyWith<$Res>  {
  factory $SourceDebugStateCopyWith(SourceDebugState value, $Res Function(SourceDebugState) _then) = _$SourceDebugStateCopyWithImpl;
@useResult
$Res call({
 SourceDebugTarget target, String query, SourceDebugStatus status, List<SourceDebugEvent> events
});




}
/// @nodoc
class _$SourceDebugStateCopyWithImpl<$Res>
    implements $SourceDebugStateCopyWith<$Res> {
  _$SourceDebugStateCopyWithImpl(this._self, this._then);

  final SourceDebugState _self;
  final $Res Function(SourceDebugState) _then;

/// Create a copy of SourceDebugState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? target = null,Object? query = null,Object? status = null,Object? events = null,}) {
  return _then(SourceDebugState(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as SourceDebugTarget,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SourceDebugStatus,events: null == events ? _self.events : events // ignore: cast_nullable_to_non_nullable
as List<SourceDebugEvent>,
  ));
}

}


/// Adds pattern-matching-related methods to [SourceDebugState].
extension SourceDebugStatePatterns on SourceDebugState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceDebugState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceDebugState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceDebugState value)  $default,){
final _that = this;
switch (_that) {
case _SourceDebugState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceDebugState value)?  $default,){
final _that = this;
switch (_that) {
case _SourceDebugState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SourceDebugTarget target,  String query,  SourceDebugStatus status,  List<SourceDebugEvent> events)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceDebugState() when $default != null:
return $default(_that.target,_that.query,_that.status,_that.events);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SourceDebugTarget target,  String query,  SourceDebugStatus status,  List<SourceDebugEvent> events)  $default,) {final _that = this;
switch (_that) {
case _SourceDebugState():
return $default(_that.target,_that.query,_that.status,_that.events);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SourceDebugTarget target,  String query,  SourceDebugStatus status,  List<SourceDebugEvent> events)?  $default,) {final _that = this;
switch (_that) {
case _SourceDebugState() when $default != null:
return $default(_that.target,_that.query,_that.status,_that.events);case _:
  return null;

}
}

}

/// @nodoc


class _SourceDebugState implements SourceDebugState {
  const _SourceDebugState({this.target = SourceDebugTarget.search, this.query = '', this.status = SourceDebugStatus.idle,  List<SourceDebugEvent> events = const <SourceDebugEvent>[]}): _events = events;
  

/// The target the next run uses.
@override@JsonKey() final  SourceDebugTarget target;
/// The query the next run sends; its meaning depends on [target].
@override@JsonKey() final  String query;
/// Where the last run stands; [SourceDebugStatus.idle] until one has been started.
@override@JsonKey() final  SourceDebugStatus status;
/// The event stream, oldest first, capped at [maxSourceDebugEvents].
 final  List<SourceDebugEvent> _events;
/// The event stream, oldest first, capped at [maxSourceDebugEvents].
@override@JsonKey() List<SourceDebugEvent> get events {
  if (_events is EqualUnmodifiableListView) return _events;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_events);
}


/// Create a copy of SourceDebugState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceDebugStateCopyWith<_SourceDebugState> get copyWith => __$SourceDebugStateCopyWithImpl<_SourceDebugState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceDebugState&&(identical(other.target, target) || other.target == target)&&(identical(other.query, query) || other.query == query)&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.events, _events));
}


@override
int get hashCode {
    return Object.hash(runtimeType,target,query,status,const DeepCollectionEquality().hash(_events));
}

@override
String toString() {
    return 'SourceDebugState(target: $target, query: $query, status: $status, events: $events)';
}


}

/// @nodoc
abstract mixin class _$SourceDebugStateCopyWith<$Res> implements $SourceDebugStateCopyWith<$Res> {
  factory _$SourceDebugStateCopyWith(_SourceDebugState value, $Res Function(_SourceDebugState) _then) = __$SourceDebugStateCopyWithImpl;
@override @useResult
$Res call({
 SourceDebugTarget target, String query, SourceDebugStatus status, List<SourceDebugEvent> events
});




}
/// @nodoc
class __$SourceDebugStateCopyWithImpl<$Res>
    implements _$SourceDebugStateCopyWith<$Res> {
  __$SourceDebugStateCopyWithImpl(this._self, this._then);

  final _SourceDebugState _self;
  final $Res Function(_SourceDebugState) _then;

/// Create a copy of SourceDebugState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? target = null,Object? query = null,Object? status = null,Object? events = null,}) {
  return _then(_SourceDebugState(
target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as SourceDebugTarget,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SourceDebugStatus,events: null == events ? _self._events : events // ignore: cast_nullable_to_non_nullable
as List<SourceDebugEvent>,
  ));
}


}

// dart format on
