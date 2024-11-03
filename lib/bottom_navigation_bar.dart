import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final GlobalKey<FocusScreenState> _focusScreenKey =
      GlobalKey<FocusScreenState>();

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

      if (!_isLoggedIn) {
        _selectedIndex = 1;
      }
    });
  }

  List<Widget> _loggedInOptions(String bookId) => <Widget>[
        FocusScreen(
          key: _focusScreenKey,
          initialTabIndex: _selectedIndex == 0 ? _initialTabIndex : 0,
          selectedBook: bookId.isNotEmpty ? bookId : 'default',
        ),
        BookshelfScreen(),
        SearchScreen(),
        QuotesScreen(),
        ProfileScreen(),
      ];

  final List<Widget> _loggedOutOptions = <Widget>[
    SearchScreen(),
    QuotesScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == 0 &&
        _focusScreenKey.currentState?.isRunning == true) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'เตือน!!!',
              style: GoogleFonts.kodchasan(
                  color: Colors.pinkAccent, fontWeight: FontWeight.w500),
            ),
            content: Text(
              'จับเวลากำลังทำงานอยู่ กรุณาหยุดจับเวลาและบันทึกข้อมูลก่อนทำรายการอื่น',
              style: GoogleFonts.kodchasan(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'ตกลง',
                  style: GoogleFonts.kodchasan(color: Colors.pinkAccent),
                ),
              ),
            ],
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.pinkAccent, width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      );
    } else {
      setState(() {
        _selectedIndex = index;
        if (index == 0) {
          _initialTabIndex = 0;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _widgetOptions =
        _isLoggedIn ? _loggedInOptions(selectedBookId) : _loggedOutOptions;

    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
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
        onTap: _onItemTapped,
      ),
    );
  }
}
