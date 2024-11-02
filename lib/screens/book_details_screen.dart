import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookDetailsScreen extends StatefulWidget {
  final dynamic book;
  final bool fromBookshelfPage;

  BookDetailsScreen({required this.book, this.fromBookshelfPage = false});

  @override
  _BookDetailsScreenState createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  String selectedShelf = '';
  List<Map<String, String>> shelves = [];
  String? userId;
  double score = 0;
  double? bookScore;
  TextEditingController pageReadController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserId(); // โหลด User_ID
    _loadBookScore();
  }

  void _loadUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('User_ID');
      print("User_ID ที่โหลดได้: $userId");
    });

    // ไม่แสดงป๊อปอัพถ้าผู้ใช้ยังไม่ได้ล็อกอิน
    if (userId == null) {
      print("ผู้ใช้งานยังไม่ได้ล็อกอิน");
      return;
    }

    _loadShelves(); // ดึงข้อมูลชั้นหนังสือหลังจากที่ผู้ใช้ล็อกอินแล้ว

    if (widget.fromBookshelfPage) {
      _loadPageRead();
    }
  }

  void _loadPageRead() async {
    if (userId != null && widget.book['Book_ID'] != null) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/get_page_read.php'),
          body: {
            'User_ID': userId,
            'Book_ID': widget.book['Book_ID'].toString(),
          },
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);

          if (result['status'] == 'success' && result['page_read'] != null) {
            int totalPages =
                int.parse(widget.book['Number_of_Page'].toString());
            int readPages = int.parse(result['page_read'].toString());

            setState(() {
              if (readPages == 0) {
                pageReadController.text = "ยังไม่ได้อ่าน";
              } else if (readPages >= totalPages) {
                pageReadController.text = "อ่านจบแล้ว";
              } else {
                pageReadController.text = result['page_read'].toString();
              }
            });
          } else {
            setState(() {
              pageReadController.text = "ยังไม่ได้อ่าน";
            });
          }
        } else {
          _showErrorDialog(
              "การดึงข้อมูลจำนวนหน้าที่อ่านล้มเหลว รหัสสถานะ: ${response.statusCode}");
        }
      } catch (e) {
        _showErrorDialog("เกิดข้อผิดพลาดในการดึงข้อมูลจำนวนหน้าที่อ่าน: $e");
      }
    } else {
      setState(() {
        pageReadController.text = "ยังไม่ได้อ่าน";
      });
    }
  }

  void _loadShelves() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get_shelves.php'),
        body: {'User_ID': userId},
      );
      if (response.statusCode == 200) {
        List<dynamic> shelvesData = jsonDecode(response.body);
        setState(() {
          shelves = shelvesData
              .map((shelf) => {
                    'Bookshelf_ID': shelf['Bookshelf_ID'].toString(),
                    'Bookshelf_Name': shelf['Bookshelf_Name'].toString(),
                  })
              .toList();
        });
      } else {
        _showErrorDialog(
            "Failed to load shelves. Status code: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorDialog("Error fetching shelves: $e");
    }
  }

  void _saveBookToShelf() async {
    if (selectedShelf.isEmpty) {
      _showErrorDialog("กรุณาเลือกชั้นหนังสือ");
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/save_book_to_shelf.php'),
        body: {
          'User_ID': userId,
          'Book_ID': widget.book['Book_ID'].toString(),
          'Bookshelf_ID': selectedShelf,
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          _showSuccessDialog("บันทึกหนังสือเข้าชั้นสำเร็จ");
        } else {
          _showErrorDialog(result['message']);
        }
      } else {
        _showErrorDialog(
            "การเชื่อมต่อกับเซิร์ฟเวอร์ล้มเหลว รหัสสถานะ: ${response.statusCode}");
      }
    } catch (e) {
      _showErrorDialog("เกิดข้อผิดพลาดในการบันทึกหนังสือ: $e");
    }
  }

  void _loadBookScore() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    if (widget.book['Book_ID'] != null && userId != null) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/get_book_score.php'),
          body: {
            'Book_ID': widget.book['Book_ID'].toString(),
            'User_ID': userId,
          },
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['status'] == 'success' && result['score'] != null) {
            setState(() {
              bookScore = double.tryParse(result['score'].toString());
            });
          } else if (result['status'] == 'error' &&
              result['message'] ==
                  'ไม่พบคะแนนสำหรับหนังสือเล่มนี้สำหรับผู้ใช้นี้') {
            setState(() {
              bookScore = null;
            });
          } else {
            print('Error: ${result['message']}');
          }
        } else {
          print('Response status: ${response.statusCode}');
        }
      } catch (e) {
        print("Error retrieving book score: $e");
      }
    } else {
      print("Book_ID is missing or not logged in.");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'เกิดข้อผิดพลาด',
            style: GoogleFonts.kodchasan(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.pinkAccent,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.kodchasan(
              fontSize: 16,
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
          actions: <Widget>[
            TextButton(
              child: Text(
                'ตกลง',
                style: GoogleFonts.kodchasan(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.pinkAccent,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'สำเร็จ!',
            style: GoogleFonts.kodchasan(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.pinkAccent,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.kodchasan(
              fontSize: 16,
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
          actions: <Widget>[
            TextButton(
              child: Text(
                'ตกลง',
                style: GoogleFonts.kodchasan(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.pinkAccent,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    print("Book_ID ที่ได้รับ: ${widget.book['Book_ID']}");

    double displayScore = widget.fromBookshelfPage
        ? (bookScore ?? 0)
        : (double.tryParse(widget.book['Score'].toString()) ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.book['Book_Name'] ?? 'Book Details',
          style: GoogleFonts.kodchasan(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 254, 176, 216),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.network(
                  widget.book['Book_Picture'] ?? '',
                  width: 200,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.image, size: 200),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'ชื่อเรื่อง: ${widget.book['Book_Name'] ?? 'Unknown Title'}',
                style: GoogleFonts.kodchasan(
                  fontSize: 18,
                ),
              ),
              Text(
                'ผู้แต่ง: ${widget.book['Author'] ?? 'Unknown Author'}',
                style: GoogleFonts.kodchasan(
                  fontSize: 18,
                ),
              ),
              Text(
                'สำนักพิมพ์: ${widget.book['Publisher'] ?? 'Unknown Publisher'}',
                style: GoogleFonts.kodchasan(
                  fontSize: 18,
                ),
              ),
              Text(
                'ครั้งที่พิมพ์: ${widget.book['Printed'] ?? 'N/A'}',
                style: GoogleFonts.kodchasan(
                  fontSize: 18,
                ),
              ),
              Text(
                'หมวดหมู่: ${widget.book['Category'] ?? 'N/A'}',
                style: GoogleFonts.kodchasan(
                  fontSize: 18,
                ),
              ),
              Text(
                'จำนวนหน้า: ${widget.book['Number_of_Page'] ?? 'N/A'} หน้า',
                style: GoogleFonts.kodchasan(
                  fontSize: 18,
                ),
              ),
              Text(
                'ISBN: ${widget.book['ISBN'] ?? 'N/A'}',
                style: GoogleFonts.kodchasan(
                  fontSize: 18,
                ),
              ),
              if (!widget.fromBookshelfPage) ...[
                SizedBox(height: 10),
                Text(
                  'คะแนน: ${double.tryParse(widget.book['Score'].toString())?.toStringAsFixed(2) ?? '0.00'}',
                  style: GoogleFonts.kodchasan(
                    fontSize: 18,
                  ),
                ),
              ],
              if (widget.fromBookshelfPage) ...[
                SizedBox(height: 10),
                Row(
                  children: [
                    Text('อ่านไปแล้ว:',
                        style: GoogleFonts.kodchasan(
                            fontSize: 18, color: Colors.black)),
                    SizedBox(width: 10),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.pinkAccent, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        pageReadController.text.isNotEmpty
                            ? pageReadController.text
                            : "ยังไม่ได้อ่าน",
                        style: GoogleFonts.kodchasan(fontSize: 18),
                      ),
                    ),
                    SizedBox(width: 5),
                    Text('หน้า', style: GoogleFonts.kodchasan(fontSize: 18)),
                  ],
                ),
              ],
              if (widget.fromBookshelfPage) ...[
                SizedBox(height: 10),
                Row(
                  children: [
                    Text('คะแนนที่ให้:',
                        style: GoogleFonts.kodchasan(fontSize: 18)),
                    SizedBox(width: 8),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < displayScore ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: widget.fromBookshelfPage
          ? null
          : FloatingActionButton(
              onPressed: _showAddToShelfDialog,
              child: Icon(Icons.add),
              backgroundColor: Colors.pinkAccent[100],
              shape: CircleBorder(),
            ),
    );
  }

  void _showAddToShelfDialog() {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'กรุณาเข้าสู่ระบบเพื่อเพิ่มหนังสือ',
            style: GoogleFonts.kodchasan(fontSize: 16, color: Colors.white),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'เพิ่มไปชั้นหนังสือ',
            style: GoogleFonts.kodchasan(color: Colors.pinkAccent),
          ),
          content: shelves.isNotEmpty
              ? SingleChildScrollView(
                  child: Column(
                    children: shelves.map((shelf) {
                      return RadioListTile<String>(
                        title: Text(
                          shelf['Bookshelf_Name'] ?? '',
                          style: GoogleFonts.kodchasan(color: Colors.black),
                        ),
                        value: shelf['Bookshelf_ID'] ?? '',
                        groupValue: selectedShelf,
                        activeColor: Colors.pinkAccent,
                        onChanged: (String? value) {
                          setState(() {
                            selectedShelf = value!;
                          });
                          Navigator.of(context).pop();
                          _showAddToShelfDialog();
                        },
                      );
                    }).toList(),
                  ),
                )
              : Text(
                  'ไม่พบชั้นหนังสือที่ต้องการเพิ่ม',
                  style:
                      GoogleFonts.kodchasan(color: Colors.black, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'ยกเลิก',
                style: GoogleFonts.kodchasan(color: Colors.pinkAccent),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (shelves.isNotEmpty)
              TextButton(
                child: Text(
                  'ตกลง',
                  style: GoogleFonts.kodchasan(color: Colors.pinkAccent),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _saveBookToShelf();
                },
              ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.pinkAccent,
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
