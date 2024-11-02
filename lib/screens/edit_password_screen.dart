import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EditPasswordScreen extends StatefulWidget {
  @override
  _EditPasswordScreenState createState() => _EditPasswordScreenState();
}

class _EditPasswordScreenState extends State<EditPasswordScreen> {
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showDialog(String title, String content, [List<Widget>? actions]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: GoogleFonts.kodchasan(
              fontWeight: FontWeight.bold,
              color: Colors.pinkAccent,
            ),
          ),
          content: Text(
            content,
            style: GoogleFonts.kodchasan(
              color: Colors.black,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(
              color: Colors.pinkAccent,
              width: 2,
            ),
          ),
          actions: actions ??
              [
                TextButton(
                  child: Text(
                    "ปิด",
                    style: GoogleFonts.kodchasan(
                      color: Colors.pinkAccent,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
        );
      },
    );
  }

  void _logout() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('User_ID');
      Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  void _showDialogAndLogout(String title, String content) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: GoogleFonts.kodchasan(
              fontWeight: FontWeight.bold,
              color: Colors.pinkAccent,
            ),
          ),
          content: Text(
            content,
            style: GoogleFonts.kodchasan(
              color: Colors.black,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(
              color: Colors.pinkAccent,
              width: 2,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                "ตกลง",
                style: GoogleFonts.kodchasan(
                  color: Colors.pinkAccent,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _logout();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _changePassword() async {
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (oldPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showDialog('ผิดพลาด', 'กรุณากรอกรหัสผ่านให้ครบทุกช่อง');
      return;
    }

    if (newPassword.contains(' ')) {
      _showDialog('ผิดพลาด', 'รหัสผ่านห้ามมีช่องว่าง');
      return;
    }

    if (newPassword == oldPassword) {
      _showDialog(
          'ผิดพลาด', 'รหัสผ่านใหม่ตรงกับรหัสผ่านเดิม ไม่สามารถเปลี่ยนได้');
      return;
    }

    if (newPassword != confirmPassword) {
      _showDialog('ผิดพลาด', 'รหัสผ่านใหม่และรหัสผ่านยืนยันไม่ตรงกัน');
      return;
    }

    if (newPassword.length < 8) {
      _showDialog('ผิดพลาด', 'รหัสผ่านควรมีอย่างน้อย 8 ตัวอักษร');
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userId = prefs.getString('User_ID') ?? 'DefaultUserID';

    var url = Uri.parse('$baseUrl/change_password.php');
    var response = await http.post(
      url,
      body: {
        'User_ID': userId,
        'old_password': oldPassword,
        'new_password': newPassword,
      },
    );

    if (response.statusCode == 200) {
      var responseData = json.decode(response.body);
      if (responseData['success']) {
        _showDialogAndLogout(
            'สำเร็จ', 'รหัสผ่านเปลี่ยนเรียบร้อยแล้ว คุณจะถูกออกจากระบบทันที');
      } else {
        _showDialog('ผิดพลาด', 'เกิดข้อผิดพลาด: ${responseData['message']}');
      }
    } else {
      _showDialog('ผิดพลาด', 'การเชื่อมต่อล้มเหลว');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'เปลี่ยนรหัสผ่าน',
          style: GoogleFonts.kodchasan(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        backgroundColor: Color.fromARGB(255, 254, 176, 216),
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: ListView(
          children: <Widget>[
            TextFormField(
              controller: _oldPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'รหัสผ่านเก่า',
                labelStyle: GoogleFonts.kodchasan(
                  fontSize: 16,
                  color: Colors.black,
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
              ),
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'รหัสผ่านใหม่',
                labelStyle: GoogleFonts.kodchasan(
                  fontSize: 16,
                  color: Colors.black,
                ),
                helperText:
                    'รหัสผ่านควรมีอย่างน้อย 8 ตัวอักษร และประกอบด้วย \nตัวอักษรพิมพ์เล็ก, พิมพ์ใหญ่, และอักษรพิเศษ',
                helperStyle: GoogleFonts.kodchasan(fontSize: 12),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
              ),
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'ยืนยันรหัสผ่านใหม่',
                labelStyle: GoogleFonts.kodchasan(
                  fontSize: 16,
                  color: Colors.black,
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _changePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent[100],
                foregroundColor: Colors.black,
                textStyle: GoogleFonts.kodchasan(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              child: Text('ยืนยันการเปลี่ยนรหัสผ่าน'),
            ),
          ],
        ),
      ),
    );
  }
}
