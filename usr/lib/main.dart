import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Define a provider. 
// Here we use a StateProvider which is great for simple mutable states like an integer.
final counterProvider = StateProvider<int>((ref) => 0);

void main() {
  // 2. Wrap the root of your app in a ProviderScope.
  // This is required for Riverpod to store and manage the state of the providers.
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
      title: 'Riverpod Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const MyHomePage(title: 'Riverpod Counter Demo'),
      },
    );
  }
}

// 3. Extend ConsumerWidget instead of StatelessWidget or StatefulWidget.
// This allows the widget to listen to providers via the WidgetRef object.
class MyHomePage extends ConsumerWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  // 4. The build method now takes an extra parameter: WidgetRef
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 5. Use ref.watch() to listen to the provider. 
    // Whenever the state changes, this widget will automatically rebuild.
    final counter = ref.watch(counterProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 6. Use ref.read() inside callbacks to modify the state.
          // We access the `.notifier` to update the state value.
          ref.read(counterProvider.notifier).state++;
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
