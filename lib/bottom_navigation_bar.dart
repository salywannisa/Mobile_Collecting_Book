import 'package:flutter/material.dart';
import 'screens/focus_screen.dart';
import 'screens/bookshelf_screen.dart';
import 'screens/search_screen.dart';
import 'screens/quotes_screen.dart';
import 'screens/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final int
      initialTabIndex; // รับค่า initialTabIndex จากหน้าอื่นสำหรับ FocusScreen
  final String selectedBook; // รับค่า selectedBook

  HomeScreen(
      {Key? key, required this.initialTabIndex, required this.selectedBook})
      : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _initialTabIndex = 0;
  String? _userId;
  bool _isLoggedIn = false;
  String selectedBookId = '';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _selectedIndex = 0;
    _initialTabIndex = widget.initialTabIndex;
    selectedBookId = widget.selectedBook;
  }

  void _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('User_ID');
      _isLoggedIn = _userId != null && _userId!.isNotEmpty;

      // ถ้าไม่ได้ล็อกอิน ให้แสดงหน้าจอ QuotesScreen
      if (!_isLoggedIn) {
        _selectedIndex = 1;
      }
    });
  }

  // ฟังก์ชันที่ให้หน้าจอเมื่อผู้ใช้ล็อกอินอยู่
  List<Widget> _loggedInOptions(String bookId) => <Widget>[
        FocusScreen(
          initialTabIndex: _selectedIndex == 0
              ? _initialTabIndex
              : 0, // ถ้าไม่ใช่แท็บแรก, ให้เปิดแท็บสถิติ
          selectedBook: bookId.isNotEmpty ? bookId : 'default',
        ),
        BookshelfScreen(),
        SearchScreen(),
        QuotesScreen(),
        ProfileScreen(),
      ];

  // ฟังก์ชันที่ให้หน้าจอเมื่อผู้ใช้ไม่ได้ล็อกอิน
  final List<Widget> _loggedOutOptions = <Widget>[
    SearchScreen(),
    QuotesScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) {
        _initialTabIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // เลือกว่าจะใช้ widget ใดตามสถานะล็อกอิน
    final List<Widget> _widgetOptions =
        _isLoggedIn ? _loggedInOptions(selectedBookId) : _loggedOutOptions;

    return Scaffold(
      body:
          _widgetOptions.elementAt(_selectedIndex), // แสดงหน้าจอตามแท็บที่เลือก
      bottomNavigationBar: BottomNavigationBar(
        items: _isLoggedIn
            ? const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.hourglass_bottom_rounded),
                  label: 'Focus',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.book_outlined),
                  label: 'ชั้นสะสม',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: 'ค้นหาหนังสือ',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_border),
                  label: 'Quotes',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'โปรไฟล์',
                ),
              ]
            : const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: 'ค้นหาหนังสือ',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_border),
                  label: 'Quotes',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'โปรไฟล์',
                ),
              ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.pinkAccent[100],
        unselectedItemColor: Color.fromARGB(255, 0, 0, 0),
        onTap: _onItemTapped, // เปลี่ยนแท็บเมื่อผู้ใช้คลิก
      ),
    );
  }
}
