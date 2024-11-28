
import 'package:flutter/material.dart';
import 'package:knovatortest/screens/postdtail.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/api.dart';


class PostListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final postProvider = Provider.of<PostProvider>(context);

    
    if (postProvider.hasError) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Error'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 60),
              SizedBox(height: 16),
              Text(
                postProvider.errorMessage,
                style: TextStyle(fontSize: 18, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => postProvider.retry(),
                child: Text('Retry'),
              )
            ],
          ),
        ),
      );
    }

    // Loading State
    if (postProvider.isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Loading Posts'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Post List
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            'My Posts',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 213, 206, 145),
      ),
      body: ListView.builder(
        itemCount: postProvider.posts.length,
        itemBuilder: (context, index) {
          final post = postProvider.posts[index];
          final isRead = postProvider.readPosts.contains(post.id);
          final timerController = postProvider.getTimerController(post.id);

          // Start timer if not already starts
          if (timerController == null) {
            postProvider.startTimer(post.id);
          }

          return VisibilityDetector(
            key: Key(post.id.toString()),
            onVisibilityChanged: (visibilityInfo) {
              if (visibilityInfo.visibleFraction > 0) {
                postProvider.resumeTimer(post.id);
              } else {
                postProvider.pauseTimer(post.id);
              }
            },
            child: Column(
              children: [
                ListTile(
                  tileColor: isRead ? Colors.white : Colors.yellow.shade100,
                  title: Text(post.title),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer),
                      Text(
                        '${timerController?.timeRemaining ?? post.timerDuration}s',
                        style: TextStyle(
                          color: timerController?.timeRemaining == 0 
                              ? Colors.red 
                              : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    postProvider.pauseTimer(post.id);
                    postProvider.markAsRead(post.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetailScreen(postId: post.id),
                      ),
                    ).then((_) {
                      postProvider.resumeTimer(post.id);
                    });
                  },
                ),
                Divider(height: 1, color: Colors.grey.shade300),
              ],
            ),
          );
        },
      ),
    );
  }
}