import 'package:flutter/material.dart';
import 'bottom_navigation_bar.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/request_password_screen.dart';
import 'screens/confirm_email_screen.dart';
import 'screens/focus_screen.dart';
import 'screens/bookshelf_screen.dart';
import 'screens/search_screen.dart';
import 'screens/quotes_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/book_goals_screen.dart';
import 'screens/time_goals_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/requests_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/message_screen.dart';
import 'screens/store_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/change_profile_screen.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(
        initialTabIndex: 0,
        selectedBook: '',
      ),
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/request-password': (context) => RequestPasswordScreen(),
        '/confirm-email': (context) =>
            ConfirmEmailScreen(email: 'example@example.com'),
        '/focus': (context) => FocusScreen(
              initialTabIndex: 0,
              selectedBook: '',
            ),
        '/bookshelf': (context) => BookshelfScreen(),
        '/search': (context) => SearchScreen(),
        '/quotes': (context) => QuotesScreen(),
        '/profile': (context) => ProfileScreen(),
        '/book-goals': (context) => BookGoalsScreen(),
        '/time-goals': (context) => TimeGoalsScreen(),
        '/goals': (context) => GoalsScreen(),
        '/requests': (context) => RequestsScreen(),
        '/user-profile': (context) => UserProfileScreen(),
        '/message': (context) => MessageScreen(),
        '/store': (context) => StoreScreen(),
        '/reports': (context) => ReportsScreen(),
        '/change-profile': (context) => ChangeProfilePictureScreen(),
      },
    );
  }
}
