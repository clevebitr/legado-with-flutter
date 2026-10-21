// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_search_scope.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ScopeSource {

/// The name the source had when the scope was picked.
 String get name;/// `bookSourceUrl` — the identity the scope actually uses.
 String get url;
/// Create a copy of ScopeSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScopeSourceCopyWith<ScopeSource> get copyWith => _$ScopeSourceCopyWithImpl<ScopeSource>(this as ScopeSource, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ScopeSource;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScopeSource&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.url, _this.url) || other.url == _this.url));
}


@override
int get hashCode {
  final _this = this as ScopeSource;
  return Object.hash(runtimeType,_this.name,_this.url);
}

@override
String toString() {
  final _this = this as ScopeSource;
  return 'ScopeSource(name: ${_this.name}, url: ${_this.url})';
}


}

/// @nodoc
abstract mixin class $ScopeSourceCopyWith<$Res>  {
  factory $ScopeSourceCopyWith(ScopeSource value, $Res Function(ScopeSource) _then) = _$ScopeSourceCopyWithImpl;
@useResult
$Res call({
 String name, String url
});




}
/// @nodoc
class _$ScopeSourceCopyWithImpl<$Res>
    implements $ScopeSourceCopyWith<$Res> {
  _$ScopeSourceCopyWithImpl(this._self, this._then);

  final ScopeSource _self;
  final $Res Function(ScopeSource) _then;

/// Create a copy of ScopeSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? url = null,}) {
  return _then(ScopeSource(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ScopeSource].
extension ScopeSourcePatterns on ScopeSource {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScopeSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScopeSource() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScopeSource value)  $default,){
final _that = this;
switch (_that) {
case _ScopeSource():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScopeSource value)?  $default,){
final _that = this;
switch (_that) {
case _ScopeSource() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String url)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScopeSource() when $default != null:
return $default(_that.name,_that.url);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String url)  $default,) {final _that = this;
switch (_that) {
case _ScopeSource():
return $default(_that.name,_that.url);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String url)?  $default,) {final _that = this;
switch (_that) {
case _ScopeSource() when $default != null:
return $default(_that.name,_that.url);case _:
  return null;

}
}

}

/// @nodoc


class _ScopeSource implements ScopeSource {
  const _ScopeSource({required this.name, required this.url});
  

/// The name the source had when the scope was picked.
@override final  String name;
/// `bookSourceUrl` — the identity the scope actually uses.
@override final  String url;

/// Create a copy of ScopeSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScopeSourceCopyWith<_ScopeSource> get copyWith => __$ScopeSourceCopyWithImpl<_ScopeSource>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScopeSource&&(identical(other.name, name) || other.name == name)&&(identical(other.url, url) || other.url == url));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,url);
}

@override
String toString() {
    return 'ScopeSource(name: $name, url: $url)';
}


}

/// @nodoc
abstract mixin class _$ScopeSourceCopyWith<$Res> implements $ScopeSourceCopyWith<$Res> {
  factory _$ScopeSourceCopyWith(_ScopeSource value, $Res Function(_ScopeSource) _then) = __$ScopeSourceCopyWithImpl;
@override @useResult
$Res call({
 String name, String url
});




}
/// @nodoc
class __$ScopeSourceCopyWithImpl<$Res>
    implements _$ScopeSourceCopyWith<$Res> {
  __$ScopeSourceCopyWithImpl(this._self, this._then);

  final _ScopeSource _self;
  final $Res Function(_ScopeSource) _then;

/// Create a copy of ScopeSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? url = null,}) {
  return _then(_ScopeSource(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$BookSearchScope {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSearchScope);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BookSearchScope()';
}


}

/// @nodoc
class $BookSearchScopeCopyWith<$Res>  {
$BookSearchScopeCopyWith(BookSearchScope _, $Res Function(BookSearchScope) __);
}


/// Adds pattern-matching-related methods to [BookSearchScope].
extension BookSearchScopePatterns on BookSearchScope {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( SearchScopeAll value)?  all,TResult Function( SearchScopeGroups value)?  groups,TResult Function( SearchScopeSources value)?  sources,required TResult orElse(),}){
final _that = this;
switch (_that) {
case SearchScopeAll() when all != null:
return all(_that);case SearchScopeGroups() when groups != null:
return groups(_that);case SearchScopeSources() when sources != null:
return sources(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( SearchScopeAll value)  all,required TResult Function( SearchScopeGroups value)  groups,required TResult Function( SearchScopeSources value)  sources,}){
final _that = this;
switch (_that) {
case SearchScopeAll():
return all(_that);case SearchScopeGroups():
return groups(_that);case SearchScopeSources():
return sources(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( SearchScopeAll value)?  all,TResult? Function( SearchScopeGroups value)?  groups,TResult? Function( SearchScopeSources value)?  sources,}){
final _that = this;
switch (_that) {
case SearchScopeAll() when all != null:
return all(_that);case SearchScopeGroups() when groups != null:
return groups(_that);case SearchScopeSources() when sources != null:
return sources(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  all,TResult Function( Set<String> groups)?  groups,TResult Function( List<ScopeSource> sources)?  sources,required TResult orElse(),}) {final _that = this;
switch (_that) {
case SearchScopeAll() when all != null:
return all();case SearchScopeGroups() when groups != null:
return groups(_that.groups);case SearchScopeSources() when sources != null:
return sources(_that.sources);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  all,required TResult Function( Set<String> groups)  groups,required TResult Function( List<ScopeSource> sources)  sources,}) {final _that = this;
switch (_that) {
case SearchScopeAll():
return all();case SearchScopeGroups():
return groups(_that.groups);case SearchScopeSources():
return sources(_that.sources);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  all,TResult? Function( Set<String> groups)?  groups,TResult? Function( List<ScopeSource> sources)?  sources,}) {final _that = this;
switch (_that) {
case SearchScopeAll() when all != null:
return all();case SearchScopeGroups() when groups != null:
return groups(_that.groups);case SearchScopeSources() when sources != null:
return sources(_that.sources);case _:
  return null;

}
}

}

/// @nodoc


class SearchScopeAll extends BookSearchScope {
  const SearchScopeAll(): super._();
  






@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchScopeAll);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'BookSearchScope.all()';
}


}




