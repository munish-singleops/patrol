import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:e2e_app/keys.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HttpScreen extends StatefulWidget {
  const HttpScreen({super.key});

  @override
  State<HttpScreen> createState() => _HttpScreenState();
}

class _HttpScreenState extends State<HttpScreen> {
  var _responseText = 'No request made yet';
  var _isLoading = false;
  final _dio = Dio();

  Future<void> _makeGetRequest() async {
    setState(() {
      _isLoading = true;
      _responseText = 'Loading...';
    });

    try {
      final response = await http.get(
        Uri.parse('https://jsonplaceholder.typicode.com/users/1'),
      );
      setState(() {
        _responseText = 'Status: ${response.statusCode}\n\n${response.body}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _responseText = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _makePostRequest() async {
    setState(() {
      _isLoading = true;
      _responseText = 'Loading...';
    });

    try {
      final response = await http.post(
        Uri.parse('https://jsonplaceholder.typicode.com/posts'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': 'Test Post',
          'body': 'This is a test',
          'userId': 1,
        }),
      );
      setState(() {
        _responseText = 'Status: ${response.statusCode}\n\n${response.body}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _responseText = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _makeMultipleRequests() async {
    setState(() {
      _isLoading = true;
      _responseText = 'Loading...';
    });

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('https://jsonplaceholder.typicode.com/users/1')),
        http.get(Uri.parse('https://jsonplaceholder.typicode.com/users/2')),
        http.get(Uri.parse('https://jsonplaceholder.typicode.com/posts/1')),
      ]);
      setState(() {
        _responseText = 'Made ${responses.length} requests\n\n'
            'User 1: ${responses[0].statusCode}\n'
            'User 2: ${responses[1].statusCode}\n'
            'Post 1: ${responses[2].statusCode}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _responseText = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _makeDioRequest() async {
    setState(() {
      _isLoading = true;
      _responseText = 'Loading...';
    });

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://jsonplaceholder.typicode.com/users/1',
      );
      setState(() {
        _responseText = 'Dio Status: ${response.statusCode}\n\n'
            '${jsonEncode(response.data)}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _responseText = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: K.httpScreen,
      appBar: AppBar(title: const Text('HTTP Test Screen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              key: K.getRequestButton,
              onPressed: _isLoading ? null : _makeGetRequest,
              child: const Text('Make GET Request'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: K.postRequestButton,
              onPressed: _isLoading ? null : _makePostRequest,
              child: const Text('Make POST Request'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: K.multipleRequestsButton,
              onPressed: _isLoading ? null : _makeMultipleRequests,
              child: const Text('Make Multiple Requests'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: K.dioRequestButton,
              onPressed: _isLoading ? null : _makeDioRequest,
              child: const Text('Make Dio Request'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Response:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _responseText,
                  key: K.responseText,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
