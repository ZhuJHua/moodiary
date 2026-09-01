// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'llm_provider.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetLlmProviderCollection on Isar {
  IsarCollection<String, LlmProvider> get llmProviders => this.collection();
}

final LlmProviderSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'LlmProvider',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'isPreset', type: IsarType.bool),
      IsarPropertySchema(
        name: 'protocol',
        type: IsarType.byte,

        enumMap: {
          "openaiCompletions": 0,
          "openaiResponses": 1,
          "anthropicMessages": 2,
        },
      ),
      IsarPropertySchema(name: 'id', type: IsarType.string),
      IsarPropertySchema(name: 'name', type: IsarType.string),
      IsarPropertySchema(name: 'type', type: IsarType.string),
      IsarPropertySchema(name: 'baseUrl', type: IsarType.string),
      IsarPropertySchema(name: 'defaultModel', type: IsarType.string),
      IsarPropertySchema(name: 'createdAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'sortOrder', type: IsarType.long),
      IsarPropertySchema(name: 'presetId', type: IsarType.string),
      IsarPropertySchema(name: 'models', type: IsarType.stringList),
      IsarPropertySchema(name: 'toolCall', type: IsarType.bool),
      IsarPropertySchema(name: 'reasoning', type: IsarType.bool),
      IsarPropertySchema(name: 'attachment', type: IsarType.bool),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<String, LlmProvider>(
    serialize: serializeLlmProvider,
    deserialize: deserializeLlmProvider,
    deserializeProperty: deserializeLlmProviderProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeLlmProvider(IsarWriter writer, LlmProvider object) {
  IsarCore.writeBool(writer, 1, value: object.isPreset);
  IsarCore.writeByte(writer, 2, object.protocol.index);
  IsarCore.writeString(writer, 3, object.id);
  IsarCore.writeString(writer, 4, object.name);
  IsarCore.writeString(writer, 5, object.type);
  IsarCore.writeString(writer, 6, object.baseUrl);
  IsarCore.writeString(writer, 7, object.defaultModel);
  IsarCore.writeLong(
    writer,
    8,
    object.createdAt.toUtc().microsecondsSinceEpoch,
  );
  IsarCore.writeLong(writer, 9, object.sortOrder);
  IsarCore.writeString(writer, 10, object.presetId);
  {
    final list = object.models;
    final listWriter = IsarCore.beginList(writer, 11, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeString(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  IsarCore.writeBool(writer, 12, value: object.toolCall);
  IsarCore.writeBool(writer, 13, value: object.reasoning);
  IsarCore.writeBool(writer, 14, value: object.attachment);
  return Isar.fastHash(object.id);
}

@isarProtected
LlmProvider deserializeLlmProvider(IsarReader reader) {
  final String _id;
  _id = IsarCore.readString(reader, 3) ?? '';
  final String _name;
  _name = IsarCore.readString(reader, 4) ?? '';
  final String _type;
  _type = IsarCore.readString(reader, 5) ?? '';
  final String _baseUrl;
  _baseUrl = IsarCore.readString(reader, 6) ?? '';
  final String _defaultModel;
  _defaultModel = IsarCore.readString(reader, 7) ?? '';
  final DateTime _createdAt;
  {
    final value = IsarCore.readLong(reader, 8);
    if (value == -9223372036854775808) {
      _createdAt = DateTime.fromMillisecondsSinceEpoch(
        0,
        isUtc: true,
      ).toLocal();
    } else {
      _createdAt = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  final int _sortOrder;
  _sortOrder = IsarCore.readLong(reader, 9);
  final String _presetId;
  _presetId = IsarCore.readString(reader, 10) ?? '';
  final List<String> _models;
  {
    final length = IsarCore.readList(reader, 11, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        _models = const <String>[];
      } else {
        final list = List<String>.filled(length, '', growable: true);
        for (var i = 0; i < length; i++) {
          list[i] = IsarCore.readString(reader, i) ?? '';
        }
        IsarCore.freeReader(reader);
        _models = list;
      }
    }
  }
  final bool _toolCall;
  _toolCall = IsarCore.readBool(reader, 12);
  final bool _reasoning;
  _reasoning = IsarCore.readBool(reader, 13);
  final bool _attachment;
  _attachment = IsarCore.readBool(reader, 14);
  final object = LlmProvider(
    id: _id,
    name: _name,
    type: _type,
    baseUrl: _baseUrl,
    defaultModel: _defaultModel,
    createdAt: _createdAt,
    sortOrder: _sortOrder,
    presetId: _presetId,
    models: _models,
    toolCall: _toolCall,
    reasoning: _reasoning,
    attachment: _attachment,
  );
  return object;
}

@isarProtected
dynamic deserializeLlmProviderProp(IsarReader reader, int property) {
  switch (property) {
    case 1:
      return IsarCore.readBool(reader, 1);
    case 2:
      {
        if (IsarCore.readNull(reader, 2)) {
          return AssistantProviderType.openaiCompletions;
        } else {
          return _llmProviderProtocol[IsarCore.readByte(reader, 2)] ??
              AssistantProviderType.openaiCompletions;
        }
      }
    case 3:
      return IsarCore.readString(reader, 3) ?? '';
    case 4:
      return IsarCore.readString(reader, 4) ?? '';
    case 5:
      return IsarCore.readString(reader, 5) ?? '';
    case 6:
      return IsarCore.readString(reader, 6) ?? '';
    case 7:
      return IsarCore.readString(reader, 7) ?? '';
    case 8:
      {
        final value = IsarCore.readLong(reader, 8);
        if (value == -9223372036854775808) {
          return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(
            value,
            isUtc: true,
          ).toLocal();
        }
      }
    case 9:
      return IsarCore.readLong(reader, 9);
    case 10:
      return IsarCore.readString(reader, 10) ?? '';
    case 11:
      {
        final length = IsarCore.readList(reader, 11, IsarCore.readerPtrPtr);
        {
          final reader = IsarCore.readerPtr;
          if (reader.isNull) {
            return const <String>[];
          } else {
            final list = List<String>.filled(length, '', growable: true);
            for (var i = 0; i < length; i++) {
              list[i] = IsarCore.readString(reader, i) ?? '';
            }
            IsarCore.freeReader(reader);
            return list;
          }
        }
      }
    case 12:
      return IsarCore.readBool(reader, 12);
    case 13:
      return IsarCore.readBool(reader, 13);
    case 14:
      return IsarCore.readBool(reader, 14);
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _LlmProviderUpdate {
  bool call({
    required String id,
    bool? isPreset,
    AssistantProviderType? protocol,
    String? name,
    String? type,
    String? baseUrl,
    String? defaultModel,
    DateTime? createdAt,
    int? sortOrder,
    String? presetId,
    bool? toolCall,
    bool? reasoning,
    bool? attachment,
  });
}

class _LlmProviderUpdateImpl implements _LlmProviderUpdate {
  const _LlmProviderUpdateImpl(this.collection);

  final IsarCollection<String, LlmProvider> collection;

  @override
  bool call({
    required String id,
    Object? isPreset = ignore,
    Object? protocol = ignore,
    Object? name = ignore,
    Object? type = ignore,
    Object? baseUrl = ignore,
    Object? defaultModel = ignore,
    Object? createdAt = ignore,
    Object? sortOrder = ignore,
    Object? presetId = ignore,
    Object? toolCall = ignore,
    Object? reasoning = ignore,
    Object? attachment = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (isPreset != ignore) 1: isPreset as bool?,
            if (protocol != ignore) 2: protocol as AssistantProviderType?,
            if (name != ignore) 4: name as String?,
            if (type != ignore) 5: type as String?,
            if (baseUrl != ignore) 6: baseUrl as String?,
            if (defaultModel != ignore) 7: defaultModel as String?,
            if (createdAt != ignore) 8: createdAt as DateTime?,
            if (sortOrder != ignore) 9: sortOrder as int?,
            if (presetId != ignore) 10: presetId as String?,
            if (toolCall != ignore) 12: toolCall as bool?,
            if (reasoning != ignore) 13: reasoning as bool?,
            if (attachment != ignore) 14: attachment as bool?,
          },
        ) >
        0;
  }
}

sealed class _LlmProviderUpdateAll {
  int call({
    required List<String> id,
    bool? isPreset,
    AssistantProviderType? protocol,
    String? name,
    String? type,
    String? baseUrl,
    String? defaultModel,
    DateTime? createdAt,
    int? sortOrder,
    String? presetId,
    bool? toolCall,
    bool? reasoning,
    bool? attachment,
  });
}

class _LlmProviderUpdateAllImpl implements _LlmProviderUpdateAll {
  const _LlmProviderUpdateAllImpl(this.collection);

  final IsarCollection<String, LlmProvider> collection;

  @override
  int call({
    required List<String> id,
    Object? isPreset = ignore,
    Object? protocol = ignore,
    Object? name = ignore,
    Object? type = ignore,
    Object? baseUrl = ignore,
    Object? defaultModel = ignore,
    Object? createdAt = ignore,
    Object? sortOrder = ignore,
    Object? presetId = ignore,
    Object? toolCall = ignore,
    Object? reasoning = ignore,
    Object? attachment = ignore,
  }) {
    return collection.updateProperties(id, {
      if (isPreset != ignore) 1: isPreset as bool?,
      if (protocol != ignore) 2: protocol as AssistantProviderType?,
      if (name != ignore) 4: name as String?,
      if (type != ignore) 5: type as String?,
      if (baseUrl != ignore) 6: baseUrl as String?,
      if (defaultModel != ignore) 7: defaultModel as String?,
      if (createdAt != ignore) 8: createdAt as DateTime?,
      if (sortOrder != ignore) 9: sortOrder as int?,
      if (presetId != ignore) 10: presetId as String?,
      if (toolCall != ignore) 12: toolCall as bool?,
      if (reasoning != ignore) 13: reasoning as bool?,
      if (attachment != ignore) 14: attachment as bool?,
    });
  }
}

extension LlmProviderUpdate on IsarCollection<String, LlmProvider> {
  _LlmProviderUpdate get update => _LlmProviderUpdateImpl(this);

  _LlmProviderUpdateAll get updateAll => _LlmProviderUpdateAllImpl(this);
}

sealed class _LlmProviderQueryUpdate {
  int call({
    bool? isPreset,
    AssistantProviderType? protocol,
    String? name,
    String? type,
    String? baseUrl,
    String? defaultModel,
    DateTime? createdAt,
    int? sortOrder,
    String? presetId,
    bool? toolCall,
    bool? reasoning,
    bool? attachment,
  });
}

class _LlmProviderQueryUpdateImpl implements _LlmProviderQueryUpdate {
  const _LlmProviderQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<LlmProvider> query;
  final int? limit;

  @override
  int call({
    Object? isPreset = ignore,
    Object? protocol = ignore,
    Object? name = ignore,
    Object? type = ignore,
    Object? baseUrl = ignore,
    Object? defaultModel = ignore,
    Object? createdAt = ignore,
    Object? sortOrder = ignore,
    Object? presetId = ignore,
    Object? toolCall = ignore,
    Object? reasoning = ignore,
    Object? attachment = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (isPreset != ignore) 1: isPreset as bool?,
      if (protocol != ignore) 2: protocol as AssistantProviderType?,
      if (name != ignore) 4: name as String?,
      if (type != ignore) 5: type as String?,
      if (baseUrl != ignore) 6: baseUrl as String?,
      if (defaultModel != ignore) 7: defaultModel as String?,
      if (createdAt != ignore) 8: createdAt as DateTime?,
      if (sortOrder != ignore) 9: sortOrder as int?,
      if (presetId != ignore) 10: presetId as String?,
      if (toolCall != ignore) 12: toolCall as bool?,
      if (reasoning != ignore) 13: reasoning as bool?,
      if (attachment != ignore) 14: attachment as bool?,
    });
  }
}

extension LlmProviderQueryUpdate on IsarQuery<LlmProvider> {
  _LlmProviderQueryUpdate get updateFirst =>
      _LlmProviderQueryUpdateImpl(this, limit: 1);

  _LlmProviderQueryUpdate get updateAll => _LlmProviderQueryUpdateImpl(this);
}

class _LlmProviderQueryBuilderUpdateImpl implements _LlmProviderQueryUpdate {
  const _LlmProviderQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<LlmProvider, LlmProvider, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? isPreset = ignore,
    Object? protocol = ignore,
    Object? name = ignore,
    Object? type = ignore,
    Object? baseUrl = ignore,
    Object? defaultModel = ignore,
    Object? createdAt = ignore,
    Object? sortOrder = ignore,
    Object? presetId = ignore,
    Object? toolCall = ignore,
    Object? reasoning = ignore,
    Object? attachment = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (isPreset != ignore) 1: isPreset as bool?,
        if (protocol != ignore) 2: protocol as AssistantProviderType?,
        if (name != ignore) 4: name as String?,
        if (type != ignore) 5: type as String?,
        if (baseUrl != ignore) 6: baseUrl as String?,
        if (defaultModel != ignore) 7: defaultModel as String?,
        if (createdAt != ignore) 8: createdAt as DateTime?,
        if (sortOrder != ignore) 9: sortOrder as int?,
        if (presetId != ignore) 10: presetId as String?,
        if (toolCall != ignore) 12: toolCall as bool?,
        if (reasoning != ignore) 13: reasoning as bool?,
        if (attachment != ignore) 14: attachment as bool?,
      });
    } finally {
      q.close();
    }
  }
}

extension LlmProviderQueryBuilderUpdate
    on QueryBuilder<LlmProvider, LlmProvider, QOperations> {
  _LlmProviderQueryUpdate get updateFirst =>
      _LlmProviderQueryBuilderUpdateImpl(this, limit: 1);

  _LlmProviderQueryUpdate get updateAll =>
      _LlmProviderQueryBuilderUpdateImpl(this);
}

const _llmProviderProtocol = {
  0: AssistantProviderType.openaiCompletions,
  1: AssistantProviderType.openaiResponses,
  2: AssistantProviderType.anthropicMessages,
};

extension LlmProviderQueryFilter
    on QueryBuilder<LlmProvider, LlmProvider, QFilterCondition> {
  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> isPresetEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> protocolEqualTo(
    AssistantProviderType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value.index),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  protocolGreaterThan(AssistantProviderType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 2, value: value.index),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  protocolGreaterThanOrEqualTo(AssistantProviderType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 2, value: value.index),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  protocolLessThan(AssistantProviderType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value.index),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  protocolLessThanOrEqualTo(AssistantProviderType value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 2, value: value.index),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> protocolBetween(
    AssistantProviderType lower,
    AssistantProviderType upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 2, lower: lower.index, upper: upper.index),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> idGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  idGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> idLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  idLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> idBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 3,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> idStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> idEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> idContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> idMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 3,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  nameGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> nameLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 4, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  nameLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 4,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> nameContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> nameMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 4,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 4, value: ''),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> typeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> typeGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  typeGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> typeLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  typeLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> typeBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 5,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> typeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> typeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> typeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> typeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 5,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> typeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  typeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> baseUrlEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  baseUrlGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  baseUrlGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> baseUrlLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 6, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  baseUrlLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> baseUrlBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 6,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  baseUrlStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> baseUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> baseUrlContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 6,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> baseUrlMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 6,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  baseUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 6, value: ''),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  baseUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 6, value: ''),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  defaultModelEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  defaultModelGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  defaultModelGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  defaultModelLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  defaultModelLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  defaultModelBetween(String lower, String upper, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 7,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  defaultModelStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  defaultModelEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  defaultModelContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 7,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  defaultModelMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 7,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  defaultModelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  defaultModelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  createdAtGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  createdAtLessThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 8, value: value));
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  createdAtLessThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  createdAtBetween(DateTime lower, DateTime upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 8, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  sortOrderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  sortOrderGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  sortOrderGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  sortOrderLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 9, value: value));
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  sortOrderLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 9, value: value),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  sortOrderBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 9, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> presetIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 10,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  presetIdGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 10,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  presetIdGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 10,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  presetIdLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 10, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  presetIdLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 10,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> presetIdBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 10,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  presetIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 10,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  presetIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 10,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  presetIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 10,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> presetIdMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 10,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  presetIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 10, value: ''),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  presetIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 10, value: ''),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  modelsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  modelsElementGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  modelsElementGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  modelsElementLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 11, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  modelsElementLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  modelsElementBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 11,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  modelsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  modelsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  modelsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 11,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  modelsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 11,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  modelsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 11, value: ''),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  modelsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 11, value: ''),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  modelsIsEmpty() {
    return not().modelsIsNotEmpty();
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  modelsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 11, value: null),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition> toolCallEqualTo(
    bool value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 12, value: value),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  reasoningEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 13, value: value),
      );
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterFilterCondition>
  attachmentEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 14, value: value),
      );
    });
  }
}

