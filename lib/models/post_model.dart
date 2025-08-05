import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String userId;
  final String userName;
  final String userPhoto;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final List<String> likes;
  final int replyCount;

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    required this.likes,
    required this.replyCount,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userPhoto: data['userPhoto'] ?? '',
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      likes: List<String>.from(data['likes'] ?? []),
      replyCount: data['replyCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'content': content,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'replyCount': replyCount,
    };
  }
}

class Reply {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String userPhoto;
  final String content;
  final DateTime createdAt;
  final List<String> likes;

  Reply({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.content,
    required this.createdAt,
    required this.likes,
  });

  factory Reply.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reply(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userPhoto: data['userPhoto'] ?? '',
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      likes: List<String>.from(data['likes'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
    };
  }
}
