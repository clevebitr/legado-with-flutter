// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_variable_dao.dart';

// ignore_for_file: type=lint
mixin _$SourceVariableDaoMixin on DatabaseAccessor<ReaderDatabase> {
  $SourceVariablesTable get sourceVariables => attachedDatabase.sourceVariables;
  SourceVariableDaoManager get managers => SourceVariableDaoManager(this);
}

class SourceVariableDaoManager {
  final _$SourceVariableDaoMixin _db;
  SourceVariableDaoManager(this._db);
  $$SourceVariablesTableTableManager get sourceVariables =>
      $$SourceVariablesTableTableManager(
        _db.attachedDatabase,
        _db.sourceVariables,
      );
}
