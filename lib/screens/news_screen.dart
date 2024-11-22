import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  late String apiUrl;
  final String apiKey = dotenv.env['NEWS_API'] ?? '';
  List<dynamic> newsResults = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    if (apiKey.isEmpty) {
      _showSnackBar('API key is missing. Please check your configuration.');
    } else {
      apiUrl =
      "https://serpapi.com/search.json?q=(pune&traffic+OR+crime+against+women)&tbm=nws&gl=IN&hl=en&tbs=qdr:w&api_key=$apiKey";
      fetchNews();
    }
  }

  Future<void> fetchNews() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> fetchedNews = data['news_results'] ?? [];

        // Sorting by combined date and time
        fetchedNews.sort((a, b) {
          String combinedDateTimeA = '${a['date'] ?? ''} ${a['time'] ?? ''}'.trim();
          String combinedDateTimeB = '${b['date'] ?? ''} ${b['time'] ?? ''}'.trim();

          DateTime dateTimeA = DateTime.tryParse(combinedDateTimeA) ?? DateTime(1970);
          DateTime dateTimeB = DateTime.tryParse(combinedDateTimeB) ?? DateTime(1970);

          return dateTimeB.compareTo(dateTimeA); // Latest first
        });

        setState(() {
          newsResults = fetchedNews;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        _showSnackBar("Failed to fetch news: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showSnackBar("An error occurred: $e");
    }
  }

  void _openNewsArticle(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      _showSnackBar('Could not launch URL: $url');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildShimmerEffect() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.all(8.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 20,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: 150,
                          height: 15,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: double.infinity,
                          height: 14,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: double.infinity,
                          height: 14,
                          color: Colors.grey.shade300,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewsCard(Map<String, dynamic> newsItem) {
    final String title = newsItem['title'] ?? 'No title available';
    final String source = newsItem['source'] ?? 'Unknown source';
    final String date = newsItem['date'] ?? 'Unknown date';
    final String snippet = newsItem['snippet'] ?? 'No snippet available';
    final String? link = newsItem['link'];
    final String thumbnail =
        newsItem['thumbnail'] ?? 'https://via.placeholder.com/150';

    return GestureDetector(
      onTap: () {
        if (link == null || link.isEmpty) {
          _showSnackBar('No link available for this news item');
          return;
        }
        _openNewsArticle(link);
      },
      child: Card(
        margin: const EdgeInsets.all(8.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  thumbnail,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image_not_supported),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              // News Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$source • $date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? _buildShimmerEffect()
          : newsResults.isEmpty
          ? const Center(
        child: Text(
          'No news articles found.',
          style: TextStyle(fontSize: 16),
        ),
      )
          : ListView.builder(
        itemCount: newsResults.length,
        itemBuilder: (context, index) {
          return _buildNewsCard(newsResults[index]);
        },
      ),
    );
  }
}