extension LlmProviderQueryObject
    on QueryBuilder<LlmProvider, LlmProvider, QFilterCondition> {}

extension LlmProviderQuerySortBy
    on QueryBuilder<LlmProvider, LlmProvider, QSortBy> {
  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByIsPreset() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByIsPresetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByProtocol() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByProtocolDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortById({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByTypeDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByBaseUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByBaseUrlDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByDefaultModel({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByDefaultModelDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByPresetId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByPresetIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByToolCall() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByToolCallDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12, sort: Sort.desc);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByReasoning() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(13);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByReasoningDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(13, sort: Sort.desc);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByAttachment() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(14);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> sortByAttachmentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(14, sort: Sort.desc);
    });
  }
}

extension LlmProviderQuerySortThenBy
    on QueryBuilder<LlmProvider, LlmProvider, QSortThenBy> {
  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByIsPreset() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByIsPresetDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByProtocol() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByProtocolDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenById({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByTypeDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByBaseUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByBaseUrlDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(6, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByDefaultModel({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByDefaultModelDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(7, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenBySortOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(9, sort: Sort.desc);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByPresetId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByPresetIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(10, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByToolCall() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByToolCallDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(12, sort: Sort.desc);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByReasoning() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(13);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByReasoningDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(13, sort: Sort.desc);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByAttachment() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(14);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterSortBy> thenByAttachmentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(14, sort: Sort.desc);
    });
  }
}

extension LlmProviderQueryWhereDistinct
    on QueryBuilder<LlmProvider, LlmProvider, QDistinct> {
  QueryBuilder<LlmProvider, LlmProvider, QAfterDistinct> distinctByIsPreset() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterDistinct> distinctByProtocol() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterDistinct> distinctByType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterDistinct> distinctByBaseUrl({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterDistinct>
  distinctByDefaultModel({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterDistinct> distinctBySortOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(9);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterDistinct> distinctByPresetId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(10, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterDistinct> distinctByModels() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(11);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterDistinct> distinctByToolCall() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(12);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterDistinct> distinctByReasoning() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(13);
    });
  }

  QueryBuilder<LlmProvider, LlmProvider, QAfterDistinct>
  distinctByAttachment() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(14);
    });
  }
}

extension LlmProviderQueryProperty1
    on QueryBuilder<LlmProvider, LlmProvider, QProperty> {
  QueryBuilder<LlmProvider, bool, QAfterProperty> isPresetProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<LlmProvider, AssistantProviderType, QAfterProperty>
  protocolProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<LlmProvider, String, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<LlmProvider, String, QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<LlmProvider, String, QAfterProperty> typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<LlmProvider, String, QAfterProperty> baseUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<LlmProvider, String, QAfterProperty> defaultModelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<LlmProvider, DateTime, QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<LlmProvider, int, QAfterProperty> sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<LlmProvider, String, QAfterProperty> presetIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<LlmProvider, List<String>, QAfterProperty> modelsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }

  QueryBuilder<LlmProvider, bool, QAfterProperty> toolCallProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(12);
    });
  }

  QueryBuilder<LlmProvider, bool, QAfterProperty> reasoningProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(13);
    });
  }

  QueryBuilder<LlmProvider, bool, QAfterProperty> attachmentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(14);
    });
  }
}

