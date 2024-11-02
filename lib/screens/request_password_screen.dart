import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';

class RequestPasswordScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();

  Future<void> requestNewPassword(BuildContext context, String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/request_password.php'),
        body: {'Email': email},
      );

      if (response.statusCode == 200) {
        // แปลงข้อความ JSON จากเซิร์ฟเวอร์
        final responseData = jsonDecode(response.body);
        String message = responseData['success'] ??
            responseData['error'] ??
            'เกิดข้อผิดพลาด';

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                responseData.containsKey('success') ? 'สำเร็จ' : 'ข้อผิดพลาด',
                style: GoogleFonts.kodchasan(
                  color: Colors.pinkAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                message,
                style: GoogleFonts.kodchasan(
                  color: Colors.black,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0),
                side: BorderSide(
                  color: Colors.pinkAccent,
                  width: 2,
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text(
                    'ตกลง',
                    style: GoogleFonts.kodchasan(
                      color: Colors.pinkAccent,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (responseData.containsKey('success')) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                ),
              ],
            );
          },
        );
      } else {
        throw Exception('Failed to request new password');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 254, 176, 216),
        title: Text(
          'ขอรหัสผ่านใหม่',
          style: GoogleFonts.kodchasan(
              color: Colors.black, fontWeight: FontWeight.w500),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'ลืมรหัสผ่าน',
              style: GoogleFonts.kodchasan(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              'กรุณากรอกอีเมลของคุณ เพื่อรับรหัสผ่านใหม่',
              style: GoogleFonts.kodchasan(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'อีเมล*',
                  labelStyle: GoogleFonts.kodchasan(
                    color: Colors.pinkAccent,
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.pinkAccent,
                    ),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.pinkAccent,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                String email = emailController.text;
                if (email.isNotEmpty) {
                  requestNewPassword(context, email);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'กรุณากรอกอีเมล',
                        style: GoogleFonts.kodchasan(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }
              },
              child: Text('ยืนยัน'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent[100],
                foregroundColor: Colors.black,
                textStyle: GoogleFonts.kodchasan(
                    fontWeight: FontWeight.w500, fontSize: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  side: BorderSide(
                    color: Colors.pinkAccent.shade100,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
