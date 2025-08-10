import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // Imported for Timer
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MyApp());

// The News model class - with improved null safety
class News {
  final String title;
  final String? image; // Image can be null from the API
  final String content;
  final String url;

  News({required this.title, this.image, required this.content, required this.url});

  // Factory constructor to parse JSON. Handles potential null values gracefully.
  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      title: json['title'] ?? 'No Title',
      image: json['urlToImage'], // Can be null
      content: json['content'] ?? 'No content available.',
      url: json['url'] ?? '',
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // State variables
  List<News> _news = [];
  int _apiPage = 1; // To track the page number for the API
  bool _isLoading = false; // To show a loader while fetching data
  final PageController _pageController = PageController(); // Controller for PageView

  @override
  void initState() {
    super.initState();
    // _isLoading = true;
    _getNewsData(); // Fetch initial news on startup
  }

  @override
  void dispose() {
    _pageController.dispose(); // Dispose the controller to prevent memory leaks
    super.dispose();
  }

  // --- Data Fetching ---
  Future<void> _getNewsData() async {
    // Prevent multiple simultaneous fetches
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    String apiKey = "a02b2e885fd6480f81b12092622f7e3c"; // Your API key
    // Added the 'page' parameter for pagination
    String urlString =
        "https://newsapi.org/v2/top-headlines?sources=techcrunch&page=$_apiPage&apiKey=$apiKey";
    Uri uri = Uri.parse(urlString);

    try {
      http.Response newsResponse = await http.get(uri);
      if (newsResponse.statusCode == 200) {
        Map<String, dynamic> jsonData = json.decode(newsResponse.body);
        List<dynamic> articles = jsonData['articles'];

        // Filter out articles that don't have content or an image
        List<News> fetchedNews = articles
            .map((json) => News.fromJson(json))
            .where((news) => news.content.isNotEmpty && news.image != null)
            .toList();

        setState(() {
          _news.addAll(fetchedNews); // Add new news to the existing list
          _apiPage++; // Increment page for the next fetch
          _isLoading = false;
        });
      } else {
        // Handle API error
        setState(() {
          _isLoading = false;
        });
        throw Exception('Failed to load news');
      }
    } catch (e) {
      // Handle other errors (e.g., no internet)
      setState(() {
        _isLoading = false;
      });
      print('Error fetching news: $e');
    }
  }
  
