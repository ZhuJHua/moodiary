class WeatherResponse {
  String? code;
  String? updateTime;
  String? fxLink;
  Now? now;
  Refer? refer;

  WeatherResponse(
      {this.code, this.updateTime, this.fxLink, this.now, this.refer});

  WeatherResponse.fromJson(Map<String, dynamic> json) {
    code = json["code"];
    updateTime = json["updateTime"];
    fxLink = json["fxLink"];
    now = json["now"] == null ? null : Now.fromJson(json["now"]);
    refer = json["refer"] == null ? null : Refer.fromJson(json["refer"]);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["code"] = code;
    data["updateTime"] = updateTime;
    data["fxLink"] = fxLink;
    if (now != null) {
      data["now"] = now?.toJson();
    }
    if (refer != null) {
      data["refer"] = refer?.toJson();
    }
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
    if (sources != null) {
      data["sources"] = sources;
    }
    if (license != null) {
      data["license"] = license;
    }
    return data;
  }
}

class Now {
  String? obsTime;
  String? temp;
  String? feelsLike;
  String? icon;
  String? text;
  String? wind360;
  String? windDir;
  String? windScale;
  String? windSpeed;
  String? humidity;
  String? precip;
  String? pressure;
  String? vis;
  String? cloud;
  String? dew;

  Now(
      {this.obsTime,
      this.temp,
      this.feelsLike,
      this.icon,
      this.text,
      this.wind360,
      this.windDir,
      this.windScale,
      this.windSpeed,
      this.humidity,
      this.precip,
      this.pressure,
      this.vis,
      this.cloud,
      this.dew});

  Now.fromJson(Map<String, dynamic> json) {
    obsTime = json["obsTime"];
    temp = json["temp"];
    feelsLike = json["feelsLike"];
    icon = json["icon"];
    text = json["text"];
    wind360 = json["wind360"];
    windDir = json["windDir"];
    windScale = json["windScale"];
    windSpeed = json["windSpeed"];
    humidity = json["humidity"];
    precip = json["precip"];
    pressure = json["pressure"];
    vis = json["vis"];
    cloud = json["cloud"];
    dew = json["dew"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["obsTime"] = obsTime;
    data["temp"] = temp;
    data["feelsLike"] = feelsLike;
    data["icon"] = icon;
    data["text"] = text;
    data["wind360"] = wind360;
    data["windDir"] = windDir;
    data["windScale"] = windScale;
    data["windSpeed"] = windSpeed;
    data["humidity"] = humidity;
    data["precip"] = precip;
    data["pressure"] = pressure;
    data["vis"] = vis;
    data["cloud"] = cloud;
    data["dew"] = dew;
    return data;
  }
}
