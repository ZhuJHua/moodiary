class HitokotoResponse {
  int? id;
  String? uuid;
  String? hitokoto;
  String? type;
  String? from;
  String? fromWho;
  String? creator;
  int? creatorUid;
  int? reviewer;
  String? commitFrom;
  String? createdAt;
  int? length;

  HitokotoResponse(
      {this.id,
      this.uuid,
      this.hitokoto,
      this.type,
      this.from,
      this.fromWho,
      this.creator,
      this.creatorUid,
      this.reviewer,
      this.commitFrom,
      this.createdAt,
      this.length});

  HitokotoResponse.fromJson(Map<String, dynamic> json) {
    id = json["id"];
    uuid = json["uuid"];
    hitokoto = json["hitokoto"];
    type = json["type"];
    from = json["from"];
    fromWho = json["from_who"];
    creator = json["creator"];
    creatorUid = json["creator_uid"];
    reviewer = json["reviewer"];
    commitFrom = json["commit_from"];
    createdAt = json["created_at"];
    length = json["length"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["id"] = id;
    data["uuid"] = uuid;
    data["hitokoto"] = hitokoto;
    data["type"] = type;
    data["from"] = from;
    data["from_who"] = fromWho;
    data["creator"] = creator;
    data["creator_uid"] = creatorUid;
    data["reviewer"] = reviewer;
    data["commit_from"] = commitFrom;
    data["created_at"] = createdAt;
    data["length"] = length;
    return data;
  }
}