  // --- URL Launcher ---
  void _launchURL(String url) async {
    if (url.isEmpty) return;
    final Uri parsedUrl = Uri.parse(url);
    if (!await launchUrl(parsedUrl, mode: LaunchMode.inAppWebView)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'News Shorts',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.grey[900], // A dark theme background
        appBar: AppBar(
          title: const Text('News Shorts 📰'),
          backgroundColor: Colors.grey[850],
          elevation: 4.0,
        ),
        body: _buildBody(),
        // Add a "Next" button at the bottom
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              // Smoothly animate to the next page
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            child: const Text(
              'Next News',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    // If news list is empty and we are still in the initial loading phase
    if (_news.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    // If news list is empty and we are done loading (e.g., API error)
    if (_news.isEmpty) {
      return const Center(child: Text("No news found. Please try again later.", style: TextStyle(color: Colors.white)));
    }

    // The main PageView builder
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical, // Swiping up/down changes news
      itemCount: _news.length,
      onPageChanged: (index) {
        // When user gets to the second to last card, fetch more news
        if (index == _news.length - 2) {
          _getNewsData();
        }
      },
      itemBuilder: (context, index) {
        return NewsPage(
          news: _news[index],
          onReadMore: () => _launchURL(_news[index].url),
        );
      },
    );
  }
}

// A new widget for displaying a single full-page news item
class NewsPage extends StatelessWidget {
  final News news;
  final VoidCallback onReadMore;

  const NewsPage({super.key, required this.news, required this.onReadMore});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // News Image
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: Image.network(
                news.image!, // We've filtered for non-null images
                fit: BoxFit.cover,
                // Loading builder for a smoother image load experience
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                // Error builder for when an image fails to load
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image, color: Colors.grey, size: 80);
                },
              ),
            ),
          ),
          const SizedBox(height: 12.0),

          // News Title
          Text(
            news.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),

          // News Content
          Expanded(
            flex: 3,
            child: Text(
              news.content,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 16.0,
                height: 1.4, // Line spacing
              ),
            ),
          ),
          const Divider(color: Colors.grey),

          // Read More button
          InkWell(
            onTap: onReadMore,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                "Tap here to read the full story →",
                style: TextStyle(color: Colors.teal[200], fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



// ------------------- Old Implementation ---------------------


// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'dart:core';
// import 'package:url_launcher/url_launcher.dart';

// void main() => runApp(MyApp());

// class News {
//   final String title;
//   final String image;
//   final String content;
//   final String url;

//   News({required this.title, required this.image, required this.content, required this.url});

//   factory News.fromJson(Map<String, dynamic> json) {
//     return News(
//       title: json['title'],
//       image: json['urlToImage'],
//       content: json['content'],
//       url: json["url"]
//     );
//   }
// }

// class NewsCard extends StatelessWidget {
//   final News news;

//   const NewsCard({super.key, required this.news});

//   void _launchURL(String url) async {
//     final Uri url0 = Uri.parse(url);
//     if (!await launchUrl(url0,mode: LaunchMode.inAppWebView)) {
//        throw 'Could not launch $url';
//   }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: EdgeInsets.all(8.0),
//       child: ExpansionTile(
//         leading: Image.network(news.image),
//         title: Text(news.title,style: 
//         TextStyle(color: Colors.teal[200],fontSize: 16,
//         fontWeight: FontWeight.w400),),
//         children: <Widget>[
//           Padding(
//             padding: EdgeInsets.all(10.0),
//             child: Text(
//               news.content,
//               style: TextStyle(fontSize: 16.0),
//             ),
//           ),
//           InkWell(
//             child: Text("Read More",style: TextStyle(color: const Color.fromARGB(255, 26, 13, 160),height: 3),),
//             onTap: (){
//               _launchURL(news.url);
//             }
//           )
//         ],
//       ),
//     );
//   }
// }

// class MyApp extends StatefulWidget {
//   const MyApp({super.key});

//   @override
//   _MyAppState createState() => _MyAppState();
// }

// class _MyAppState extends State<MyApp> {
//   List<News> _news = [];

//   @override
//   void initState() {
//     super.initState();
//     _getNewsData();
//   }

//   Future<void> _getNewsData() async {
//   http.Response newsResponse;
//   String apiKey = "a02b2e885fd6480f81b12092622f7e3c"; // Your API key
//   String urlString =
//       "https://newsapi.org/v2/top-headlines?sources=techcrunch&apiKey=$apiKey";

//   Uri uri = Uri.parse(urlString);
//   newsResponse = await http.get(uri);

//   if (newsResponse.statusCode == 200) {
//     Map<String, dynamic> jsonData = json.decode(newsResponse.body);
//     if (jsonData['articles'] != null) {
//       List<dynamic> articles = jsonData['articles'];

//       // Tell Flutter that the state is changing so it can rebuild the UI.
//       setState(() {
//         _news = articles.map((json) => News.fromJson(json)).toList();
//       });

//     } else {
//       // It's good practice to handle errors by showing a message
//       // For now, we'll just throw an exception.
//       throw Exception('No articles found in the response');
//     }
//   } else {
//     throw Exception('Failed to load news');
//   }
// }


//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'My News Reader App',
//       debugShowCheckedModeBanner: false,
//       home: Scaffold(
//         backgroundColor: const Color.fromARGB(255, 202, 242, 239),
//         appBar: AppBar(
//           title: Text('My News Reader App'),
//           backgroundColor: const Color.fromARGB(255, 76, 163, 175),
//         ),
//         body: _news==null ? CircularProgressIndicator() :ListView.builder(
//                 itemCount: _news.length,
//                 itemBuilder: (context, index) {
//                   return  NewsCard(news: _news[index]);
//                 },
//               ),
//       ),
//     );
//   }
// }