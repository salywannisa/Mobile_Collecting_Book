import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  TextEditingController _titleController = TextEditingController();
  TextEditingController _detailsController = TextEditingController();
  File? _selectedImage;

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('User_ID') ?? 'DefaultUserID';
  }

  Future<void> _submitReport() async {
    String userId = await _getUserId();
    String title = _titleController.text.trim();
    String details = _detailsController.text.trim();
    if (title.isEmpty || details.isEmpty) {
      _showDialog('ผิดพลาด', 'หัวข้อและรายละเอียดห้ามว่าง');
      return;
    }
    var request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/upload_report.php'));
    request.fields['title'] = _titleController.text;
    request.fields['details'] = _detailsController.text;
    request.fields['User_ID'] = userId;

    if (_selectedImage != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        _selectedImage!.path,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    var response = await request.send();

    if (response.statusCode == 200) {
      _showConfirmationDialog();
      _titleController.clear();
      _detailsController.clear();
      setState(() {
        _selectedImage = null;
      });
    } else {
      _showDialog('ผิดพลาด', 'การส่งข้อมูลล้มเหลว');
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.pinkAccent,
              width: 2,
            ),
          ),
          title: Text(
            'สำเร็จ',
            style: GoogleFonts.kodchasan(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.pinkAccent,
            ),
            textAlign: TextAlign.left,
          ),
          content: Text(
            'ส่งคำร้องเรียบร้อยแล้ว',
            style: GoogleFonts.kodchasan(
              fontSize: 16,
              fontWeight: FontWeight.normal,
              color: Colors.black,
            ),
            textAlign: TextAlign.left,
          ),
          actions: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  primary: Colors.pinkAccent,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: Text(
                  'ตกลง',
                  style: GoogleFonts.kodchasan(
                    color: Colors.pinkAccent,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.pinkAccent, width: 2),
          ),
          title: Text(
            title,
            style: GoogleFonts.kodchasan(
              color: Colors.pinkAccent,
            ),
          ),
          content: Text(
            content,
            style: GoogleFonts.kodchasan(
              color: Colors.black,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                "ปิด",
                style: GoogleFonts.kodchasan(color: Colors.pinkAccent),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'แจ้งปัญหาการใช้งาน',
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
        child: ListView(
          children: [
            Text(
              'หัวข้อ :',
              style: GoogleFonts.kodchasan(fontSize: 18),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'กรอกหัวข้อ',
                hintStyle: GoogleFonts.kodchasan(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.pinkAccent,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.pinkAccent,
                    width: 2,
                  ),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.pinkAccent,
                    width: 1,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'รายละเอียด :',
              style: GoogleFonts.kodchasan(fontSize: 18),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'กรอกรายละเอียด',
                hintStyle: GoogleFonts.kodchasan(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.pinkAccent,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.pinkAccent,
                    width: 2,
                  ),
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Colors.pinkAccent,
                    width: 1,
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'แนบรูปภาพ :',
              style: GoogleFonts.kodchasan(fontSize: 18),
            ),
            SizedBox(height: 8),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.pinkAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedImage != null
                    ? Image.file(_selectedImage!)
                    : Center(
                        child: Icon(
                          Icons.image,
                          size: 50,
                          color: Colors.pinkAccent,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'รองรับไฟล์ JPG ที่มีขนาดไม่เกิน 10 MB',
              style: GoogleFonts.kodchasan(color: Colors.red),
            ),
            SizedBox(height: 16),
            Center(
              child: OutlinedButton(
                onPressed: _submitReport,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent[100],
                  side: BorderSide(color: Colors.pinkAccent.shade100),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text(
                  'ส่ง',
                  style: GoogleFonts.kodchasan(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
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
