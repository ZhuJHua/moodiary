class ShiplyResponse {
  ApkBasicInfo? apkBasicInfo;
  ClientInfo? clientInfo;
  Extra? extra;
  int? grayType;
  String? newFeature;
  int? popInterval;
  int? popTimes;
  int? publishTime;
  int? receiveMoment;
  int? remindType;
  int? status;
  String? tacticsId;
  String? title;
  int? undisturbedDuration;
  int? updateStrategy;
  int? updateTime;

  ShiplyResponse(
      {this.apkBasicInfo,
      this.clientInfo,
      this.extra,
      this.grayType,
      this.newFeature,
      this.popInterval,
      this.popTimes,
      this.publishTime,
      this.receiveMoment,
      this.remindType,
      this.status,
      this.tacticsId,
      this.title,
      this.undisturbedDuration,
      this.updateStrategy,
      this.updateTime});

  ShiplyResponse.fromJson(Map<String, dynamic> json) {
    apkBasicInfo = json["apkBasicInfo"] == null
        ? null
        : ApkBasicInfo.fromJson(json["apkBasicInfo"]);
    clientInfo = json["clientInfo"] == null
        ? null
        : ClientInfo.fromJson(json["clientInfo"]);
    extra = json["extra"] == null ? null : Extra.fromJson(json["extra"]);
    grayType = json["grayType"];
    newFeature = json["newFeature"];
    popInterval = json["popInterval"];
    popTimes = json["popTimes"];
    publishTime = json["publishTime"];
    receiveMoment = json["receiveMoment"];
    remindType = json["remindType"];
    status = json["status"];
    tacticsId = json["tacticsId"];
    title = json["title"];
    undisturbedDuration = json["undisturbedDuration"];
    updateStrategy = json["updateStrategy"];
    updateTime = json["updateTime"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (apkBasicInfo != null) {
      data["apkBasicInfo"] = apkBasicInfo?.toJson();
    }
    if (clientInfo != null) {
      data["clientInfo"] = clientInfo?.toJson();
    }
    if (extra != null) {
      data["extra"] = extra?.toJson();
    }
    data["grayType"] = grayType;
    data["newFeature"] = newFeature;
    data["popInterval"] = popInterval;
    data["popTimes"] = popTimes;
    data["publishTime"] = publishTime;
    data["receiveMoment"] = receiveMoment;
    data["remindType"] = remindType;
    data["status"] = status;
    data["tacticsId"] = tacticsId;
    data["title"] = title;
    data["undisturbedDuration"] = undisturbedDuration;
    data["updateStrategy"] = updateStrategy;
    data["updateTime"] = updateTime;
    return data;
  }
}

class Extra {
  Extra();

  Extra.fromJson(Map<String, dynamic> json);

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    return data;
  }
}

class ClientInfo {
  String? description;
  String? title;
  int? type;

  ClientInfo({this.description, this.title, this.type});

  ClientInfo.fromJson(Map<String, dynamic> json) {
    description = json["description"];
    title = json["title"];
    type = json["type"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["description"] = description;
    data["title"] = title;
    data["type"] = type;
    return data;
  }
}

class ApkBasicInfo {
  String? md5;
  int? pkgSize;
  int? buildNo;
  String? bundleId;
  String? downloadUrl;
  String? pkgName;
  int? versionCode;
  String? version;

  ApkBasicInfo(
      {this.md5,
      this.pkgSize,
      this.buildNo,
      this.bundleId,
      this.downloadUrl,
      this.pkgName,
      this.versionCode,
      this.version});

  ApkBasicInfo.fromJson(Map<String, dynamic> json) {
    md5 = json["md5"];
    pkgSize = json["pkgSize"];
    buildNo = json["buildNo"];
    bundleId = json["bundleId"];
    downloadUrl = json["downloadUrl"];
    pkgName = json["pkgName"];
    versionCode = json["versionCode"];
    version = json["version"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["md5"] = md5;
    data["pkgSize"] = pkgSize;
    data["buildNo"] = buildNo;
    data["bundleId"] = bundleId;
    data["downloadUrl"] = downloadUrl;
    data["pkgName"] = pkgName;
    data["versionCode"] = versionCode;
    data["version"] = version;
    return data;
  }
}