extension LlmProviderQueryProperty2<R>
    on QueryBuilder<LlmProvider, R, QAfterProperty> {
  QueryBuilder<LlmProvider, (R, bool), QAfterProperty> isPresetProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<LlmProvider, (R, AssistantProviderType), QAfterProperty>
  protocolProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<LlmProvider, (R, String), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<LlmProvider, (R, String), QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<LlmProvider, (R, String), QAfterProperty> typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<LlmProvider, (R, String), QAfterProperty> baseUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<LlmProvider, (R, String), QAfterProperty>
  defaultModelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<LlmProvider, (R, DateTime), QAfterProperty> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<LlmProvider, (R, int), QAfterProperty> sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<LlmProvider, (R, String), QAfterProperty> presetIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<LlmProvider, (R, List<String>), QAfterProperty>
  modelsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }

  QueryBuilder<LlmProvider, (R, bool), QAfterProperty> toolCallProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(12);
    });
  }

  QueryBuilder<LlmProvider, (R, bool), QAfterProperty> reasoningProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(13);
    });
  }

  QueryBuilder<LlmProvider, (R, bool), QAfterProperty> attachmentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(14);
    });
  }
}

extension LlmProviderQueryProperty3<R1, R2>
    on QueryBuilder<LlmProvider, (R1, R2), QAfterProperty> {
  QueryBuilder<LlmProvider, (R1, R2, bool), QOperations> isPresetProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<LlmProvider, (R1, R2, AssistantProviderType), QOperations>
  protocolProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<LlmProvider, (R1, R2, String), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<LlmProvider, (R1, R2, String), QOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<LlmProvider, (R1, R2, String), QOperations> typeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<LlmProvider, (R1, R2, String), QOperations> baseUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<LlmProvider, (R1, R2, String), QOperations>
  defaultModelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<LlmProvider, (R1, R2, DateTime), QOperations>
  createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }

  QueryBuilder<LlmProvider, (R1, R2, int), QOperations> sortOrderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(9);
    });
  }

  QueryBuilder<LlmProvider, (R1, R2, String), QOperations> presetIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(10);
    });
  }

  QueryBuilder<LlmProvider, (R1, R2, List<String>), QOperations>
  modelsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(11);
    });
  }

  QueryBuilder<LlmProvider, (R1, R2, bool), QOperations> toolCallProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(12);
    });
  }

  QueryBuilder<LlmProvider, (R1, R2, bool), QOperations> reasoningProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(13);
    });
  }

  QueryBuilder<LlmProvider, (R1, R2, bool), QOperations> attachmentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(14);
    });
  }
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LlmProvider _$LlmProviderFromJson(Map<String, dynamic> json) => _LlmProvider(
  id: json['id'] as String,
  name: json['name'] as String,
  type: json['type'] as String,
  baseUrl: json['baseUrl'] as String,
  defaultModel: json['defaultModel'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  sortOrder: (json['sortOrder'] as num).toInt(),
  presetId: json['presetId'] as String? ?? '',
  models:
      (json['models'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  toolCall: json['toolCall'] as bool? ?? false,
  reasoning: json['reasoning'] as bool? ?? false,
  attachment: json['attachment'] as bool? ?? false,
);

Map<String, dynamic> _$LlmProviderToJson(_LlmProvider instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': instance.type,
      'baseUrl': instance.baseUrl,
      'defaultModel': instance.defaultModel,
      'createdAt': instance.createdAt.toIso8601String(),
      'sortOrder': instance.sortOrder,
      'presetId': instance.presetId,
      'models': instance.models,
      'toolCall': instance.toolCall,
      'reasoning': instance.reasoning,
      'attachment': instance.attachment,
    };
