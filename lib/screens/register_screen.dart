import 'dart:convert';
import 'package:collecting_book/screens/confirm_email_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _birthYearController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  Future<void> _register() async {
    var url = Uri.parse('$baseUrl/register.php');

    try {
      var response = await http.post(url, body: {
        'User_Name': _usernameController.text,
        'Year_of_Birth': _birthYearController.text,
        'Email': _emailController.text,
        'Password': _passwordController.text,
        'ConfirmPassword': _confirmPasswordController.text,
      });

      // ตรวจสอบการตอบกลับจากเซิร์ฟเวอร์
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode != 200) {
        _showSnackbar('ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้');
        return;
      }

      var jsonResponse = json.decode(response.body);

      if (jsonResponse.containsKey('error')) {
        print('Error from server: ${jsonResponse['error']}');
        _showSnackbar(jsonResponse['error']);
      } else if (jsonResponse.containsKey('success')) {
        print('Success message from server: ${jsonResponse['success']}');
        _showSnackbar(jsonResponse['success']);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ConfirmEmailScreen(
              email: _emailController.text,
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackbar('เกิดข้อผิดพลาดในการเชื่อมต่อ: $e');
      print('Error: $e');
    }
  }

  void _showSnackbar(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: GoogleFonts.kodchasan(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'สมัครสมาชิก',
          style: GoogleFonts.kodchasan(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        backgroundColor: Color.fromARGB(255, 254, 176, 216),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'ชื่อบัญชี',
                      labelStyle: GoogleFonts.kodchasan(
                        color: Colors.pinkAccent,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.pinkAccent,
                        ),
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.pinkAccent,
                          width: 2.0,
                        ),
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                    ),
                    style: GoogleFonts.kodchasan(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'กรุณากรอกชื่อบัญชี';
                      }
                      if (value.contains(' ')) {
                        return 'ห้ามมีการเว้นวรรคในชื่อบัญชี';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
                        return 'ชื่อบัญชีต้องเป็นตัวอักษรภาษาอังกฤษเท่านั้น';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: _birthYearController,
                    decoration: InputDecoration(
                      labelText: 'ปีเกิด(ค.ศ.)',
                      labelStyle: GoogleFonts.kodchasan(
                        color: Colors.pinkAccent,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.pinkAccent,
                        ),
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.pinkAccent,
                          width: 2.0,
                        ),
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                    ),
                    style: GoogleFonts.kodchasan(),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'อีเมล',
                      labelStyle: GoogleFonts.kodchasan(
                        color: Colors.pinkAccent,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.pinkAccent,
                        ),
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.pinkAccent,
                          width: 2.0,
                        ),
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                    ),
                    style: GoogleFonts.kodchasan(),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'รหัสผ่าน',
                      labelStyle: GoogleFonts.kodchasan(
                        color: Colors.pinkAccent,
                      ),
                      helperText:
                          'รหัสผ่านควรมีอย่างน้อย 8 ตัวอักษร และประกอบด้วย \nตัวอักษรพิมพ์เล็ก, พิมพ์ใหญ่, และอักษรพิเศษ',
                      helperStyle: GoogleFonts.kodchasan(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.pinkAccent,
                        ),
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.pinkAccent,
                          width: 2.0,
                        ),
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                    ),
                    style: GoogleFonts.kodchasan(),
                    obscureText: true,
                  ),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'ยืนยันรหัสผ่าน',
                      labelStyle: GoogleFonts.kodchasan(
                        color: Colors.pinkAccent,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.pinkAccent,
                        ),
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.pinkAccent,
                          width: 2.0,
                        ),
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                    ),
                    style: GoogleFonts.kodchasan(),
                    obscureText: true,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _register();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromARGB(255, 255, 255, 255),
                      foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                      side: BorderSide(
                        color: Colors.pinkAccent,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                    ),
                    child: Text(
                      'สมัคร',
                      style: GoogleFonts.kodchasan(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
