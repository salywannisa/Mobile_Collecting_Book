import 'dart:convert';
import 'package:collecting_book/screens/requests_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'book_details_screen.dart';
import 'dart:io';

HttpClient httpClient = new HttpClient();

class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _scanBarcode = 'กรุณากดสแกน';

  @override
  void initState() {
    super.initState();
  }

  // ฟังก์ชันดึงหนังสือแนะนำ
  Future<Map<String, dynamic>> _fetchRecommendedBooks() async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/get_recommended_books.php'));

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);

        return data;
      } else {
        throw Exception('Failed to load recommended books');
      }
    } catch (e) {
      print('Error: $e');
      throw ('ไม่มีการเชื่อมต่ออินเตอร์เน็ต');
    }
  }

  // ฟังก์ชันดึงหนังสือทั้งหมด (จากแท็บค้นหา)
  Future<List<dynamic>> _fetchBooks() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get_books.php'),
        body: {'search': _searchQuery},
      );

      if (response.statusCode == 200) {
        List<dynamic> books = json.decode(response.body);

        return books;
      } else {
        throw Exception('Failed to load books');
      }
    } catch (e) {
      print('Error: $e');
      throw ('ไม่มีการเชื่อมต่ออินเตอร์เน็ต');
    }
  }

  Future<void> scanBarcodeNormal() async {
    String barcodeScanRes;
    try {
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#ff6666', 'ยกเลิก', true, ScanMode.BARCODE);

      print('Scanned barcode: $barcodeScanRes');

      if (barcodeScanRes == '-1') {
        print('Barcode scan canceled');
        setState(() {
          _scanBarcode = 'การสแกนถูกยกเลิก';
        });
      } else if (!RegExp(r'^\d+$').hasMatch(barcodeScanRes)) {
        setState(() {
          _scanBarcode = 'รูปแบบของบาร์โค้ดไม่ถูกต้อง';
        });
      } else {
        setState(() {
          _scanBarcode = barcodeScanRes;
        });
        await sendBarcodeToServer(barcodeScanRes);
      }
    } on PlatformException {
      barcodeScanRes = 'Failed to get platform version.';
      setState(() {
        _scanBarcode = barcodeScanRes;
      });
    }

    if (!mounted) return;
  }

  Future<void> sendBarcodeToServer(String barcode) async {
    var url = Uri.parse('$baseUrl/barcode.php');

    try {
      var response = await http.post(url, body: {
        'barcode': barcode,
      });

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'success' &&
            jsonResponse['book'] != null) {
          var book = jsonResponse['book'];
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookDetailsScreen(book: book),
            ),
          );
        } else {
          _showNotFoundDialog();
        }
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void _showNotFoundDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(
              color: Colors.pinkAccent,
              width: 2.0,
            ),
          ),
          title: Text(
            'ไม่พบหนังสือ',
            style: GoogleFonts.kodchasan(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.pinkAccent,
            ),
          ),
          content: Text(
            'ไม่พบข้อมูลหนังสือที่สแกน',
            style: GoogleFonts.kodchasan(
              fontSize: 16,
              color: Colors.black,
            ),
          ),
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.pinkAccent,
                  ),
                  child: Text(
                    'ออก',
                    style: GoogleFonts.kodchasan(),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.pinkAccent,
                  ),
                  child: Text(
                    'แจ้งคำร้อง',
                    style: GoogleFonts.kodchasan(),
                  ),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    String? userId = prefs.getString('User_ID');

                    Navigator.of(context).pop();

                    if (userId == null || userId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'กรุณาเข้าสู่ระบบก่อนทำการแจ้งคำร้อง',
                            style: GoogleFonts.kodchasan(
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RequestsScreen(),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'ค้นหาหนังสือ',
            style: GoogleFonts.kodchasan(
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: Color.fromARGB(255, 254, 176, 216),
          centerTitle: true,
          bottom: TabBar(
            indicatorPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            indicatorSize: TabBarIndicatorSize.label,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(50.0),
              color: Colors.white,
            ),
            tabs: [
              Tab(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'แนะนำหนังสือ',
                      style: GoogleFonts.kodchasan(
                        fontSize: 12.0,
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              Tab(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'ค้นหา',
                      style: GoogleFonts.kodchasan(color: Colors.black),
                    ),
                  ),
                ),
              ),
              Tab(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'สแกน',
                      style: GoogleFonts.kodchasan(color: Colors.black),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // แท็บหนังสือแนะนำ
            FutureBuilder<Map<String, dynamic>>(
              future: _fetchRecommendedBooks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                      child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('ไม่พบหนังสือแนะนำ'));
                }

                final booksByQuotes =
                    snapshot.data!['by_quotes'] as List<dynamic>;
                final booksByScores =
                    snapshot.data!['by_scores'] as List<dynamic>;
                final booksAdminRecommended =
                    snapshot.data!['admin_recommended'] as List<dynamic>;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // หนังสือแนะนำโดยผู้ดูแลระบบ
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '✨หนังสือแนะนำโดยผู้ดูแลระบบ✨',
                          style: GoogleFonts.kodchasan(
                            fontSize: 16,
                            color: Colors.pinkAccent,
                          ),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: booksAdminRecommended.length,
                        itemBuilder: (context, index) {
                          final book = booksAdminRecommended[index];
                          final bookName =
                              book['Book_Name'] ?? 'ไม่ทราบชื่อหนังสือ';
                          final author = book['Author'] ?? 'ไม่ทราบชื่อผู้แต่ง';
                          final bookPicture = book['Book_Picture'] ?? '';

                          return Column(
                            children: [
                              ListTile(
                                leading: (bookPicture.isNotEmpty)
                                    ? Image.network(
                                        bookPicture,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      )
                                    : Icon(Icons.book),
                                title: Text(
                                  bookName,
                                  style: GoogleFonts.kodchasan(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  author,
                                  style: GoogleFonts.kodchasan(
                                    fontSize: 12,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          BookDetailsScreen(book: book),
                                    ),
                                  );
                                },
                              ),
                              Divider(),
                            ],
                          );
                        },
                      ),

                      // หนังสือที่มีโควตมากที่สุด
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '💬หนังสือที่มีโควตมากที่สุด💬',
                          style: GoogleFonts.kodchasan(
                            fontSize: 16,
                            color: Colors.pinkAccent,
                          ),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: booksByQuotes.length,
                        itemBuilder: (context, index) {
                          final book = booksByQuotes[index];
                          final bookName =
                              book['Book_Name'] ?? 'ไม่ทราบชื่อหนังสือ';
                          final author = book['Author'] ?? 'ไม่ทราบชื่อผู้แต่ง';
                          final bookPicture = book['Book_Picture'] ?? '';
                          final numberOfQuotes = book['number_of_quotes'] ?? 0;

                          return Column(
                            children: [
                              ListTile(
                                leading: (bookPicture.isNotEmpty)
                                    ? Image.network(
                                        bookPicture,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      )
                                    : Icon(Icons.book),
                                title: Text(
                                  bookName,
                                  style: GoogleFonts.kodchasan(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '$author\n',
                                        style: GoogleFonts.kodchasan(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'จำนวนโควต: $numberOfQuotes',
                                        style: GoogleFonts.kodchasan(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.orangeAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          BookDetailsScreen(book: book),
                                    ),
                                  );
                                },
                              ),
                              Divider(),
                            ],
                          );
                        },
                      ),

                      // หนังสือที่มีคะแนนสูงสุด
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '⭐️หนังสือที่มีคะแนนสูงสุด⭐️',
                          style: GoogleFonts.kodchasan(
                            fontSize: 16,
                            color: Colors.pinkAccent,
                          ),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: booksByScores.length,
                        itemBuilder: (context, index) {
                          final book = booksByScores[index];
                          final bookName =
                              book['Book_Name'] ?? 'ไม่ทราบชื่อหนังสือ';
                          final author = book['Author'] ?? 'ไม่ทราบชื่อผู้แต่ง';
                          final bookPicture = book['Book_Picture'] ?? '';
                          final score = book['Score'] ?? 0;

                          return Column(
                            children: [
                              ListTile(
                                leading: (bookPicture.isNotEmpty)
                                    ? Image.network(
                                        bookPicture,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      )
                                    : Icon(Icons.book),
                                title: Text(
                                  bookName,
                                  style: GoogleFonts.kodchasan(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '$author\n',
                                        style: GoogleFonts.kodchasan(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'คะแนน: $score',
                                        style: GoogleFonts.kodchasan(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.orangeAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          BookDetailsScreen(book: book),
                                    ),
                                  );
                                },
                              ),
                              Divider(),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            // แท็บค้นหา
            Column(
              children: [
                SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ชื่อหนังสือ, ชื่อผู้แต่ง, ชื่อสำนักพิมพ์',
                      hintStyle: GoogleFonts.kodchasan(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 12.0, horizontal: 20.0),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.pinkAccent),
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.pinkAccent),
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                    ),
                    style: GoogleFonts.kodchasan(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                    onChanged: (value) {
                      _onSearch(value);
                    },
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: _fetchBooks(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(
                            child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(child: Text('No books found'));
                      }

                      final books = snapshot.data!;
                      return ListView.builder(
                        itemCount: books.length,
                        itemBuilder: (context, index) {
                          final book = books[index];
                          final bookName = book['Book_Name'] ?? 'Unknown Title';
                          final author = book['Author'] ?? 'Unknown Author';
                          final bookPicture = book['Book_Picture'] ?? '';

                          return Column(
                            children: [
                              ListTile(
                                leading: (bookPicture.isNotEmpty)
                                    ? Image.network(
                                        bookPicture,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      )
                                    : Icon(Icons.book),
                                title: Text(
                                  bookName,
                                  style: GoogleFonts.kodchasan(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  author,
                                  style: GoogleFonts.kodchasan(
                                    fontSize: 12,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          BookDetailsScreen(book: book),
                                    ),
                                  );
                                },
                              ),
                              Divider(),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            // แท็บสแกน
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'ผลการสแกน: $_scanBarcode',
                    style: GoogleFonts.kodchasan(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => scanBarcodeNormal(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.pinkAccent, width: 2.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                    ),
                    child: Text(
                      'สแกนบาร์โค้ด',
                      style: GoogleFonts.kodchasan(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.pinkAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