/// @nodoc


class SearchScopeGroups extends BookSearchScope {
  const SearchScopeGroups( Set<String> groups): _groups = groups,super._();
  

 final  Set<String> _groups;
 Set<String> get groups {
  if (_groups is EqualUnmodifiableSetView) return _groups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_groups);
}


/// Create a copy of BookSearchScope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchScopeGroupsCopyWith<SearchScopeGroups> get copyWith => _$SearchScopeGroupsCopyWithImpl<SearchScopeGroups>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchScopeGroups&&const DeepCollectionEquality().equals(other.groups, _groups));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_groups));
}

@override
String toString() {
    return 'BookSearchScope.groups(groups: $groups)';
}


}

/// @nodoc
abstract mixin class $SearchScopeGroupsCopyWith<$Res> implements $BookSearchScopeCopyWith<$Res> {
  factory $SearchScopeGroupsCopyWith(SearchScopeGroups value, $Res Function(SearchScopeGroups) _then) = _$SearchScopeGroupsCopyWithImpl;
@useResult
$Res call({
 Set<String> groups
});




}
/// @nodoc
class _$SearchScopeGroupsCopyWithImpl<$Res>
    implements $SearchScopeGroupsCopyWith<$Res> {
  _$SearchScopeGroupsCopyWithImpl(this._self, this._then);

  final SearchScopeGroups _self;
  final $Res Function(SearchScopeGroups) _then;

/// Create a copy of BookSearchScope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? groups = null,}) {
  return _then(SearchScopeGroups(
null == groups ? _self._groups : groups // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}


}

/// @nodoc


class SearchScopeSources extends BookSearchScope {
  const SearchScopeSources( List<ScopeSource> sources): _sources = sources,super._();
  

 final  List<ScopeSource> _sources;
 List<ScopeSource> get sources {
  if (_sources is EqualUnmodifiableListView) return _sources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sources);
}


/// Create a copy of BookSearchScope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchScopeSourcesCopyWith<SearchScopeSources> get copyWith => _$SearchScopeSourcesCopyWithImpl<SearchScopeSources>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchScopeSources&&const DeepCollectionEquality().equals(other.sources, _sources));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_sources));
}

@override
String toString() {
    return 'BookSearchScope.sources(sources: $sources)';
}


}

/// @nodoc
abstract mixin class $SearchScopeSourcesCopyWith<$Res> implements $BookSearchScopeCopyWith<$Res> {
  factory $SearchScopeSourcesCopyWith(SearchScopeSources value, $Res Function(SearchScopeSources) _then) = _$SearchScopeSourcesCopyWithImpl;
@useResult
$Res call({
 List<ScopeSource> sources
});




}
/// @nodoc
class _$SearchScopeSourcesCopyWithImpl<$Res>
    implements $SearchScopeSourcesCopyWith<$Res> {
  _$SearchScopeSourcesCopyWithImpl(this._self, this._then);

  final SearchScopeSources _self;
  final $Res Function(SearchScopeSources) _then;

/// Create a copy of BookSearchScope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? sources = null,}) {
  return _then(SearchScopeSources(
null == sources ? _self._sources : sources // ignore: cast_nullable_to_non_nullable
as List<ScopeSource>,
  ));
}


}

// dart format on
