import 'package:json_annotation/json_annotation.dart';

part 'historical_attack.g.dart';

@JsonSerializable()
class HistoricalAttack {
  final int id;
  final String date;
  final int year;
  final String month;
  final String title;
  final Victim victim;
  final Attacker attacker;
  final Attack attack;
  final String summary;
  final List<String> tags;
  final Source source;

  const HistoricalAttack({
    required this.id,
    required this.date,
    required this.year,
    required this.month,
    required this.title,
    required this.victim,
    required this.attacker,
    required this.attack,
    required this.summary,
    required this.tags,
    required this.source,
  });

  factory HistoricalAttack.fromJson(Map<String, dynamic> json) =>
      _$HistoricalAttackFromJson(json);

  Map<String, dynamic> toJson() => _$HistoricalAttackToJson(this);
}

@JsonSerializable()
class Victim {
  final String name;
  final String country;
  @JsonKey(name: 'country_code')
  final String countryCode;
  final double latitude;
  final double longitude;

  const Victim({
    required this.name,
    required this.country,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
  });

  factory Victim.fromJson(Map<String, dynamic> json) => _$VictimFromJson(json);

  Map<String, dynamic> toJson() => _$VictimToJson(this);
}

@JsonSerializable()
class Attacker {
  final String name;
  final String type;

  const Attacker({required this.name, required this.type});

  factory Attacker.fromJson(Map<String, dynamic> json) =>
      _$AttackerFromJson(json);

  Map<String, dynamic> toJson() => _$AttackerToJson(this);
}

@JsonSerializable()
class Attack {
  final String category;
  final int severity;
  @JsonKey(name: 'target_sector')
  final String targetSector;

  const Attack({
    required this.category,
    required this.severity,
    required this.targetSector,
  });

  factory Attack.fromJson(Map<String, dynamic> json) => _$AttackFromJson(json);

  Map<String, dynamic> toJson() => _$AttackToJson(this);
}

@JsonSerializable()
class Source {
  final String name;
  final int year;

  const Source({required this.name, required this.year});

  factory Source.fromJson(Map<String, dynamic> json) => _$SourceFromJson(json);

  Map<String, dynamic> toJson() => _$SourceToJson(this);
}
