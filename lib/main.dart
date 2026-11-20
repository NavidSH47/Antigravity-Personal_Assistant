import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'app.dart';

export 'app.dart';
export 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.init();
  runApp(NSHAssistantApp(storage: storage));
}
