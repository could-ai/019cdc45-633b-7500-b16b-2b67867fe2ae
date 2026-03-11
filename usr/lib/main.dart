import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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
    // For the initial load, we can still generate random IDs or use defaults.
    final initialUserId = Random().nextInt(10) + 1;
    final initialPostId = Random().nextInt(100) + 1;
    return _fetchAll(initialUserId, initialPostId);
  }

  // Helper to fetch just the user, now accepts an ID
  Future<String> _fetchUser(int userId) async {
    final response = await http.get(Uri.parse('https://jsonplaceholder.typicode.com/users/$userId'));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['name'];
    } else {
      throw Exception('Failed to load user');
    }
  }

  // Helper to fetch just the post, now accepts an ID
  Future<String> _fetchPost(int postId) async {
    final response = await http.get(Uri.parse('https://jsonplaceholder.typicode.com/posts/$postId'));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['title'];
    } else {
      throw Exception('Failed to load post');
    }
  }

  // Helper to fetch both concurrently, now accepts IDs
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

  // Refresh everything with specific IDs
  Future<void> refreshAll(int userId, int postId) async {
    state = const AsyncLoading<DashboardData>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _fetchAll(userId, postId));
  }

  // Refresh ONLY the user with a specific ID
  Future<void> refreshUser(int userId) async {
    final currentData = state.value;
    if (currentData == null) {
      // Fallback if there's no current data
      return refreshAll(userId, Random().nextInt(100) + 1);
    }

    state = const AsyncLoading<DashboardData>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final newUserName = await _fetchUser(userId);
      return currentData.copyWith(userName: newUserName);
    });
  }

  // Refresh ONLY the post with a specific ID
  Future<void> refreshPost(int postId) async {
    final currentData = state.value;
    if (currentData == null) {
      // Fallback if there's no current data
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
        '/': (context) => const MyHomePage(title: 'AsyncNotifier Demo'),
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Center(
        child: asyncDashboardData.when(
          skipLoadingOnReload: true,
          data: (data) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
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
                  'Fetched from multiple APIs:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                
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
                              // Client generates the ID and passes it to the provider
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
                              // Client generates the ID and passes it to the provider
                              final randomPostId = Random().nextInt(100) + 1;
                              ref.read(dashboardProvider.notifier).refreshPost(randomPostId);
                            },
                    ),
                  ),
                ),
              ],
            ),
          ),
          loading: () => const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Fetching remote resources...'),
            ],
          ),
          error: (error, stackTrace) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Oops! Something went wrong.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final randomUserId = Random().nextInt(10) + 1;
                    final randomPostId = Random().nextInt(100) + 1;
                    ref.read(dashboardProvider.notifier).refreshAll(randomUserId, randomPostId);
                  },
                  child: const Text('Try Again'),
                )
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: asyncDashboardData.isLoading 
            ? null 
            : () {
                // Client generates both IDs and passes them to the provider
                final randomUserId = Random().nextInt(10) + 1;
                final randomPostId = Random().nextInt(100) + 1;
                ref.read(dashboardProvider.notifier).refreshAll(randomUserId, randomPostId);
              },
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh All'),
      ),
    );
  }
}
