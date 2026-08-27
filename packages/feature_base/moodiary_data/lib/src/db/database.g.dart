// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class DiaryFts extends Table
    with TableInfo<DiaryFts, DiaryFt>, VirtualTableInfo<DiaryFts, DiaryFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DiaryFts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleTokMeta = const VerificationMeta(
    'titleTok',
  );
  late final GeneratedColumn<String> titleTok = GeneratedColumn<String>(
    'title_tok',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _bodyTokMeta = const VerificationMeta(
    'bodyTok',
  );
  late final GeneratedColumn<String> bodyTok = GeneratedColumn<String>(
    'body_tok',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [titleTok, bodyTok];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_fts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryFt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title_tok')) {
      context.handle(
        _titleTokMeta,
        titleTok.isAcceptableOrUnknown(data['title_tok']!, _titleTokMeta),
      );
    }
    if (data.containsKey('body_tok')) {
      context.handle(
        _bodyTokMeta,
        bodyTok.isAcceptableOrUnknown(data['body_tok']!, _bodyTokMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  DiaryFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryFt(
      titleTok: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_tok'],
      ),
      bodyTok: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_tok'],
      ),
    );
  }

  @override
  DiaryFts createAlias(String alias) {
    return DiaryFts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(title_tok, body_tok, content=\'\', contentless_delete=1, tokenize=\'unicode61\', prefix=\'2\', detail=full, columnsize=1)';
}

class DiaryFt extends DataClass implements Insertable<DiaryFt> {
  final String? titleTok;
  final String? bodyTok;
  const DiaryFt({this.titleTok, this.bodyTok});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || titleTok != null) {
      map['title_tok'] = Variable<String>(titleTok);
    }
    if (!nullToAbsent || bodyTok != null) {
      map['body_tok'] = Variable<String>(bodyTok);
    }
    return map;
  }

  DiaryFtsCompanion toCompanion(bool nullToAbsent) {
    return DiaryFtsCompanion(
      titleTok: titleTok == null && nullToAbsent
          ? const Value.absent()
          : Value(titleTok),
      bodyTok: bodyTok == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyTok),
    );
  }

  factory DiaryFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryFt(
      titleTok: serializer.fromJson<String?>(json['title_tok']),
      bodyTok: serializer.fromJson<String?>(json['body_tok']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'title_tok': serializer.toJson<String?>(titleTok),
      'body_tok': serializer.toJson<String?>(bodyTok),
    };
  }

  DiaryFt copyWith({
    Value<String?> titleTok = const Value.absent(),
    Value<String?> bodyTok = const Value.absent(),
  }) => DiaryFt(
    titleTok: titleTok.present ? titleTok.value : this.titleTok,
    bodyTok: bodyTok.present ? bodyTok.value : this.bodyTok,
  );
  DiaryFt copyWithCompanion(DiaryFtsCompanion data) {
    return DiaryFt(
      titleTok: data.titleTok.present ? data.titleTok.value : this.titleTok,
      bodyTok: data.bodyTok.present ? data.bodyTok.value : this.bodyTok,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryFt(')
          ..write('titleTok: $titleTok, ')
          ..write('bodyTok: $bodyTok')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(titleTok, bodyTok);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryFt &&
          other.titleTok == this.titleTok &&
          other.bodyTok == this.bodyTok);
}

class DiaryFtsCompanion extends UpdateCompanion<DiaryFt> {
  final Value<String?> titleTok;
  final Value<String?> bodyTok;
  final Value<int> rowid;
  const DiaryFtsCompanion({
    this.titleTok = const Value.absent(),
    this.bodyTok = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiaryFtsCompanion.insert({
    this.titleTok = const Value.absent(),
    this.bodyTok = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  static Insertable<DiaryFt> custom({
    Expression<String>? titleTok,
    Expression<String>? bodyTok,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (titleTok != null) 'title_tok': titleTok,
      if (bodyTok != null) 'body_tok': bodyTok,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiaryFtsCompanion copyWith({
    Value<String?>? titleTok,
    Value<String?>? bodyTok,
    Value<int>? rowid,
  }) {
    return DiaryFtsCompanion(
      titleTok: titleTok ?? this.titleTok,
      bodyTok: bodyTok ?? this.bodyTok,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (titleTok.present) {
      map['title_tok'] = Variable<String>(titleTok.value);
    }
    if (bodyTok.present) {
      map['body_tok'] = Variable<String>(bodyTok.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryFtsCompanion(')
          ..write('titleTok: $titleTok, ')
          ..write('bodyTok: $bodyTok, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Diaries extends Table with TableInfo<Diaries, DiaryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Diaries(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ridMeta = const VerificationMeta('rid');
  late final GeneratedColumn<int> rid = GeneratedColumn<int>(
    'rid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'PRIMARY KEY',
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE',
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _contentTextMeta = const VerificationMeta(
    'contentText',
  );
  late final GeneratedColumn<String> contentText = GeneratedColumn<String>(
    'content_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  late final GeneratedColumn<int> time = GeneratedColumn<int>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  late final GeneratedColumn<int> lastModified = GeneratedColumn<int>(
    'last_modified',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _showMeta = const VerificationMeta('show');
  late final GeneratedColumn<int> show = GeneratedColumn<int>(
    'show',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _moodMeta = const VerificationMeta('mood');
  late final GeneratedColumn<double> mood = GeneratedColumn<double>(
    'mood',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _aspectMeta = const VerificationMeta('aspect');
  late final GeneratedColumn<double> aspect = GeneratedColumn<double>(
    'aspect',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _placeNameMeta = const VerificationMeta(
    'placeName',
  );
  late final GeneratedColumn<String> placeName = GeneratedColumn<String>(
    'place_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _weatherIconMeta = const VerificationMeta(
    'weatherIcon',
  );
  late final GeneratedColumn<String> weatherIcon = GeneratedColumn<String>(
    'weather_icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _weatherTempMeta = const VerificationMeta(
    'weatherTemp',
  );
  late final GeneratedColumn<String> weatherTemp = GeneratedColumn<String>(
    'weather_temp',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _weatherTextMeta = const VerificationMeta(
    'weatherText',
  );
  late final GeneratedColumn<String> weatherText = GeneratedColumn<String>(
    'weather_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    rid,
    id,
    categoryId,
    title,
    content,
    contentText,
    time,
    lastModified,
    show,
    mood,
    type,
    aspect,
    latitude,
    longitude,
    placeName,
    weatherIcon,
    weatherTemp,
    weatherText,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('rid')) {
      context.handle(
        _ridMeta,
        rid.isAcceptableOrUnknown(data['rid']!, _ridMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('content_text')) {
      context.handle(
        _contentTextMeta,
        contentText.isAcceptableOrUnknown(
          data['content_text']!,
          _contentTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentTextMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastModifiedMeta);
    }
    if (data.containsKey('show')) {
      context.handle(
        _showMeta,
        show.isAcceptableOrUnknown(data['show']!, _showMeta),
      );
    } else if (isInserting) {
      context.missing(_showMeta);
    }
    if (data.containsKey('mood')) {
      context.handle(
        _moodMeta,
        mood.isAcceptableOrUnknown(data['mood']!, _moodMeta),
      );
    } else if (isInserting) {
      context.missing(_moodMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('aspect')) {
      context.handle(
        _aspectMeta,
        aspect.isAcceptableOrUnknown(data['aspect']!, _aspectMeta),
      );
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('place_name')) {
      context.handle(
        _placeNameMeta,
        placeName.isAcceptableOrUnknown(data['place_name']!, _placeNameMeta),
      );
    }
    if (data.containsKey('weather_icon')) {
      context.handle(
        _weatherIconMeta,
        weatherIcon.isAcceptableOrUnknown(
          data['weather_icon']!,
          _weatherIconMeta,
        ),
      );
    }
    if (data.containsKey('weather_temp')) {
      context.handle(
        _weatherTempMeta,
        weatherTemp.isAcceptableOrUnknown(
          data['weather_temp']!,
          _weatherTempMeta,
        ),
      );
    }
    if (data.containsKey('weather_text')) {
      context.handle(
        _weatherTextMeta,
        weatherText.isAcceptableOrUnknown(
          data['weather_text']!,
          _weatherTextMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rid};
  @override
  DiaryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryRow(
      rid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rid'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      contentText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_text'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time'],
      )!,
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_modified'],
      )!,
      show: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}show'],
      )!,
      mood: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mood'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      aspect: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}aspect'],
      ),
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      placeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}place_name'],
      ),
      weatherIcon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weather_icon'],
      ),
      weatherTemp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weather_temp'],
      ),
      weatherText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weather_text'],
      ),
    );
  }

  @override
  Diaries createAlias(String alias) {
    return Diaries(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class DiaryRow extends DataClass implements Insertable<DiaryRow> {
  final int rid;
  final String id;
  final String? categoryId;
  final String title;
  final String content;
  final String contentText;
  final int time;
  final int lastModified;
  final int show;
  final double mood;
  final String type;
  final double? aspect;
  final double? latitude;
  final double? longitude;
  final String? placeName;
  final String? weatherIcon;
  final String? weatherTemp;
  final String? weatherText;
  const DiaryRow({
    required this.rid,
    required this.id,
    this.categoryId,
    required this.title,
    required this.content,
    required this.contentText,
    required this.time,
    required this.lastModified,
    required this.show,
    required this.mood,
    required this.type,
    this.aspect,
    this.latitude,
    this.longitude,
    this.placeName,
    this.weatherIcon,
    this.weatherTemp,
    this.weatherText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['rid'] = Variable<int>(rid);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['content_text'] = Variable<String>(contentText);
    map['time'] = Variable<int>(time);
    map['last_modified'] = Variable<int>(lastModified);
    map['show'] = Variable<int>(show);
    map['mood'] = Variable<double>(mood);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || aspect != null) {
      map['aspect'] = Variable<double>(aspect);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || placeName != null) {
      map['place_name'] = Variable<String>(placeName);
    }
    if (!nullToAbsent || weatherIcon != null) {
      map['weather_icon'] = Variable<String>(weatherIcon);
    }
    if (!nullToAbsent || weatherTemp != null) {
      map['weather_temp'] = Variable<String>(weatherTemp);
    }
    if (!nullToAbsent || weatherText != null) {
      map['weather_text'] = Variable<String>(weatherText);
    }
    return map;
  }

  DiariesCompanion toCompanion(bool nullToAbsent) {
    return DiariesCompanion(
      rid: Value(rid),
      id: Value(id),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      title: Value(title),
      content: Value(content),
      contentText: Value(contentText),
      time: Value(time),
      lastModified: Value(lastModified),
      show: Value(show),
      mood: Value(mood),
      type: Value(type),
      aspect: aspect == null && nullToAbsent
          ? const Value.absent()
          : Value(aspect),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      placeName: placeName == null && nullToAbsent
          ? const Value.absent()
          : Value(placeName),
      weatherIcon: weatherIcon == null && nullToAbsent
          ? const Value.absent()
          : Value(weatherIcon),
      weatherTemp: weatherTemp == null && nullToAbsent
          ? const Value.absent()
          : Value(weatherTemp),
      weatherText: weatherText == null && nullToAbsent
          ? const Value.absent()
          : Value(weatherText),
    );
  }

  factory DiaryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryRow(
      rid: serializer.fromJson<int>(json['rid']),
      id: serializer.fromJson<String>(json['id']),
      categoryId: serializer.fromJson<String?>(json['category_id']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      contentText: serializer.fromJson<String>(json['content_text']),
      time: serializer.fromJson<int>(json['time']),
      lastModified: serializer.fromJson<int>(json['last_modified']),
      show: serializer.fromJson<int>(json['show']),
      mood: serializer.fromJson<double>(json['mood']),
      type: serializer.fromJson<String>(json['type']),
      aspect: serializer.fromJson<double?>(json['aspect']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      placeName: serializer.fromJson<String?>(json['place_name']),
      weatherIcon: serializer.fromJson<String?>(json['weather_icon']),
      weatherTemp: serializer.fromJson<String?>(json['weather_temp']),
      weatherText: serializer.fromJson<String?>(json['weather_text']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rid': serializer.toJson<int>(rid),
      'id': serializer.toJson<String>(id),
      'category_id': serializer.toJson<String?>(categoryId),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'content_text': serializer.toJson<String>(contentText),
      'time': serializer.toJson<int>(time),
      'last_modified': serializer.toJson<int>(lastModified),
      'show': serializer.toJson<int>(show),
      'mood': serializer.toJson<double>(mood),
      'type': serializer.toJson<String>(type),
      'aspect': serializer.toJson<double?>(aspect),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'place_name': serializer.toJson<String?>(placeName),
      'weather_icon': serializer.toJson<String?>(weatherIcon),
      'weather_temp': serializer.toJson<String?>(weatherTemp),
      'weather_text': serializer.toJson<String?>(weatherText),
    };
  }

  DiaryRow copyWith({
    int? rid,
    String? id,
    Value<String?> categoryId = const Value.absent(),
    String? title,
    String? content,
    String? contentText,
    int? time,
    int? lastModified,
    int? show,
    double? mood,
    String? type,
    Value<double?> aspect = const Value.absent(),
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<String?> placeName = const Value.absent(),
    Value<String?> weatherIcon = const Value.absent(),
    Value<String?> weatherTemp = const Value.absent(),
    Value<String?> weatherText = const Value.absent(),
  }) => DiaryRow(
    rid: rid ?? this.rid,
    id: id ?? this.id,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    title: title ?? this.title,
    content: content ?? this.content,
    contentText: contentText ?? this.contentText,
    time: time ?? this.time,
    lastModified: lastModified ?? this.lastModified,
    show: show ?? this.show,
    mood: mood ?? this.mood,
    type: type ?? this.type,
    aspect: aspect.present ? aspect.value : this.aspect,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    placeName: placeName.present ? placeName.value : this.placeName,
    weatherIcon: weatherIcon.present ? weatherIcon.value : this.weatherIcon,
    weatherTemp: weatherTemp.present ? weatherTemp.value : this.weatherTemp,
    weatherText: weatherText.present ? weatherText.value : this.weatherText,
  );
  DiaryRow copyWithCompanion(DiariesCompanion data) {
    return DiaryRow(
      rid: data.rid.present ? data.rid.value : this.rid,
      id: data.id.present ? data.id.value : this.id,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      contentText: data.contentText.present
          ? data.contentText.value
          : this.contentText,
      time: data.time.present ? data.time.value : this.time,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      show: data.show.present ? data.show.value : this.show,
      mood: data.mood.present ? data.mood.value : this.mood,
      type: data.type.present ? data.type.value : this.type,
      aspect: data.aspect.present ? data.aspect.value : this.aspect,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      placeName: data.placeName.present ? data.placeName.value : this.placeName,
      weatherIcon: data.weatherIcon.present
          ? data.weatherIcon.value
          : this.weatherIcon,
      weatherTemp: data.weatherTemp.present
          ? data.weatherTemp.value
          : this.weatherTemp,
      weatherText: data.weatherText.present
          ? data.weatherText.value
          : this.weatherText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryRow(')
          ..write('rid: $rid, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('contentText: $contentText, ')
          ..write('time: $time, ')
          ..write('lastModified: $lastModified, ')
          ..write('show: $show, ')
          ..write('mood: $mood, ')
          ..write('type: $type, ')
          ..write('aspect: $aspect, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('placeName: $placeName, ')
          ..write('weatherIcon: $weatherIcon, ')
          ..write('weatherTemp: $weatherTemp, ')
          ..write('weatherText: $weatherText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    rid,
    id,
    categoryId,
    title,
    content,
    contentText,
    time,
    lastModified,
    show,
    mood,
    type,
    aspect,
    latitude,
    longitude,
    placeName,
    weatherIcon,
    weatherTemp,
    weatherText,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryRow &&
          other.rid == this.rid &&
          other.id == this.id &&
          other.categoryId == this.categoryId &&
          other.title == this.title &&
          other.content == this.content &&
          other.contentText == this.contentText &&
          other.time == this.time &&
          other.lastModified == this.lastModified &&
          other.show == this.show &&
          other.mood == this.mood &&
          other.type == this.type &&
          other.aspect == this.aspect &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.placeName == this.placeName &&
          other.weatherIcon == this.weatherIcon &&
          other.weatherTemp == this.weatherTemp &&
          other.weatherText == this.weatherText);
}

class DiariesCompanion extends UpdateCompanion<DiaryRow> {
  final Value<int> rid;
  final Value<String> id;
  final Value<String?> categoryId;
  final Value<String> title;
  final Value<String> content;
  final Value<String> contentText;
  final Value<int> time;
  final Value<int> lastModified;
  final Value<int> show;
  final Value<double> mood;
  final Value<String> type;
  final Value<double?> aspect;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String?> placeName;
  final Value<String?> weatherIcon;
  final Value<String?> weatherTemp;
  final Value<String?> weatherText;
  const DiariesCompanion({
    this.rid = const Value.absent(),
    this.id = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.contentText = const Value.absent(),
    this.time = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.show = const Value.absent(),
    this.mood = const Value.absent(),
    this.type = const Value.absent(),
    this.aspect = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.placeName = const Value.absent(),
    this.weatherIcon = const Value.absent(),
    this.weatherTemp = const Value.absent(),
    this.weatherText = const Value.absent(),
  });
  DiariesCompanion.insert({
    this.rid = const Value.absent(),
    required String id,
    this.categoryId = const Value.absent(),
    required String title,
    required String content,
    required String contentText,
    required int time,
    required int lastModified,
    required int show,
    required double mood,
    required String type,
    this.aspect = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.placeName = const Value.absent(),
    this.weatherIcon = const Value.absent(),
    this.weatherTemp = const Value.absent(),
    this.weatherText = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       content = Value(content),
       contentText = Value(contentText),
       time = Value(time),
       lastModified = Value(lastModified),
       show = Value(show),
       mood = Value(mood),
       type = Value(type);
  static Insertable<DiaryRow> custom({
    Expression<int>? rid,
    Expression<String>? id,
    Expression<String>? categoryId,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? contentText,
    Expression<int>? time,
    Expression<int>? lastModified,
    Expression<int>? show,
    Expression<double>? mood,
    Expression<String>? type,
    Expression<double>? aspect,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? placeName,
    Expression<String>? weatherIcon,
    Expression<String>? weatherTemp,
    Expression<String>? weatherText,
  }) {
    return RawValuesInsertable({
      if (rid != null) 'rid': rid,
      if (id != null) 'id': id,
      if (categoryId != null) 'category_id': categoryId,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (contentText != null) 'content_text': contentText,
      if (time != null) 'time': time,
      if (lastModified != null) 'last_modified': lastModified,
      if (show != null) 'show': show,
      if (mood != null) 'mood': mood,
      if (type != null) 'type': type,
      if (aspect != null) 'aspect': aspect,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (placeName != null) 'place_name': placeName,
      if (weatherIcon != null) 'weather_icon': weatherIcon,
      if (weatherTemp != null) 'weather_temp': weatherTemp,
      if (weatherText != null) 'weather_text': weatherText,
    });
  }

  DiariesCompanion copyWith({
    Value<int>? rid,
    Value<String>? id,
    Value<String?>? categoryId,
    Value<String>? title,
    Value<String>? content,
    Value<String>? contentText,
    Value<int>? time,
    Value<int>? lastModified,
    Value<int>? show,
    Value<double>? mood,
    Value<String>? type,
    Value<double?>? aspect,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<String?>? placeName,
    Value<String?>? weatherIcon,
    Value<String?>? weatherTemp,
    Value<String?>? weatherText,
  }) {
    return DiariesCompanion(
      rid: rid ?? this.rid,
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      content: content ?? this.content,
      contentText: contentText ?? this.contentText,
      time: time ?? this.time,
      lastModified: lastModified ?? this.lastModified,
      show: show ?? this.show,
      mood: mood ?? this.mood,
      type: type ?? this.type,
      aspect: aspect ?? this.aspect,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeName: placeName ?? this.placeName,
      weatherIcon: weatherIcon ?? this.weatherIcon,
      weatherTemp: weatherTemp ?? this.weatherTemp,
      weatherText: weatherText ?? this.weatherText,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rid.present) {
      map['rid'] = Variable<int>(rid.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (contentText.present) {
      map['content_text'] = Variable<String>(contentText.value);
    }
    if (time.present) {
      map['time'] = Variable<int>(time.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<int>(lastModified.value);
    }
    if (show.present) {
      map['show'] = Variable<int>(show.value);
    }
    if (mood.present) {
      map['mood'] = Variable<double>(mood.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (aspect.present) {
      map['aspect'] = Variable<double>(aspect.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (placeName.present) {
      map['place_name'] = Variable<String>(placeName.value);
    }
    if (weatherIcon.present) {
      map['weather_icon'] = Variable<String>(weatherIcon.value);
    }
    if (weatherTemp.present) {
      map['weather_temp'] = Variable<String>(weatherTemp.value);
    }
    if (weatherText.present) {
      map['weather_text'] = Variable<String>(weatherText.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiariesCompanion(')
          ..write('rid: $rid, ')
          ..write('id: $id, ')
          ..write('categoryId: $categoryId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('contentText: $contentText, ')
          ..write('time: $time, ')
          ..write('lastModified: $lastModified, ')
          ..write('show: $show, ')
          ..write('mood: $mood, ')
          ..write('type: $type, ')
          ..write('aspect: $aspect, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('placeName: $placeName, ')
          ..write('weatherIcon: $weatherIcon, ')
          ..write('weatherTemp: $weatherTemp, ')
          ..write('weatherText: $weatherText')
          ..write(')'))
        .toString();
  }
}

class DiaryLinks extends Table with TableInfo<DiaryLinks, DiaryLinkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DiaryLinks(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _srcIdMeta = const VerificationMeta('srcId');
  late final GeneratedColumn<String> srcId = GeneratedColumn<String>(
    'src_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES diaries(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _dstIdMeta = const VerificationMeta('dstId');
  late final GeneratedColumn<String> dstId = GeneratedColumn<String>(
    'dst_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [srcId, dstId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryLinkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('src_id')) {
      context.handle(
        _srcIdMeta,
        srcId.isAcceptableOrUnknown(data['src_id']!, _srcIdMeta),
      );
    } else if (isInserting) {
      context.missing(_srcIdMeta);
    }
    if (data.containsKey('dst_id')) {
      context.handle(
        _dstIdMeta,
        dstId.isAcceptableOrUnknown(data['dst_id']!, _dstIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dstIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {srcId, dstId};
  @override
  DiaryLinkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryLinkRow(
      srcId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}src_id'],
      )!,
      dstId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dst_id'],
      )!,
    );
  }

  @override
  DiaryLinks createAlias(String alias) {
    return DiaryLinks(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(src_id, dst_id)'];
  @override
  bool get dontWriteConstraints => true;
}

class DiaryLinkRow extends DataClass implements Insertable<DiaryLinkRow> {
  final String srcId;
  final String dstId;
  const DiaryLinkRow({required this.srcId, required this.dstId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['src_id'] = Variable<String>(srcId);
    map['dst_id'] = Variable<String>(dstId);
    return map;
  }

  DiaryLinksCompanion toCompanion(bool nullToAbsent) {
    return DiaryLinksCompanion(srcId: Value(srcId), dstId: Value(dstId));
  }

  factory DiaryLinkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryLinkRow(
      srcId: serializer.fromJson<String>(json['src_id']),
      dstId: serializer.fromJson<String>(json['dst_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'src_id': serializer.toJson<String>(srcId),
      'dst_id': serializer.toJson<String>(dstId),
    };
  }

  DiaryLinkRow copyWith({String? srcId, String? dstId}) =>
      DiaryLinkRow(srcId: srcId ?? this.srcId, dstId: dstId ?? this.dstId);
  DiaryLinkRow copyWithCompanion(DiaryLinksCompanion data) {
    return DiaryLinkRow(
      srcId: data.srcId.present ? data.srcId.value : this.srcId,
      dstId: data.dstId.present ? data.dstId.value : this.dstId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryLinkRow(')
          ..write('srcId: $srcId, ')
          ..write('dstId: $dstId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(srcId, dstId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryLinkRow &&
          other.srcId == this.srcId &&
          other.dstId == this.dstId);
}

class DiaryLinksCompanion extends UpdateCompanion<DiaryLinkRow> {
  final Value<String> srcId;
  final Value<String> dstId;
  final Value<int> rowid;
  const DiaryLinksCompanion({
    this.srcId = const Value.absent(),
    this.dstId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiaryLinksCompanion.insert({
    required String srcId,
    required String dstId,
    this.rowid = const Value.absent(),
  }) : srcId = Value(srcId),
       dstId = Value(dstId);
  static Insertable<DiaryLinkRow> custom({
    Expression<String>? srcId,
    Expression<String>? dstId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (srcId != null) 'src_id': srcId,
      if (dstId != null) 'dst_id': dstId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiaryLinksCompanion copyWith({
    Value<String>? srcId,
    Value<String>? dstId,
    Value<int>? rowid,
  }) {
    return DiaryLinksCompanion(
      srcId: srcId ?? this.srcId,
      dstId: dstId ?? this.dstId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (srcId.present) {
      map['src_id'] = Variable<String>(srcId.value);
    }
    if (dstId.present) {
      map['dst_id'] = Variable<String>(dstId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryLinksCompanion(')
          ..write('srcId: $srcId, ')
          ..write('dstId: $dstId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class LlmProviders extends Table with TableInfo<LlmProviders, LlmProviderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LlmProviders(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _baseUrlMeta = const VerificationMeta(
    'baseUrl',
  );
  late final GeneratedColumn<String> baseUrl = GeneratedColumn<String>(
    'base_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _defaultModelMeta = const VerificationMeta(
    'defaultModel',
  );
  late final GeneratedColumn<String> defaultModel = GeneratedColumn<String>(
    'default_model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _presetIdMeta = const VerificationMeta(
    'presetId',
  );
  late final GeneratedColumn<String> presetId = GeneratedColumn<String>(
    'preset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _modelsJsonMeta = const VerificationMeta(
    'modelsJson',
  );
  late final GeneratedColumn<String> modelsJson = GeneratedColumn<String>(
    'models_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'[]\'',
    defaultValue: const CustomExpression('\'[]\''),
  );
  static const VerificationMeta _toolCallMeta = const VerificationMeta(
    'toolCall',
  );
  late final GeneratedColumn<int> toolCall = GeneratedColumn<int>(
    'tool_call',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _reasoningMeta = const VerificationMeta(
    'reasoning',
  );
  late final GeneratedColumn<int> reasoning = GeneratedColumn<int>(
    'reasoning',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _attachmentMeta = const VerificationMeta(
    'attachment',
  );
  late final GeneratedColumn<int> attachment = GeneratedColumn<int>(
    'attachment',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    baseUrl,
    defaultModel,
    createdAt,
    sortOrder,
    presetId,
    modelsJson,
    toolCall,
    reasoning,
    attachment,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'llm_providers';
  @override
  VerificationContext validateIntegrity(
    Insertable<LlmProviderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('base_url')) {
      context.handle(
        _baseUrlMeta,
        baseUrl.isAcceptableOrUnknown(data['base_url']!, _baseUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_baseUrlMeta);
    }
    if (data.containsKey('default_model')) {
      context.handle(
        _defaultModelMeta,
        defaultModel.isAcceptableOrUnknown(
          data['default_model']!,
          _defaultModelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defaultModelMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('preset_id')) {
      context.handle(
        _presetIdMeta,
        presetId.isAcceptableOrUnknown(data['preset_id']!, _presetIdMeta),
      );
    }
    if (data.containsKey('models_json')) {
      context.handle(
        _modelsJsonMeta,
        modelsJson.isAcceptableOrUnknown(data['models_json']!, _modelsJsonMeta),
      );
    }
    if (data.containsKey('tool_call')) {
      context.handle(
        _toolCallMeta,
        toolCall.isAcceptableOrUnknown(data['tool_call']!, _toolCallMeta),
      );
    }
    if (data.containsKey('reasoning')) {
      context.handle(
        _reasoningMeta,
        reasoning.isAcceptableOrUnknown(data['reasoning']!, _reasoningMeta),
      );
    }
    if (data.containsKey('attachment')) {
      context.handle(
        _attachmentMeta,
        attachment.isAcceptableOrUnknown(data['attachment']!, _attachmentMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LlmProviderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LlmProviderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      baseUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_url'],
      )!,
      defaultModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_model'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      presetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preset_id'],
      )!,
      modelsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}models_json'],
      )!,
      toolCall: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tool_call'],
      )!,
      reasoning: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reasoning'],
      )!,
      attachment: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attachment'],
      )!,
    );
  }

  @override
  LlmProviders createAlias(String alias) {
    return LlmProviders(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class LlmProviderRow extends DataClass implements Insertable<LlmProviderRow> {
  final String id;
  final String name;
  final String type;
  final String baseUrl;
  final String defaultModel;
  final int createdAt;
  final int sortOrder;
  final String presetId;
  final String modelsJson;
  final int toolCall;
  final int reasoning;
  final int attachment;
  const LlmProviderRow({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    required this.defaultModel,
    required this.createdAt,
    required this.sortOrder,
    required this.presetId,
    required this.modelsJson,
    required this.toolCall,
    required this.reasoning,
    required this.attachment,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['base_url'] = Variable<String>(baseUrl);
    map['default_model'] = Variable<String>(defaultModel);
    map['created_at'] = Variable<int>(createdAt);
    map['sort_order'] = Variable<int>(sortOrder);
    map['preset_id'] = Variable<String>(presetId);
    map['models_json'] = Variable<String>(modelsJson);
    map['tool_call'] = Variable<int>(toolCall);
    map['reasoning'] = Variable<int>(reasoning);
    map['attachment'] = Variable<int>(attachment);
    return map;
  }

  LlmProvidersCompanion toCompanion(bool nullToAbsent) {
    return LlmProvidersCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      baseUrl: Value(baseUrl),
      defaultModel: Value(defaultModel),
      createdAt: Value(createdAt),
      sortOrder: Value(sortOrder),
      presetId: Value(presetId),
      modelsJson: Value(modelsJson),
      toolCall: Value(toolCall),
      reasoning: Value(reasoning),
      attachment: Value(attachment),
    );
  }

  factory LlmProviderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LlmProviderRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      baseUrl: serializer.fromJson<String>(json['base_url']),
      defaultModel: serializer.fromJson<String>(json['default_model']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      sortOrder: serializer.fromJson<int>(json['sort_order']),
      presetId: serializer.fromJson<String>(json['preset_id']),
      modelsJson: serializer.fromJson<String>(json['models_json']),
      toolCall: serializer.fromJson<int>(json['tool_call']),
      reasoning: serializer.fromJson<int>(json['reasoning']),
      attachment: serializer.fromJson<int>(json['attachment']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'base_url': serializer.toJson<String>(baseUrl),
      'default_model': serializer.toJson<String>(defaultModel),
      'created_at': serializer.toJson<int>(createdAt),
      'sort_order': serializer.toJson<int>(sortOrder),
      'preset_id': serializer.toJson<String>(presetId),
      'models_json': serializer.toJson<String>(modelsJson),
      'tool_call': serializer.toJson<int>(toolCall),
      'reasoning': serializer.toJson<int>(reasoning),
      'attachment': serializer.toJson<int>(attachment),
    };
  }

  LlmProviderRow copyWith({
    String? id,
    String? name,
    String? type,
    String? baseUrl,
    String? defaultModel,
    int? createdAt,
    int? sortOrder,
    String? presetId,
    String? modelsJson,
    int? toolCall,
    int? reasoning,
    int? attachment,
  }) => LlmProviderRow(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    baseUrl: baseUrl ?? this.baseUrl,
    defaultModel: defaultModel ?? this.defaultModel,
    createdAt: createdAt ?? this.createdAt,
    sortOrder: sortOrder ?? this.sortOrder,
    presetId: presetId ?? this.presetId,
    modelsJson: modelsJson ?? this.modelsJson,
    toolCall: toolCall ?? this.toolCall,
    reasoning: reasoning ?? this.reasoning,
    attachment: attachment ?? this.attachment,
  );
  LlmProviderRow copyWithCompanion(LlmProvidersCompanion data) {
    return LlmProviderRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      baseUrl: data.baseUrl.present ? data.baseUrl.value : this.baseUrl,
      defaultModel: data.defaultModel.present
          ? data.defaultModel.value
          : this.defaultModel,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      presetId: data.presetId.present ? data.presetId.value : this.presetId,
      modelsJson: data.modelsJson.present
          ? data.modelsJson.value
          : this.modelsJson,
      toolCall: data.toolCall.present ? data.toolCall.value : this.toolCall,
      reasoning: data.reasoning.present ? data.reasoning.value : this.reasoning,
      attachment: data.attachment.present
          ? data.attachment.value
          : this.attachment,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LlmProviderRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('defaultModel: $defaultModel, ')
          ..write('createdAt: $createdAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('presetId: $presetId, ')
          ..write('modelsJson: $modelsJson, ')
          ..write('toolCall: $toolCall, ')
          ..write('reasoning: $reasoning, ')
          ..write('attachment: $attachment')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    baseUrl,
    defaultModel,
    createdAt,
    sortOrder,
    presetId,
    modelsJson,
    toolCall,
    reasoning,
    attachment,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LlmProviderRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.baseUrl == this.baseUrl &&
          other.defaultModel == this.defaultModel &&
          other.createdAt == this.createdAt &&
          other.sortOrder == this.sortOrder &&
          other.presetId == this.presetId &&
          other.modelsJson == this.modelsJson &&
          other.toolCall == this.toolCall &&
          other.reasoning == this.reasoning &&
          other.attachment == this.attachment);
}

class LlmProvidersCompanion extends UpdateCompanion<LlmProviderRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> baseUrl;
  final Value<String> defaultModel;
  final Value<int> createdAt;
  final Value<int> sortOrder;
  final Value<String> presetId;
  final Value<String> modelsJson;
  final Value<int> toolCall;
  final Value<int> reasoning;
  final Value<int> attachment;
  final Value<int> rowid;
  const LlmProvidersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.baseUrl = const Value.absent(),
    this.defaultModel = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.presetId = const Value.absent(),
    this.modelsJson = const Value.absent(),
    this.toolCall = const Value.absent(),
    this.reasoning = const Value.absent(),
    this.attachment = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LlmProvidersCompanion.insert({
    required String id,
    required String name,
    required String type,
    required String baseUrl,
    required String defaultModel,
    required int createdAt,
    required int sortOrder,
    this.presetId = const Value.absent(),
    this.modelsJson = const Value.absent(),
    this.toolCall = const Value.absent(),
    this.reasoning = const Value.absent(),
    this.attachment = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type),
       baseUrl = Value(baseUrl),
       defaultModel = Value(defaultModel),
       createdAt = Value(createdAt),
       sortOrder = Value(sortOrder);
  static Insertable<LlmProviderRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? baseUrl,
    Expression<String>? defaultModel,
    Expression<int>? createdAt,
    Expression<int>? sortOrder,
    Expression<String>? presetId,
    Expression<String>? modelsJson,
    Expression<int>? toolCall,
    Expression<int>? reasoning,
    Expression<int>? attachment,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (baseUrl != null) 'base_url': baseUrl,
      if (defaultModel != null) 'default_model': defaultModel,
      if (createdAt != null) 'created_at': createdAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (presetId != null) 'preset_id': presetId,
      if (modelsJson != null) 'models_json': modelsJson,
      if (toolCall != null) 'tool_call': toolCall,
      if (reasoning != null) 'reasoning': reasoning,
      if (attachment != null) 'attachment': attachment,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LlmProvidersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String>? baseUrl,
    Value<String>? defaultModel,
    Value<int>? createdAt,
    Value<int>? sortOrder,
    Value<String>? presetId,
    Value<String>? modelsJson,
    Value<int>? toolCall,
    Value<int>? reasoning,
    Value<int>? attachment,
    Value<int>? rowid,
  }) {
    return LlmProvidersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModel: defaultModel ?? this.defaultModel,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
      presetId: presetId ?? this.presetId,
      modelsJson: modelsJson ?? this.modelsJson,
      toolCall: toolCall ?? this.toolCall,
      reasoning: reasoning ?? this.reasoning,
      attachment: attachment ?? this.attachment,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (baseUrl.present) {
      map['base_url'] = Variable<String>(baseUrl.value);
    }
    if (defaultModel.present) {
      map['default_model'] = Variable<String>(defaultModel.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (presetId.present) {
      map['preset_id'] = Variable<String>(presetId.value);
    }
    if (modelsJson.present) {
      map['models_json'] = Variable<String>(modelsJson.value);
    }
    if (toolCall.present) {
      map['tool_call'] = Variable<int>(toolCall.value);
    }
    if (reasoning.present) {
      map['reasoning'] = Variable<int>(reasoning.value);
    }
    if (attachment.present) {
      map['attachment'] = Variable<int>(attachment.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LlmProvidersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('baseUrl: $baseUrl, ')
          ..write('defaultModel: $defaultModel, ')
          ..write('createdAt: $createdAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('presetId: $presetId, ')
          ..write('modelsJson: $modelsJson, ')
          ..write('toolCall: $toolCall, ')
          ..write('reasoning: $reasoning, ')
          ..write('attachment: $attachment, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ChatSessions extends Table with TableInfo<ChatSessions, ChatSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ChatSessions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _reasoningEffortMeta = const VerificationMeta(
    'reasoningEffort',
  );
  late final GeneratedColumn<String> reasoningEffort = GeneratedColumn<String>(
    'reasoning_effort',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _compactedSummaryMeta = const VerificationMeta(
    'compactedSummary',
  );
  late final GeneratedColumn<String> compactedSummary = GeneratedColumn<String>(
    'compacted_summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _compactedUpToMessageIdMeta =
      const VerificationMeta('compactedUpToMessageId');
  late final GeneratedColumn<String> compactedUpToMessageId =
      GeneratedColumn<String>(
        'compacted_up_to_message_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _compactedAtMeta = const VerificationMeta(
    'compactedAt',
  );
  late final GeneratedColumn<int> compactedAt = GeneratedColumn<int>(
    'compacted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _compactedInputTokensAtTriggerMeta =
      const VerificationMeta('compactedInputTokensAtTrigger');
  late final GeneratedColumn<int> compactedInputTokensAtTrigger =
      GeneratedColumn<int>(
        'compacted_input_tokens_at_trigger',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _agentPresetIdMeta = const VerificationMeta(
    'agentPresetId',
  );
  late final GeneratedColumn<String> agentPresetId = GeneratedColumn<String>(
    'agent_preset_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _personaSnapshotMeta = const VerificationMeta(
    'personaSnapshot',
  );
  late final GeneratedColumn<String> personaSnapshot = GeneratedColumn<String>(
    'persona_snapshot',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _toolsSnapshotJsonMeta = const VerificationMeta(
    'toolsSnapshotJson',
  );
  late final GeneratedColumn<String> toolsSnapshotJson =
      GeneratedColumn<String>(
        'tools_snapshot_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    providerId,
    model,
    createdAt,
    updatedAt,
    reasoningEffort,
    compactedSummary,
    compactedUpToMessageId,
    compactedAt,
    compactedInputTokensAtTrigger,
    agentPresetId,
    personaSnapshot,
    toolsSnapshotJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('reasoning_effort')) {
      context.handle(
        _reasoningEffortMeta,
        reasoningEffort.isAcceptableOrUnknown(
          data['reasoning_effort']!,
          _reasoningEffortMeta,
        ),
      );
    }
    if (data.containsKey('compacted_summary')) {
      context.handle(
        _compactedSummaryMeta,
        compactedSummary.isAcceptableOrUnknown(
          data['compacted_summary']!,
          _compactedSummaryMeta,
        ),
      );
    }
    if (data.containsKey('compacted_up_to_message_id')) {
      context.handle(
        _compactedUpToMessageIdMeta,
        compactedUpToMessageId.isAcceptableOrUnknown(
          data['compacted_up_to_message_id']!,
          _compactedUpToMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('compacted_at')) {
      context.handle(
        _compactedAtMeta,
        compactedAt.isAcceptableOrUnknown(
          data['compacted_at']!,
          _compactedAtMeta,
        ),
      );
    }
    if (data.containsKey('compacted_input_tokens_at_trigger')) {
      context.handle(
        _compactedInputTokensAtTriggerMeta,
        compactedInputTokensAtTrigger.isAcceptableOrUnknown(
          data['compacted_input_tokens_at_trigger']!,
          _compactedInputTokensAtTriggerMeta,
        ),
      );
    }
    if (data.containsKey('agent_preset_id')) {
      context.handle(
        _agentPresetIdMeta,
        agentPresetId.isAcceptableOrUnknown(
          data['agent_preset_id']!,
          _agentPresetIdMeta,
        ),
      );
    }
    if (data.containsKey('persona_snapshot')) {
      context.handle(
        _personaSnapshotMeta,
        personaSnapshot.isAcceptableOrUnknown(
          data['persona_snapshot']!,
          _personaSnapshotMeta,
        ),
      );
    }
    if (data.containsKey('tools_snapshot_json')) {
      context.handle(
        _toolsSnapshotJsonMeta,
        toolsSnapshotJson.isAcceptableOrUnknown(
          data['tools_snapshot_json']!,
          _toolsSnapshotJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      reasoningEffort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reasoning_effort'],
      )!,
      compactedSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compacted_summary'],
      ),
      compactedUpToMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compacted_up_to_message_id'],
      ),
      compactedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}compacted_at'],
      ),
      compactedInputTokensAtTrigger: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}compacted_input_tokens_at_trigger'],
      ),
      agentPresetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_preset_id'],
      ),
      personaSnapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persona_snapshot'],
      ),
      toolsSnapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tools_snapshot_json'],
      ),
    );
  }

  @override
  ChatSessions createAlias(String alias) {
    return ChatSessions(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ChatSessionRow extends DataClass implements Insertable<ChatSessionRow> {
  final String id;
  final String title;
  final String providerId;
  final String model;
  final int createdAt;
  final int updatedAt;
  final String reasoningEffort;
  final String? compactedSummary;
  final String? compactedUpToMessageId;
  final int? compactedAt;
  final int? compactedInputTokensAtTrigger;
  final String? agentPresetId;
  final String? personaSnapshot;
  final String? toolsSnapshotJson;
  const ChatSessionRow({
    required this.id,
    required this.title,
    required this.providerId,
    required this.model,
    required this.createdAt,
    required this.updatedAt,
    required this.reasoningEffort,
    this.compactedSummary,
    this.compactedUpToMessageId,
    this.compactedAt,
    this.compactedInputTokensAtTrigger,
    this.agentPresetId,
    this.personaSnapshot,
    this.toolsSnapshotJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['provider_id'] = Variable<String>(providerId);
    map['model'] = Variable<String>(model);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['reasoning_effort'] = Variable<String>(reasoningEffort);
    if (!nullToAbsent || compactedSummary != null) {
      map['compacted_summary'] = Variable<String>(compactedSummary);
    }
    if (!nullToAbsent || compactedUpToMessageId != null) {
      map['compacted_up_to_message_id'] = Variable<String>(
        compactedUpToMessageId,
      );
    }
    if (!nullToAbsent || compactedAt != null) {
      map['compacted_at'] = Variable<int>(compactedAt);
    }
    if (!nullToAbsent || compactedInputTokensAtTrigger != null) {
      map['compacted_input_tokens_at_trigger'] = Variable<int>(
        compactedInputTokensAtTrigger,
      );
    }
    if (!nullToAbsent || agentPresetId != null) {
      map['agent_preset_id'] = Variable<String>(agentPresetId);
    }
    if (!nullToAbsent || personaSnapshot != null) {
      map['persona_snapshot'] = Variable<String>(personaSnapshot);
    }
    if (!nullToAbsent || toolsSnapshotJson != null) {
      map['tools_snapshot_json'] = Variable<String>(toolsSnapshotJson);
    }
    return map;
  }

  ChatSessionsCompanion toCompanion(bool nullToAbsent) {
    return ChatSessionsCompanion(
      id: Value(id),
      title: Value(title),
      providerId: Value(providerId),
      model: Value(model),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      reasoningEffort: Value(reasoningEffort),
      compactedSummary: compactedSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(compactedSummary),
      compactedUpToMessageId: compactedUpToMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(compactedUpToMessageId),
      compactedAt: compactedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(compactedAt),
      compactedInputTokensAtTrigger:
          compactedInputTokensAtTrigger == null && nullToAbsent
          ? const Value.absent()
          : Value(compactedInputTokensAtTrigger),
      agentPresetId: agentPresetId == null && nullToAbsent
          ? const Value.absent()
          : Value(agentPresetId),
      personaSnapshot: personaSnapshot == null && nullToAbsent
          ? const Value.absent()
          : Value(personaSnapshot),
      toolsSnapshotJson: toolsSnapshotJson == null && nullToAbsent
          ? const Value.absent()
          : Value(toolsSnapshotJson),
    );
  }

  factory ChatSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatSessionRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      providerId: serializer.fromJson<String>(json['provider_id']),
      model: serializer.fromJson<String>(json['model']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
      reasoningEffort: serializer.fromJson<String>(json['reasoning_effort']),
      compactedSummary: serializer.fromJson<String?>(json['compacted_summary']),
      compactedUpToMessageId: serializer.fromJson<String?>(
        json['compacted_up_to_message_id'],
      ),
      compactedAt: serializer.fromJson<int?>(json['compacted_at']),
      compactedInputTokensAtTrigger: serializer.fromJson<int?>(
        json['compacted_input_tokens_at_trigger'],
      ),
      agentPresetId: serializer.fromJson<String?>(json['agent_preset_id']),
      personaSnapshot: serializer.fromJson<String?>(json['persona_snapshot']),
      toolsSnapshotJson: serializer.fromJson<String?>(
        json['tools_snapshot_json'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'provider_id': serializer.toJson<String>(providerId),
      'model': serializer.toJson<String>(model),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
      'reasoning_effort': serializer.toJson<String>(reasoningEffort),
      'compacted_summary': serializer.toJson<String?>(compactedSummary),
      'compacted_up_to_message_id': serializer.toJson<String?>(
        compactedUpToMessageId,
      ),
      'compacted_at': serializer.toJson<int?>(compactedAt),
      'compacted_input_tokens_at_trigger': serializer.toJson<int?>(
        compactedInputTokensAtTrigger,
      ),
      'agent_preset_id': serializer.toJson<String?>(agentPresetId),
      'persona_snapshot': serializer.toJson<String?>(personaSnapshot),
      'tools_snapshot_json': serializer.toJson<String?>(toolsSnapshotJson),
    };
  }

  ChatSessionRow copyWith({
    String? id,
    String? title,
    String? providerId,
    String? model,
    int? createdAt,
    int? updatedAt,
    String? reasoningEffort,
    Value<String?> compactedSummary = const Value.absent(),
    Value<String?> compactedUpToMessageId = const Value.absent(),
    Value<int?> compactedAt = const Value.absent(),
    Value<int?> compactedInputTokensAtTrigger = const Value.absent(),
    Value<String?> agentPresetId = const Value.absent(),
    Value<String?> personaSnapshot = const Value.absent(),
    Value<String?> toolsSnapshotJson = const Value.absent(),
  }) => ChatSessionRow(
    id: id ?? this.id,
    title: title ?? this.title,
    providerId: providerId ?? this.providerId,
    model: model ?? this.model,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    reasoningEffort: reasoningEffort ?? this.reasoningEffort,
    compactedSummary: compactedSummary.present
        ? compactedSummary.value
        : this.compactedSummary,
    compactedUpToMessageId: compactedUpToMessageId.present
        ? compactedUpToMessageId.value
        : this.compactedUpToMessageId,
    compactedAt: compactedAt.present ? compactedAt.value : this.compactedAt,
    compactedInputTokensAtTrigger: compactedInputTokensAtTrigger.present
        ? compactedInputTokensAtTrigger.value
        : this.compactedInputTokensAtTrigger,
    agentPresetId: agentPresetId.present
        ? agentPresetId.value
        : this.agentPresetId,
    personaSnapshot: personaSnapshot.present
        ? personaSnapshot.value
        : this.personaSnapshot,
    toolsSnapshotJson: toolsSnapshotJson.present
        ? toolsSnapshotJson.value
        : this.toolsSnapshotJson,
  );
  ChatSessionRow copyWithCompanion(ChatSessionsCompanion data) {
    return ChatSessionRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      model: data.model.present ? data.model.value : this.model,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      reasoningEffort: data.reasoningEffort.present
          ? data.reasoningEffort.value
          : this.reasoningEffort,
      compactedSummary: data.compactedSummary.present
          ? data.compactedSummary.value
          : this.compactedSummary,
      compactedUpToMessageId: data.compactedUpToMessageId.present
          ? data.compactedUpToMessageId.value
          : this.compactedUpToMessageId,
      compactedAt: data.compactedAt.present
          ? data.compactedAt.value
          : this.compactedAt,
      compactedInputTokensAtTrigger: data.compactedInputTokensAtTrigger.present
          ? data.compactedInputTokensAtTrigger.value
          : this.compactedInputTokensAtTrigger,
      agentPresetId: data.agentPresetId.present
          ? data.agentPresetId.value
          : this.agentPresetId,
      personaSnapshot: data.personaSnapshot.present
          ? data.personaSnapshot.value
          : this.personaSnapshot,
      toolsSnapshotJson: data.toolsSnapshotJson.present
          ? data.toolsSnapshotJson.value
          : this.toolsSnapshotJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatSessionRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('providerId: $providerId, ')
          ..write('model: $model, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('reasoningEffort: $reasoningEffort, ')
          ..write('compactedSummary: $compactedSummary, ')
          ..write('compactedUpToMessageId: $compactedUpToMessageId, ')
          ..write('compactedAt: $compactedAt, ')
          ..write(
            'compactedInputTokensAtTrigger: $compactedInputTokensAtTrigger, ',
          )
          ..write('agentPresetId: $agentPresetId, ')
          ..write('personaSnapshot: $personaSnapshot, ')
          ..write('toolsSnapshotJson: $toolsSnapshotJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    providerId,
    model,
    createdAt,
    updatedAt,
    reasoningEffort,
    compactedSummary,
    compactedUpToMessageId,
    compactedAt,
    compactedInputTokensAtTrigger,
    agentPresetId,
    personaSnapshot,
    toolsSnapshotJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatSessionRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.providerId == this.providerId &&
          other.model == this.model &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.reasoningEffort == this.reasoningEffort &&
          other.compactedSummary == this.compactedSummary &&
          other.compactedUpToMessageId == this.compactedUpToMessageId &&
          other.compactedAt == this.compactedAt &&
          other.compactedInputTokensAtTrigger ==
              this.compactedInputTokensAtTrigger &&
          other.agentPresetId == this.agentPresetId &&
          other.personaSnapshot == this.personaSnapshot &&
          other.toolsSnapshotJson == this.toolsSnapshotJson);
}

class ChatSessionsCompanion extends UpdateCompanion<ChatSessionRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> providerId;
  final Value<String> model;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> reasoningEffort;
  final Value<String?> compactedSummary;
  final Value<String?> compactedUpToMessageId;
  final Value<int?> compactedAt;
  final Value<int?> compactedInputTokensAtTrigger;
  final Value<String?> agentPresetId;
  final Value<String?> personaSnapshot;
  final Value<String?> toolsSnapshotJson;
  final Value<int> rowid;
  const ChatSessionsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.providerId = const Value.absent(),
    this.model = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.reasoningEffort = const Value.absent(),
    this.compactedSummary = const Value.absent(),
    this.compactedUpToMessageId = const Value.absent(),
    this.compactedAt = const Value.absent(),
    this.compactedInputTokensAtTrigger = const Value.absent(),
    this.agentPresetId = const Value.absent(),
    this.personaSnapshot = const Value.absent(),
    this.toolsSnapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatSessionsCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    required String providerId,
    required String model,
    required int createdAt,
    required int updatedAt,
    this.reasoningEffort = const Value.absent(),
    this.compactedSummary = const Value.absent(),
    this.compactedUpToMessageId = const Value.absent(),
    this.compactedAt = const Value.absent(),
    this.compactedInputTokensAtTrigger = const Value.absent(),
    this.agentPresetId = const Value.absent(),
    this.personaSnapshot = const Value.absent(),
    this.toolsSnapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       providerId = Value(providerId),
       model = Value(model),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ChatSessionRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? providerId,
    Expression<String>? model,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? reasoningEffort,
    Expression<String>? compactedSummary,
    Expression<String>? compactedUpToMessageId,
    Expression<int>? compactedAt,
    Expression<int>? compactedInputTokensAtTrigger,
    Expression<String>? agentPresetId,
    Expression<String>? personaSnapshot,
    Expression<String>? toolsSnapshotJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (providerId != null) 'provider_id': providerId,
      if (model != null) 'model': model,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (reasoningEffort != null) 'reasoning_effort': reasoningEffort,
      if (compactedSummary != null) 'compacted_summary': compactedSummary,
      if (compactedUpToMessageId != null)
        'compacted_up_to_message_id': compactedUpToMessageId,
      if (compactedAt != null) 'compacted_at': compactedAt,
      if (compactedInputTokensAtTrigger != null)
        'compacted_input_tokens_at_trigger': compactedInputTokensAtTrigger,
      if (agentPresetId != null) 'agent_preset_id': agentPresetId,
      if (personaSnapshot != null) 'persona_snapshot': personaSnapshot,
      if (toolsSnapshotJson != null) 'tools_snapshot_json': toolsSnapshotJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? providerId,
    Value<String>? model,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? reasoningEffort,
    Value<String?>? compactedSummary,
    Value<String?>? compactedUpToMessageId,
    Value<int?>? compactedAt,
    Value<int?>? compactedInputTokensAtTrigger,
    Value<String?>? agentPresetId,
    Value<String?>? personaSnapshot,
    Value<String?>? toolsSnapshotJson,
    Value<int>? rowid,
  }) {
    return ChatSessionsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      providerId: providerId ?? this.providerId,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
      compactedSummary: compactedSummary ?? this.compactedSummary,
      compactedUpToMessageId:
          compactedUpToMessageId ?? this.compactedUpToMessageId,
      compactedAt: compactedAt ?? this.compactedAt,
      compactedInputTokensAtTrigger:
          compactedInputTokensAtTrigger ?? this.compactedInputTokensAtTrigger,
      agentPresetId: agentPresetId ?? this.agentPresetId,
      personaSnapshot: personaSnapshot ?? this.personaSnapshot,
      toolsSnapshotJson: toolsSnapshotJson ?? this.toolsSnapshotJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (reasoningEffort.present) {
      map['reasoning_effort'] = Variable<String>(reasoningEffort.value);
    }
    if (compactedSummary.present) {
      map['compacted_summary'] = Variable<String>(compactedSummary.value);
    }
    if (compactedUpToMessageId.present) {
      map['compacted_up_to_message_id'] = Variable<String>(
        compactedUpToMessageId.value,
      );
    }
    if (compactedAt.present) {
      map['compacted_at'] = Variable<int>(compactedAt.value);
    }
    if (compactedInputTokensAtTrigger.present) {
      map['compacted_input_tokens_at_trigger'] = Variable<int>(
        compactedInputTokensAtTrigger.value,
      );
    }
    if (agentPresetId.present) {
      map['agent_preset_id'] = Variable<String>(agentPresetId.value);
    }
    if (personaSnapshot.present) {
      map['persona_snapshot'] = Variable<String>(personaSnapshot.value);
    }
    if (toolsSnapshotJson.present) {
      map['tools_snapshot_json'] = Variable<String>(toolsSnapshotJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatSessionsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('providerId: $providerId, ')
          ..write('model: $model, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('reasoningEffort: $reasoningEffort, ')
          ..write('compactedSummary: $compactedSummary, ')
          ..write('compactedUpToMessageId: $compactedUpToMessageId, ')
          ..write('compactedAt: $compactedAt, ')
          ..write(
            'compactedInputTokensAtTrigger: $compactedInputTokensAtTrigger, ',
          )
          ..write('agentPresetId: $agentPresetId, ')
          ..write('personaSnapshot: $personaSnapshot, ')
          ..write('toolsSnapshotJson: $toolsSnapshotJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ChatMessages extends Table with TableInfo<ChatMessages, ChatMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ChatMessages(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES chat_sessions(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _reasoningMeta = const VerificationMeta(
    'reasoning',
  );
  late final GeneratedColumn<String> reasoning = GeneratedColumn<String>(
    'reasoning',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _thinkingMillisMeta = const VerificationMeta(
    'thinkingMillis',
  );
  late final GeneratedColumn<int> thinkingMillis = GeneratedColumn<int>(
    'thinking_millis',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _imageNameMeta = const VerificationMeta(
    'imageName',
  );
  late final GeneratedColumn<String> imageName = GeneratedColumn<String>(
    'image_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _inputTokensMeta = const VerificationMeta(
    'inputTokens',
  );
  late final GeneratedColumn<int> inputTokens = GeneratedColumn<int>(
    'input_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _outputTokensMeta = const VerificationMeta(
    'outputTokens',
  );
  late final GeneratedColumn<int> outputTokens = GeneratedColumn<int>(
    'output_tokens',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    role,
    content,
    createdAt,
    reasoning,
    thinkingMillis,
    imageName,
    inputTokens,
    outputTokens,
    model,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('reasoning')) {
      context.handle(
        _reasoningMeta,
        reasoning.isAcceptableOrUnknown(data['reasoning']!, _reasoningMeta),
      );
    }
    if (data.containsKey('thinking_millis')) {
      context.handle(
        _thinkingMillisMeta,
        thinkingMillis.isAcceptableOrUnknown(
          data['thinking_millis']!,
          _thinkingMillisMeta,
        ),
      );
    }
    if (data.containsKey('image_name')) {
      context.handle(
        _imageNameMeta,
        imageName.isAcceptableOrUnknown(data['image_name']!, _imageNameMeta),
      );
    }
    if (data.containsKey('input_tokens')) {
      context.handle(
        _inputTokensMeta,
        inputTokens.isAcceptableOrUnknown(
          data['input_tokens']!,
          _inputTokensMeta,
        ),
      );
    }
    if (data.containsKey('output_tokens')) {
      context.handle(
        _outputTokensMeta,
        outputTokens.isAcceptableOrUnknown(
          data['output_tokens']!,
          _outputTokensMeta,
        ),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      reasoning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reasoning'],
      ),
      thinkingMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}thinking_millis'],
      ),
      imageName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_name'],
      ),
      inputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_tokens'],
      ),
      outputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_tokens'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
    );
  }

  @override
  ChatMessages createAlias(String alias) {
    return ChatMessages(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ChatMessageRow extends DataClass implements Insertable<ChatMessageRow> {
  final String id;
  final String sessionId;
  final String role;
  final String content;
  final int createdAt;
  final String? reasoning;
  final int? thinkingMillis;
  final String? imageName;
  final int? inputTokens;
  final int? outputTokens;
  final String? model;
  const ChatMessageRow({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.reasoning,
    this.thinkingMillis,
    this.imageName,
    this.inputTokens,
    this.outputTokens,
    this.model,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || reasoning != null) {
      map['reasoning'] = Variable<String>(reasoning);
    }
    if (!nullToAbsent || thinkingMillis != null) {
      map['thinking_millis'] = Variable<int>(thinkingMillis);
    }
    if (!nullToAbsent || imageName != null) {
      map['image_name'] = Variable<String>(imageName);
    }
    if (!nullToAbsent || inputTokens != null) {
      map['input_tokens'] = Variable<int>(inputTokens);
    }
    if (!nullToAbsent || outputTokens != null) {
      map['output_tokens'] = Variable<int>(outputTokens);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      role: Value(role),
      content: Value(content),
      createdAt: Value(createdAt),
      reasoning: reasoning == null && nullToAbsent
          ? const Value.absent()
          : Value(reasoning),
      thinkingMillis: thinkingMillis == null && nullToAbsent
          ? const Value.absent()
          : Value(thinkingMillis),
      imageName: imageName == null && nullToAbsent
          ? const Value.absent()
          : Value(imageName),
      inputTokens: inputTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(inputTokens),
      outputTokens: outputTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(outputTokens),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
    );
  }

  factory ChatMessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessageRow(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['session_id']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      reasoning: serializer.fromJson<String?>(json['reasoning']),
      thinkingMillis: serializer.fromJson<int?>(json['thinking_millis']),
      imageName: serializer.fromJson<String?>(json['image_name']),
      inputTokens: serializer.fromJson<int?>(json['input_tokens']),
      outputTokens: serializer.fromJson<int?>(json['output_tokens']),
      model: serializer.fromJson<String?>(json['model']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'session_id': serializer.toJson<String>(sessionId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'created_at': serializer.toJson<int>(createdAt),
      'reasoning': serializer.toJson<String?>(reasoning),
      'thinking_millis': serializer.toJson<int?>(thinkingMillis),
      'image_name': serializer.toJson<String?>(imageName),
      'input_tokens': serializer.toJson<int?>(inputTokens),
      'output_tokens': serializer.toJson<int?>(outputTokens),
      'model': serializer.toJson<String?>(model),
    };
  }

  ChatMessageRow copyWith({
    String? id,
    String? sessionId,
    String? role,
    String? content,
    int? createdAt,
    Value<String?> reasoning = const Value.absent(),
    Value<int?> thinkingMillis = const Value.absent(),
    Value<String?> imageName = const Value.absent(),
    Value<int?> inputTokens = const Value.absent(),
    Value<int?> outputTokens = const Value.absent(),
    Value<String?> model = const Value.absent(),
  }) => ChatMessageRow(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    role: role ?? this.role,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    reasoning: reasoning.present ? reasoning.value : this.reasoning,
    thinkingMillis: thinkingMillis.present
        ? thinkingMillis.value
        : this.thinkingMillis,
    imageName: imageName.present ? imageName.value : this.imageName,
    inputTokens: inputTokens.present ? inputTokens.value : this.inputTokens,
    outputTokens: outputTokens.present ? outputTokens.value : this.outputTokens,
    model: model.present ? model.value : this.model,
  );
  ChatMessageRow copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessageRow(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      reasoning: data.reasoning.present ? data.reasoning.value : this.reasoning,
      thinkingMillis: data.thinkingMillis.present
          ? data.thinkingMillis.value
          : this.thinkingMillis,
      imageName: data.imageName.present ? data.imageName.value : this.imageName,
      inputTokens: data.inputTokens.present
          ? data.inputTokens.value
          : this.inputTokens,
      outputTokens: data.outputTokens.present
          ? data.outputTokens.value
          : this.outputTokens,
      model: data.model.present ? data.model.value : this.model,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessageRow(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('reasoning: $reasoning, ')
          ..write('thinkingMillis: $thinkingMillis, ')
          ..write('imageName: $imageName, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('model: $model')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    role,
    content,
    createdAt,
    reasoning,
    thinkingMillis,
    imageName,
    inputTokens,
    outputTokens,
    model,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessageRow &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.role == this.role &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.reasoning == this.reasoning &&
          other.thinkingMillis == this.thinkingMillis &&
          other.imageName == this.imageName &&
          other.inputTokens == this.inputTokens &&
          other.outputTokens == this.outputTokens &&
          other.model == this.model);
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessageRow> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> role;
  final Value<String> content;
  final Value<int> createdAt;
  final Value<String?> reasoning;
  final Value<int?> thinkingMillis;
  final Value<String?> imageName;
  final Value<int?> inputTokens;
  final Value<int?> outputTokens;
  final Value<String?> model;
  final Value<int> rowid;
  const ChatMessagesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.reasoning = const Value.absent(),
    this.thinkingMillis = const Value.absent(),
    this.imageName = const Value.absent(),
    this.inputTokens = const Value.absent(),
    this.outputTokens = const Value.absent(),
    this.model = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    required String id,
    required String sessionId,
    required String role,
    required String content,
    required int createdAt,
    this.reasoning = const Value.absent(),
    this.thinkingMillis = const Value.absent(),
    this.imageName = const Value.absent(),
    this.inputTokens = const Value.absent(),
    this.outputTokens = const Value.absent(),
    this.model = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       role = Value(role),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<ChatMessageRow> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<int>? createdAt,
    Expression<String>? reasoning,
    Expression<int>? thinkingMillis,
    Expression<String>? imageName,
    Expression<int>? inputTokens,
    Expression<int>? outputTokens,
    Expression<String>? model,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (reasoning != null) 'reasoning': reasoning,
      if (thinkingMillis != null) 'thinking_millis': thinkingMillis,
      if (imageName != null) 'image_name': imageName,
      if (inputTokens != null) 'input_tokens': inputTokens,
      if (outputTokens != null) 'output_tokens': outputTokens,
      if (model != null) 'model': model,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? role,
    Value<String>? content,
    Value<int>? createdAt,
    Value<String?>? reasoning,
    Value<int?>? thinkingMillis,
    Value<String?>? imageName,
    Value<int?>? inputTokens,
    Value<int?>? outputTokens,
    Value<String?>? model,
    Value<int>? rowid,
  }) {
    return ChatMessagesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      reasoning: reasoning ?? this.reasoning,
      thinkingMillis: thinkingMillis ?? this.thinkingMillis,
      imageName: imageName ?? this.imageName,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      model: model ?? this.model,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (reasoning.present) {
      map['reasoning'] = Variable<String>(reasoning.value);
    }
    if (thinkingMillis.present) {
      map['thinking_millis'] = Variable<int>(thinkingMillis.value);
    }
    if (imageName.present) {
      map['image_name'] = Variable<String>(imageName.value);
    }
    if (inputTokens.present) {
      map['input_tokens'] = Variable<int>(inputTokens.value);
    }
    if (outputTokens.present) {
      map['output_tokens'] = Variable<int>(outputTokens.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('reasoning: $reasoning, ')
          ..write('thinkingMillis: $thinkingMillis, ')
          ..write('imageName: $imageName, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('model: $model, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AssistantToolCalls extends Table
    with TableInfo<AssistantToolCalls, AssistantToolCallRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AssistantToolCalls(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL REFERENCES chat_messages(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _callIdMeta = const VerificationMeta('callId');
  late final GeneratedColumn<String> callId = GeneratedColumn<String>(
    'call_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _argsJsonMeta = const VerificationMeta(
    'argsJson',
  );
  late final GeneratedColumn<String> argsJson = GeneratedColumn<String>(
    'args_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  late final GeneratedColumn<int> done = GeneratedColumn<int>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    seq,
    callId,
    name,
    argsJson,
    result,
    done,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assistant_tool_calls';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssistantToolCallRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('call_id')) {
      context.handle(
        _callIdMeta,
        callId.isAcceptableOrUnknown(data['call_id']!, _callIdMeta),
      );
    } else if (isInserting) {
      context.missing(_callIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('args_json')) {
      context.handle(
        _argsJsonMeta,
        argsJson.isAcceptableOrUnknown(data['args_json']!, _argsJsonMeta),
      );
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId, seq};
  @override
  AssistantToolCallRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssistantToolCallRow(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      callId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}call_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      argsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}args_json'],
      )!,
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}done'],
      )!,
    );
  }

  @override
  AssistantToolCalls createAlias(String alias) {
    return AssistantToolCalls(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(message_id, seq)'];
  @override
  bool get dontWriteConstraints => true;
}

class AssistantToolCallRow extends DataClass
    implements Insertable<AssistantToolCallRow> {
  final String messageId;
  final int seq;
  final String callId;
  final String name;
  final String argsJson;
  final String result;
  final int done;
  const AssistantToolCallRow({
    required this.messageId,
    required this.seq,
    required this.callId,
    required this.name,
    required this.argsJson,
    required this.result,
    required this.done,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['seq'] = Variable<int>(seq);
    map['call_id'] = Variable<String>(callId);
    map['name'] = Variable<String>(name);
    map['args_json'] = Variable<String>(argsJson);
    map['result'] = Variable<String>(result);
    map['done'] = Variable<int>(done);
    return map;
  }

  AssistantToolCallsCompanion toCompanion(bool nullToAbsent) {
    return AssistantToolCallsCompanion(
      messageId: Value(messageId),
      seq: Value(seq),
      callId: Value(callId),
      name: Value(name),
      argsJson: Value(argsJson),
      result: Value(result),
      done: Value(done),
    );
  }

  factory AssistantToolCallRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssistantToolCallRow(
      messageId: serializer.fromJson<String>(json['message_id']),
      seq: serializer.fromJson<int>(json['seq']),
      callId: serializer.fromJson<String>(json['call_id']),
      name: serializer.fromJson<String>(json['name']),
      argsJson: serializer.fromJson<String>(json['args_json']),
      result: serializer.fromJson<String>(json['result']),
      done: serializer.fromJson<int>(json['done']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'message_id': serializer.toJson<String>(messageId),
      'seq': serializer.toJson<int>(seq),
      'call_id': serializer.toJson<String>(callId),
      'name': serializer.toJson<String>(name),
      'args_json': serializer.toJson<String>(argsJson),
      'result': serializer.toJson<String>(result),
      'done': serializer.toJson<int>(done),
    };
  }

  AssistantToolCallRow copyWith({
    String? messageId,
    int? seq,
    String? callId,
    String? name,
    String? argsJson,
    String? result,
    int? done,
  }) => AssistantToolCallRow(
    messageId: messageId ?? this.messageId,
    seq: seq ?? this.seq,
    callId: callId ?? this.callId,
    name: name ?? this.name,
    argsJson: argsJson ?? this.argsJson,
    result: result ?? this.result,
    done: done ?? this.done,
  );
  AssistantToolCallRow copyWithCompanion(AssistantToolCallsCompanion data) {
    return AssistantToolCallRow(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      seq: data.seq.present ? data.seq.value : this.seq,
      callId: data.callId.present ? data.callId.value : this.callId,
      name: data.name.present ? data.name.value : this.name,
      argsJson: data.argsJson.present ? data.argsJson.value : this.argsJson,
      result: data.result.present ? data.result.value : this.result,
      done: data.done.present ? data.done.value : this.done,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssistantToolCallRow(')
          ..write('messageId: $messageId, ')
          ..write('seq: $seq, ')
          ..write('callId: $callId, ')
          ..write('name: $name, ')
          ..write('argsJson: $argsJson, ')
          ..write('result: $result, ')
          ..write('done: $done')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(messageId, seq, callId, name, argsJson, result, done);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantToolCallRow &&
          other.messageId == this.messageId &&
          other.seq == this.seq &&
          other.callId == this.callId &&
          other.name == this.name &&
          other.argsJson == this.argsJson &&
          other.result == this.result &&
          other.done == this.done);
}

class AssistantToolCallsCompanion
    extends UpdateCompanion<AssistantToolCallRow> {
  final Value<String> messageId;
  final Value<int> seq;
  final Value<String> callId;
  final Value<String> name;
  final Value<String> argsJson;
  final Value<String> result;
  final Value<int> done;
  final Value<int> rowid;
  const AssistantToolCallsCompanion({
    this.messageId = const Value.absent(),
    this.seq = const Value.absent(),
    this.callId = const Value.absent(),
    this.name = const Value.absent(),
    this.argsJson = const Value.absent(),
    this.result = const Value.absent(),
    this.done = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssistantToolCallsCompanion.insert({
    required String messageId,
    required int seq,
    required String callId,
    required String name,
    this.argsJson = const Value.absent(),
    this.result = const Value.absent(),
    this.done = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       seq = Value(seq),
       callId = Value(callId),
       name = Value(name);
  static Insertable<AssistantToolCallRow> custom({
    Expression<String>? messageId,
    Expression<int>? seq,
    Expression<String>? callId,
    Expression<String>? name,
    Expression<String>? argsJson,
    Expression<String>? result,
    Expression<int>? done,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (seq != null) 'seq': seq,
      if (callId != null) 'call_id': callId,
      if (name != null) 'name': name,
      if (argsJson != null) 'args_json': argsJson,
      if (result != null) 'result': result,
      if (done != null) 'done': done,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssistantToolCallsCompanion copyWith({
    Value<String>? messageId,
    Value<int>? seq,
    Value<String>? callId,
    Value<String>? name,
    Value<String>? argsJson,
    Value<String>? result,
    Value<int>? done,
    Value<int>? rowid,
  }) {
    return AssistantToolCallsCompanion(
      messageId: messageId ?? this.messageId,
      seq: seq ?? this.seq,
      callId: callId ?? this.callId,
      name: name ?? this.name,
      argsJson: argsJson ?? this.argsJson,
      result: result ?? this.result,
      done: done ?? this.done,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (callId.present) {
      map['call_id'] = Variable<String>(callId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (argsJson.present) {
      map['args_json'] = Variable<String>(argsJson.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (done.present) {
      map['done'] = Variable<int>(done.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssistantToolCallsCompanion(')
          ..write('messageId: $messageId, ')
          ..write('seq: $seq, ')
          ..write('callId: $callId, ')
          ..write('name: $name, ')
          ..write('argsJson: $argsJson, ')
          ..write('result: $result, ')
          ..write('done: $done, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Memories extends Table with TableInfo<Memories, MemoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Memories(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    category,
    content,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memories';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MemoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  Memories createAlias(String alias) {
    return Memories(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class MemoryRow extends DataClass implements Insertable<MemoryRow> {
  final String id;
  final String category;
  final String content;
  final int createdAt;
  final int updatedAt;
  const MemoryRow({
    required this.id,
    required this.category,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category'] = Variable<String>(category);
    map['content'] = Variable<String>(content);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MemoriesCompanion toCompanion(bool nullToAbsent) {
    return MemoriesCompanion(
      id: Value(id),
      category: Value(category),
      content: Value(content),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MemoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemoryRow(
      id: serializer.fromJson<String>(json['id']),
      category: serializer.fromJson<String>(json['category']),
      content: serializer.fromJson<String>(json['content']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'category': serializer.toJson<String>(category),
      'content': serializer.toJson<String>(content),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
    };
  }

  MemoryRow copyWith({
    String? id,
    String? category,
    String? content,
    int? createdAt,
    int? updatedAt,
  }) => MemoryRow(
    id: id ?? this.id,
    category: category ?? this.category,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MemoryRow copyWithCompanion(MemoriesCompanion data) {
    return MemoryRow(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      content: data.content.present ? data.content.value : this.content,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemoryRow(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, category, content, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemoryRow &&
          other.id == this.id &&
          other.category == this.category &&
          other.content == this.content &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MemoriesCompanion extends UpdateCompanion<MemoryRow> {
  final Value<String> id;
  final Value<String> category;
  final Value<String> content;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const MemoriesCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.content = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemoriesCompanion.insert({
    required String id,
    required String category,
    required String content,
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       category = Value(category),
       content = Value(content),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MemoryRow> custom({
    Expression<String>? id,
    Expression<String>? category,
    Expression<String>? content,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (content != null) 'content': content,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? category,
    Value<String>? content,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return MemoriesCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemoriesCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('content: $content, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AgentPresets extends Table with TableInfo<AgentPresets, AgentPresetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AgentPresets(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'\'',
    defaultValue: const CustomExpression('\'\''),
  );
  static const VerificationMeta _personaMeta = const VerificationMeta(
    'persona',
  );
  late final GeneratedColumn<String> persona = GeneratedColumn<String>(
    'persona',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _toolsJsonMeta = const VerificationMeta(
    'toolsJson',
  );
  late final GeneratedColumn<String> toolsJson = GeneratedColumn<String>(
    'tools_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    persona,
    toolsJson,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_presets';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentPresetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('persona')) {
      context.handle(
        _personaMeta,
        persona.isAcceptableOrUnknown(data['persona']!, _personaMeta),
      );
    } else if (isInserting) {
      context.missing(_personaMeta);
    }
    if (data.containsKey('tools_json')) {
      context.handle(
        _toolsJsonMeta,
        toolsJson.isAcceptableOrUnknown(data['tools_json']!, _toolsJsonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgentPresetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentPresetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      persona: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}persona'],
      )!,
      toolsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tools_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  AgentPresets createAlias(String alias) {
    return AgentPresets(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class AgentPresetRow extends DataClass implements Insertable<AgentPresetRow> {
  final String id;
  final String name;
  final String description;
  final String persona;
  final String? toolsJson;
  final int createdAt;
  final int updatedAt;
  const AgentPresetRow({
    required this.id,
    required this.name,
    required this.description,
    required this.persona,
    this.toolsJson,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['persona'] = Variable<String>(persona);
    if (!nullToAbsent || toolsJson != null) {
      map['tools_json'] = Variable<String>(toolsJson);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AgentPresetsCompanion toCompanion(bool nullToAbsent) {
    return AgentPresetsCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      persona: Value(persona),
      toolsJson: toolsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(toolsJson),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AgentPresetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentPresetRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      persona: serializer.fromJson<String>(json['persona']),
      toolsJson: serializer.fromJson<String?>(json['tools_json']),
      createdAt: serializer.fromJson<int>(json['created_at']),
      updatedAt: serializer.fromJson<int>(json['updated_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'persona': serializer.toJson<String>(persona),
      'tools_json': serializer.toJson<String?>(toolsJson),
      'created_at': serializer.toJson<int>(createdAt),
      'updated_at': serializer.toJson<int>(updatedAt),
    };
  }

  AgentPresetRow copyWith({
    String? id,
    String? name,
    String? description,
    String? persona,
    Value<String?> toolsJson = const Value.absent(),
    int? createdAt,
    int? updatedAt,
  }) => AgentPresetRow(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    persona: persona ?? this.persona,
    toolsJson: toolsJson.present ? toolsJson.value : this.toolsJson,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AgentPresetRow copyWithCompanion(AgentPresetsCompanion data) {
    return AgentPresetRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      persona: data.persona.present ? data.persona.value : this.persona,
      toolsJson: data.toolsJson.present ? data.toolsJson.value : this.toolsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentPresetRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('persona: $persona, ')
          ..write('toolsJson: $toolsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    persona,
    toolsJson,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentPresetRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.persona == this.persona &&
          other.toolsJson == this.toolsJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AgentPresetsCompanion extends UpdateCompanion<AgentPresetRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> description;
  final Value<String> persona;
  final Value<String?> toolsJson;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AgentPresetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.persona = const Value.absent(),
    this.toolsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentPresetsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required String persona,
    this.toolsJson = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       persona = Value(persona),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AgentPresetRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? persona,
    Expression<String>? toolsJson,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (persona != null) 'persona': persona,
      if (toolsJson != null) 'tools_json': toolsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentPresetsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? description,
    Value<String>? persona,
    Value<String?>? toolsJson,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return AgentPresetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      persona: persona ?? this.persona,
      toolsJson: toolsJson ?? this.toolsJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (persona.present) {
      map['persona'] = Variable<String>(persona.value);
    }
    if (toolsJson.present) {
      map['tools_json'] = Variable<String>(toolsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentPresetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('persona: $persona, ')
          ..write('toolsJson: $toolsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Tombstones extends Table with TableInfo<Tombstones, TombstoneRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Tombstones(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _timeMsMeta = const VerificationMeta('timeMs');
  late final GeneratedColumn<int> timeMs = GeneratedColumn<int>(
    'time_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _pushedBackendsJsonMeta =
      const VerificationMeta('pushedBackendsJson');
  late final GeneratedColumn<String> pushedBackendsJson =
      GeneratedColumn<String>(
        'pushed_backends_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: 'NOT NULL DEFAULT \'[]\'',
        defaultValue: const CustomExpression('\'[]\''),
      );
  @override
  List<GeneratedColumn> get $columns => [key, timeMs, pushedBackendsJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tombstones';
  @override
  VerificationContext validateIntegrity(
    Insertable<TombstoneRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('time_ms')) {
      context.handle(
        _timeMsMeta,
        timeMs.isAcceptableOrUnknown(data['time_ms']!, _timeMsMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMsMeta);
    }
    if (data.containsKey('pushed_backends_json')) {
      context.handle(
        _pushedBackendsJsonMeta,
        pushedBackendsJson.isAcceptableOrUnknown(
          data['pushed_backends_json']!,
          _pushedBackendsJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  TombstoneRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TombstoneRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      timeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_ms'],
      )!,
      pushedBackendsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pushed_backends_json'],
      )!,
    );
  }

  @override
  Tombstones createAlias(String alias) {
    return Tombstones(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class TombstoneRow extends DataClass implements Insertable<TombstoneRow> {
  final String key;
  final int timeMs;
  final String pushedBackendsJson;
  const TombstoneRow({
    required this.key,
    required this.timeMs,
    required this.pushedBackendsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['time_ms'] = Variable<int>(timeMs);
    map['pushed_backends_json'] = Variable<String>(pushedBackendsJson);
    return map;
  }

  TombstonesCompanion toCompanion(bool nullToAbsent) {
    return TombstonesCompanion(
      key: Value(key),
      timeMs: Value(timeMs),
      pushedBackendsJson: Value(pushedBackendsJson),
    );
  }

  factory TombstoneRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TombstoneRow(
      key: serializer.fromJson<String>(json['key']),
      timeMs: serializer.fromJson<int>(json['time_ms']),
      pushedBackendsJson: serializer.fromJson<String>(
        json['pushed_backends_json'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'time_ms': serializer.toJson<int>(timeMs),
      'pushed_backends_json': serializer.toJson<String>(pushedBackendsJson),
    };
  }

  TombstoneRow copyWith({
    String? key,
    int? timeMs,
    String? pushedBackendsJson,
  }) => TombstoneRow(
    key: key ?? this.key,
    timeMs: timeMs ?? this.timeMs,
    pushedBackendsJson: pushedBackendsJson ?? this.pushedBackendsJson,
  );
  TombstoneRow copyWithCompanion(TombstonesCompanion data) {
    return TombstoneRow(
      key: data.key.present ? data.key.value : this.key,
      timeMs: data.timeMs.present ? data.timeMs.value : this.timeMs,
      pushedBackendsJson: data.pushedBackendsJson.present
          ? data.pushedBackendsJson.value
          : this.pushedBackendsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TombstoneRow(')
          ..write('key: $key, ')
          ..write('timeMs: $timeMs, ')
          ..write('pushedBackendsJson: $pushedBackendsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, timeMs, pushedBackendsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TombstoneRow &&
          other.key == this.key &&
          other.timeMs == this.timeMs &&
          other.pushedBackendsJson == this.pushedBackendsJson);
}

class TombstonesCompanion extends UpdateCompanion<TombstoneRow> {
  final Value<String> key;
  final Value<int> timeMs;
  final Value<String> pushedBackendsJson;
  final Value<int> rowid;
  const TombstonesCompanion({
    this.key = const Value.absent(),
    this.timeMs = const Value.absent(),
    this.pushedBackendsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TombstonesCompanion.insert({
    required String key,
    required int timeMs,
    this.pushedBackendsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       timeMs = Value(timeMs);
  static Insertable<TombstoneRow> custom({
    Expression<String>? key,
    Expression<int>? timeMs,
    Expression<String>? pushedBackendsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (timeMs != null) 'time_ms': timeMs,
      if (pushedBackendsJson != null)
        'pushed_backends_json': pushedBackendsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TombstonesCompanion copyWith({
    Value<String>? key,
    Value<int>? timeMs,
    Value<String>? pushedBackendsJson,
    Value<int>? rowid,
  }) {
    return TombstonesCompanion(
      key: key ?? this.key,
      timeMs: timeMs ?? this.timeMs,
      pushedBackendsJson: pushedBackendsJson ?? this.pushedBackendsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (timeMs.present) {
      map['time_ms'] = Variable<int>(timeMs.value);
    }
    if (pushedBackendsJson.present) {
      map['pushed_backends_json'] = Variable<String>(pushedBackendsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TombstonesCompanion(')
          ..write('key: $key, ')
          ..write('timeMs: $timeMs, ')
          ..write('pushedBackendsJson: $pushedBackendsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Categories extends Table with TableInfo<Categories, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Categories(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  late final GeneratedColumn<int> lastModified = GeneratedColumn<int>(
    'last_modified',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    lastModified,
    parentId,
    color,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastModifiedMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_modified'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
    );
  }

  @override
  Categories createAlias(String alias) {
    return Categories(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  final String id;
  final String name;
  final int lastModified;
  final String? parentId;
  final int? color;
  const CategoryRow({
    required this.id,
    required this.name,
    required this.lastModified,
    this.parentId,
    this.color,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['last_modified'] = Variable<int>(lastModified);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      lastModified: Value(lastModified),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      lastModified: serializer.fromJson<int>(json['last_modified']),
      parentId: serializer.fromJson<String?>(json['parent_id']),
      color: serializer.fromJson<int?>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'last_modified': serializer.toJson<int>(lastModified),
      'parent_id': serializer.toJson<String?>(parentId),
      'color': serializer.toJson<int?>(color),
    };
  }

  CategoryRow copyWith({
    String? id,
    String? name,
    int? lastModified,
    Value<String?> parentId = const Value.absent(),
    Value<int?> color = const Value.absent(),
  }) => CategoryRow(
    id: id ?? this.id,
    name: name ?? this.name,
    lastModified: lastModified ?? this.lastModified,
    parentId: parentId.present ? parentId.value : this.parentId,
    color: color.present ? color.value : this.color,
  );
  CategoryRow copyWithCompanion(CategoriesCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('lastModified: $lastModified, ')
          ..write('parentId: $parentId, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, lastModified, parentId, color);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.lastModified == this.lastModified &&
          other.parentId == this.parentId &&
          other.color == this.color);
}

class CategoriesCompanion extends UpdateCompanion<CategoryRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> lastModified;
  final Value<String?> parentId;
  final Value<int?> color;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.parentId = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String name,
    required int lastModified,
    this.parentId = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       lastModified = Value(lastModified);
  static Insertable<CategoryRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? lastModified,
    Expression<String>? parentId,
    Expression<int>? color,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (lastModified != null) 'last_modified': lastModified,
      if (parentId != null) 'parent_id': parentId,
      if (color != null) 'color': color,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? lastModified,
    Value<String?>? parentId,
    Value<int?>? color,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      lastModified: lastModified ?? this.lastModified,
      parentId: parentId ?? this.parentId,
      color: color ?? this.color,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<int>(lastModified.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('lastModified: $lastModified, ')
          ..write('parentId: $parentId, ')
          ..write('color: $color, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Fonts extends Table with TableInfo<Fonts, FontRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Fonts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fontFamilyMeta = const VerificationMeta(
    'fontFamily',
  );
  late final GeneratedColumn<String> fontFamily = GeneratedColumn<String>(
    'font_family',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _fontFileNameMeta = const VerificationMeta(
    'fontFileName',
  );
  late final GeneratedColumn<String> fontFileName = GeneratedColumn<String>(
    'font_file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _wghtAxisJsonMeta = const VerificationMeta(
    'wghtAxisJson',
  );
  late final GeneratedColumn<String> wghtAxisJson = GeneratedColumn<String>(
    'wght_axis_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    fontFamily,
    fontFileName,
    wghtAxisJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fonts';
  @override
  VerificationContext validateIntegrity(
    Insertable<FontRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('font_family')) {
      context.handle(
        _fontFamilyMeta,
        fontFamily.isAcceptableOrUnknown(data['font_family']!, _fontFamilyMeta),
      );
    } else if (isInserting) {
      context.missing(_fontFamilyMeta);
    }
    if (data.containsKey('font_file_name')) {
      context.handle(
        _fontFileNameMeta,
        fontFileName.isAcceptableOrUnknown(
          data['font_file_name']!,
          _fontFileNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fontFileNameMeta);
    }
    if (data.containsKey('wght_axis_json')) {
      context.handle(
        _wghtAxisJsonMeta,
        wghtAxisJson.isAcceptableOrUnknown(
          data['wght_axis_json']!,
          _wghtAxisJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fontFamily};
  @override
  FontRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FontRow(
      fontFamily: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}font_family'],
      )!,
      fontFileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}font_file_name'],
      )!,
      wghtAxisJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wght_axis_json'],
      )!,
    );
  }

  @override
  Fonts createAlias(String alias) {
    return Fonts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class FontRow extends DataClass implements Insertable<FontRow> {
  final String fontFamily;
  final String fontFileName;
  final String wghtAxisJson;
  const FontRow({
    required this.fontFamily,
    required this.fontFileName,
    required this.wghtAxisJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['font_family'] = Variable<String>(fontFamily);
    map['font_file_name'] = Variable<String>(fontFileName);
    map['wght_axis_json'] = Variable<String>(wghtAxisJson);
    return map;
  }

  FontsCompanion toCompanion(bool nullToAbsent) {
    return FontsCompanion(
      fontFamily: Value(fontFamily),
      fontFileName: Value(fontFileName),
      wghtAxisJson: Value(wghtAxisJson),
    );
  }

  factory FontRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FontRow(
      fontFamily: serializer.fromJson<String>(json['font_family']),
      fontFileName: serializer.fromJson<String>(json['font_file_name']),
      wghtAxisJson: serializer.fromJson<String>(json['wght_axis_json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'font_family': serializer.toJson<String>(fontFamily),
      'font_file_name': serializer.toJson<String>(fontFileName),
      'wght_axis_json': serializer.toJson<String>(wghtAxisJson),
    };
  }

  FontRow copyWith({
    String? fontFamily,
    String? fontFileName,
    String? wghtAxisJson,
  }) => FontRow(
    fontFamily: fontFamily ?? this.fontFamily,
    fontFileName: fontFileName ?? this.fontFileName,
    wghtAxisJson: wghtAxisJson ?? this.wghtAxisJson,
  );
  FontRow copyWithCompanion(FontsCompanion data) {
    return FontRow(
      fontFamily: data.fontFamily.present
          ? data.fontFamily.value
          : this.fontFamily,
      fontFileName: data.fontFileName.present
          ? data.fontFileName.value
          : this.fontFileName,
      wghtAxisJson: data.wghtAxisJson.present
          ? data.wghtAxisJson.value
          : this.wghtAxisJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FontRow(')
          ..write('fontFamily: $fontFamily, ')
          ..write('fontFileName: $fontFileName, ')
          ..write('wghtAxisJson: $wghtAxisJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(fontFamily, fontFileName, wghtAxisJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FontRow &&
          other.fontFamily == this.fontFamily &&
          other.fontFileName == this.fontFileName &&
          other.wghtAxisJson == this.wghtAxisJson);
}

class FontsCompanion extends UpdateCompanion<FontRow> {
  final Value<String> fontFamily;
  final Value<String> fontFileName;
  final Value<String> wghtAxisJson;
  final Value<int> rowid;
  const FontsCompanion({
    this.fontFamily = const Value.absent(),
    this.fontFileName = const Value.absent(),
    this.wghtAxisJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FontsCompanion.insert({
    required String fontFamily,
    required String fontFileName,
    this.wghtAxisJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : fontFamily = Value(fontFamily),
       fontFileName = Value(fontFileName);
  static Insertable<FontRow> custom({
    Expression<String>? fontFamily,
    Expression<String>? fontFileName,
    Expression<String>? wghtAxisJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fontFamily != null) 'font_family': fontFamily,
      if (fontFileName != null) 'font_file_name': fontFileName,
      if (wghtAxisJson != null) 'wght_axis_json': wghtAxisJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FontsCompanion copyWith({
    Value<String>? fontFamily,
    Value<String>? fontFileName,
    Value<String>? wghtAxisJson,
    Value<int>? rowid,
  }) {
    return FontsCompanion(
      fontFamily: fontFamily ?? this.fontFamily,
      fontFileName: fontFileName ?? this.fontFileName,
      wghtAxisJson: wghtAxisJson ?? this.wghtAxisJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fontFamily.present) {
      map['font_family'] = Variable<String>(fontFamily.value);
    }
    if (fontFileName.present) {
      map['font_file_name'] = Variable<String>(fontFileName.value);
    }
    if (wghtAxisJson.present) {
      map['wght_axis_json'] = Variable<String>(wghtAxisJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FontsCompanion(')
          ..write('fontFamily: $fontFamily, ')
          ..write('fontFileName: $fontFileName, ')
          ..write('wghtAxisJson: $wghtAxisJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class MediaInfos extends Table with TableInfo<MediaInfos, MediaInfoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  MediaInfos(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _lastModifiedMeta = const VerificationMeta(
    'lastModified',
  );
  late final GeneratedColumn<int> lastModified = GeneratedColumn<int>(
    'last_modified',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    fileName,
    name,
    durationMs,
    lastModified,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_infos';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaInfoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('last_modified')) {
      context.handle(
        _lastModifiedMeta,
        lastModified.isAcceptableOrUnknown(
          data['last_modified']!,
          _lastModifiedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastModifiedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fileName};
  @override
  MediaInfoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaInfoRow(
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      lastModified: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_modified'],
      )!,
    );
  }

  @override
  MediaInfos createAlias(String alias) {
    return MediaInfos(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class MediaInfoRow extends DataClass implements Insertable<MediaInfoRow> {
  final String fileName;
  final String? name;
  final int? durationMs;
  final int lastModified;
  const MediaInfoRow({
    required this.fileName,
    this.name,
    this.durationMs,
    required this.lastModified,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_name'] = Variable<String>(fileName);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['last_modified'] = Variable<int>(lastModified);
    return map;
  }

  MediaInfosCompanion toCompanion(bool nullToAbsent) {
    return MediaInfosCompanion(
      fileName: Value(fileName),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      lastModified: Value(lastModified),
    );
  }

  factory MediaInfoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaInfoRow(
      fileName: serializer.fromJson<String>(json['file_name']),
      name: serializer.fromJson<String?>(json['name']),
      durationMs: serializer.fromJson<int?>(json['duration_ms']),
      lastModified: serializer.fromJson<int>(json['last_modified']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'file_name': serializer.toJson<String>(fileName),
      'name': serializer.toJson<String?>(name),
      'duration_ms': serializer.toJson<int?>(durationMs),
      'last_modified': serializer.toJson<int>(lastModified),
    };
  }

  MediaInfoRow copyWith({
    String? fileName,
    Value<String?> name = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    int? lastModified,
  }) => MediaInfoRow(
    fileName: fileName ?? this.fileName,
    name: name.present ? name.value : this.name,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    lastModified: lastModified ?? this.lastModified,
  );
  MediaInfoRow copyWithCompanion(MediaInfosCompanion data) {
    return MediaInfoRow(
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      name: data.name.present ? data.name.value : this.name,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      lastModified: data.lastModified.present
          ? data.lastModified.value
          : this.lastModified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaInfoRow(')
          ..write('fileName: $fileName, ')
          ..write('name: $name, ')
          ..write('durationMs: $durationMs, ')
          ..write('lastModified: $lastModified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(fileName, name, durationMs, lastModified);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaInfoRow &&
          other.fileName == this.fileName &&
          other.name == this.name &&
          other.durationMs == this.durationMs &&
          other.lastModified == this.lastModified);
}

class MediaInfosCompanion extends UpdateCompanion<MediaInfoRow> {
  final Value<String> fileName;
  final Value<String?> name;
  final Value<int?> durationMs;
  final Value<int> lastModified;
  final Value<int> rowid;
  const MediaInfosCompanion({
    this.fileName = const Value.absent(),
    this.name = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.lastModified = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaInfosCompanion.insert({
    required String fileName,
    this.name = const Value.absent(),
    this.durationMs = const Value.absent(),
    required int lastModified,
    this.rowid = const Value.absent(),
  }) : fileName = Value(fileName),
       lastModified = Value(lastModified);
  static Insertable<MediaInfoRow> custom({
    Expression<String>? fileName,
    Expression<String>? name,
    Expression<int>? durationMs,
    Expression<int>? lastModified,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fileName != null) 'file_name': fileName,
      if (name != null) 'name': name,
      if (durationMs != null) 'duration_ms': durationMs,
      if (lastModified != null) 'last_modified': lastModified,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaInfosCompanion copyWith({
    Value<String>? fileName,
    Value<String?>? name,
    Value<int?>? durationMs,
    Value<int>? lastModified,
    Value<int>? rowid,
  }) {
    return MediaInfosCompanion(
      fileName: fileName ?? this.fileName,
      name: name ?? this.name,
      durationMs: durationMs ?? this.durationMs,
      lastModified: lastModified ?? this.lastModified,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (lastModified.present) {
      map['last_modified'] = Variable<int>(lastModified.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaInfosCompanion(')
          ..write('fileName: $fileName, ')
          ..write('name: $name, ')
          ..write('durationMs: $durationMs, ')
          ..write('lastModified: $lastModified, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class DiaryMedia extends Table with TableInfo<DiaryMedia, DiaryMediaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DiaryMedia(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _diaryIdMeta = const VerificationMeta(
    'diaryId',
  );
  late final GeneratedColumn<String> diaryId = GeneratedColumn<String>(
    'diary_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES diaries(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [diaryId, kind, seq, fileName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_media';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryMediaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('diary_id')) {
      context.handle(
        _diaryIdMeta,
        diaryId.isAcceptableOrUnknown(data['diary_id']!, _diaryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_diaryIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {diaryId, kind, seq};
  @override
  DiaryMediaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryMediaRow(
      diaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diary_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
    );
  }

  @override
  DiaryMedia createAlias(String alias) {
    return DiaryMedia(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(diary_id, kind, seq)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class DiaryMediaRow extends DataClass implements Insertable<DiaryMediaRow> {
  final String diaryId;
  final String kind;
  final int seq;
  final String fileName;
  const DiaryMediaRow({
    required this.diaryId,
    required this.kind,
    required this.seq,
    required this.fileName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['diary_id'] = Variable<String>(diaryId);
    map['kind'] = Variable<String>(kind);
    map['seq'] = Variable<int>(seq);
    map['file_name'] = Variable<String>(fileName);
    return map;
  }

  DiaryMediaCompanion toCompanion(bool nullToAbsent) {
    return DiaryMediaCompanion(
      diaryId: Value(diaryId),
      kind: Value(kind),
      seq: Value(seq),
      fileName: Value(fileName),
    );
  }

  factory DiaryMediaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryMediaRow(
      diaryId: serializer.fromJson<String>(json['diary_id']),
      kind: serializer.fromJson<String>(json['kind']),
      seq: serializer.fromJson<int>(json['seq']),
      fileName: serializer.fromJson<String>(json['file_name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'diary_id': serializer.toJson<String>(diaryId),
      'kind': serializer.toJson<String>(kind),
      'seq': serializer.toJson<int>(seq),
      'file_name': serializer.toJson<String>(fileName),
    };
  }

  DiaryMediaRow copyWith({
    String? diaryId,
    String? kind,
    int? seq,
    String? fileName,
  }) => DiaryMediaRow(
    diaryId: diaryId ?? this.diaryId,
    kind: kind ?? this.kind,
    seq: seq ?? this.seq,
    fileName: fileName ?? this.fileName,
  );
  DiaryMediaRow copyWithCompanion(DiaryMediaCompanion data) {
    return DiaryMediaRow(
      diaryId: data.diaryId.present ? data.diaryId.value : this.diaryId,
      kind: data.kind.present ? data.kind.value : this.kind,
      seq: data.seq.present ? data.seq.value : this.seq,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryMediaRow(')
          ..write('diaryId: $diaryId, ')
          ..write('kind: $kind, ')
          ..write('seq: $seq, ')
          ..write('fileName: $fileName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(diaryId, kind, seq, fileName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryMediaRow &&
          other.diaryId == this.diaryId &&
          other.kind == this.kind &&
          other.seq == this.seq &&
          other.fileName == this.fileName);
}

class DiaryMediaCompanion extends UpdateCompanion<DiaryMediaRow> {
  final Value<String> diaryId;
  final Value<String> kind;
  final Value<int> seq;
  final Value<String> fileName;
  final Value<int> rowid;
  const DiaryMediaCompanion({
    this.diaryId = const Value.absent(),
    this.kind = const Value.absent(),
    this.seq = const Value.absent(),
    this.fileName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiaryMediaCompanion.insert({
    required String diaryId,
    required String kind,
    required int seq,
    required String fileName,
    this.rowid = const Value.absent(),
  }) : diaryId = Value(diaryId),
       kind = Value(kind),
       seq = Value(seq),
       fileName = Value(fileName);
  static Insertable<DiaryMediaRow> custom({
    Expression<String>? diaryId,
    Expression<String>? kind,
    Expression<int>? seq,
    Expression<String>? fileName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (diaryId != null) 'diary_id': diaryId,
      if (kind != null) 'kind': kind,
      if (seq != null) 'seq': seq,
      if (fileName != null) 'file_name': fileName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiaryMediaCompanion copyWith({
    Value<String>? diaryId,
    Value<String>? kind,
    Value<int>? seq,
    Value<String>? fileName,
    Value<int>? rowid,
  }) {
    return DiaryMediaCompanion(
      diaryId: diaryId ?? this.diaryId,
      kind: kind ?? this.kind,
      seq: seq ?? this.seq,
      fileName: fileName ?? this.fileName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (diaryId.present) {
      map['diary_id'] = Variable<String>(diaryId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryMediaCompanion(')
          ..write('diaryId: $diaryId, ')
          ..write('kind: $kind, ')
          ..write('seq: $seq, ')
          ..write('fileName: $fileName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class DiaryTags extends Table with TableInfo<DiaryTags, DiaryTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DiaryTags(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _diaryIdMeta = const VerificationMeta(
    'diaryId',
  );
  late final GeneratedColumn<String> diaryId = GeneratedColumn<String>(
    'diary_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES diaries(id)ON DELETE CASCADE',
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [diaryId, seq, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diary_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiaryTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('diary_id')) {
      context.handle(
        _diaryIdMeta,
        diaryId.isAcceptableOrUnknown(data['diary_id']!, _diaryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_diaryIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {diaryId, seq};
  @override
  DiaryTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiaryTagRow(
      diaryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diary_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  DiaryTags createAlias(String alias) {
    return DiaryTags(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(diary_id, seq)'];
  @override
  bool get dontWriteConstraints => true;
}

class DiaryTagRow extends DataClass implements Insertable<DiaryTagRow> {
  final String diaryId;
  final int seq;
  final String tag;
  const DiaryTagRow({
    required this.diaryId,
    required this.seq,
    required this.tag,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['diary_id'] = Variable<String>(diaryId);
    map['seq'] = Variable<int>(seq);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  DiaryTagsCompanion toCompanion(bool nullToAbsent) {
    return DiaryTagsCompanion(
      diaryId: Value(diaryId),
      seq: Value(seq),
      tag: Value(tag),
    );
  }

  factory DiaryTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiaryTagRow(
      diaryId: serializer.fromJson<String>(json['diary_id']),
      seq: serializer.fromJson<int>(json['seq']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'diary_id': serializer.toJson<String>(diaryId),
      'seq': serializer.toJson<int>(seq),
      'tag': serializer.toJson<String>(tag),
    };
  }

  DiaryTagRow copyWith({String? diaryId, int? seq, String? tag}) => DiaryTagRow(
    diaryId: diaryId ?? this.diaryId,
    seq: seq ?? this.seq,
    tag: tag ?? this.tag,
  );
  DiaryTagRow copyWithCompanion(DiaryTagsCompanion data) {
    return DiaryTagRow(
      diaryId: data.diaryId.present ? data.diaryId.value : this.diaryId,
      seq: data.seq.present ? data.seq.value : this.seq,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiaryTagRow(')
          ..write('diaryId: $diaryId, ')
          ..write('seq: $seq, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(diaryId, seq, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiaryTagRow &&
          other.diaryId == this.diaryId &&
          other.seq == this.seq &&
          other.tag == this.tag);
}

class DiaryTagsCompanion extends UpdateCompanion<DiaryTagRow> {
  final Value<String> diaryId;
  final Value<int> seq;
  final Value<String> tag;
  final Value<int> rowid;
  const DiaryTagsCompanion({
    this.diaryId = const Value.absent(),
    this.seq = const Value.absent(),
    this.tag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiaryTagsCompanion.insert({
    required String diaryId,
    required int seq,
    required String tag,
    this.rowid = const Value.absent(),
  }) : diaryId = Value(diaryId),
       seq = Value(seq),
       tag = Value(tag);
  static Insertable<DiaryTagRow> custom({
    Expression<String>? diaryId,
    Expression<int>? seq,
    Expression<String>? tag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (diaryId != null) 'diary_id': diaryId,
      if (seq != null) 'seq': seq,
      if (tag != null) 'tag': tag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiaryTagsCompanion copyWith({
    Value<String>? diaryId,
    Value<int>? seq,
    Value<String>? tag,
    Value<int>? rowid,
  }) {
    return DiaryTagsCompanion(
      diaryId: diaryId ?? this.diaryId,
      seq: seq ?? this.seq,
      tag: tag ?? this.tag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (diaryId.present) {
      map['diary_id'] = Variable<String>(diaryId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiaryTagsCompanion(')
          ..write('diaryId: $diaryId, ')
          ..write('seq: $seq, ')
          ..write('tag: $tag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$MoodiaryDatabase extends GeneratedDatabase {
  _$MoodiaryDatabase(QueryExecutor e) : super(e);
  $MoodiaryDatabaseManager get managers => $MoodiaryDatabaseManager(this);
  late final DiaryFts diaryFts = DiaryFts(this);
  late final Diaries diaries = Diaries(this);
  late final DiaryLinks diaryLinks = DiaryLinks(this);
  late final LlmProviders llmProviders = LlmProviders(this);
  late final Index idxLlmProvidersSort = Index(
    'idx_llm_providers_sort',
    'CREATE INDEX idx_llm_providers_sort ON llm_providers (sort_order)',
  );
  late final ChatSessions chatSessions = ChatSessions(this);
  late final Index idxChatSessionsUpdated = Index(
    'idx_chat_sessions_updated',
    'CREATE INDEX idx_chat_sessions_updated ON chat_sessions (updated_at DESC)',
  );
  late final ChatMessages chatMessages = ChatMessages(this);
  late final Index idxChatMessagesSession = Index(
    'idx_chat_messages_session',
    'CREATE INDEX idx_chat_messages_session ON chat_messages (session_id, created_at)',
  );
  late final AssistantToolCalls assistantToolCalls = AssistantToolCalls(this);
  late final Memories memories = Memories(this);
  late final Index idxMemoriesUpdated = Index(
    'idx_memories_updated',
    'CREATE INDEX idx_memories_updated ON memories (updated_at DESC)',
  );
  late final AgentPresets agentPresets = AgentPresets(this);
  late final Tombstones tombstones = Tombstones(this);
  late final Index idxTombstonesTime = Index(
    'idx_tombstones_time',
    'CREATE INDEX idx_tombstones_time ON tombstones (time_ms)',
  );
  late final Categories categories = Categories(this);
  late final Fonts fonts = Fonts(this);
  late final MediaInfos mediaInfos = MediaInfos(this);
  late final Index idxDiariesShowTime = Index(
    'idx_diaries_show_time',
    'CREATE INDEX idx_diaries_show_time ON diaries (show, time DESC, id DESC)',
  );
  late final Index idxDiariesShowCatTime = Index(
    'idx_diaries_show_cat_time',
    'CREATE INDEX idx_diaries_show_cat_time ON diaries (show, category_id, time DESC, id DESC)',
  );
  late final Index idxDiariesShowLastmod = Index(
    'idx_diaries_show_lastmod',
    'CREATE INDEX idx_diaries_show_lastmod ON diaries (show, last_modified DESC, id DESC)',
  );
  late final DiaryMedia diaryMedia = DiaryMedia(this);
  late final Index idxDiaryMediaKind = Index(
    'idx_diary_media_kind',
    'CREATE INDEX idx_diary_media_kind ON diary_media (kind, diary_id)',
  );
  late final Index idxDiaryMediaFile = Index(
    'idx_diary_media_file',
    'CREATE INDEX idx_diary_media_file ON diary_media (file_name)',
  );
  late final DiaryTags diaryTags = DiaryTags(this);
  late final Index idxDiaryTagsTag = Index(
    'idx_diary_tags_tag',
    'CREATE INDEX idx_diary_tags_tag ON diary_tags (tag)',
  );
  late final Index idxDiaryLinksDst = Index(
    'idx_diary_links_dst',
    'CREATE INDEX idx_diary_links_dst ON diary_links (dst_id)',
  );
  Future<int> ftsDelete(int rid) {
    return customUpdate(
      'DELETE FROM diary_fts WHERE "rowid" = ?1',
      variables: [Variable<int>(rid)],
      updates: {diaryFts},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> ftsInsert(int rid, String? titleTok, String? bodyTok) {
    return customInsert(
      'INSERT INTO diary_fts ("rowid", title_tok, body_tok) VALUES (?1, ?2, ?3)',
      variables: [
        Variable<int>(rid),
        Variable<String>(titleTok),
        Variable<String>(bodyTok),
      ],
      updates: {diaryFts},
    );
  }

  Selectable<FtsSearchByRankResult> ftsSearchByRank(
    String query,
    FtsSearchByRank$pred pred,
    int limitCount,
  ) {
    var $arrayStartIndex = 3;
    final generatedpred = $write(
      pred(this.diaryFts, alias(this.diaries, 'd')),
      hasMultipleTables: true,
      startIndex: $arrayStartIndex,
    );
    $arrayStartIndex += generatedpred.amountOfVariables;
    return customSelect(
      'SELECT"d"."rid" AS "nested_0.rid", "d"."id" AS "nested_0.id", "d"."category_id" AS "nested_0.category_id", "d"."title" AS "nested_0.title", "d"."content" AS "nested_0.content", "d"."content_text" AS "nested_0.content_text", "d"."time" AS "nested_0.time", "d"."last_modified" AS "nested_0.last_modified", "d"."show" AS "nested_0.show", "d"."mood" AS "nested_0.mood", "d"."type" AS "nested_0.type", "d"."aspect" AS "nested_0.aspect", "d"."latitude" AS "nested_0.latitude", "d"."longitude" AS "nested_0.longitude", "d"."place_name" AS "nested_0.place_name", "d"."weather_icon" AS "nested_0.weather_icon", "d"."weather_temp" AS "nested_0.weather_temp", "d"."weather_text" AS "nested_0.weather_text" FROM diary_fts INNER JOIN diaries AS d ON d.rid = diary_fts."rowid" WHERE diary_fts MATCH ?1 AND d.show = 1 AND ${generatedpred.sql} ORDER BY rank, d.time DESC, d.id DESC LIMIT ?2',
      variables: [
        Variable<String>(query),
        Variable<int>(limitCount),
        ...generatedpred.introducedVariables,
      ],
      readsFrom: {diaryFts, diaries, ...generatedpred.watchedTables},
    ).asyncMap(
      (QueryRow row) async => FtsSearchByRankResult(
        d: await diaries.mapFromRow(row, tablePrefix: 'nested_0'),
      ),
    );
  }

  Selectable<FtsSearchByTimeResult> ftsSearchByTime(
    String query,
    FtsSearchByTime$pred pred,
    FtsSearchByTime$order order,
    int limitCount,
  ) {
    var $arrayStartIndex = 3;
    final generatedpred = $write(
      pred(this.diaryFts, alias(this.diaries, 'd')),
      hasMultipleTables: true,
      startIndex: $arrayStartIndex,
    );
    $arrayStartIndex += generatedpred.amountOfVariables;
    final generatedorder = $write(
      order?.call(this.diaryFts, alias(this.diaries, 'd')) ??
          const OrderBy.nothing(),
      hasMultipleTables: true,
      startIndex: $arrayStartIndex,
    );
    $arrayStartIndex += generatedorder.amountOfVariables;
    return customSelect(
      'SELECT"d"."rid" AS "nested_0.rid", "d"."id" AS "nested_0.id", "d"."category_id" AS "nested_0.category_id", "d"."title" AS "nested_0.title", "d"."content" AS "nested_0.content", "d"."content_text" AS "nested_0.content_text", "d"."time" AS "nested_0.time", "d"."last_modified" AS "nested_0.last_modified", "d"."show" AS "nested_0.show", "d"."mood" AS "nested_0.mood", "d"."type" AS "nested_0.type", "d"."aspect" AS "nested_0.aspect", "d"."latitude" AS "nested_0.latitude", "d"."longitude" AS "nested_0.longitude", "d"."place_name" AS "nested_0.place_name", "d"."weather_icon" AS "nested_0.weather_icon", "d"."weather_temp" AS "nested_0.weather_temp", "d"."weather_text" AS "nested_0.weather_text" FROM diary_fts INNER JOIN diaries AS d ON d.rid = diary_fts."rowid" WHERE diary_fts MATCH ?1 AND d.show = 1 AND ${generatedpred.sql} ${generatedorder.sql} LIMIT ?2',
      variables: [
        Variable<String>(query),
        Variable<int>(limitCount),
        ...generatedpred.introducedVariables,
        ...generatedorder.introducedVariables,
      ],
      readsFrom: {
        diaryFts,
        diaries,
        ...generatedpred.watchedTables,
        ...generatedorder.watchedTables,
      },
    ).asyncMap(
      (QueryRow row) async => FtsSearchByTimeResult(
        d: await diaries.mapFromRow(row, tablePrefix: 'nested_0'),
      ),
    );
  }

  Selectable<BacklinksResult> backlinks(String toId) {
    return customSelect(
      'SELECT"d"."rid" AS "nested_0.rid", "d"."id" AS "nested_0.id", "d"."category_id" AS "nested_0.category_id", "d"."title" AS "nested_0.title", "d"."content" AS "nested_0.content", "d"."content_text" AS "nested_0.content_text", "d"."time" AS "nested_0.time", "d"."last_modified" AS "nested_0.last_modified", "d"."show" AS "nested_0.show", "d"."mood" AS "nested_0.mood", "d"."type" AS "nested_0.type", "d"."aspect" AS "nested_0.aspect", "d"."latitude" AS "nested_0.latitude", "d"."longitude" AS "nested_0.longitude", "d"."place_name" AS "nested_0.place_name", "d"."weather_icon" AS "nested_0.weather_icon", "d"."weather_temp" AS "nested_0.weather_temp", "d"."weather_text" AS "nested_0.weather_text" FROM diary_links AS l INNER JOIN diaries AS d ON d.id = l.src_id WHERE l.dst_id = ?1 AND d.show = 1 ORDER BY d.time DESC, d.id DESC',
      variables: [Variable<String>(toId)],
      readsFrom: {diaryLinks, diaries},
    ).asyncMap(
      (QueryRow row) async => BacklinksResult(
        d: await diaries.mapFromRow(row, tablePrefix: 'nested_0'),
      ),
    );
  }

  Selectable<ForwardLinksResult> forwardLinks(String fromId) {
    return customSelect(
      'SELECT"d"."rid" AS "nested_0.rid", "d"."id" AS "nested_0.id", "d"."category_id" AS "nested_0.category_id", "d"."title" AS "nested_0.title", "d"."content" AS "nested_0.content", "d"."content_text" AS "nested_0.content_text", "d"."time" AS "nested_0.time", "d"."last_modified" AS "nested_0.last_modified", "d"."show" AS "nested_0.show", "d"."mood" AS "nested_0.mood", "d"."type" AS "nested_0.type", "d"."aspect" AS "nested_0.aspect", "d"."latitude" AS "nested_0.latitude", "d"."longitude" AS "nested_0.longitude", "d"."place_name" AS "nested_0.place_name", "d"."weather_icon" AS "nested_0.weather_icon", "d"."weather_temp" AS "nested_0.weather_temp", "d"."weather_text" AS "nested_0.weather_text" FROM diary_links AS l INNER JOIN diaries AS d ON d.id = l.dst_id WHERE l.src_id = ?1 AND d.id != ?1 AND d.show = 1 ORDER BY d.time DESC, d.id DESC',
      variables: [Variable<String>(fromId)],
      readsFrom: {diaryLinks, diaries},
    ).asyncMap(
      (QueryRow row) async => ForwardLinksResult(
        d: await diaries.mapFromRow(row, tablePrefix: 'nested_0'),
      ),
    );
  }

  Selectable<bool> hasAnyLink(String id) {
    return customSelect(
      'SELECT EXISTS (SELECT 1 AS _c0 FROM diary_links WHERE(src_id = ?1 AND dst_id != ?1)OR(dst_id = ?1 AND src_id != ?1)) AS present',
      variables: [Variable<String>(id)],
      readsFrom: {diaryLinks},
    ).map((QueryRow row) => row.read<bool>('present'));
  }

  Selectable<DiaryLinkRow> visibleLinkEdges() {
    return customSelect(
      'SELECT l.src_id AS srcId, l.dst_id AS dstId FROM diary_links AS l INNER JOIN diaries AS s ON s.id = l.src_id INNER JOIN diaries AS t ON t.id = l.dst_id WHERE s.show = 1 AND t.show = 1 AND l.src_id != l.dst_id',
      variables: [],
      readsFrom: {diaryLinks, diaries},
    ).asyncMap(
      (QueryRow row) async => diaryLinks.mapFromRowWithAlias(row, const {
        'srcId': 'src_id',
        'dstId': 'dst_id',
      }),
    );
  }

  Selectable<DiaryLinkRow> outEdgesOf(List<String> ids) {
    var $arrayStartIndex = 1;
    final expandedids = $expandVar($arrayStartIndex, ids.length);
    $arrayStartIndex += ids.length;
    return customSelect(
      'SELECT src_id AS srcId, dst_id AS dstId FROM diary_links WHERE src_id IN ($expandedids) AND dst_id != src_id',
      variables: [for (var $ in ids) Variable<String>($)],
      readsFrom: {diaryLinks},
    ).asyncMap(
      (QueryRow row) async => diaryLinks.mapFromRowWithAlias(row, const {
        'srcId': 'src_id',
        'dstId': 'dst_id',
      }),
    );
  }

  Selectable<DiaryLinkRow> inEdgesOf(List<String> ids) {
    var $arrayStartIndex = 1;
    final expandedids = $expandVar($arrayStartIndex, ids.length);
    $arrayStartIndex += ids.length;
    return customSelect(
      'SELECT src_id AS srcId, dst_id AS dstId FROM diary_links WHERE dst_id IN ($expandedids) AND src_id != dst_id',
      variables: [for (var $ in ids) Variable<String>($)],
      readsFrom: {diaryLinks},
    ).asyncMap(
      (QueryRow row) async => diaryLinks.mapFromRowWithAlias(row, const {
        'srcId': 'src_id',
        'dstId': 'dst_id',
      }),
    );
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    diaryFts,
    diaries,
    diaryLinks,
    llmProviders,
    idxLlmProvidersSort,
    chatSessions,
    idxChatSessionsUpdated,
    chatMessages,
    idxChatMessagesSession,
    assistantToolCalls,
    memories,
    idxMemoriesUpdated,
    agentPresets,
    tombstones,
    idxTombstonesTime,
    categories,
    fonts,
    mediaInfos,
    idxDiariesShowTime,
    idxDiariesShowCatTime,
    idxDiariesShowLastmod,
    diaryMedia,
    idxDiaryMediaKind,
    idxDiaryMediaFile,
    diaryTags,
    idxDiaryTagsTag,
    idxDiaryLinksDst,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'diaries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('diary_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chat_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('chat_messages', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'chat_messages',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('assistant_tool_calls', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'diaries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('diary_media', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'diaries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('diary_tags', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $DiaryFtsCreateCompanionBuilder = DiaryFtsCompanion Function({
  Value<String?> titleTok,
  Value<String?> bodyTok,
  Value<int> rowid,
});
typedef $DiaryFtsUpdateCompanionBuilder = DiaryFtsCompanion Function({
  Value<String?> titleTok,
  Value<String?> bodyTok,
  Value<int> rowid,
});

class $DiaryFtsFilterComposer extends Composer<_$MoodiaryDatabase, DiaryFts> {
  $DiaryFtsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get titleTok => $composableBuilder(
    column: $table.titleTok,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyTok => $composableBuilder(
    column: $table.bodyTok,
    builder: (column) => ColumnFilters(column),
  );
}

class $DiaryFtsOrderingComposer extends Composer<_$MoodiaryDatabase, DiaryFts> {
  $DiaryFtsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get titleTok => $composableBuilder(
    column: $table.titleTok,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyTok => $composableBuilder(
    column: $table.bodyTok,
    builder: (column) => ColumnOrderings(column),
  );
}

class $DiaryFtsAnnotationComposer
    extends Composer<_$MoodiaryDatabase, DiaryFts> {
  $DiaryFtsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get titleTok =>
      $composableBuilder(column: $table.titleTok, builder: (column) => column);

  GeneratedColumn<String> get bodyTok =>
      $composableBuilder(column: $table.bodyTok, builder: (column) => column);
}

class $DiaryFtsTableManager
    extends
        RootTableManager<
          _$MoodiaryDatabase,
          DiaryFts,
          DiaryFt,
          $DiaryFtsFilterComposer,
          $DiaryFtsOrderingComposer,
          $DiaryFtsAnnotationComposer,
          $DiaryFtsCreateCompanionBuilder,
          $DiaryFtsUpdateCompanionBuilder,
          (DiaryFt, BaseReferences<_$MoodiaryDatabase, DiaryFts, DiaryFt>),
          DiaryFt,
          PrefetchHooks Function()
        > {
  $DiaryFtsTableManager(_$MoodiaryDatabase db, DiaryFts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $DiaryFtsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $DiaryFtsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $DiaryFtsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String?> titleTok = const Value.absent(),
                Value<String?> bodyTok = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryFtsCompanion(
                titleTok: titleTok,
                bodyTok: bodyTok,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String?> titleTok = const Value.absent(),
                Value<String?> bodyTok = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryFtsCompanion.insert(
                titleTok: titleTok,
                bodyTok: bodyTok,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $DiaryFtsProcessedTableManager =
    ProcessedTableManager<
      _$MoodiaryDatabase,
      DiaryFts,
      DiaryFt,
      $DiaryFtsFilterComposer,
      $DiaryFtsOrderingComposer,
      $DiaryFtsAnnotationComposer,
      $DiaryFtsCreateCompanionBuilder,
      $DiaryFtsUpdateCompanionBuilder,
      (DiaryFt, BaseReferences<_$MoodiaryDatabase, DiaryFts, DiaryFt>),
      DiaryFt,
      PrefetchHooks Function()
    >;
typedef $DiariesCreateCompanionBuilder = DiariesCompanion Function({
  Value<int> rid,
  required String id,
  Value<String?> categoryId,
  required String title,
  required String content,
  required String contentText,
  required int time,
  required int lastModified,
  required int show,
  required double mood,
  required String type,
  Value<double?> aspect,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String?> placeName,
  Value<String?> weatherIcon,
  Value<String?> weatherTemp,
  Value<String?> weatherText,
});
typedef $DiariesUpdateCompanionBuilder = DiariesCompanion Function({
  Value<int> rid,
  Value<String> id,
  Value<String?> categoryId,
  Value<String> title,
  Value<String> content,
  Value<String> contentText,
  Value<int> time,
  Value<int> lastModified,
  Value<int> show,
  Value<double> mood,
  Value<String> type,
  Value<double?> aspect,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String?> placeName,
  Value<String?> weatherIcon,
  Value<String?> weatherTemp,
  Value<String?> weatherText,
});

final class $DiariesReferences
    extends BaseReferences<_$MoodiaryDatabase, Diaries, DiaryRow> {
  $DiariesReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<DiaryLinks, List<DiaryLinkRow>>
  _diaryLinksRefsTable(_$MoodiaryDatabase db) => MultiTypedResultKey.fromTable(
    db.diaryLinks,
    aliasName: 'diaries__id__diary_links__src_id',
  );

  $DiaryLinksProcessedTableManager get diaryLinksRefs {
    final manager = $DiaryLinksTableManager(
      $_db,
      $_db.diaryLinks,
    ).filter((f) => f.srcId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_diaryLinksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<DiaryMedia, List<DiaryMediaRow>>
  _diaryMediaRefsTable(_$MoodiaryDatabase db) => MultiTypedResultKey.fromTable(
    db.diaryMedia,
    aliasName: 'diaries__id__diary_media__diary_id',
  );

  $DiaryMediaProcessedTableManager get diaryMediaRefs {
    final manager = $DiaryMediaTableManager(
      $_db,
      $_db.diaryMedia,
    ).filter((f) => f.diaryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_diaryMediaRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<DiaryTags, List<DiaryTagRow>> _diaryTagsRefsTable(
    _$MoodiaryDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.diaryTags,
    aliasName: 'diaries__id__diary_tags__diary_id',
  );

  $DiaryTagsProcessedTableManager get diaryTagsRefs {
    final manager = $DiaryTagsTableManager(
      $_db,
      $_db.diaryTags,
    ).filter((f) => f.diaryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_diaryTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $DiariesFilterComposer extends Composer<_$MoodiaryDatabase, Diaries> {
  $DiariesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get rid => $composableBuilder(
    column: $table.rid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentText => $composableBuilder(
    column: $table.contentText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get show => $composableBuilder(
    column: $table.show,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get aspect => $composableBuilder(
    column: $table.aspect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get placeName => $composableBuilder(
    column: $table.placeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weatherIcon => $composableBuilder(
    column: $table.weatherIcon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weatherTemp => $composableBuilder(
    column: $table.weatherTemp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weatherText => $composableBuilder(
    column: $table.weatherText,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> diaryLinksRefs(
    Expression<bool> Function($DiaryLinksFilterComposer f) f,
  ) {
    final $DiaryLinksFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.diaryLinks,
      getReferencedColumn: (t) => t.srcId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DiaryLinksFilterComposer(
            $db: $db,
            $table: $db.diaryLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> diaryMediaRefs(
    Expression<bool> Function($DiaryMediaFilterComposer f) f,
  ) {
    final $DiaryMediaFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.diaryMedia,
      getReferencedColumn: (t) => t.diaryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DiaryMediaFilterComposer(
            $db: $db,
            $table: $db.diaryMedia,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> diaryTagsRefs(
    Expression<bool> Function($DiaryTagsFilterComposer f) f,
  ) {
    final $DiaryTagsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.diaryTags,
      getReferencedColumn: (t) => t.diaryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DiaryTagsFilterComposer(
            $db: $db,
            $table: $db.diaryTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $DiariesOrderingComposer extends Composer<_$MoodiaryDatabase, Diaries> {
  $DiariesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get rid => $composableBuilder(
    column: $table.rid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentText => $composableBuilder(
    column: $table.contentText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get show => $composableBuilder(
    column: $table.show,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get mood => $composableBuilder(
    column: $table.mood,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get aspect => $composableBuilder(
    column: $table.aspect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get placeName => $composableBuilder(
    column: $table.placeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weatherIcon => $composableBuilder(
    column: $table.weatherIcon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weatherTemp => $composableBuilder(
    column: $table.weatherTemp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weatherText => $composableBuilder(
    column: $table.weatherText,
    builder: (column) => ColumnOrderings(column),
  );
}

class $DiariesAnnotationComposer extends Composer<_$MoodiaryDatabase, Diaries> {
  $DiariesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get rid =>
      $composableBuilder(column: $table.rid, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get contentText => $composableBuilder(
    column: $table.contentText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<int> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );

  GeneratedColumn<int> get show =>
      $composableBuilder(column: $table.show, builder: (column) => column);

  GeneratedColumn<double> get mood =>
      $composableBuilder(column: $table.mood, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get aspect =>
      $composableBuilder(column: $table.aspect, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get placeName =>
      $composableBuilder(column: $table.placeName, builder: (column) => column);

  GeneratedColumn<String> get weatherIcon => $composableBuilder(
    column: $table.weatherIcon,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weatherTemp => $composableBuilder(
    column: $table.weatherTemp,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weatherText => $composableBuilder(
    column: $table.weatherText,
    builder: (column) => column,
  );

  Expression<T> diaryLinksRefs<T extends Object>(
    Expression<T> Function($DiaryLinksAnnotationComposer a) f,
  ) {
    final $DiaryLinksAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.diaryLinks,
      getReferencedColumn: (t) => t.srcId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DiaryLinksAnnotationComposer(
            $db: $db,
            $table: $db.diaryLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> diaryMediaRefs<T extends Object>(
    Expression<T> Function($DiaryMediaAnnotationComposer a) f,
  ) {
    final $DiaryMediaAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.diaryMedia,
      getReferencedColumn: (t) => t.diaryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DiaryMediaAnnotationComposer(
            $db: $db,
            $table: $db.diaryMedia,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> diaryTagsRefs<T extends Object>(
    Expression<T> Function($DiaryTagsAnnotationComposer a) f,
  ) {
    final $DiaryTagsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.diaryTags,
      getReferencedColumn: (t) => t.diaryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DiaryTagsAnnotationComposer(
            $db: $db,
            $table: $db.diaryTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $DiariesTableManager
    extends
        RootTableManager<
          _$MoodiaryDatabase,
          Diaries,
          DiaryRow,
          $DiariesFilterComposer,
          $DiariesOrderingComposer,
          $DiariesAnnotationComposer,
          $DiariesCreateCompanionBuilder,
          $DiariesUpdateCompanionBuilder,
          (DiaryRow, $DiariesReferences),
          DiaryRow,
          PrefetchHooks Function({
            bool diaryLinksRefs,
            bool diaryMediaRefs,
            bool diaryTagsRefs,
          })
        > {
  $DiariesTableManager(_$MoodiaryDatabase db, Diaries table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $DiariesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $DiariesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $DiariesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> rid = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> contentText = const Value.absent(),
                Value<int> time = const Value.absent(),
                Value<int> lastModified = const Value.absent(),
                Value<int> show = const Value.absent(),
                Value<double> mood = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double?> aspect = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String?> placeName = const Value.absent(),
                Value<String?> weatherIcon = const Value.absent(),
                Value<String?> weatherTemp = const Value.absent(),
                Value<String?> weatherText = const Value.absent(),
              }) => DiariesCompanion(
                rid: rid,
                id: id,
                categoryId: categoryId,
                title: title,
                content: content,
                contentText: contentText,
                time: time,
                lastModified: lastModified,
                show: show,
                mood: mood,
                type: type,
                aspect: aspect,
                latitude: latitude,
                longitude: longitude,
                placeName: placeName,
                weatherIcon: weatherIcon,
                weatherTemp: weatherTemp,
                weatherText: weatherText,
              ),
          createCompanionCallback:
              ({
                Value<int> rid = const Value.absent(),
                required String id,
                Value<String?> categoryId = const Value.absent(),
                required String title,
                required String content,
                required String contentText,
                required int time,
                required int lastModified,
                required int show,
                required double mood,
                required String type,
                Value<double?> aspect = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<String?> placeName = const Value.absent(),
                Value<String?> weatherIcon = const Value.absent(),
                Value<String?> weatherTemp = const Value.absent(),
                Value<String?> weatherText = const Value.absent(),
              }) => DiariesCompanion.insert(
                rid: rid,
                id: id,
                categoryId: categoryId,
                title: title,
                content: content,
                contentText: contentText,
                time: time,
                lastModified: lastModified,
                show: show,
                mood: mood,
                type: type,
                aspect: aspect,
                latitude: latitude,
                longitude: longitude,
                placeName: placeName,
                weatherIcon: weatherIcon,
                weatherTemp: weatherTemp,
                weatherText: weatherText,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (e.readTable(table), $DiariesReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                diaryLinksRefs = false,
                diaryMediaRefs = false,
                diaryTagsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (diaryLinksRefs) db.diaryLinks,
                    if (diaryMediaRefs) db.diaryMedia,
                    if (diaryTagsRefs) db.diaryTags,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (diaryLinksRefs)
                        await $_getPrefetchedData<
                          DiaryRow,
                          Diaries,
                          DiaryLinkRow
                        >(
                          currentTable: table,
                          referencedTable: $DiariesReferences
                              ._diaryLinksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $DiariesReferences(db, table, p0).diaryLinksRefs,
                          referencedItemsForCurrentItem: (
                            item,
                            referencedItems,
                          ) => referencedItems.where((e) => e.srcId == item.id),
                          typedResults: items,
                        ),
                      if (diaryMediaRefs)
                        await $_getPrefetchedData<
                          DiaryRow,
                          Diaries,
                          DiaryMediaRow
                        >(
                          currentTable: table,
                          referencedTable: $DiariesReferences
                              ._diaryMediaRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $DiariesReferences(db, table, p0).diaryMediaRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.diaryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (diaryTagsRefs)
                        await $_getPrefetchedData<
                          DiaryRow,
                          Diaries,
                          DiaryTagRow
                        >(
                          currentTable: table,
                          referencedTable: $DiariesReferences
                              ._diaryTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $DiariesReferences(db, table, p0).diaryTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.diaryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $DiariesProcessedTableManager =
    ProcessedTableManager<
      _$MoodiaryDatabase,
      Diaries,
      DiaryRow,
      $DiariesFilterComposer,
      $DiariesOrderingComposer,
      $DiariesAnnotationComposer,
      $DiariesCreateCompanionBuilder,
      $DiariesUpdateCompanionBuilder,
      (DiaryRow, $DiariesReferences),
      DiaryRow,
      PrefetchHooks Function({
        bool diaryLinksRefs,
        bool diaryMediaRefs,
        bool diaryTagsRefs,
      })
    >;
typedef $DiaryLinksCreateCompanionBuilder = DiaryLinksCompanion Function({
  required String srcId,
  required String dstId,
  Value<int> rowid,
});
typedef $DiaryLinksUpdateCompanionBuilder = DiaryLinksCompanion Function({
  Value<String> srcId,
  Value<String> dstId,
  Value<int> rowid,
});

final class $DiaryLinksReferences
    extends BaseReferences<_$MoodiaryDatabase, DiaryLinks, DiaryLinkRow> {
  $DiaryLinksReferences(super.$_db, super.$_table, super.$_typedResult);

  static Diaries _srcIdTable(_$MoodiaryDatabase db) =>
      db.diaries.createAlias('diary_links__src_id__diaries__id');

  $DiariesProcessedTableManager get srcId {
    final $_column = $_itemColumn<String>('src_id')!;

    final manager = $DiariesTableManager(
      $_db,
      $_db.diaries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_srcIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $DiaryLinksFilterComposer
    extends Composer<_$MoodiaryDatabase, DiaryLinks> {
  $DiaryLinksFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dstId => $composableBuilder(
    column: $table.dstId,
    builder: (column) => ColumnFilters(column),
  );

  $DiariesFilterComposer get srcId {
    final $DiariesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.srcId,
      referencedTable: $db.diaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DiariesFilterComposer(
            $db: $db,
            $table: $db.diaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DiaryLinksOrderingComposer
    extends Composer<_$MoodiaryDatabase, DiaryLinks> {
  $DiaryLinksOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dstId => $composableBuilder(
    column: $table.dstId,
    builder: (column) => ColumnOrderings(column),
  );

  $DiariesOrderingComposer get srcId {
    final $DiariesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.srcId,
      referencedTable: $db.diaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DiariesOrderingComposer(
            $db: $db,
            $table: $db.diaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DiaryLinksAnnotationComposer
    extends Composer<_$MoodiaryDatabase, DiaryLinks> {
  $DiaryLinksAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dstId =>
      $composableBuilder(column: $table.dstId, builder: (column) => column);

  $DiariesAnnotationComposer get srcId {
    final $DiariesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.srcId,
      referencedTable: $db.diaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DiariesAnnotationComposer(
            $db: $db,
            $table: $db.diaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DiaryLinksTableManager
    extends
        RootTableManager<
          _$MoodiaryDatabase,
          DiaryLinks,
          DiaryLinkRow,
          $DiaryLinksFilterComposer,
          $DiaryLinksOrderingComposer,
          $DiaryLinksAnnotationComposer,
          $DiaryLinksCreateCompanionBuilder,
          $DiaryLinksUpdateCompanionBuilder,
          (DiaryLinkRow, $DiaryLinksReferences),
          DiaryLinkRow,
          PrefetchHooks Function({bool srcId})
        > {
  $DiaryLinksTableManager(_$MoodiaryDatabase db, DiaryLinks table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $DiaryLinksFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $DiaryLinksOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $DiaryLinksAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> srcId = const Value.absent(),
            Value<String> dstId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => DiaryLinksCompanion(srcId: srcId, dstId: dstId, rowid: rowid),
          createCompanionCallback:
              ({
                required String srcId,
                required String dstId,
                Value<int> rowid = const Value.absent(),
              }) => DiaryLinksCompanion.insert(
                srcId: srcId,
                dstId: dstId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $DiaryLinksReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({srcId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (srcId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.srcId,
                        referencedTable: $DiaryLinksReferences._srcIdTable(db),
                        referencedColumn: $DiaryLinksReferences
                            ._srcIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $DiaryLinksProcessedTableManager =
    ProcessedTableManager<
      _$MoodiaryDatabase,
      DiaryLinks,
      DiaryLinkRow,
      $DiaryLinksFilterComposer,
      $DiaryLinksOrderingComposer,
      $DiaryLinksAnnotationComposer,
      $DiaryLinksCreateCompanionBuilder,
      $DiaryLinksUpdateCompanionBuilder,
      (DiaryLinkRow, $DiaryLinksReferences),
      DiaryLinkRow,
      PrefetchHooks Function({bool srcId})
    >;
typedef $LlmProvidersCreateCompanionBuilder = LlmProvidersCompanion Function({
  required String id,
  required String name,
  required String type,
  required String baseUrl,
  required String defaultModel,
  required int createdAt,
  required int sortOrder,
  Value<String> presetId,
  Value<String> modelsJson,
  Value<int> toolCall,
  Value<int> reasoning,
  Value<int> attachment,
  Value<int> rowid,
});
typedef $LlmProvidersUpdateCompanionBuilder = LlmProvidersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> type,
  Value<String> baseUrl,
  Value<String> defaultModel,
  Value<int> createdAt,
  Value<int> sortOrder,
  Value<String> presetId,
  Value<String> modelsJson,
  Value<int> toolCall,
  Value<int> reasoning,
  Value<int> attachment,
  Value<int> rowid,
});

class $LlmProvidersFilterComposer
    extends Composer<_$MoodiaryDatabase, LlmProviders> {
  $LlmProvidersFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultModel => $composableBuilder(
    column: $table.defaultModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get presetId => $composableBuilder(
    column: $table.presetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelsJson => $composableBuilder(
    column: $table.modelsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get toolCall => $composableBuilder(
    column: $table.toolCall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reasoning => $composableBuilder(
    column: $table.reasoning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attachment => $composableBuilder(
    column: $table.attachment,
    builder: (column) => ColumnFilters(column),
  );
}

class $LlmProvidersOrderingComposer
    extends Composer<_$MoodiaryDatabase, LlmProviders> {
  $LlmProvidersOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseUrl => $composableBuilder(
    column: $table.baseUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultModel => $composableBuilder(
    column: $table.defaultModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get presetId => $composableBuilder(
    column: $table.presetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelsJson => $composableBuilder(
    column: $table.modelsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get toolCall => $composableBuilder(
    column: $table.toolCall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reasoning => $composableBuilder(
    column: $table.reasoning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attachment => $composableBuilder(
    column: $table.attachment,
    builder: (column) => ColumnOrderings(column),
  );
}

class $LlmProvidersAnnotationComposer
    extends Composer<_$MoodiaryDatabase, LlmProviders> {
  $LlmProvidersAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get baseUrl =>
      $composableBuilder(column: $table.baseUrl, builder: (column) => column);

  GeneratedColumn<String> get defaultModel => $composableBuilder(
    column: $table.defaultModel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get presetId =>
      $composableBuilder(column: $table.presetId, builder: (column) => column);

  GeneratedColumn<String> get modelsJson => $composableBuilder(
    column: $table.modelsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get toolCall =>
      $composableBuilder(column: $table.toolCall, builder: (column) => column);

  GeneratedColumn<int> get reasoning =>
      $composableBuilder(column: $table.reasoning, builder: (column) => column);

  GeneratedColumn<int> get attachment => $composableBuilder(
    column: $table.attachment,
    builder: (column) => column,
  );
}

class $LlmProvidersTableManager
    extends
        RootTableManager<
          _$MoodiaryDatabase,
          LlmProviders,
          LlmProviderRow,
          $LlmProvidersFilterComposer,
          $LlmProvidersOrderingComposer,
          $LlmProvidersAnnotationComposer,
          $LlmProvidersCreateCompanionBuilder,
          $LlmProvidersUpdateCompanionBuilder,
          (
            LlmProviderRow,
            BaseReferences<_$MoodiaryDatabase, LlmProviders, LlmProviderRow>,
          ),
          LlmProviderRow,
          PrefetchHooks Function()
        > {
  $LlmProvidersTableManager(_$MoodiaryDatabase db, LlmProviders table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $LlmProvidersFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $LlmProvidersOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $LlmProvidersAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> baseUrl = const Value.absent(),
                Value<String> defaultModel = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> presetId = const Value.absent(),
                Value<String> modelsJson = const Value.absent(),
                Value<int> toolCall = const Value.absent(),
                Value<int> reasoning = const Value.absent(),
                Value<int> attachment = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LlmProvidersCompanion(
                id: id,
                name: name,
                type: type,
                baseUrl: baseUrl,
                defaultModel: defaultModel,
                createdAt: createdAt,
                sortOrder: sortOrder,
                presetId: presetId,
                modelsJson: modelsJson,
                toolCall: toolCall,
                reasoning: reasoning,
                attachment: attachment,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String type,
                required String baseUrl,
                required String defaultModel,
                required int createdAt,
                required int sortOrder,
                Value<String> presetId = const Value.absent(),
                Value<String> modelsJson = const Value.absent(),
                Value<int> toolCall = const Value.absent(),
                Value<int> reasoning = const Value.absent(),
                Value<int> attachment = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LlmProvidersCompanion.insert(
                id: id,
                name: name,
                type: type,
                baseUrl: baseUrl,
                defaultModel: defaultModel,
                createdAt: createdAt,
                sortOrder: sortOrder,
                presetId: presetId,
                modelsJson: modelsJson,
                toolCall: toolCall,
                reasoning: reasoning,
                attachment: attachment,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $LlmProvidersProcessedTableManager =
    ProcessedTableManager<
      _$MoodiaryDatabase,
      LlmProviders,
      LlmProviderRow,
      $LlmProvidersFilterComposer,
      $LlmProvidersOrderingComposer,
      $LlmProvidersAnnotationComposer,
      $LlmProvidersCreateCompanionBuilder,
      $LlmProvidersUpdateCompanionBuilder,
      (
        LlmProviderRow,
        BaseReferences<_$MoodiaryDatabase, LlmProviders, LlmProviderRow>,
      ),
      LlmProviderRow,
      PrefetchHooks Function()
    >;
typedef $ChatSessionsCreateCompanionBuilder = ChatSessionsCompanion Function({
  required String id,
  Value<String> title,
  required String providerId,
  required String model,
  required int createdAt,
  required int updatedAt,
  Value<String> reasoningEffort,
  Value<String?> compactedSummary,
  Value<String?> compactedUpToMessageId,
  Value<int?> compactedAt,
  Value<int?> compactedInputTokensAtTrigger,
  Value<String?> agentPresetId,
  Value<String?> personaSnapshot,
  Value<String?> toolsSnapshotJson,
  Value<int> rowid,
});
typedef $ChatSessionsUpdateCompanionBuilder = ChatSessionsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> providerId,
  Value<String> model,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<String> reasoningEffort,
  Value<String?> compactedSummary,
  Value<String?> compactedUpToMessageId,
  Value<int?> compactedAt,
  Value<int?> compactedInputTokensAtTrigger,
  Value<String?> agentPresetId,
  Value<String?> personaSnapshot,
  Value<String?> toolsSnapshotJson,
  Value<int> rowid,
});

final class $ChatSessionsReferences
    extends BaseReferences<_$MoodiaryDatabase, ChatSessions, ChatSessionRow> {
  $ChatSessionsReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<ChatMessages, List<ChatMessageRow>>
  _chatMessagesRefsTable(_$MoodiaryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.chatMessages,
        aliasName: 'chat_sessions__id__chat_messages__session_id',
      );

  $ChatMessagesProcessedTableManager get chatMessagesRefs {
    final manager = $ChatMessagesTableManager(
      $_db,
      $_db.chatMessages,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_chatMessagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $ChatSessionsFilterComposer
    extends Composer<_$MoodiaryDatabase, ChatSessions> {
  $ChatSessionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasoningEffort => $composableBuilder(
    column: $table.reasoningEffort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get compactedSummary => $composableBuilder(
    column: $table.compactedSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get compactedUpToMessageId => $composableBuilder(
    column: $table.compactedUpToMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get compactedAt => $composableBuilder(
    column: $table.compactedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get compactedInputTokensAtTrigger => $composableBuilder(
    column: $table.compactedInputTokensAtTrigger,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentPresetId => $composableBuilder(
    column: $table.agentPresetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personaSnapshot => $composableBuilder(
    column: $table.personaSnapshot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolsSnapshotJson => $composableBuilder(
    column: $table.toolsSnapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> chatMessagesRefs(
    Expression<bool> Function($ChatMessagesFilterComposer f) f,
  ) {
    final $ChatMessagesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chatMessages,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ChatMessagesFilterComposer(
            $db: $db,
            $table: $db.chatMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ChatSessionsOrderingComposer
    extends Composer<_$MoodiaryDatabase, ChatSessions> {
  $ChatSessionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasoningEffort => $composableBuilder(
    column: $table.reasoningEffort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get compactedSummary => $composableBuilder(
    column: $table.compactedSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get compactedUpToMessageId => $composableBuilder(
    column: $table.compactedUpToMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get compactedAt => $composableBuilder(
    column: $table.compactedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get compactedInputTokensAtTrigger => $composableBuilder(
    column: $table.compactedInputTokensAtTrigger,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentPresetId => $composableBuilder(
    column: $table.agentPresetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personaSnapshot => $composableBuilder(
    column: $table.personaSnapshot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolsSnapshotJson => $composableBuilder(
    column: $table.toolsSnapshotJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ChatSessionsAnnotationComposer
    extends Composer<_$MoodiaryDatabase, ChatSessions> {
  $ChatSessionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get reasoningEffort => $composableBuilder(
    column: $table.reasoningEffort,
    builder: (column) => column,
  );

  GeneratedColumn<String> get compactedSummary => $composableBuilder(
    column: $table.compactedSummary,
    builder: (column) => column,
  );

  GeneratedColumn<String> get compactedUpToMessageId => $composableBuilder(
    column: $table.compactedUpToMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get compactedAt => $composableBuilder(
    column: $table.compactedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get compactedInputTokensAtTrigger => $composableBuilder(
    column: $table.compactedInputTokensAtTrigger,
    builder: (column) => column,
  );

  GeneratedColumn<String> get agentPresetId => $composableBuilder(
    column: $table.agentPresetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get personaSnapshot => $composableBuilder(
    column: $table.personaSnapshot,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toolsSnapshotJson => $composableBuilder(
    column: $table.toolsSnapshotJson,
    builder: (column) => column,
  );

  Expression<T> chatMessagesRefs<T extends Object>(
    Expression<T> Function($ChatMessagesAnnotationComposer a) f,
  ) {
    final $ChatMessagesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chatMessages,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ChatMessagesAnnotationComposer(
            $db: $db,
            $table: $db.chatMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ChatSessionsTableManager
    extends
        RootTableManager<
          _$MoodiaryDatabase,
          ChatSessions,
          ChatSessionRow,
          $ChatSessionsFilterComposer,
          $ChatSessionsOrderingComposer,
          $ChatSessionsAnnotationComposer,
          $ChatSessionsCreateCompanionBuilder,
          $ChatSessionsUpdateCompanionBuilder,
          (ChatSessionRow, $ChatSessionsReferences),
          ChatSessionRow,
          PrefetchHooks Function({bool chatMessagesRefs})
        > {
  $ChatSessionsTableManager(_$MoodiaryDatabase db, ChatSessions table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ChatSessionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ChatSessionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ChatSessionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> reasoningEffort = const Value.absent(),
                Value<String?> compactedSummary = const Value.absent(),
                Value<String?> compactedUpToMessageId = const Value.absent(),
                Value<int?> compactedAt = const Value.absent(),
                Value<int?> compactedInputTokensAtTrigger =
                    const Value.absent(),
                Value<String?> agentPresetId = const Value.absent(),
                Value<String?> personaSnapshot = const Value.absent(),
                Value<String?> toolsSnapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatSessionsCompanion(
                id: id,
                title: title,
                providerId: providerId,
                model: model,
                createdAt: createdAt,
                updatedAt: updatedAt,
                reasoningEffort: reasoningEffort,
                compactedSummary: compactedSummary,
                compactedUpToMessageId: compactedUpToMessageId,
                compactedAt: compactedAt,
                compactedInputTokensAtTrigger: compactedInputTokensAtTrigger,
                agentPresetId: agentPresetId,
                personaSnapshot: personaSnapshot,
                toolsSnapshotJson: toolsSnapshotJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> title = const Value.absent(),
                required String providerId,
                required String model,
                required int createdAt,
                required int updatedAt,
                Value<String> reasoningEffort = const Value.absent(),
                Value<String?> compactedSummary = const Value.absent(),
                Value<String?> compactedUpToMessageId = const Value.absent(),
                Value<int?> compactedAt = const Value.absent(),
                Value<int?> compactedInputTokensAtTrigger =
                    const Value.absent(),
                Value<String?> agentPresetId = const Value.absent(),
                Value<String?> personaSnapshot = const Value.absent(),
                Value<String?> toolsSnapshotJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatSessionsCompanion.insert(
                id: id,
                title: title,
                providerId: providerId,
                model: model,
                createdAt: createdAt,
                updatedAt: updatedAt,
                reasoningEffort: reasoningEffort,
                compactedSummary: compactedSummary,
                compactedUpToMessageId: compactedUpToMessageId,
                compactedAt: compactedAt,
                compactedInputTokensAtTrigger: compactedInputTokensAtTrigger,
                agentPresetId: agentPresetId,
                personaSnapshot: personaSnapshot,
                toolsSnapshotJson: toolsSnapshotJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $ChatSessionsReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({chatMessagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (chatMessagesRefs) db.chatMessages],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (chatMessagesRefs)
                    await $_getPrefetchedData<
                      ChatSessionRow,
                      ChatSessions,
                      ChatMessageRow
                    >(
                      currentTable: table,
                      referencedTable: $ChatSessionsReferences
                          ._chatMessagesRefsTable(db),
                      managerFromTypedResult: (p0) => $ChatSessionsReferences(
                        db,
                        table,
                        p0,
                      ).chatMessagesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $ChatSessionsProcessedTableManager =
    ProcessedTableManager<
      _$MoodiaryDatabase,
      ChatSessions,
      ChatSessionRow,
      $ChatSessionsFilterComposer,
      $ChatSessionsOrderingComposer,
      $ChatSessionsAnnotationComposer,
      $ChatSessionsCreateCompanionBuilder,
      $ChatSessionsUpdateCompanionBuilder,
      (ChatSessionRow, $ChatSessionsReferences),
      ChatSessionRow,
      PrefetchHooks Function({bool chatMessagesRefs})
    >;
typedef $ChatMessagesCreateCompanionBuilder = ChatMessagesCompanion Function({
  required String id,
  required String sessionId,
  required String role,
  required String content,
  required int createdAt,
  Value<String?> reasoning,
  Value<int?> thinkingMillis,
  Value<String?> imageName,
  Value<int?> inputTokens,
  Value<int?> outputTokens,
  Value<String?> model,
  Value<int> rowid,
});
typedef $ChatMessagesUpdateCompanionBuilder = ChatMessagesCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String> role,
  Value<String> content,
  Value<int> createdAt,
  Value<String?> reasoning,
  Value<int?> thinkingMillis,
  Value<String?> imageName,
  Value<int?> inputTokens,
  Value<int?> outputTokens,
  Value<String?> model,
  Value<int> rowid,
});

final class $ChatMessagesReferences
    extends BaseReferences<_$MoodiaryDatabase, ChatMessages, ChatMessageRow> {
  $ChatMessagesReferences(super.$_db, super.$_table, super.$_typedResult);

  static ChatSessions _sessionIdTable(_$MoodiaryDatabase db) => db.chatSessions
      .createAlias('chat_messages__session_id__chat_sessions__id');

  $ChatSessionsProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $ChatSessionsTableManager(
      $_db,
      $_db.chatSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<AssistantToolCalls, List<AssistantToolCallRow>>
  _assistantToolCallsRefsTable(_$MoodiaryDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.assistantToolCalls,
        aliasName: 'chat_messages__id__assistant_tool_calls__message_id',
      );

  $AssistantToolCallsProcessedTableManager get assistantToolCallsRefs {
    final manager = $AssistantToolCallsTableManager(
      $_db,
      $_db.assistantToolCalls,
    ).filter((f) => f.messageId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _assistantToolCallsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $ChatMessagesFilterComposer
    extends Composer<_$MoodiaryDatabase, ChatMessages> {
  $ChatMessagesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasoning => $composableBuilder(
    column: $table.reasoning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get thinkingMillis => $composableBuilder(
    column: $table.thinkingMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageName => $composableBuilder(
    column: $table.imageName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  $ChatSessionsFilterComposer get sessionId {
    final $ChatSessionsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.chatSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ChatSessionsFilterComposer(
            $db: $db,
            $table: $db.chatSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> assistantToolCallsRefs(
    Expression<bool> Function($AssistantToolCallsFilterComposer f) f,
  ) {
    final $AssistantToolCallsFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assistantToolCalls,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AssistantToolCallsFilterComposer(
            $db: $db,
            $table: $db.assistantToolCalls,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ChatMessagesOrderingComposer
    extends Composer<_$MoodiaryDatabase, ChatMessages> {
  $ChatMessagesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasoning => $composableBuilder(
    column: $table.reasoning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get thinkingMillis => $composableBuilder(
    column: $table.thinkingMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageName => $composableBuilder(
    column: $table.imageName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  $ChatSessionsOrderingComposer get sessionId {
    final $ChatSessionsOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.chatSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ChatSessionsOrderingComposer(
            $db: $db,
            $table: $db.chatSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ChatMessagesAnnotationComposer
    extends Composer<_$MoodiaryDatabase, ChatMessages> {
  $ChatMessagesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get reasoning =>
      $composableBuilder(column: $table.reasoning, builder: (column) => column);

  GeneratedColumn<int> get thinkingMillis => $composableBuilder(
    column: $table.thinkingMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageName =>
      $composableBuilder(column: $table.imageName, builder: (column) => column);

  GeneratedColumn<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  $ChatSessionsAnnotationComposer get sessionId {
    final $ChatSessionsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.chatSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ChatSessionsAnnotationComposer(
            $db: $db,
            $table: $db.chatSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> assistantToolCallsRefs<T extends Object>(
    Expression<T> Function($AssistantToolCallsAnnotationComposer a) f,
  ) {
    final $AssistantToolCallsAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assistantToolCalls,
      getReferencedColumn: (t) => t.messageId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $AssistantToolCallsAnnotationComposer(
            $db: $db,
            $table: $db.assistantToolCalls,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $ChatMessagesTableManager
    extends
        RootTableManager<
          _$MoodiaryDatabase,
          ChatMessages,
          ChatMessageRow,
          $ChatMessagesFilterComposer,
          $ChatMessagesOrderingComposer,
          $ChatMessagesAnnotationComposer,
          $ChatMessagesCreateCompanionBuilder,
          $ChatMessagesUpdateCompanionBuilder,
          (ChatMessageRow, $ChatMessagesReferences),
          ChatMessageRow,
          PrefetchHooks Function({bool sessionId, bool assistantToolCallsRefs})
        > {
  $ChatMessagesTableManager(_$MoodiaryDatabase db, ChatMessages table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ChatMessagesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ChatMessagesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ChatMessagesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> reasoning = const Value.absent(),
                Value<int?> thinkingMillis = const Value.absent(),
                Value<String?> imageName = const Value.absent(),
                Value<int?> inputTokens = const Value.absent(),
                Value<int?> outputTokens = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion(
                id: id,
                sessionId: sessionId,
                role: role,
                content: content,
                createdAt: createdAt,
                reasoning: reasoning,
                thinkingMillis: thinkingMillis,
                imageName: imageName,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                model: model,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String role,
                required String content,
                required int createdAt,
                Value<String?> reasoning = const Value.absent(),
                Value<int?> thinkingMillis = const Value.absent(),
                Value<String?> imageName = const Value.absent(),
                Value<int?> inputTokens = const Value.absent(),
                Value<int?> outputTokens = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion.insert(
                id: id,
                sessionId: sessionId,
                role: role,
                content: content,
                createdAt: createdAt,
                reasoning: reasoning,
                thinkingMillis: thinkingMillis,
                imageName: imageName,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                model: model,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $ChatMessagesReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({sessionId = false, assistantToolCallsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (assistantToolCallsRefs) db.assistantToolCalls,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sessionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sessionId,
                            referencedTable: $ChatMessagesReferences
                                ._sessionIdTable(db),
                            referencedColumn: $ChatMessagesReferences
                                ._sessionIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (assistantToolCallsRefs)
                        await $_getPrefetchedData<
                          ChatMessageRow,
                          ChatMessages,
                          AssistantToolCallRow
                        >(
                          currentTable: table,
                          referencedTable: $ChatMessagesReferences
                              ._assistantToolCallsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $ChatMessagesReferences(
                                db,
                                table,
                                p0,
                              ).assistantToolCallsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.messageId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $ChatMessagesProcessedTableManager =
    ProcessedTableManager<
      _$MoodiaryDatabase,
      ChatMessages,
      ChatMessageRow,
      $ChatMessagesFilterComposer,
      $ChatMessagesOrderingComposer,
      $ChatMessagesAnnotationComposer,
      $ChatMessagesCreateCompanionBuilder,
      $ChatMessagesUpdateCompanionBuilder,
      (ChatMessageRow, $ChatMessagesReferences),
      ChatMessageRow,
      PrefetchHooks Function({bool sessionId, bool assistantToolCallsRefs})
    >;
typedef $AssistantToolCallsCreateCompanionBuilder =
    AssistantToolCallsCompanion Function({
      required String messageId,
      required int seq,
      required String callId,
      required String name,
      Value<String> argsJson,
      Value<String> result,
      Value<int> done,
      Value<int> rowid,
    });
typedef $AssistantToolCallsUpdateCompanionBuilder =
    AssistantToolCallsCompanion Function({
      Value<String> messageId,
      Value<int> seq,
      Value<String> callId,
      Value<String> name,
      Value<String> argsJson,
      Value<String> result,
      Value<int> done,
      Value<int> rowid,
    });

final class $AssistantToolCallsReferences
    extends
        BaseReferences<
          _$MoodiaryDatabase,
          AssistantToolCalls,
          AssistantToolCallRow
        > {
  $AssistantToolCallsReferences(super.$_db, super.$_table, super.$_typedResult);

  static ChatMessages _messageIdTable(_$MoodiaryDatabase db) => db.chatMessages
      .createAlias('assistant_tool_calls__message_id__chat_messages__id');

  $ChatMessagesProcessedTableManager get messageId {
    final $_column = $_itemColumn<String>('message_id')!;

    final manager = $ChatMessagesTableManager(
      $_db,
      $_db.chatMessages,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_messageIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $AssistantToolCallsFilterComposer
    extends Composer<_$MoodiaryDatabase, AssistantToolCalls> {
  $AssistantToolCallsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get callId => $composableBuilder(
    column: $table.callId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get argsJson => $composableBuilder(
    column: $table.argsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  $ChatMessagesFilterComposer get messageId {
    final $ChatMessagesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.chatMessages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ChatMessagesFilterComposer(
            $db: $db,
            $table: $db.chatMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $AssistantToolCallsOrderingComposer
    extends Composer<_$MoodiaryDatabase, AssistantToolCalls> {
  $AssistantToolCallsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get callId => $composableBuilder(
    column: $table.callId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get argsJson => $composableBuilder(
    column: $table.argsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  $ChatMessagesOrderingComposer get messageId {
    final $ChatMessagesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.chatMessages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ChatMessagesOrderingComposer(
            $db: $db,
            $table: $db.chatMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $AssistantToolCallsAnnotationComposer
    extends Composer<_$MoodiaryDatabase, AssistantToolCalls> {
  $AssistantToolCallsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get callId =>
      $composableBuilder(column: $table.callId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get argsJson =>
      $composableBuilder(column: $table.argsJson, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<int> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  $ChatMessagesAnnotationComposer get messageId {
    final $ChatMessagesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.messageId,
      referencedTable: $db.chatMessages,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ChatMessagesAnnotationComposer(
            $db: $db,
            $table: $db.chatMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $AssistantToolCallsTableManager
    extends
        RootTableManager<
          _$MoodiaryDatabase,
          AssistantToolCalls,
          AssistantToolCallRow,
          $AssistantToolCallsFilterComposer,
          $AssistantToolCallsOrderingComposer,
          $AssistantToolCallsAnnotationComposer,
          $AssistantToolCallsCreateCompanionBuilder,
          $AssistantToolCallsUpdateCompanionBuilder,
          (AssistantToolCallRow, $AssistantToolCallsReferences),
          AssistantToolCallRow,
          PrefetchHooks Function({bool messageId})
        > {
  $AssistantToolCallsTableManager(
    _$MoodiaryDatabase db,
    AssistantToolCalls table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AssistantToolCallsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AssistantToolCallsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AssistantToolCallsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> callId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> argsJson = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<int> done = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssistantToolCallsCompanion(
                messageId: messageId,
                seq: seq,
                callId: callId,
                name: name,
                argsJson: argsJson,
                result: result,
                done: done,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required int seq,
                required String callId,
                required String name,
                Value<String> argsJson = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<int> done = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssistantToolCallsCompanion.insert(
                messageId: messageId,
                seq: seq,
                callId: callId,
                name: name,
                argsJson: argsJson,
                result: result,
                done: done,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $AssistantToolCallsReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({messageId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (messageId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.messageId,
                        referencedTable: $AssistantToolCallsReferences
                            ._messageIdTable(db),
                        referencedColumn: $AssistantToolCallsReferences
                            ._messageIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $AssistantToolCallsProcessedTableManager =
    ProcessedTableManager<
      _$MoodiaryDatabase,
      AssistantToolCalls,
      AssistantToolCallRow,
      $AssistantToolCallsFilterComposer,
      $AssistantToolCallsOrderingComposer,
      $AssistantToolCallsAnnotationComposer,
      $AssistantToolCallsCreateCompanionBuilder,
      $AssistantToolCallsUpdateCompanionBuilder,
      (AssistantToolCallRow, $AssistantToolCallsReferences),
      AssistantToolCallRow,
      PrefetchHooks Function({bool messageId})
    >;
typedef $MemoriesCreateCompanionBuilder = MemoriesCompanion Function({
  required String id,
  required String category,
  required String content,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $MemoriesUpdateCompanionBuilder = MemoriesCompanion Function({
  Value<String> id,
  Value<String> category,
  Value<String> content,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $MemoriesFilterComposer extends Composer<_$MoodiaryDatabase, Memories> {
  $MemoriesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $MemoriesOrderingComposer extends Composer<_$MoodiaryDatabase, Memories> {
  $MemoriesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $MemoriesAnnotationComposer
    extends Composer<_$MoodiaryDatabase, Memories> {
  $MemoriesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $MemoriesTableManager
    extends
        RootTableManager<
          _$MoodiaryDatabase,
          Memories,
          MemoryRow,
          $MemoriesFilterComposer,
          $MemoriesOrderingComposer,
          $MemoriesAnnotationComposer,
          $MemoriesCreateCompanionBuilder,
          $MemoriesUpdateCompanionBuilder,
          (MemoryRow, BaseReferences<_$MoodiaryDatabase, Memories, MemoryRow>),
          MemoryRow,
          PrefetchHooks Function()
        > {
  $MemoriesTableManager(_$MoodiaryDatabase db, Memories table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MemoriesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MemoriesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MemoriesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemoriesCompanion(
                id: id,
                category: category,
                content: content,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String category,
                required String content,
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MemoriesCompanion.insert(
                id: id,
                category: category,
                content: content,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $MemoriesProcessedTableManager =
    ProcessedTableManager<
      _$MoodiaryDatabase,
      Memories,
      MemoryRow,
      $MemoriesFilterComposer,
      $MemoriesOrderingComposer,
      $MemoriesAnnotationComposer,
      $MemoriesCreateCompanionBuilder,
      $MemoriesUpdateCompanionBuilder,
      (MemoryRow, BaseReferences<_$MoodiaryDatabase, Memories, MemoryRow>),
      MemoryRow,
      PrefetchHooks Function()
    >;
typedef $AgentPresetsCreateCompanionBuilder = AgentPresetsCompanion Function({
  required String id,
  required String name,
  Value<String> description,
  required String persona,
  Value<String?> toolsJson,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $AgentPresetsUpdateCompanionBuilder = AgentPresetsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> description,
  Value<String> persona,
  Value<String?> toolsJson,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $AgentPresetsFilterComposer
    extends Composer<_$MoodiaryDatabase, AgentPresets> {
  $AgentPresetsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get persona => $composableBuilder(
    column: $table.persona,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toolsJson => $composableBuilder(
    column: $table.toolsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $AgentPresetsOrderingComposer
    extends Composer<_$MoodiaryDatabase, AgentPresets> {
  $AgentPresetsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get persona => $composableBuilder(
    column: $table.persona,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toolsJson => $composableBuilder(
    column: $table.toolsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AgentPresetsAnnotationComposer
    extends Composer<_$MoodiaryDatabase, AgentPresets> {
  $AgentPresetsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get persona =>
      $composableBuilder(column: $table.persona, builder: (column) => column);

  GeneratedColumn<String> get toolsJson =>
      $composableBuilder(column: $table.toolsJson, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $AgentPresetsTableManager
    extends
        RootTableManager<
          _$MoodiaryDatabase,
          AgentPresets,
          AgentPresetRow,
          $AgentPresetsFilterComposer,
          $AgentPresetsOrderingComposer,
          $AgentPresetsAnnotationComposer,
          $AgentPresetsCreateCompanionBuilder,
          $AgentPresetsUpdateCompanionBuilder,
          (
            AgentPresetRow,
            BaseReferences<_$MoodiaryDatabase, AgentPresets, AgentPresetRow>,
          ),
          AgentPresetRow,
          PrefetchHooks Function()
        > {
  $AgentPresetsTableManager(_$MoodiaryDatabase db, AgentPresets table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AgentPresetsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AgentPresetsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AgentPresetsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> persona = const Value.absent(),
                Value<String?> toolsJson = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentPresetsCompanion(
                id: id,
                name: name,
                description: description,
                persona: persona,
                toolsJson: toolsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> description = const Value.absent(),
                required String persona,
                Value<String?> toolsJson = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AgentPresetsCompanion.insert(
                id: id,
                name: name,
                description: description,
                persona: persona,
                toolsJson: toolsJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $AgentPresetsProcessedTableManager =
    ProcessedTableManager<
      _$MoodiaryDatabase,
      AgentPresets,
      AgentPresetRow,
      $AgentPresetsFilterComposer,
      $AgentPresetsOrderingComposer,
      $AgentPresetsAnnotationComposer,
      $AgentPresetsCreateCompanionBuilder,
      $AgentPresetsUpdateCompanionBuilder,
      (
        AgentPresetRow,
        BaseReferences<_$MoodiaryDatabase, AgentPresets, AgentPresetRow>,
      ),
      AgentPresetRow,
      PrefetchHooks Function()
    >;
typedef $TombstonesCreateCompanionBuilder = TombstonesCompanion Function({
  required String key,
  required int timeMs,
  Value<String> pushedBackendsJson,
  Value<int> rowid,
});
typedef $TombstonesUpdateCompanionBuilder = TombstonesCompanion Function({
  Value<String> key,
  Value<int> timeMs,
  Value<String> pushedBackendsJson,
  Value<int> rowid,
});

class $TombstonesFilterComposer
    extends Composer<_$MoodiaryDatabase, Tombstones> {
  $TombstonesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeMs => $composableBuilder(
    column: $table.timeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pushedBackendsJson => $composableBuilder(
    column: $table.pushedBackendsJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $TombstonesOrderingComposer
    extends Composer<_$MoodiaryDatabase, Tombstones> {
  $TombstonesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeMs => $composableBuilder(
    column: $table.timeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pushedBackendsJson => $composableBuilder(
    column: $table.pushedBackendsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $TombstonesAnnotationComposer
    extends Composer<_$MoodiaryDatabase, Tombstones> {
  $TombstonesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get timeMs =>
      $composableBuilder(column: $table.timeMs, builder: (column) => column);

  GeneratedColumn<String> get pushedBackendsJson => $composableBuilder(
    column: $table.pushedBackendsJson,
    builder: (column) => column,
  );
}

class $TombstonesTableManager
    extends
        RootTableManager<
          _$MoodiaryDatabase,
          Tombstones,
          TombstoneRow,
          $TombstonesFilterComposer,
          $TombstonesOrderingComposer,
          $TombstonesAnnotationComposer,
          $TombstonesCreateCompanionBuilder,
          $TombstonesUpdateCompanionBuilder,
          (
            TombstoneRow,
            BaseReferences<_$MoodiaryDatabase, Tombstones, TombstoneRow>,
          ),
          TombstoneRow,
          PrefetchHooks Function()
        > {
  $TombstonesTableManager(_$MoodiaryDatabase db, Tombstones table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $TombstonesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $TombstonesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $TombstonesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<int> timeMs = const Value.absent(),
                Value<String> pushedBackendsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TombstonesCompanion(
                key: key,
                timeMs: timeMs,
                pushedBackendsJson: pushedBackendsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required int timeMs,
                Value<String> pushedBackendsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TombstonesCompanion.insert(
                key: key,
                timeMs: timeMs,
                pushedBackendsJson: pushedBackendsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $TombstonesProcessedTableManager =
    ProcessedTableManager<
      _$MoodiaryDatabase,
      Tombstones,
      TombstoneRow,
      $TombstonesFilterComposer,
      $TombstonesOrderingComposer,
      $TombstonesAnnotationComposer,
      $TombstonesCreateCompanionBuilder,
      $TombstonesUpdateCompanionBuilder,
      (
        TombstoneRow,
        BaseReferences<_$MoodiaryDatabase, Tombstones, TombstoneRow>,
      ),
      TombstoneRow,
      PrefetchHooks Function()
    >;
typedef $CategoriesCreateCompanionBuilder = CategoriesCompanion Function({
  required String id,
  required String name,
  required int lastModified,
  Value<String?> parentId,
  Value<int?> color,
  Value<int> rowid,
});
typedef $CategoriesUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> lastModified,
  Value<String?> parentId,
  Value<int?> color,
  Value<int> rowid,
});

class $CategoriesFilterComposer
    extends Composer<_$MoodiaryDatabase, Categories> {
  $CategoriesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );
}

class $CategoriesOrderingComposer
    extends Composer<_$MoodiaryDatabase, Categories> {
  $CategoriesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );
}

class $CategoriesAnnotationComposer
    extends Composer<_$MoodiaryDatabase, Categories> {
  $CategoriesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);
}

class $CategoriesTableManager
    extends
        RootTableManager<
          _$MoodiaryDatabase,
          Categories,
          CategoryRow,
          $CategoriesFilterComposer,
          $CategoriesOrderingComposer,
          $CategoriesAnnotationComposer,
          $CategoriesCreateCompanionBuilder,
          $CategoriesUpdateCompanionBuilder,
          (
            CategoryRow,
            BaseReferences<_$MoodiaryDatabase, Categories, CategoryRow>,
          ),
          CategoryRow,
          PrefetchHooks Function()
        > {
  $CategoriesTableManager(_$MoodiaryDatabase db, Categories table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $CategoriesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $CategoriesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $CategoriesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> lastModified = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                lastModified: lastModified,
                parentId: parentId,
                color: color,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int lastModified,
                Value<String?> parentId = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                lastModified: lastModified,
                parentId: parentId,
                color: color,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $CategoriesProcessedTableManager =
    ProcessedTableManager<
      _$MoodiaryDatabase,
      Categories,
      CategoryRow,
      $CategoriesFilterComposer,
      $CategoriesOrderingComposer,
      $CategoriesAnnotationComposer,
      $CategoriesCreateCompanionBuilder,
      $CategoriesUpdateCompanionBuilder,
      (
        CategoryRow,
        BaseReferences<_$MoodiaryDatabase, Categories, CategoryRow>,
      ),
      CategoryRow,
      PrefetchHooks Function()
    >;
typedef $FontsCreateCompanionBuilder = FontsCompanion Function({
  required String fontFamily,
  required String fontFileName,
  Value<String> wghtAxisJson,
  Value<int> rowid,
});
typedef $FontsUpdateCompanionBuilder = FontsCompanion Function({
  Value<String> fontFamily,
  Value<String> fontFileName,
  Value<String> wghtAxisJson,
  Value<int> rowid,
});

class $FontsFilterComposer extends Composer<_$MoodiaryDatabase, Fonts> {
  $FontsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fontFamily => $composableBuilder(
    column: $table.fontFamily,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fontFileName => $composableBuilder(
    column: $table.fontFileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wghtAxisJson => $composableBuilder(
    column: $table.wghtAxisJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $FontsOrderingComposer extends Composer<_$MoodiaryDatabase, Fonts> {
  $FontsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fontFamily => $composableBuilder(
    column: $table.fontFamily,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fontFileName => $composableBuilder(
    column: $table.fontFileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wghtAxisJson => $composableBuilder(
    column: $table.wghtAxisJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $FontsAnnotationComposer extends Composer<_$MoodiaryDatabase, Fonts> {
  $FontsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fontFamily => $composableBuilder(
    column: $table.fontFamily,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fontFileName => $composableBuilder(
    column: $table.fontFileName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get wghtAxisJson => $composableBuilder(
    column: $table.wghtAxisJson,
    builder: (column) => column,
  );
}

class $FontsTableManager
    extends
        RootTableManager<
          _$MoodiaryDatabase,
          Fonts,
          FontRow,
          $FontsFilterComposer,
          $FontsOrderingComposer,
          $FontsAnnotationComposer,
          $FontsCreateCompanionBuilder,
          $FontsUpdateCompanionBuilder,
          (FontRow, BaseReferences<_$MoodiaryDatabase, Fonts, FontRow>),
          FontRow,
          PrefetchHooks Function()
        > {
  $FontsTableManager(_$MoodiaryDatabase db, Fonts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $FontsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $FontsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $FontsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> fontFamily = const Value.absent(),
                Value<String> fontFileName = const Value.absent(),
                Value<String> wghtAxisJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FontsCompanion(
                fontFamily: fontFamily,
                fontFileName: fontFileName,
                wghtAxisJson: wghtAxisJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fontFamily,
                required String fontFileName,
                Value<String> wghtAxisJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FontsCompanion.insert(
                fontFamily: fontFamily,
                fontFileName: fontFileName,
                wghtAxisJson: wghtAxisJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $FontsProcessedTableManager =
    ProcessedTableManager<
      _$MoodiaryDatabase,
      Fonts,
      FontRow,
      $FontsFilterComposer,
      $FontsOrderingComposer,
      $FontsAnnotationComposer,
      $FontsCreateCompanionBuilder,
      $FontsUpdateCompanionBuilder,
      (FontRow, BaseReferences<_$MoodiaryDatabase, Fonts, FontRow>),
      FontRow,
      PrefetchHooks Function()
    >;
typedef $MediaInfosCreateCompanionBuilder = MediaInfosCompanion Function({
  required String fileName,
  Value<String?> name,
  Value<int?> durationMs,
  required int lastModified,
  Value<int> rowid,
});
typedef $MediaInfosUpdateCompanionBuilder = MediaInfosCompanion Function({
  Value<String> fileName,
  Value<String?> name,
  Value<int?> durationMs,
  Value<int> lastModified,
  Value<int> rowid,
});

class $MediaInfosFilterComposer
    extends Composer<_$MoodiaryDatabase, MediaInfos> {
  $MediaInfosFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnFilters(column),
  );
}

class $MediaInfosOrderingComposer
    extends Composer<_$MoodiaryDatabase, MediaInfos> {
  $MediaInfosOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => ColumnOrderings(column),
  );
}

class $MediaInfosAnnotationComposer
    extends Composer<_$MoodiaryDatabase, MediaInfos> {
  $MediaInfosAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastModified => $composableBuilder(
    column: $table.lastModified,
    builder: (column) => column,
  );
}

class $MediaInfosTableManager
    extends
        RootTableManager<
          _$MoodiaryDatabase,
          MediaInfos,
          MediaInfoRow,
          $MediaInfosFilterComposer,
          $MediaInfosOrderingComposer,
          $MediaInfosAnnotationComposer,
          $MediaInfosCreateCompanionBuilder,
          $MediaInfosUpdateCompanionBuilder,
          (
            MediaInfoRow,
            BaseReferences<_$MoodiaryDatabase, MediaInfos, MediaInfoRow>,
          ),
          MediaInfoRow,
          PrefetchHooks Function()
        > {
  $MediaInfosTableManager(_$MoodiaryDatabase db, MediaInfos table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MediaInfosFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MediaInfosOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MediaInfosAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> fileName = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int> lastModified = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaInfosCompanion(
                fileName: fileName,
                name: name,
                durationMs: durationMs,
                lastModified: lastModified,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fileName,
                Value<String?> name = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                required int lastModified,
                Value<int> rowid = const Value.absent(),
              }) => MediaInfosCompanion.insert(
                fileName: fileName,
                name: name,
                durationMs: durationMs,
                lastModified: lastModified,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $MediaInfosProcessedTableManager =
    ProcessedTableManager<
      _$MoodiaryDatabase,
      MediaInfos,
      MediaInfoRow,
      $MediaInfosFilterComposer,
      $MediaInfosOrderingComposer,
      $MediaInfosAnnotationComposer,
      $MediaInfosCreateCompanionBuilder,
      $MediaInfosUpdateCompanionBuilder,
      (
        MediaInfoRow,
        BaseReferences<_$MoodiaryDatabase, MediaInfos, MediaInfoRow>,
      ),
      MediaInfoRow,
      PrefetchHooks Function()
    >;
typedef $DiaryMediaCreateCompanionBuilder = DiaryMediaCompanion Function({
  required String diaryId,
  required String kind,
  required int seq,
  required String fileName,
  Value<int> rowid,
});
typedef $DiaryMediaUpdateCompanionBuilder = DiaryMediaCompanion Function({
  Value<String> diaryId,
  Value<String> kind,
  Value<int> seq,
  Value<String> fileName,
  Value<int> rowid,
});

final class $DiaryMediaReferences
    extends BaseReferences<_$MoodiaryDatabase, DiaryMedia, DiaryMediaRow> {
  $DiaryMediaReferences(super.$_db, super.$_table, super.$_typedResult);

  static Diaries _diaryIdTable(_$MoodiaryDatabase db) =>
      db.diaries.createAlias('diary_media__diary_id__diaries__id');

  $DiariesProcessedTableManager get diaryId {
    final $_column = $_itemColumn<String>('diary_id')!;

    final manager = $DiariesTableManager(
      $_db,
      $_db.diaries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_diaryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $DiaryMediaFilterComposer
    extends Composer<_$MoodiaryDatabase, DiaryMedia> {
  $DiaryMediaFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  $DiariesFilterComposer get diaryId {
    final $DiariesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.diaryId,
      referencedTable: $db.diaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DiariesFilterComposer(
            $db: $db,
            $table: $db.diaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DiaryMediaOrderingComposer
    extends Composer<_$MoodiaryDatabase, DiaryMedia> {
  $DiaryMediaOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  $DiariesOrderingComposer get diaryId {
    final $DiariesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.diaryId,
      referencedTable: $db.diaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DiariesOrderingComposer(
            $db: $db,
            $table: $db.diaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DiaryMediaAnnotationComposer
    extends Composer<_$MoodiaryDatabase, DiaryMedia> {
  $DiaryMediaAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  $DiariesAnnotationComposer get diaryId {
    final $DiariesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.diaryId,
      referencedTable: $db.diaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DiariesAnnotationComposer(
            $db: $db,
            $table: $db.diaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DiaryMediaTableManager
    extends
        RootTableManager<
          _$MoodiaryDatabase,
          DiaryMedia,
          DiaryMediaRow,
          $DiaryMediaFilterComposer,
          $DiaryMediaOrderingComposer,
          $DiaryMediaAnnotationComposer,
          $DiaryMediaCreateCompanionBuilder,
          $DiaryMediaUpdateCompanionBuilder,
          (DiaryMediaRow, $DiaryMediaReferences),
          DiaryMediaRow,
          PrefetchHooks Function({bool diaryId})
        > {
  $DiaryMediaTableManager(_$MoodiaryDatabase db, DiaryMedia table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $DiaryMediaFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $DiaryMediaOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $DiaryMediaAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> diaryId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryMediaCompanion(
                diaryId: diaryId,
                kind: kind,
                seq: seq,
                fileName: fileName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String diaryId,
                required String kind,
                required int seq,
                required String fileName,
                Value<int> rowid = const Value.absent(),
              }) => DiaryMediaCompanion.insert(
                diaryId: diaryId,
                kind: kind,
                seq: seq,
                fileName: fileName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $DiaryMediaReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({diaryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (diaryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.diaryId,
                        referencedTable: $DiaryMediaReferences._diaryIdTable(
                          db,
                        ),
                        referencedColumn: $DiaryMediaReferences
                            ._diaryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $DiaryMediaProcessedTableManager =
    ProcessedTableManager<
      _$MoodiaryDatabase,
      DiaryMedia,
      DiaryMediaRow,
      $DiaryMediaFilterComposer,
      $DiaryMediaOrderingComposer,
      $DiaryMediaAnnotationComposer,
      $DiaryMediaCreateCompanionBuilder,
      $DiaryMediaUpdateCompanionBuilder,
      (DiaryMediaRow, $DiaryMediaReferences),
      DiaryMediaRow,
      PrefetchHooks Function({bool diaryId})
    >;
typedef $DiaryTagsCreateCompanionBuilder = DiaryTagsCompanion Function({
  required String diaryId,
  required int seq,
  required String tag,
  Value<int> rowid,
});
typedef $DiaryTagsUpdateCompanionBuilder = DiaryTagsCompanion Function({
  Value<String> diaryId,
  Value<int> seq,
  Value<String> tag,
  Value<int> rowid,
});

final class $DiaryTagsReferences
    extends BaseReferences<_$MoodiaryDatabase, DiaryTags, DiaryTagRow> {
  $DiaryTagsReferences(super.$_db, super.$_table, super.$_typedResult);

  static Diaries _diaryIdTable(_$MoodiaryDatabase db) =>
      db.diaries.createAlias('diary_tags__diary_id__diaries__id');

  $DiariesProcessedTableManager get diaryId {
    final $_column = $_itemColumn<String>('diary_id')!;

    final manager = $DiariesTableManager(
      $_db,
      $_db.diaries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_diaryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $DiaryTagsFilterComposer extends Composer<_$MoodiaryDatabase, DiaryTags> {
  $DiaryTagsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  $DiariesFilterComposer get diaryId {
    final $DiariesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.diaryId,
      referencedTable: $db.diaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DiariesFilterComposer(
            $db: $db,
            $table: $db.diaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DiaryTagsOrderingComposer
    extends Composer<_$MoodiaryDatabase, DiaryTags> {
  $DiaryTagsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  $DiariesOrderingComposer get diaryId {
    final $DiariesOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.diaryId,
      referencedTable: $db.diaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DiariesOrderingComposer(
            $db: $db,
            $table: $db.diaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DiaryTagsAnnotationComposer
    extends Composer<_$MoodiaryDatabase, DiaryTags> {
  $DiaryTagsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  $DiariesAnnotationComposer get diaryId {
    final $DiariesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.diaryId,
      referencedTable: $db.diaries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $DiariesAnnotationComposer(
            $db: $db,
            $table: $db.diaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $DiaryTagsTableManager
    extends
        RootTableManager<
          _$MoodiaryDatabase,
          DiaryTags,
          DiaryTagRow,
          $DiaryTagsFilterComposer,
          $DiaryTagsOrderingComposer,
          $DiaryTagsAnnotationComposer,
          $DiaryTagsCreateCompanionBuilder,
          $DiaryTagsUpdateCompanionBuilder,
          (DiaryTagRow, $DiaryTagsReferences),
          DiaryTagRow,
          PrefetchHooks Function({bool diaryId})
        > {
  $DiaryTagsTableManager(_$MoodiaryDatabase db, DiaryTags table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $DiaryTagsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $DiaryTagsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $DiaryTagsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> diaryId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DiaryTagsCompanion(
                diaryId: diaryId,
                seq: seq,
                tag: tag,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String diaryId,
                required int seq,
                required String tag,
                Value<int> rowid = const Value.absent(),
              }) => DiaryTagsCompanion.insert(
                diaryId: diaryId,
                seq: seq,
                tag: tag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (e.readTable(table), $DiaryTagsReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({diaryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (diaryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.diaryId,
                        referencedTable: $DiaryTagsReferences._diaryIdTable(db),
                        referencedColumn: $DiaryTagsReferences
                            ._diaryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $DiaryTagsProcessedTableManager =
    ProcessedTableManager<
      _$MoodiaryDatabase,
      DiaryTags,
      DiaryTagRow,
      $DiaryTagsFilterComposer,
      $DiaryTagsOrderingComposer,
      $DiaryTagsAnnotationComposer,
      $DiaryTagsCreateCompanionBuilder,
      $DiaryTagsUpdateCompanionBuilder,
      (DiaryTagRow, $DiaryTagsReferences),
      DiaryTagRow,
      PrefetchHooks Function({bool diaryId})
    >;

class $MoodiaryDatabaseManager {
  final _$MoodiaryDatabase _db;
  $MoodiaryDatabaseManager(this._db);
  $DiaryFtsTableManager get diaryFts =>
      $DiaryFtsTableManager(_db, _db.diaryFts);
  $DiariesTableManager get diaries => $DiariesTableManager(_db, _db.diaries);
  $DiaryLinksTableManager get diaryLinks =>
      $DiaryLinksTableManager(_db, _db.diaryLinks);
  $LlmProvidersTableManager get llmProviders =>
      $LlmProvidersTableManager(_db, _db.llmProviders);
  $ChatSessionsTableManager get chatSessions =>
      $ChatSessionsTableManager(_db, _db.chatSessions);
  $ChatMessagesTableManager get chatMessages =>
      $ChatMessagesTableManager(_db, _db.chatMessages);
  $AssistantToolCallsTableManager get assistantToolCalls =>
      $AssistantToolCallsTableManager(_db, _db.assistantToolCalls);
  $MemoriesTableManager get memories =>
      $MemoriesTableManager(_db, _db.memories);
  $AgentPresetsTableManager get agentPresets =>
      $AgentPresetsTableManager(_db, _db.agentPresets);
  $TombstonesTableManager get tombstones =>
      $TombstonesTableManager(_db, _db.tombstones);
  $CategoriesTableManager get categories =>
      $CategoriesTableManager(_db, _db.categories);
  $FontsTableManager get fonts => $FontsTableManager(_db, _db.fonts);
  $MediaInfosTableManager get mediaInfos =>
      $MediaInfosTableManager(_db, _db.mediaInfos);
  $DiaryMediaTableManager get diaryMedia =>
      $DiaryMediaTableManager(_db, _db.diaryMedia);
  $DiaryTagsTableManager get diaryTags =>
      $DiaryTagsTableManager(_db, _db.diaryTags);
}

class FtsSearchByRankResult {
  final DiaryRow d;
  FtsSearchByRankResult({required this.d});
}

typedef FtsSearchByRank$pred = Expression<bool> Function(
  DiaryFts diary_fts,
  Diaries d,
);

class FtsSearchByTimeResult {
  final DiaryRow d;
  FtsSearchByTimeResult({required this.d});
}

typedef FtsSearchByTime$pred = Expression<bool> Function(
  DiaryFts diary_fts,
  Diaries d,
);
typedef FtsSearchByTime$order = OrderBy Function(DiaryFts diary_fts, Diaries d);

class BacklinksResult {
  final DiaryRow d;
  BacklinksResult({required this.d});
}

class ForwardLinksResult {
  final DiaryRow d;
  ForwardLinksResult({required this.d});
}
