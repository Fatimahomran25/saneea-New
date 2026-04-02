import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';

import 'views/intro.dart';
import 'views/signup.dart';
import 'views/login.dart';
import 'views/freelancer_home.dart';
import 'views/client_home_screen.dart';
import 'views/admin_home.dart';
import 'views/password.dart'; // <-- ForgotPasswordScreen + ResetPasswordScreen

import 'package:saneea_app/views/admin_profile.dart';
import 'views/bank_account.dart';
import 'views/freelancer_profile.dart';
import 'views/client_profile.dart';


final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initDynamicLinks();
  }

  Future<void> _initDynamicLinks() async {
    // لما التطبيق شغال (Foreground)
    FirebaseDynamicLinks.instance.onLink
        .listen((PendingDynamicLinkData data) {
          final Uri link = data.link;
          _handleResetLink(link);
        })
        .onError((e) {
          debugPrint('DynamicLink error: $e');
        });

    // لما التطبيق ينفتح من رابط (Cold start)
    final PendingDynamicLinkData? data = await FirebaseDynamicLinks.instance
        .getInitialLink();

    if (data != null) {
      _handleResetLink(data.link);
    }
  }

  void _handleResetLink(Uri link) {
    // Firebase sends:
    // https://xxxx.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=XXX...
    final mode = link.queryParameters['mode'];
    final oobCode = link.queryParameters['oobCode'];

    if (mode == 'resetPassword' && oobCode != null && oobCode.isNotEmpty) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(oobCode: oobCode),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // navigatorKey: navigatorKey,
      title: 'Saneea',
      debugShowCheckedModeBanner: false,
      initialRoute: '/intro',
      routes: {
        '/intro': (context) => const IntroScreen(),
        '/signup': (context) => const SignupScreen(),
        '/login': (context) => const login(),
        '/freelancerHome': (_) => const FreelancerHomeView(),
        '/clientHome': (_) => const ClientHomeScreen(),
        '/adminHome': (context) => const AdminHomeScreen(),
        '/adminProfile': (_) => const AdminProfileScreen(),
        '/forgotPassword': (context) => const ForgotPasswordScreen(),
        '/freelancerProfile': (_) => const FreelancerProfileView(),
        '/clientProfile': (_) => const ClientProfile(),
        '/bankAccount': (_) => const BankAccountView(),


      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
