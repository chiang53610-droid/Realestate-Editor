import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/video_provider.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VideoProvider(),
      child: MaterialApp(
        title: 'AI 房仲剪輯',
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
