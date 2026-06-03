// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_NotificationItem _$NotificationItemFromJson(Map<String, dynamic> json) =>
    _NotificationItem(
      id: json['id'] as String,
      type: json['type'] as String?,
      title: json['title'] as String?,
      body: json['body'] as String?,
      createdAt: json['created_at'] as String?,
      isUnread: json['is_unread'] as bool? ?? true,
    );

Map<String, dynamic> _$NotificationItemToJson(_NotificationItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'title': instance.title,
      'body': instance.body,
      'created_at': instance.createdAt,
      'is_unread': instance.isUnread,
    };
