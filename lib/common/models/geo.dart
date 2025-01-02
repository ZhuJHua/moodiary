class GeoResponse {
  String? code;
  List<Location>? location;
  Refer? refer;

  GeoResponse({this.code, this.location, this.refer});

  GeoResponse.fromJson(Map<String, dynamic> json) {
    code = json["code"];
    location = json["location"] == null
        ? null
        : (json["location"] as List).map((e) => Location.fromJson(e)).toList();
    refer = json["refer"] == null ? null : Refer.fromJson(json["refer"]);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["code"] = code;
    data["location"] = location?.map((e) => e.toJson()).toList();
    data["refer"] = refer?.toJson();
    return data;
  }
}

class Refer {
  List<String>? sources;
  List<String>? license;

  Refer({this.sources, this.license});

  Refer.fromJson(Map<String, dynamic> json) {
    sources =
        json["sources"] == null ? null : List<String>.from(json["sources"]);
    license =
        json["license"] == null ? null : List<String>.from(json["license"]);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["sources"] = sources;
    data["license"] = license;
    return data;
  }
}

class Location {
  String? name;
  String? id;
  String? lat;
  String? lon;
  String? adm2;
  String? adm1;
  String? country;
  String? tz;
  String? utcOffset;
  String? isDst;
  String? type;
  String? rank;
  String? fxLink;

  Location({
    this.name,
    this.id,
    this.lat,
    this.lon,
    this.adm2,
    this.adm1,
    this.country,
    this.tz,
    this.utcOffset,
    this.isDst,
    this.type,
    this.rank,
    this.fxLink,
  });

  Location.fromJson(Map<String, dynamic> json) {
    name = json["name"];
    id = json["id"];
    lat = json["lat"];
    lon = json["lon"];
    adm2 = json["adm2"];
    adm1 = json["adm1"];
    country = json["country"];
    tz = json["tz"];
    utcOffset = json["utcOffset"];
    isDst = json["isDst"];
    type = json["type"];
    rank = json["rank"];
    fxLink = json["fxLink"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["name"] = name;
    data["id"] = id;
    data["lat"] = lat;
    data["lon"] = lon;
    data["adm2"] = adm2;
    data["adm1"] = adm1;
    data["country"] = country;
    data["tz"] = tz;
    data["utcOffset"] = utcOffset;
    data["isDst"] = isDst;
    data["type"] = type;
    data["rank"] = rank;
    data["fxLink"] = fxLink;
    return data;
  }
}
