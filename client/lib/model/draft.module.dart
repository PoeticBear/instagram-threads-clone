class DraftInfo {
  final int id;
  final String content;
  final List<String> mediaUrls;
  final List<String>? pollOptions;
  final int? topicId;
  final int? replyType;
  final String? location;
  final int? quotePostId;
  final String createTime;
  final String? updateTime;

  DraftInfo({
    required this.id,
    required this.content,
    this.mediaUrls = const [],
    this.pollOptions,
    this.topicId,
    this.replyType,
    this.location,
    this.quotePostId,
    required this.createTime,
    this.updateTime,
  });

  factory DraftInfo.fromJson(Map<String, dynamic> json) {
    return DraftInfo(
      id: json['id'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      mediaUrls: (json['media_list'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      pollOptions: (json['poll_options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
      topicId: json['topic_id'] as int?,
      replyType: json['reply_type'] as int?,
      location: json['location'] as String?,
      quotePostId: json['quote_post_id'] as int?,
      createTime: json['create_time'] as String? ?? '',
      updateTime: json['update_time'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'media_urls': mediaUrls,
      if (pollOptions != null) 'poll_options': pollOptions,
      if (topicId != null) 'topic_id': topicId,
      if (replyType != null) 'reply_type': replyType,
      if (location != null) 'location': location,
      if (quotePostId != null) 'quote_post_id': quotePostId,
      'create_time': createTime,
      if (updateTime != null) 'update_time': updateTime,
    };
  }

  DraftInfo copyWith({
    int? id,
    String? content,
    List<String>? mediaUrls,
    List<String>? pollOptions,
    int? topicId,
    int? replyType,
    String? location,
    int? quotePostId,
    String? createTime,
    String? updateTime,
  }) {
    return DraftInfo(
      id: id ?? this.id,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      pollOptions: pollOptions ?? this.pollOptions,
      topicId: topicId ?? this.topicId,
      replyType: replyType ?? this.replyType,
      location: location ?? this.location,
      quotePostId: quotePostId ?? this.quotePostId,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }
}
