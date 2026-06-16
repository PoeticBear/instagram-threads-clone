class DraftInfo {
  final int id;
  final String content;
  // 媒体 URL 列表（向后兼容老格式：直接是 URL 字符串数组）
  final List<String> mediaUrls;
  // 媒体类型列表，与 mediaUrls 一一对应：[1=image, 2=video, 3=gif, ...]
  // 缺省时按 mediaUrls 顺序默认全为 1（向后兼容老数据）。
  final List<int> mediaTypes;
  final List<String>? pollOptions;
  final int? topicId;
  final int? replyType;
  final String? location;
  final int? quotePostId;
  final String createTime;
  final String? updateTime;
  // 位置经纬度（与 location 配套；地图选址时由服务端可选使用）
  final double? latitude;
  final double? longitude;

  DraftInfo({
    required this.id,
    required this.content,
    this.mediaUrls = const [],
    this.mediaTypes = const [],
    this.pollOptions,
    this.topicId,
    this.replyType,
    this.location,
    this.latitude,
    this.longitude,
    this.quotePostId,
    required this.createTime,
    this.updateTime,
  });

  /// 取指定索引媒体类型，越界或缺省时返回 1（image）。
  int mediaTypeAt(int index) {
    if (index < 0 || index >= mediaTypes.length) return 1;
    return mediaTypes[index];
  }

  /// 是否含视频
  bool get hasVideo => mediaTypes.contains(2);

  /// 首个媒体 URL（用于草稿列表缩略图），无媒体时返回 null
  String? get firstMediaUrl {
    if (mediaUrls.isEmpty) return null;
    final url = mediaUrls.first;
    return url.isEmpty ? null : url;
  }

  factory DraftInfo.fromJson(Map<String, dynamic> json) {
    // 解析 media_list 数组为 URL + media_type。
    // 旧版 API 返回 [String] 格式时，toString() 也能拿到 URL 兜底。
    final List<String> mediaUrls = [];
    final List<int> mediaTypes = [];
    final mediaListRaw = json['media_list'];
    if (mediaListRaw is List) {
      for (final e in mediaListRaw) {
        if (e is Map) {
          final url = e['url']?.toString();
          if (url != null && url.isNotEmpty) {
            mediaUrls.add(url);
            final t = e['media_type'];
            if (t is int) {
              mediaTypes.add(t);
            } else if (t is num) {
              mediaTypes.add(t.toInt());
            } else if (t is String) {
              mediaTypes.add(int.tryParse(t) ?? 1);
            } else {
              mediaTypes.add(1);
            }
          }
        } else if (e is String) {
          // 老格式：直接是 URL 字符串
          mediaUrls.add(e);
          mediaTypes.add(1);
        }
      }
    }

    // 顶层 media_urls（部分老版本字段）
    final mediaUrlsRaw = json['media_urls'];
    if (mediaUrlsRaw is List && mediaUrls.isEmpty) {
      for (final e in mediaUrlsRaw) {
        if (e is String) {
          mediaUrls.add(e);
          mediaTypes.add(1);
        }
      }
    }

    // 顶层 media_types（独立数组，与 media_urls 等长）
    final mediaTypesRaw = json['media_types'];
    if (mediaTypesRaw is List && mediaTypesRaw.length == mediaUrls.length) {
      for (int i = 0; i < mediaTypesRaw.length; i++) {
        final t = mediaTypesRaw[i];
        if (t is int) {
          mediaTypes[i] = t;
        } else if (t is num) {
          mediaTypes[i] = t.toInt();
        } else if (t is String) {
          mediaTypes[i] = int.tryParse(t) ?? 1;
        }
      }
    }

    return DraftInfo(
      id: json['id'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      mediaUrls: mediaUrls,
      mediaTypes: mediaTypes,
      pollOptions: (json['poll_options'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      topicId: json['topic_id'] as int?,
      replyType: json['reply_type'] as int?,
      location: json['location'] as String?,
      latitude: (json['latitude'] is num)
          ? (json['latitude'] as num).toDouble()
          : (json['latitude'] is String
              ? double.tryParse(json['latitude'] as String)
              : null),
      longitude: (json['longitude'] is num)
          ? (json['longitude'] as num).toDouble()
          : (json['longitude'] is String
              ? double.tryParse(json['longitude'] as String)
              : null),
      quotePostId: json['quote_post_id'] as int?,
      createTime: json['create_time'] as String? ?? '',
      updateTime: json['update_time'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      if (mediaUrls.isNotEmpty) 'media_urls': mediaUrls,
      if (mediaTypes.isNotEmpty) 'media_types': mediaTypes,
      if (pollOptions != null) 'poll_options': pollOptions,
      if (topicId != null) 'topic_id': topicId,
      if (replyType != null) 'reply_type': replyType,
      if (location != null) 'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (quotePostId != null) 'quote_post_id': quotePostId,
      'create_time': createTime,
      if (updateTime != null) 'update_time': updateTime,
    };
  }

  DraftInfo copyWith({
    int? id,
    String? content,
    List<String>? mediaUrls,
    List<int>? mediaTypes,
    List<String>? pollOptions,
    int? topicId,
    int? replyType,
    String? location,
    double? latitude,
    double? longitude,
    int? quotePostId,
    String? createTime,
    String? updateTime,
  }) {
    return DraftInfo(
      id: id ?? this.id,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaTypes: mediaTypes ?? this.mediaTypes,
      pollOptions: pollOptions ?? this.pollOptions,
      topicId: topicId ?? this.topicId,
      replyType: replyType ?? this.replyType,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      quotePostId: quotePostId ?? this.quotePostId,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }
}
