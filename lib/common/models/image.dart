class BingImage {
  List<Images>? images;
  Tooltips? tooltips;

  BingImage({this.images, this.tooltips});

  BingImage.fromJson(Map<String, dynamic> json) {
    images = json["images"] == null ? null : (json["images"] as List).map((e) => Images.fromJson(e)).toList();
    tooltips = json["tooltips"] == null ? null : Tooltips.fromJson(json["tooltips"]);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (images != null) {
      data["images"] = images?.map((e) => e.toJson()).toList();
    }
    if (tooltips != null) {
      data["tooltips"] = tooltips?.toJson();
    }
    return data;
  }
}

class Tooltips {
  String? loading;
  String? previous;
  String? next;
  String? walle;
  String? walls;

  Tooltips({this.loading, this.previous, this.next, this.walle, this.walls});

  Tooltips.fromJson(Map<String, dynamic> json) {
    loading = json["loading"];
    previous = json["previous"];
    next = json["next"];
    walle = json["walle"];
    walls = json["walls"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["loading"] = loading;
    data["previous"] = previous;
    data["next"] = next;
    data["walle"] = walle;
    data["walls"] = walls;
    return data;
  }
}

class Images {
  String? startdate;
  String? fullstartdate;
  String? enddate;
  String? url;
  String? urlbase;
  String? copyright;
  String? copyrightlink;
  String? title;
  String? quiz;
  bool? wp;
  String? hsh;
  int? drk;
  int? top;
  int? bot;
  List<dynamic>? hs;

  Images(
      {this.startdate,
      this.fullstartdate,
      this.enddate,
      this.url,
      this.urlbase,
      this.copyright,
      this.copyrightlink,
      this.title,
      this.quiz,
      this.wp,
      this.hsh,
      this.drk,
      this.top,
      this.bot,
      this.hs});

  Images.fromJson(Map<String, dynamic> json) {
    startdate = json["startdate"];
    fullstartdate = json["fullstartdate"];
    enddate = json["enddate"];
    url = json["url"];
    urlbase = json["urlbase"];
    copyright = json["copyright"];
    copyrightlink = json["copyrightlink"];
    title = json["title"];
    quiz = json["quiz"];
    wp = json["wp"];
    hsh = json["hsh"];
    drk = json["drk"];
    top = json["top"];
    bot = json["bot"];
    hs = json["hs"] ?? [];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["startdate"] = startdate;
    data["fullstartdate"] = fullstartdate;
    data["enddate"] = enddate;
    data["url"] = url;
    data["urlbase"] = urlbase;
    data["copyright"] = copyright;
    data["copyrightlink"] = copyrightlink;
    data["title"] = title;
    data["quiz"] = quiz;
    data["wp"] = wp;
    data["hsh"] = hsh;
    data["drk"] = drk;
    data["top"] = top;
    data["bot"] = bot;
    if (hs != null) {
      data["hs"] = hs;
    }
    return data;
  }
}
