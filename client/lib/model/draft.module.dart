class DraftInfo {
  final int id;
  final String content;
  final List<String> mediaUrls;
  final List<String>? pollOptions;
  final List<int>? topicIds;
  final int? replySettings;
  final String createdAt;
  final String? updatedAt;

  DraftInfo({
    required this.id,
    required this.content,
    this.mediaUrls = const [],
    this.pollOptions,
    this.topicIds,
    this.replySettings,
    required this.createdAt,
    this.updatedAt,
  });

  factory DraftInfo.fromJson(Map<String, dynamic> json) {
    return DraftInfo(
      id: json['id'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      mediaUrls: (json['media_urls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      pollOptions: (json['poll_options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
      topicIds: (json['topic_ids'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      replySettings: json['reply_settings'] as int?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'media_urls': mediaUrls,
      if (pollOptions != null) 'poll_options': pollOptions,
      if (topicIds != null) 'topic_ids': topicIds,
      if (replySettings != null) 'reply_settings': replySettings,
      'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  DraftInfo copyWith({
    int? id,
    String? content,
    List<String>? mediaUrls,
    List<String>? pollOptions,
    List<int>? topicIds,
    int? replySettings,
    String? createdAt,
    String? updatedAt,
  }) {
    return DraftInfo(
      id: id ?? this.id,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      pollOptions: pollOptions ?? this.pollOptions,
      topicIds: topicIds ?? this.topicIds,
      replySettings: replySettings ?? this.replySettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
