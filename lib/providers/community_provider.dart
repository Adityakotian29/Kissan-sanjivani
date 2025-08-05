import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';

final communityProvider = StateNotifierProvider<CommunityNotifier, AsyncValue<List<Post>>>((ref) {
  return CommunityNotifier();
});

class CommunityNotifier extends StateNotifier<AsyncValue<List<Post>>> {
  CommunityNotifier() : super(const AsyncValue.loading()) {
    loadPosts();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> loadPosts() async {
    try {
      state = const AsyncValue.loading();
      
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .get();

      final posts = snapshot.docs
          .map((doc) => Post.fromFirestore(doc))
          .toList();
      
      state = AsyncValue.data(posts);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> createPost(String content, {String? imageUrl}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final post = Post(
        id: '',
        userId: user.uid,
        userName: userData['name'] ?? 'Anonymous',
        userPhoto: userData['photoURL'] ?? '',
        content: content,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        likes: [],
        replyCount: 0,
      );

      await _firestore.collection('posts').add(post.toFirestore());
      await loadPosts();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> likePost(String postId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final postRef = _firestore.collection('posts').doc(postId);
      final postDoc = await postRef.get();
      final post = Post.fromFirestore(postDoc);

      final updatedLikes = post.likes.contains(user.uid)
          ? post.likes.where((id) => id != user.uid).toList()
          : [...post.likes, user.uid];

      await postRef.update({'likes': updatedLikes});
      await loadPosts();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Reply>> getReplies(String postId) async {
    try {
      final snapshot = await _firestore
          .collection('replies')
          .where('postId', isEqualTo: postId)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => Reply.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to load replies: $e');
    }
  }

  Future<void> addReply(String postId, String content) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final reply = Reply(
        id: '',
        postId: postId,
        userId: user.uid,
        userName: userData['name'] ?? 'Anonymous',
        userPhoto: userData['photoURL'] ?? '',
        content: content,
        createdAt: DateTime.now(),
        likes: [],
      );

      await _firestore.collection('replies').add(reply.toFirestore());
      
      // Update reply count
      final postRef = _firestore.collection('posts').doc(postId);
      final postDoc = await postRef.get();
      final post = Post.fromFirestore(postDoc);
      await postRef.update({'replyCount': post.replyCount + 1});
      
      await loadPosts();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> likeReply(String replyId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final replyRef = _firestore.collection('replies').doc(replyId);
      final replyDoc = await replyRef.get();
      final reply = Reply.fromFirestore(replyDoc);

      final updatedLikes = reply.likes.contains(user.uid)
          ? reply.likes.where((id) => id != user.uid).toList()
          : [...reply.likes, user.uid];

      await replyRef.update({'likes': updatedLikes});
    } catch (e) {
      rethrow;
    }
  }
}
