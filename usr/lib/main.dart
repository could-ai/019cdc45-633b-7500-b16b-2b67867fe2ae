import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// We removed the DashboardData class entirely!
// Instead, we are using a Dart 3 Named Record: ({String userName, String postTitle})
// This allows the provider to return two separate strings without needing a custom class.

class DashboardNotifier extends AsyncNotifier<({String userName, String postTitle})> {
  
  @override
  Future<({String userName, String postTitle})> build() async {
    return _fetchAll();
  }

  // Helper to fetch just the user
  Future<String> _fetchUser() async {
    final randomUserId = Random().nextInt(10) + 1;
    final response = await http.get(Uri.parse('https://jsonplaceholder.typicode.com/users/$randomUserId'));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['name'];
    } else {
      throw Exception('Failed to load user');
    }
  }

  // Helper to fetch just the post
  Future<String> _fetchPost() async {
    final randomPostId = Random().nextInt(100) + 1;
    final response = await http.get(Uri.parse('https://jsonplaceholder.typicode.com/posts/$randomPostId'));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['title'];
    } else {
      throw Exception('Failed to load post');
    }
  }

  // Helper to fetch both concurrently
  Future<({String userName, String postTitle})> _fetchAll() async {
    final results = await Future.wait([
      _fetchUser(),
      _fetchPost(),
    ]);
    
    // Return a Dart 3 Named Record containing our two strings
    return (
      userName: results[0],
      postTitle: results[1],
    );
  }

  // Refresh everything
  Future<void> refreshAll() async {
    // Set state to loading but preserve the previous data so the UI doesn't flash
    state = const AsyncLoading<({String userName, String postTitle})>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _fetchAll());
  }

  // Refresh ONLY the user
  Future<void> refreshUser() async {
    final currentData = state.value;
    // If we don't have current data, just do a full refresh
    if (currentData == null) {
      return refreshAll();
    }

    state = const AsyncLoading<({String userName, String postTitle})>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final newUserName = await _fetchUser();
      // Return a new Record keeping the old postTitle
      return (
        userName: newUserName,
        postTitle: currentData.postTitle,
      );
    });
  }

  // Refresh ONLY the post
  Future<void> refreshPost() async {
    final currentData = state.value;
    // If we don't have current data, just do a full refresh
    if (currentData == null) {
      return refreshAll();
    }

    state = const AsyncLoading<({String userName, String postTitle})>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final newPostTitle = await _fetchPost();
      // Return a new Record keeping the old userName
      return (
        userName: currentData.userName,
        postTitle: newPostTitle,
      );
    });
  }
}

final dashboardProvider = AsyncNotifierProvider<DashboardNotifier, ({String userName, String postTitle})>(() {
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
          // skipLoadingOnReload: true prevents the UI from reverting to the 
          // full-screen loading spinner when we are just refreshing data.
          skipLoadingOnReload: true,
          data: (data) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.cloud_done, size: 64, color: Colors.teal),
                const SizedBox(height: 24),
                
                // Show a small progress indicator at the top if we are currently fetching
                if (asyncDashboardData.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: LinearProgressIndicator(),
                  )
                else
                  const SizedBox(height: 20), // Placeholder to prevent layout jump

                Text(
                  'Fetched from multiple APIs:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                
                // User Card
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Random User'),
                    // Accessing the named record field
                    subtitle: Text(data.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh User Only',
                      // Disable button if currently loading
                      onPressed: asyncDashboardData.isLoading 
                          ? null 
                          : () => ref.read(dashboardProvider.notifier).refreshUser(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Post Card
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.article),
                    title: const Text('Random Post Title'),
                    // Accessing the named record field
                    subtitle: Text(data.postTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh Post Only',
                      // Disable button if currently loading
                      onPressed: asyncDashboardData.isLoading 
                          ? null 
                          : () => ref.read(dashboardProvider.notifier).refreshPost(),
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
                  onPressed: () => ref.read(dashboardProvider.notifier).refreshAll(),
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
            : () => ref.read(dashboardProvider.notifier).refreshAll(),
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh All'),
      ),
    );
  }
}
