import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';


class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
}

class DataException implements Exception {
  final String message;
  DataException(this.message);
}


class Post {
  final int id;
  final String title;
  final String body;
  final int timerDuration;

  Post({
    required this.id, 
    required this.title, 
    required this.body,
    int? timerDuration
  }) : timerDuration = timerDuration ?? (10 + Random().nextInt(21));

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'], 
      title: json['title'], 
      body: json['body'],
      timerDuration: 10 + Random().nextInt(21)
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
    };
  }
}


class TimerController {
  Timer? _timer;
  int _timeRemaining;
  bool _isVisible;
  final void Function(int timeRemaining) onTick;

  TimerController(int initialTime, this._isVisible, this.onTick)
      : _timeRemaining = initialTime;

  int get timeRemaining => _timeRemaining;

  void start() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isVisible) {
        if (_timeRemaining > 0) {
          _timeRemaining--;
          onTick(_timeRemaining);
        } else {
          _timer?.cancel();
        }
      }
    });
  }

  void pause() {
    _isVisible = false;
    _timer?.cancel();
  }

  void resume() {
    _isVisible = true;
    start();
  }

  void stop() {
    _timer?.cancel();
  }
}


class PostProvider with ChangeNotifier {
  List<Post> _posts = [];
  Set<int> _readPosts = {};
  final Map<int, TimerController> _timers = {};
  SharedPreferences? _prefs;
  
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  PostProvider() {
    _loadPosts();
  }

  
  List<Post> get posts => _posts;
  Set<int> get readPosts => _readPosts;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;

  TimerController? getTimerController(int postId) => _timers[postId];

  
  Future<void> _loadPosts() async {
    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      
      _prefs = await SharedPreferences.getInstance();

      
      _readPosts = _prefs?.getStringList('readPosts')
              ?.map((id) => int.parse(id)).toSet() ??
          {};

    
      String? storedPosts = _prefs?.getString('posts');
      if (storedPosts != null) {
        _posts = (jsonDecode(storedPosts) as List)
            .map((data) => Post.fromJson(data))
            .toList();
      }

      
      final response = await http
          .get(
            Uri.parse('https://jsonplaceholder.typicode.com/posts'),
            headers: {"Connection": "Keep-Alive", "Keep-Alive": "timeout=5, max=1000"},
          )
          .timeout(
            Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Network request timed out'),
          );

      if (response.statusCode == 200) {
        _posts = (jsonDecode(response.body) as List)
            .map((data) => Post.fromJson(data))
            .toList();
        
        
        _prefs?.setString('posts', response.body);
      } else {
        throw HttpException('Failed to load posts: ${response.statusCode}');
      }
    } on SocketException {
      _hasError = true;
      _errorMessage = 'No internet connection. Please check your network.';
    } on TimeoutException {
      _hasError = true;
      _errorMessage = 'Network request timed out. Please try again.';
    } on HttpException catch (e) {
      _hasError = true;
      _errorMessage = e.message;
    } catch (e) {
      _hasError = true;
      _errorMessage = 'An unexpected error occurred. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  
  void retry() {
    _loadPosts();
  }

  
  void markAsRead(int postId) {
    _readPosts.add(postId);
    _prefs?.setStringList(
        'readPosts', _readPosts.map((id) => id.toString()).toList());
    notifyListeners();
  }

  
  void startTimer(int postId) {
    if (!_timers.containsKey(postId)) {
      final post = _posts.firstWhere((p) => p.id == postId);
      _timers[postId] = TimerController(post.timerDuration, true, (timeRemaining) {
        notifyListeners();
      });
      _timers[postId]?.start();
    }
  }

  void pauseTimer(int postId) {
    _timers[postId]?.pause();
  }

  void resumeTimer(int postId) {
    _timers[postId]?.resume();
  }

  void stopTimer(int postId) {
    _timers[postId]?.stop();
    _timers.remove(postId);
  }
}