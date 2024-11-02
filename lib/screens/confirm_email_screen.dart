import 'package:collecting_book/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';
import 'dart:convert';
import 'dart:async';

class ConfirmEmailScreen extends StatefulWidget {
  final String email; // รับค่า email จากหน้าก่อนหน้า

  ConfirmEmailScreen({required this.email}); // เพิ่ม constructor เพื่อรับ email

  @override
  _ConfirmEmailScreenState createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends State<ConfirmEmailScreen> {
  Timer? _timer;
  int _start = 300; // 10 minutes in seconds
  bool _showResendLink = false;

  List<TextEditingController> _otpControllers =
      List.generate(6, (index) => TextEditingController());

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  Future<void> _resendOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/resend_otp.php'),
        body: {'Email': email},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Response from server: $data");
        if (data['success'] != null) {
          print("OTP ส่งสำเร็จ");
          _showResendDialog();
        } else if (data['error'] != null) {
          print("Error: ${data['error']}");
        }
      } else {
        print("Failed to resend OTP: ${response.statusCode}");
      }
    } catch (e) {
      print("Error resending OTP: $e");
    }
  }

  void startTimer() {
    _showResendLink = false;
    _timer?.cancel();
    setState(() {
      _start = 300;
    });
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          _showResendLink = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  void _showResendDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            "OTP ถูกส่งสำเร็จ",
            style: GoogleFonts.kodchasan(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.pinkAccent,
            ),
          ),
          content: Text(
            "กรุณาตรวจสอบอีเมลของคุณ",
            style: GoogleFonts.kodchasan(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: BorderSide(
              color: Colors.pinkAccent,
              width: 2.0,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                startTimer(); // เริ่มจับเวลาถอยหลังใหม่
              },
              child: Text(
                "ตกลง",
                style: GoogleFonts.kodchasan(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.pinkAccent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpControllers.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<Map<String, dynamic>?> verifyOtp(String enteredOtp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify_otp.php'),
        body: {'OTP': enteredOtp},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to verify OTP');
      }
    } catch (e) {
      print('Error verifying OTP: $e');
      return null;
    }
  }

  void _submitOtp() async {
    String enteredOtp = _getEnteredOtp();
    final result = await verifyOtp(enteredOtp);

    if (result != null && result['status'] == 'success') {
      _showDialog('ยืนยันสำเร็จ', 'OTP ถูกต้อง', true);
    } else {
      _showDialog(
          'เกิดข้อผิดพลาด', result?['message'] ?? 'เกิดข้อผิดพลาด', false);
    }
  }

  void _showDialog(String title, String content, bool success) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: GoogleFonts.kodchasan(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: success ? Colors.pinkAccent : Colors.pinkAccent,
            ),
          ),
          content: Text(
            content,
            style: GoogleFonts.kodchasan(
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: BorderSide(
              color: success ? Colors.pinkAccent : Colors.pinkAccent,
              width: 2.0,
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'ตกลง',
                style: GoogleFonts.kodchasan(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.pinkAccent,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                if (success) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _getEnteredOtp() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  @override
  Widget build(BuildContext context) {
    print('Email being used: ${widget.email}');
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            'ยืนยันอีเมล',
            style: GoogleFonts.kodchasan(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
          backgroundColor: Color.fromARGB(255, 254, 176, 216),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'ส่งรหัสไปที่ \n${widget.email} แล้ว \nกรุณาตรวจสอบอีเมลของคุณ',
                textAlign: TextAlign.center,
                style: GoogleFonts.kodchasan(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 45,
                      child: TextField(
                        controller: _otpControllers[index],
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.kodchasan(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.pinkAccent,
                        ),
                        decoration: InputDecoration(
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
                          counterText: '',
                        ),
                        onChanged: (value) {
                          if (value.length == 1) {
                            FocusScope.of(context).nextFocus();
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitOtp,
                child: Text(
                  'ยืนยัน OTP',
                  style: GoogleFonts.kodchasan(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.pinkAccent),
                ),
              ),
              SizedBox(height: 20),
              Text(
                "${(_start ~/ 60).toString().padLeft(2, '0')}:${(_start % 60).toString().padLeft(2, '0')}",
                style: GoogleFonts.kodchasan(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.pinkAccent,
                ),
              ),
              if (_showResendLink)
                TextButton(
                  onPressed: () {
                    _resendOtp(widget.email);
                  },
                  child: Text(
                    'ส่งอีกครั้ง',
                    style: GoogleFonts.kodchasan(
                      fontSize: 16,
                      color: Colors.blueAccent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
