import 'package:collecting_book/bottom_navigation_bar.dart';
import 'package:collecting_book/screens/confirm_email_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'book_goals_screen.dart';
import 'time_goals_screen.dart';

// ตัวแปร Global สำหรับเก็บสถานะล็อกอิน
String? userId;

// ฟังก์ชันสำหรับจัดการสถานะล็อกอิน
Future<void> setUserId(String newUserId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('User_ID', newUserId);
  userId = newUserId;
}

Future<void> clearUserId() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('User_ID');
  userId = null;
}

Future<String?> getUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('User_ID');
}

// ฟังก์ชันสำหรับบันทึกและดึง User_Name จาก SharedPreferences
Future<void> setUserName(String newUserName) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('User_Name', newUserName);
  print("User_Name saved: $newUserName"); // ตรวจสอบการบันทึก
}

Future<String?> getUserName() async {
  final prefs = await SharedPreferences.getInstance();
  String? userName = prefs.getString('User_Name');
  print("User_Name from SharedPreferences: $userName"); // ตรวจสอบการดึงข้อมูล
  return userName;
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userNameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _userNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login.php'),
        body: {
          'user_name': _userNameController.text,
          'password': _passwordController.text,
        },
      );

      print('Response Body: ${response.body}');

      final responseData = json.decode(response.body);
      print('Response Data: $responseData');

      if (responseData['status'] == 'success') {
        String userId = responseData['User_ID'];
        String userName = _userNameController.text;

        if (userId.isNotEmpty) {
          await setUserId(userId);
          await setUserName(userName);

          print('User_ID saved: $userId');

          if (mounted) {
            _checkGoalExists(userId);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'ไม่พบ User_ID ในการตอบกลับ',
                  style: GoogleFonts.kodchasan(color: Colors.pinkAccent),
                ),
              ),
            );
          }
        }
      } else {
        String errorMessage = responseData['message'] ??
            'ไม่พบชื่อบัญชีในระบบหรือรหัสผ่านไม่ถูกต้อง';
        String? email = responseData['Email'];

        if (responseData['status'] == 'error' &&
            errorMessage == 'บัญชียังไม่ได้รับการยืนยัน') {
          if (mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text(
                    'กรุณายืนยันตัวตน',
                    style: GoogleFonts.kodchasan(
                        color: Colors.pinkAccent, fontWeight: FontWeight.w500),
                  ),
                  content: Text(
                    errorMessage,
                    style: GoogleFonts.kodchasan(
                        fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: Text(
                        'ตกลง',
                        style: GoogleFonts.kodchasan(color: Colors.pinkAccent),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                ConfirmEmailScreen(email: email!),
                          ),
                        );
                      },
                    ),
                  ],
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.pink, width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              },
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  errorMessage,
                  style: GoogleFonts.kodchasan(),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'เกิดข้อผิดพลาด: $e',
              style: GoogleFonts.kodchasan(color: Colors.pinkAccent),
            ),
          ),
        );
      }
    }
  }

  Future<void> _checkGoalExists(String userId) async {
    var url = Uri.parse(
        '$baseUrl/check_goal.php'); // URL สำหรับตรวจสอบการตั้งเป้าหมาย

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {'User_ID': userId},
      );

      // พิมพ์การตอบสนองจากเซิร์ฟเวอร์เพื่อตรวจสอบ
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);

        // ตรวจสอบว่าค่าที่ได้รับจาก responseData ไม่เป็น null
        bool goalExists = responseData['goal_exists'] ?? false;
        bool goalsSet = responseData['goals_set'] ?? false;

        if (!goalExists) {
          print('User has not set a goal yet. Navigating to BookGoalsScreen.');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => BookGoalsScreen()),
          );
        } else if (!goalsSet) {
          print(
              'User has not set time goals yet. Navigating to TimeGoalsScreen.');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => TimeGoalsScreen()),
          );
        } else {
          // นำทางไปหน้า HomeScreen หากผู้ใช้ตั้งเป้าหมายทั้งหมดแล้ว
          print('User already has all goals set. Navigating to HomeScreen.');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => HomeScreen(
                      initialTabIndex: 0,
                      selectedBook: '',
                    )),
          );
        }
      } else {
        print('Failed to check goal: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error occurred while checking goal: $e');
    }
  }

  Future<void> _checkStoredUserId() async {
    String? storedUserId = await getUserId();
    print('Stored User_ID: $storedUserId'); // ตรวจสอบว่าค่าถูกบันทึกหรือไม่
  }

  @override
  void initState() {
    super.initState();
    _checkStoredUserId();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'เข้าสู่ระบบ',
          style: GoogleFonts.kodchasan(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        backgroundColor: Color.fromARGB(255, 254, 176, 216),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.topCenter,
                child: Image.asset(
                  'assets/images/splash_image.png',
                  height: 250,
                  fit: BoxFit.contain,
                ),
              ),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(height: 250),
                    TextFormField(
                      controller: _userNameController,
                      decoration: InputDecoration(
                        labelText: 'ชื่อบัญชี',
                        labelStyle: GoogleFonts.kodchasan(
                          color: Colors.pinkAccent,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.pinkAccent,
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.pinkAccent,
                            width: 2.0,
                          ),
                        ),
                        errorStyle: GoogleFonts.kodchasan(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณาใส่ชื่อบัญชี';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'รหัสผ่าน',
                        labelStyle: GoogleFonts.kodchasan(
                          color: Colors.pinkAccent,
                        ),
                        floatingLabelStyle: GoogleFonts.kodchasan(
                          color: Colors.pinkAccent,
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.pinkAccent,
                          ),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.pinkAccent,
                            width: 2.0,
                          ),
                        ),
                        errorStyle: GoogleFonts.kodchasan(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'กรุณาใส่รหัสผ่าน';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/request-password');
                        },
                        child: Text(
                          'ลืมรหัสผ่าน',
                          style: GoogleFonts.kodchasan(
                            color: Colors.pinkAccent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: SizedBox(
                        width: 150,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _login();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pinkAccent[100],
                            foregroundColor: Colors.black,
                            side: BorderSide(color: Colors.pinkAccent.shade100),
                          ),
                          child: Text(
                            'เข้าสู่ระบบ',
                            style: GoogleFonts.kodchasan(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: Text(
                        'สมัครสมาชิก',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.kodchasan(
                          color: Colors.pinkAccent,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
