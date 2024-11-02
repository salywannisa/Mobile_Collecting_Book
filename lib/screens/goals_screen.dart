import 'package:collecting_book/bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class GoalsScreen extends StatefulWidget {
  @override
  _GoalsScreenState createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  int? numberOfBooks;
  String? days;
  String? userId;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndFetchGoalsData();
  }

  Future<void> _loadUserIdAndFetchGoalsData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('User_ID');
    });

    if (userId != null) {
      _fetchGoalsData();
    } else {
      print('User_ID not found in SharedPreferences');
    }
  }

  Future<void> _fetchGoalsData() async {
    try {
      if (userId != null) {
        final response =
            await http.get(Uri.parse('$baseUrl/goals.php?user_id=$userId'));

        print('Response body: ${response.body}');

        if (response.statusCode == 200) {
          final decodedData = json.decode(response.body);
          final data = decodedData['data'];

          setState(() {
            numberOfBooks = data['Number_of_Books'];
            days = data['Days'];
          });

          print('Number of Books: $numberOfBooks');
          print('Days: $days');
        } else {
          print('Failed to load data: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error: $e');
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
        backgroundColor: Color.fromARGB(255, 254, 176, 216),
        centerTitle: true,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/books2.png',
                    width: 200,
                    height: 200,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'เป้าหมายการอ่านในปีนี้',
                    style: GoogleFonts.kodchasan(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.pinkAccent,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    numberOfBooks != null
                        ? 'อ่านหนังสือ $numberOfBooks เล่ม'
                        : 'กำลังโหลดข้อมูล...',
                    style: GoogleFonts.kodchasan(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    days != null ? 'วัน: $days' : 'กำลังโหลดข้อมูล...',
                    style: GoogleFonts.kodchasan(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 300,
            height: 60,
            child: Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => HomeScreen(
                              initialTabIndex: 0,
                              selectedBook: '',
                            )),
                    (Route<dynamic> route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent[100],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'เสร็จสิ้น',
                  style: GoogleFonts.kodchasan(
                    fontSize: 18,
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
