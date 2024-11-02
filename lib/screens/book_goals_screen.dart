import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'time_goals_screen.dart';

class BookGoalsScreen extends StatefulWidget {
  @override
  _BookGoalsScreenState createState() => _BookGoalsScreenState();
}

class _BookGoalsScreenState extends State<BookGoalsScreen> {
  final _bookCountController = TextEditingController();
  String userId = '';

  @override
  void initState() {
    super.initState();
    _loadUserIdAndCheckGoal();
  }

  @override
  void dispose() {
    _bookCountController.dispose();
    super.dispose();
  }

  Future<void> _loadUserIdAndCheckGoal() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('User_ID') ?? '';
    print('Loaded User_ID: $userId');

    if (userId.isNotEmpty) {
      await _checkGoalExists(); // ตรวจสอบว่ามีการตั้งเป้าหมายแล้วหรือยัง
    }
  }

  Future<void> _checkGoalExists() async {
    var url = Uri.parse('$baseUrl/check_goal.php');

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {'User_ID': userId},
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);

        if (responseData['goal_exists']) {
          print('User already has a goal set.');
          _navigateToTimeGoalsScreen();
        } else {
          print('User has not set a goal yet.');
        }
      } else {
        print('Failed to check goal: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error occurred while checking goal: $e');
    }
  }

  void _navigateToTimeGoalsScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => TimeGoalsScreen()),
    );
  }

  Future<void> _saveBookGoals() async {
    final numberOfBooks = _bookCountController.text;
    var url = Uri.parse('$baseUrl/book_goals.php');

    if (userId.isEmpty) {
      print('User_ID is empty');
      return;
    }

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          'User_ID': userId,
          'Number_of_Books': numberOfBooks,
        },
      );

      print('User_ID: $userId');
      print('Number_of_Books: $numberOfBooks');
      print('Response body: ${response.body}');

      var responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (responseData['success'] || responseData['goal_exists']) {
          print(responseData['message'] ?? 'User already has a goal set.');
          _navigateToTimeGoalsScreen(); // นำผู้ใช้ไปยังหน้าจอ TimeGoalsScreen
        } else {
          print('Failed to update: ${responseData['message']}');
        }
      } else {
        print('Failed to connect: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error occurred: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'เป้าหมาย',
          style: GoogleFonts.kodchasan(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 254, 176, 216),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset(
                    'assets/images/books.png',
                    width: 100,
                    height: 100,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'ในปีนี้คุณต้องการอ่านหนังสือกี่เล่ม',
                    style: GoogleFonts.kodchasan(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(
                    width: 100,
                    child: TextField(
                      controller: _bookCountController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.kodchasan(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        labelText: 'จำนวนเล่ม',
                        labelStyle: GoogleFonts.kodchasan(
                          color: Colors.pinkAccent,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.pinkAccent,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.pinkAccent,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.pinkAccent,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: SizedBox(
              width: 300,
              height: 40,
              child: ElevatedButton(
                onPressed: () {
                  if (_bookCountController.text.isNotEmpty) {
                    _saveBookGoals();
                  } else {
                    print('กรุณากรอกจำนวนเล่ม');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent[100],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: Text(
                  'ถัดไป',
                  style: GoogleFonts.kodchasan(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
