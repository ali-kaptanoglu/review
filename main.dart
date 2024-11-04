import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Store Reviews',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ReviewsPage(),
    );
  }
}

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  List<Review> reviews = [];
  bool isLoading = false;
  bool hasMore = true;
  int currentPage = 1;
  final int pageSize = 50; // Apple Store API'nin sayfa başına maksimum değeri
  String? currentAppId;
  final TextEditingController _appIdController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _appIdController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (!isLoading && hasMore) {
        fetchReviews(currentAppId!, loadMore: true);
      }
    }
  }

  Future<void> fetchReviews(String appId, {bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        reviews.clear();
        currentPage = 1;
        hasMore = true;
        currentAppId = appId;
      });
    }

    if (!hasMore) return;

    setState(() {
      isLoading = true;
    });

    try {
      // App Store RSS Feed API'si için URL
      final url = 'https://itunes.apple.com/rss/customerreviews/page=$currentPage/id=$appId/sortBy=mostRecent/json';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final entries = data['feed']['entry'] as List?;

        if (entries != null && entries.isNotEmpty) {
          final newReviews = entries.map((entry) => Review.fromJson(entry)).toList();
          
          setState(() {
            reviews.addAll(newReviews);
            currentPage++;
            // Eğer gelen veri sayısı page size'dan azsa, daha fazla veri yoktur
            hasMore = newReviews.length >= pageSize;
          });
        } else {
          setState(() {
            hasMore = false;
          });
        }
      } else {
        throw Exception('Failed to load reviews');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() {
        hasMore = false;
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Store Reviews'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _appIdController,
                    decoration: const InputDecoration(
                      labelText: 'App ID',
                      hintText: 'Enter App Store App ID',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_appIdController.text.isNotEmpty) {
                      fetchReviews(_appIdController.text);
                    }
                  },
                  child: const Text('Get Reviews'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  itemCount: reviews.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == reviews.length) {
                      return hasMore
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No more reviews'),
                              ),
                            );
                    }
                    return ReviewCard(review: reviews[index]);
                  },
                ),
                if (isLoading && reviews.isEmpty)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          // Review sayısını gösteren bilgi çubuğu
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Reviews: ${reviews.length}'),
                if (hasMore)
                  const Text('Scroll down to load more')
                else
                  const Text('All reviews loaded'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Review {
  final String author;
  final String title;
  final String content;
  final String rating;
  final String date;

  Review({
    required this.author,
    required this.title,
    required this.content,
    required this.rating,
    required this.date,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      author: json['author']['name']['label'] ?? 'Unknown',
      title: json['title']['label'] ?? '',
      content: json['content']['label'] ?? '',
      rating: json['im:rating']['label'] ?? '0',
      date: json['updated']['label'] ?? '',
    );
  }
}

class ReviewCard extends StatelessWidget {
  final Review review;

  const ReviewCard({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    review.author,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    Text(review.rating),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              review.title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(review.content),
            const SizedBox(height: 8),
            Text(
              review.date,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
