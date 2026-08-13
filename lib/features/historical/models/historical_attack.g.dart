// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'historical_attack.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HistoricalAttack _$HistoricalAttackFromJson(Map<String, dynamic> json) =>
    HistoricalAttack(
      id: (json['id'] as num).toInt(),
      date: json['date'] as String,
      year: (json['year'] as num).toInt(),
      month: json['month'] as String,
      title: json['title'] as String,
      victim: Victim.fromJson(json['victim'] as Map<String, dynamic>),
      attacker: Attacker.fromJson(json['attacker'] as Map<String, dynamic>),
      attack: Attack.fromJson(json['attack'] as Map<String, dynamic>),
      summary: json['summary'] as String,
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      source: Source.fromJson(json['source'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$HistoricalAttackToJson(HistoricalAttack instance) =>
    <String, dynamic>{
      'id': instance.id,
      'date': instance.date,
      'year': instance.year,
      'month': instance.month,
      'title': instance.title,
      'victim': instance.victim,
      'attacker': instance.attacker,
      'attack': instance.attack,
      'summary': instance.summary,
      'tags': instance.tags,
      'source': instance.source,
    };

Victim _$VictimFromJson(Map<String, dynamic> json) => Victim(
  name: json['name'] as String,
  country: json['country'] as String,
  countryCode: json['country_code'] as String,
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
);

Map<String, dynamic> _$VictimToJson(Victim instance) => <String, dynamic>{
  'name': instance.name,
  'country': instance.country,
  'country_code': instance.countryCode,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
};

Attacker _$AttackerFromJson(Map<String, dynamic> json) =>
    Attacker(name: json['name'] as String, type: json['type'] as String);

Map<String, dynamic> _$AttackerToJson(Attacker instance) => <String, dynamic>{
  'name': instance.name,
  'type': instance.type,
};

Attack _$AttackFromJson(Map<String, dynamic> json) => Attack(
  category: json['category'] as String,
  severity: (json['severity'] as num).toInt(),
  targetSector: json['target_sector'] as String,
);

Map<String, dynamic> _$AttackToJson(Attack instance) => <String, dynamic>{
  'category': instance.category,
  'severity': instance.severity,
  'target_sector': instance.targetSector,
};

Source _$SourceFromJson(Map<String, dynamic> json) =>
    Source(name: json['name'] as String, year: (json['year'] as num).toInt());

Map<String, dynamic> _$SourceToJson(Source instance) => <String, dynamic>{
  'name': instance.name,
  'year': instance.year,
};
