import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// 1. Define a model class to hold the combined data from multiple sources.
class DashboardData {
  final String userName;
  final String postTitle;

  DashboardData({required this.userName, required this.postTitle});
}

// 2. Create an AsyncNotifier class.
// This class manages asynchronous state. The generic type <DashboardData> 
// specifies the type of data this notifier will hold.
class DashboardNotifier extends AsyncNotifier<DashboardData> {
  
  // 3. The build method is required. It initializes the state.
  // This is where you perform your initial asynchronous operations.
  @override
  Future<DashboardData> build() async {
    return _fetchData();
  }

  // A helper method to fetch data from multiple remote resources concurrently.
  Future<DashboardData> _fetchData() async {
    // We use JSONPlaceholder, a free fake API for testing.
    // Randomizing IDs to show state changes on refresh.
    final randomUserId = Random().nextInt(10) + 1;
    final randomPostId = Random().nextInt(100) + 1;

    // Start both HTTP requests concurrently
    final userFuture = http.get(Uri.parse('https://jsonplaceholder.typicode.com/users/$randomUserId'));
    final postFuture = http.get(Uri.parse('https://jsonplaceholder.typicode.com/posts/$randomPostId'));

    // Wait for both requests to complete
    final results = await Future.wait([userFuture, postFuture]);
    final userResponse = results[0];
    final postResponse = results[1];

    if (userResponse.statusCode == 200 && postResponse.statusCode == 200) {
      final userData = jsonDecode(userResponse.body);
      final postData = jsonDecode(postResponse.body);
      
      return DashboardData(
        userName: userData['name'],
        postTitle: postData['title'],
      );
    } else {
      throw Exception('Failed to load data from remote resources');
    }
  }

  // 4. Add methods to mutate the state.
  // Here we add a refresh method that sets the state to loading, 
  // fetches new data, and updates the state.
  Future<void> refresh() async {
    // Set state to loading while we fetch new data
    state = const AsyncValue.loading();
    
    // AsyncValue.guard automatically handles catching errors and 
    // converting them into AsyncValue.error, or AsyncValue.data on success.
    state = await AsyncValue.guard(() => _fetchData());
  }
}

// 5. Create the AsyncNotifierProvider.
// This exposes the DashboardNotifier and its state to the rest of the app.
final dashboardProvider = AsyncNotifierProvider<DashboardNotifier, DashboardData>(() {
  return DashboardNotifier();
});

void main() {
  runApp(
    // ProviderScope is required at the root to store Riverpod state.
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

// 6. Extend ConsumerWidget to listen to the provider.
class MyHomePage extends ConsumerWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 7. Watch the provider. 
    // Because it's an AsyncNotifierProvider, the state is an AsyncValue<DashboardData>.
    final asyncDashboardData = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Center(
        // 8. Use the .when() method on AsyncValue to handle the different states:
        // data, loading, and error. This makes UI state management very clean.
        child: asyncDashboardData.when(
          data: (data) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.cloud_done, size: 64, color: Colors.teal),
                const SizedBox(height: 24),
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
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.article),
                    title: const Text('Random Post Title'),
                    subtitle: Text(data.postTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
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
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // 9. Call the refresh method on the notifier to trigger a new fetch.
          ref.read(dashboardProvider.notifier).refresh();
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh Data'),
      ),
    );
  }
}
