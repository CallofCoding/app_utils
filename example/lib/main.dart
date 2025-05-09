import 'package:app_utils/app_utils.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  NetworkServiceConfig().initialize(
    responseValidationKey: 'status',
    showLogs: true,
    onUnAuthentication: (context) {
      print('main');
    },
    snackBar: (message) {
      return SnackBar(content: Text(message));
    },
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppUtils.instance.navigatorKey,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  NetworkServiceHandler serviceHandler = NetworkServiceHandler();

  Future<void> getData()async{
    String url = "https://dog.ceo/api/breeds/image/random";
    serviceHandler.getDataHandler(url,onSuccess: (response) {
      UserSession.instance.saveToken('234890qwertyuiop');
      response['data'];

    },);

  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppTextField(errorMsg: 'errorMsg'),
          FutureBuilder(future: getData(), builder: (context, snapshot) => SnapshotHandler(snapshot: snapshot, onSuccess: (data) => SizedBox(),),),
        ],
      ),
    );
  }
}
