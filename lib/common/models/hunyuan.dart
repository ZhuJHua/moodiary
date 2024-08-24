class PublicHeader {
  String? action;
  int? timestamp;
  String? version;
  String? authorization;

  Map<String, dynamic> toMap() {
    return {
      'X-TC-Action': action,
      'X-TC-Timestamp': timestamp,
      'X-TC-Version': version,
      'Authorization': authorization,
    };
  }

  PublicHeader.fromMap(Map<String, dynamic> map) {
    action = map['X-TC-Action'];
    timestamp = map['X-TC-Timestamp'];
    version = map['X-TC-Version'];
    authorization = map['Authorization'];
  }

  PublicHeader(this.action, this.timestamp, this.version, this.authorization);
}

class Message {
  late String role;
  late String content;

  Message(this.role, this.content);

  Map<String, dynamic> toMap() {
    return {'Role': role, 'Content': content};
  }

  Message.fromMap(Map<String, dynamic> map) {
    role = map['Role'];
    content = map['Content'];
  }
}

class HunyuanResponse {
  String? note;
  List<Choices>? choices;
  int? created;
  String? id;
  Usage? usage;

  HunyuanResponse({this.note, this.choices, this.created, this.id, this.usage});

  HunyuanResponse.fromJson(Map<String, dynamic> json) {
    note = json["Note"];
    choices = json["Choices"] == null ? null : (json["Choices"] as List).map((e) => Choices.fromJson(e)).toList();
    created = json["Created"];
    id = json["Id"];
    usage = json["Usage"] == null ? null : Usage.fromJson(json["Usage"]);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["Note"] = note;
    if (choices != null) {
      data["Choices"] = choices?.map((e) => e.toJson()).toList();
    }
    data["Created"] = created;
    data["Id"] = id;
    if (usage != null) {
      data["Usage"] = usage?.toJson();
    }
    return data;
  }
}

class Usage {
  int? promptTokens;
  int? completionTokens;
  int? totalTokens;

  Usage({this.promptTokens, this.completionTokens, this.totalTokens});

  Usage.fromJson(Map<String, dynamic> json) {
    promptTokens = json["PromptTokens"];
    completionTokens = json["CompletionTokens"];
    totalTokens = json["TotalTokens"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["PromptTokens"] = promptTokens;
    data["CompletionTokens"] = completionTokens;
    data["TotalTokens"] = totalTokens;
    return data;
  }
}

class Choices {
  String? finishReason;
  Delta? delta;

  Choices({this.finishReason, this.delta});

  Choices.fromJson(Map<String, dynamic> json) {
    finishReason = json["FinishReason"];
    delta = json["Delta"] == null ? null : Delta.fromJson(json["Delta"]);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["FinishReason"] = finishReason;
    if (delta != null) {
      data["Delta"] = delta?.toJson();
    }
    return data;
  }
}

class Delta {
  String? role;
  String? content;

  Delta({this.role, this.content});

  Delta.fromJson(Map<String, dynamic> json) {
    role = json["Role"];
    content = json["Content"];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data["Role"] = role;
    data["Content"] = content;
    return data;
  }
}
