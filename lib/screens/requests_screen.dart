import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RequestsScreen extends StatefulWidget {
  @override
  _RequestsScreenState createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController authorController = TextEditingController();
  final TextEditingController editionController = TextEditingController();
  final TextEditingController isbnController = TextEditingController();
  String? selectedShelf;
  List<dynamic> bookshelves = [];
  File? imageFile;

  @override
  void initState() {
    super.initState();
    fetchBookshelves();
  }

  Future<void> fetchBookshelves() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    final response = await http.post(
      Uri.parse('$baseUrl/get_bookshelves_for_requests.php'),
      body: {'User_ID': userId},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success']) {
        setState(() {
          bookshelves = data['bookshelves'];
        });
      } else {
        _showDialog("ผิดพลาด", data['message'] ?? "เกิดข้อผิดพลาดที่ไม่รู้จัก");
      }
    } else {
      _showDialog("ผิดพลาด", "ไม่สามารถโหลดข้อมูลชั้นหนังสือได้");
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 480,
      maxHeight: 640,
      imageQuality: 100,
    );
    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> submitRequest() async {
    if (!_validateAndSave()) {
      return;
    }

    if (imageFile != null && !imageFile!.path.endsWith('.jpg')) {
      _showDialog("Error", "Only JPG images are allowed.");
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/upload_request.php'),
    );
    request.fields['User_ID'] = userId ?? '';
    request.fields['Bookshelf_ID'] = selectedShelf ?? '';
    request.fields['Request_Book_Name'] = titleController.text;
    request.fields['Request_Author'] =
        authorController.text; // ตรวจสอบให้แน่ใจว่านี้ถูกต้อง
    request.fields['Request_Printed'] = editionController.text;
    request.fields['Request_ISBN'] = isbnController.text;

    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile!.path,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    var response = await request.send();
    if (response.statusCode == 200) {
      _showDialog("สำเร็จ", "ส่งคำร้องเรียบร้อยแล้ว");
      _clearForm();
    } else {
      _showDialog("ผิดพลาด", "ไม่สามารถส่งคำร้องได้");
    }
  }

  bool _validateAndSave() {
    if (titleController.text.isEmpty ||
        authorController.text.isEmpty ||
        isbnController.text.isEmpty ||
        selectedShelf == null) {
      _showDialog("ผิดพลาด", "โปรดกรอกข้อมูลในช่องที่มี * ทั้งหมด");
      return false;
    }

    if (!RegExp(r'^[0-9]{10}$').hasMatch(isbnController.text) &&
        !RegExp(r'^[0-9]{13}$').hasMatch(isbnController.text)) {
      _showDialog("ผิดพลาด", "ISBN ต้องเป็นตัวเลข 10 หรือ 13 หลักเท่านั้น");
      return false;
    }

    if (editionController.text.isNotEmpty &&
        !RegExp(r'^[0-9]+$').hasMatch(editionController.text)) {
      _showDialog("ผิดพลาด", "กรุณากรอกตัวเลขเท่านั้น");
      return false;
    }

    return true;
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: GoogleFonts.kodchasan(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.pinkAccent,
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
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(
              color: Colors.pinkAccent,
              width: 2,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'ตกลง',
                style: GoogleFonts.kodchasan(
                  fontSize: 16,
                  color: Colors.pinkAccent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _clearForm() {
    titleController.clear();
    authorController.clear();
    editionController.clear();
    isbnController.clear();
    setState(() {
      selectedShelf = null;
      imageFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'แจ้งคำร้องขอเพิ่มหนังสือ',
          style: GoogleFonts.kodchasan(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.black, // สีของฟอนต์ใน AppBar
          ),
        ),
        backgroundColor: Color.fromARGB(255, 254, 176, 216),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            GestureDetector(
              onTap: pickImage,
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  width: 150,
                  height: 190,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.pinkAccent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: imageFile != null
                      ? Image.file(imageFile!, fit: BoxFit.cover)
                      : Center(
                          child: Icon(
                            Icons.image,
                            size: 50,
                            color: Colors.pinkAccent,
                          ),
                        ),
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              'รองรับไฟล์ JPG ที่มีขนาดไม่เกิน 10 MB',
              style: GoogleFonts.kodchasan(
                fontSize: 14,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'ชื่อหนังสือ*',
                labelStyle: GoogleFonts.kodchasan(),
                floatingLabelStyle: GoogleFonts.kodchasan(
                  color: Colors.black,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent, width: 2),
                ),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: authorController,
              decoration: InputDecoration(
                labelText: 'ผู้แต่ง*',
                labelStyle: GoogleFonts.kodchasan(),
                floatingLabelStyle: GoogleFonts.kodchasan(
                  color: Colors.black,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent, width: 2),
                ),
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: editionController,
              decoration: InputDecoration(
                labelText: 'ครั้งที่พิมพ์',
                labelStyle: GoogleFonts.kodchasan(),
                floatingLabelStyle: GoogleFonts.kodchasan(
                  color: Colors.black,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent, width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            TextField(
              controller: isbnController,
              decoration: InputDecoration(
                labelText: 'ISBN*',
                labelStyle: GoogleFonts.kodchasan(),
                floatingLabelStyle: GoogleFonts.kodchasan(
                  color: Colors.black,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent, width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: selectedShelf,
              decoration: InputDecoration(
                labelText: 'เพิ่มที่ชั้นหนังสือ*',
                labelStyle: GoogleFonts.kodchasan(),
                floatingLabelStyle: GoogleFonts.kodchasan(
                  color: Colors.black,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.pinkAccent, width: 2),
                ),
              ),
              onChanged: (String? newValue) {
                setState(() {
                  selectedShelf = newValue;
                });
              },
              items: bookshelves.map<DropdownMenuItem<String>>((shelf) {
                return DropdownMenuItem<String>(
                  value: shelf['Bookshelf_ID'].toString(),
                  child: Text(
                    shelf['Bookshelf_Name'],
                    style: GoogleFonts.kodchasan(),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: submitRequest,
              child: Text(
                'ส่ง',
                style: GoogleFonts.kodchasan(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent[100],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
