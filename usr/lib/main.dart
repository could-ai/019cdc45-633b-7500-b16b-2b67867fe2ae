import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// --- Existing Dashboard Data & Provider ---

class DashboardData {
  final String userName;
  final String postTitle;

  DashboardData({
    required this.userName,
    required this.postTitle,
  });

  DashboardData copyWith({
    String? userName,
    String? postTitle,
  }) {
    return DashboardData(
      userName: userName ?? this.userName,
      postTitle: postTitle ?? this.postTitle,
    );
  }
}

class DashboardNotifier extends AsyncNotifier<DashboardData> {
  @override
  Future<DashboardData> build() async {
    final initialUserId = Random().nextInt(10) + 1;
    final initialPostId = Random().nextInt(100) + 1;
    return _fetchAll(initialUserId, initialPostId);
  }

  Future<String> _fetchUser(int userId) async {
    final response = await http.get(Uri.parse('https://jsonplaceholder.typicode.com/users/$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['name'];
    } else {
      throw Exception('Failed to load user');
    }
  }

  Future<String> _fetchPost(int postId) async {
    final response = await http.get(Uri.parse('https://jsonplaceholder.typicode.com/posts/$postId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['title'];
    } else {
      throw Exception('Failed to load post');
    }
  }

  Future<DashboardData> _fetchAll(int userId, int postId) async {
    final results = await Future.wait([
      _fetchUser(userId),
      _fetchPost(postId),
    ]);
    return DashboardData(
      userName: results[0],
      postTitle: results[1],
    );
  }

  Future<void> refreshAll(int userId, int postId) async {
    state = const AsyncLoading<DashboardData>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _fetchAll(userId, postId));
  }

  Future<void> refreshUser(int userId) async {
    final currentData = state.value;
    if (currentData == null) {
      return refreshAll(userId, Random().nextInt(100) + 1);
    }
    state = const AsyncLoading<DashboardData>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final newUserName = await _fetchUser(userId);
      return currentData.copyWith(userName: newUserName);
    });
  }

  Future<void> refreshPost(int postId) async {
    final currentData = state.value;
    if (currentData == null) {
      return refreshAll(Random().nextInt(10) + 1, postId);
    }
    state = const AsyncLoading<DashboardData>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final newPostTitle = await _fetchPost(postId);
      return currentData.copyWith(postTitle: newPostTitle);
    });
  }
}

final dashboardProvider = AsyncNotifierProvider<DashboardNotifier, DashboardData>(() {
  return DashboardNotifier();
});


// --- New Streaming Data & Provider ---

class Photo {
  final int id;
  final String title;
  final String thumbnailUrl;

  Photo({required this.id, required this.title, required this.thumbnailUrl});

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
      title: json['title'],
      thumbnailUrl: json['thumbnailUrl'],
    );
  }
}

Future<List<Photo>> _fetchRandomPhotos() async {
  // Fetch a random page of 4 photos to simulate changing live data
  final randomStart = Random().nextInt(100);
  final response = await http.get(
    Uri.parse('https://jsonplaceholder.typicode.com/photos?_start=$randomStart&_limit=4')
  );

  if (response.statusCode == 200) {
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Photo.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load live photos');
  }
}

// StreamProvider that yields new data immediately, and then every 10 seconds
final livePhotosProvider = StreamProvider<List<Photo>>((ref) async* {
  // 1. Yield initial data immediately
  yield await _fetchRandomPhotos();

  // 2. Yield new data every 10 seconds using Stream.periodic
  await for (final _ in Stream.periodic(const Duration(seconds: 10))) {
    yield await _fetchRandomPhotos();
  }
});


// --- App & UI ---

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riverpod AsyncNotifier Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MyHomePage(title: 'Riverpod Providers Demo'),
      },
    );
  }
}

class MyHomePage extends ConsumerWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDashboardData = ref.watch(dashboardProvider);
    final livePhotosData = ref.watch(livePhotosProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      // Wrapped in SingleChildScrollView to allow scrolling with the new grid
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- Dashboard Section (AsyncNotifierProvider) ---
              const Icon(Icons.cloud_done, size: 64, color: Colors.teal),
              const SizedBox(height: 24),
              
              if (asyncDashboardData.isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: LinearProgressIndicator(),
                )
              else
                const SizedBox(height: 20),

              Text(
                'Manual Fetch (AsyncNotifier):',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              asyncDashboardData.when(
                skipLoadingOnReload: true,
                data: (data) => Column(
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Random User'),
                        subtitle: Text(data.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh User Only',
                          onPressed: asyncDashboardData.isLoading 
                              ? null 
                              : () {
                                  final randomUserId = Random().nextInt(10) + 1;
                                  ref.read(dashboardProvider.notifier).refreshUser(randomUserId);
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.article),
                        title: const Text('Random Post Title'),
                        subtitle: Text(data.postTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Refresh Post Only',
                          onPressed: asyncDashboardData.isLoading 
                              ? null 
                              : () {
                                  final randomPostId = Random().nextInt(100) + 1;
                                  ref.read(dashboardProvider.notifier).refreshPost(randomPostId);
                                },
                        ),
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(child: Text('Error: $error', style: const TextStyle(color: Colors.red))),
              ),

              const SizedBox(height: 32),
              const Divider(thickness: 2),
              const SizedBox(height: 16),

              // --- Live Feed Section (StreamProvider) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sensors, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Text(
                    'Live Feed (Updates every 10s):',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              livePhotosData.when(
                data: (photos) => GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Image.network(
                              photo.thumbnailUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              photo.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, stackTrace) => Center(
                  child: Text('Error loading live feed: $error', style: const TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: asyncDashboardData.isLoading 
            ? null 
            : () {
                final randomUserId = Random().nextInt(10) + 1;
                final randomPostId = Random().nextInt(100) + 1;
                ref.read(dashboardProvider.notifier).refreshAll(randomUserId, randomPostId);
              },
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh Manual Data'),
      ),
    );
  }
}
