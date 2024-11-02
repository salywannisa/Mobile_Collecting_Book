import 'dart:convert';
import 'package:collecting_book/screens/book_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';
import 'login_screen.dart'; // นำเข้าไฟล์ login_screen.dart

class QuotesScreen extends StatefulWidget {
  @override
  _QuotesScreenState createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;
  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  late Future<List<Map<String, dynamic>>> _userQuotesFuture;
  late Future<List<Map<String, dynamic>>> _allQuotesFuture;
  final TextEditingController _quoteController = TextEditingController();
  final TextEditingController _pageController = TextEditingController();
  bool _isPrivate = false;
  bool _isAddingQuote = false;
  bool _isEditing = false;
  String? selectedCategoryId;
  String? _editingQuoteId;
  String? selectedBookId = '';
  Map<String, bool> filters = {};
  Map<String, bool> likedQuotes = {};
  List<GlobalKey> _quoteKeys = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _categoriesFuture = _fetchCategories();
    _userQuotesFuture = _fetchUserQuotes();
    _allQuotesFuture = _fetchAllQuotes();
    _quoteKeys = List.generate(100, (index) => GlobalKey());

    _fetchBooks().then((books) {
      if (books.isNotEmpty) {
        setState(() {
          selectedBookId = '';
        });
      }
    });

    _tabController.addListener(() async {
      if (_tabController.index == 1) {
        bool isLoggedIn = await _checkLoginStatus();
        if (!isLoggedIn) {
          _tabController.animateTo(0);
          _openLoginScreen(context);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');
    print('User_ID from SharedPreferences: $userId');
    return userId != null && userId.isNotEmpty;
  }

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('User_ID');
  }

  void _openLoginScreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.pinkAccent,
              width: 2,
            ),
          ),
          title: Center(
              child: Text(
            'กรุณาลงชื่อเข้าใช้งาน',
            style: GoogleFonts.kodchasan(),
          )),
          content: Container(
            height: 100,
            child: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
                child: Text(
                  'เข้าสู่ระบบ',
                  style: GoogleFonts.kodchasan(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: BorderSide(
                    color: Colors.pinkAccent,
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCategories() async {
    final url = Uri.parse('$baseUrl/categories.php');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      if (response.body.isNotEmpty) {
        try {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            List<Map<String, dynamic>> categories =
                List<Map<String, dynamic>>.from(responseData['data']);
            return categories;
          } else {
            print('Failed to fetch categories: ${responseData['error']}');
            return [];
          }
        } catch (e) {
          print('Error decoding JSON: $e');
          return [];
        }
      } else {
        print('Response body is empty');
        return [];
      }
    } else {
      print('Failed to fetch categories. Status code: ${response.statusCode}');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchBooks() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    if (userId == null) {
      print('User not logged in');
      return [];
    }

    final url = Uri.parse('$baseUrl/fetch_books.php');
    final response = await http.post(url, body: {
      'User_ID': userId,
    });

    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      if (response.body.isNotEmpty) {
        try {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            List<Map<String, dynamic>> books =
                List<Map<String, dynamic>>.from(responseData['data']);
            return books;
          } else {
            print('Failed to fetch books: ${responseData['error']}');
            return [];
          }
        } catch (e) {
          print('Error decoding JSON: $e');
          return [];
        }
      } else {
        print('Response body is empty');
        return [];
      }
    } else {
      print('Failed to fetch books. Status code: ${response.statusCode}');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllQuotes() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    final url = Uri.parse('$baseUrl/fetch_all_quotes.php');
    final response = await http.post(url, body: {
      'User_ID': userId ?? 'public',
      'Category_ID': selectedCategoryId ?? '',
    });

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      try {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          List<Map<String, dynamic>> quotes =
              List<Map<String, dynamic>>.from(responseData['data']);

          setState(() {
            likedQuotes.clear();
            quotes.forEach((quote) {
              likedQuotes[quote['Quote_ID'].toString()] = quote['isLiked'] == 1;
            });
          });

          return quotes;
        } else {
          print('Failed to fetch quotes: ${responseData['error']}');
          return [];
        }
      } catch (e) {
        print('Error decoding JSON: $e');
        return [];
      }
    } else {
      print('Failed to fetch quotes. Status code: ${response.statusCode}');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserQuotes() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    if (userId == null) {
      return [];
    }

    final url = Uri.parse('$baseUrl/fetch_quotes.php');
    final response = await http.post(url, body: {
      'User_ID': userId,
      'Category_ID': selectedCategoryId ?? '',
    });

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      final responseData = json.decode(response.body);
      if (responseData['success'] == true) {
        List<Map<String, dynamic>> quotes =
            List<Map<String, dynamic>>.from(responseData['data']);

        setState(() {
          likedQuotes.clear();
          quotes.forEach((quote) {
            likedQuotes[quote['Quote_ID'].toString()] = quote['isLiked'] == 1;
          });
        });

        return quotes;
      }
    }

    return [];
  }

  void _showCategoryFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('ไม่มีหมวดหมู่'));
                }

                List<Map<String, dynamic>> categories = snapshot.data!;
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: Colors.pinkAccent,
                      width: 2,
                    ),
                  ),
                  title: Text(
                    'กรองหมวดหมู่หนังสือ',
                    style: GoogleFonts.kodchasan(
                      // เปลี่ยนฟอนต์
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Container(
                    width: double.maxFinite,
                    height: 400.0,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return RadioListTile<String?>(
                            title: Text(
                              'ทั้งหมด',
                              style: GoogleFonts.kodchasan(
                                fontSize: 14,
                              ),
                            ),
                            value: null,
                            groupValue:
                                selectedCategoryId, // ตรวจสอบว่าค่าไหนถูกเลือก
                            activeColor: Colors.pinkAccent,
                            onChanged: (String? value) {
                              setStateDialog(() {
                                selectedCategoryId = null;
                              });
                            },
                          );
                        }

                        final category = categories[index - 1];
                        return RadioListTile<String?>(
                          title: Text(
                            category['Category_Name'],
                            style: GoogleFonts.kodchasan(
                              fontSize: 14,
                            ),
                          ),
                          value: category['Category_ID'].toString(),
                          groupValue: selectedCategoryId,
                          activeColor: Colors.pinkAccent,
                          onChanged: (String? value) {
                            setStateDialog(() {
                              selectedCategoryId =
                                  value; // อัปเดตหมวดหมู่ที่เลือก
                            });
                          },
                        );
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'ยกเลิก',
                        style: GoogleFonts.kodchasan(
                          color: Colors.pinkAccent,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          // ตรวจสอบว่าอยู่ในแท็บไหน
                          if (_tabController.index == 0) {
                            _allQuotesFuture = _fetchAllQuotes();
                          } else if (_tabController.index == 1) {
                            _userQuotesFuture = _fetchUserQuotes();
                          }
                        });
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'ตกลง',
                        style: GoogleFonts.kodchasan(
                          color: Colors.pinkAccent,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _addQuote(
      String quote, String page, bool isPrivate, String? bookId) async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    print('Sending to PHP:');
    print('User_ID: $userId');
    print('Book_ID: $bookId');
    print('Quote_Detail: $quote');
    print('Page_of_Quote: $page');
    print('Quote_Status: ${isPrivate ? "1" : "2"}');

    final url = Uri.parse('$baseUrl/add_quote.php');
    final response = await http.post(url, body: {
      'action': 'add',
      'User_ID': userId,
      'Book_ID': bookId,
      'Quote_Detail': quote,
      'Page_of_Quote': page,
      'Quote_Status': isPrivate ? '1' : '2',
    });

    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['success']) {
        if (responseData['data'].isNotEmpty) {
          print(
              'Quote added successfully with ID: ${responseData['data']['Quote_ID']}');
          _showSuccessPopup(responseData['message'] ?? 'เพิ่มโควตสำเร็จ');
          setState(() {
            _quoteController.clear();
            _pageController.clear();
            _isPrivate = false;
            selectedBookId = '';
            _userQuotesFuture = _fetchUserQuotes();
          });
        } else {
          print('Failed to add quote: No data returned');
          _showErrorPopup('การเพิ่มโควตล้มเหลว เนื่องจากไม่มีข้อมูลที่ส่งกลับ');
        }
      } else {
        print('Failed to add quote: ${responseData['error']}');
        _showErrorPopup(responseData['error'] ?? 'เพิ่มโควตไม่สำเร็จ');
      }
    } else {
      print('Failed to add quote. Status code: ${response.statusCode}');
      _showErrorPopup('การเชื่อมต่อกับเซิร์ฟเวอร์ล้มเหลว');
    }
  }

  void _showSuccessPopup(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.kodchasan(
              fontSize: 16,
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
                setState(() {
                  _isAddingQuote = false;
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.pinkAccent,
              width: 2,
            ),
          ),
          title: Text(
            'เกิดข้อผิดพลาด',
            style: GoogleFonts.kodchasan(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: GoogleFonts.kodchasan(
              fontSize: 16,
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
                setState(() {
                  _isAddingQuote = true;
                });
              },
            ),
          ],
        );
      },
    );
  }

  void _editQuote(Map<String, dynamic> quote) {
    setState(() {
      _isAddingQuote = true;
      _isEditing = true;
      _editingQuoteId = quote['Quote_ID'].toString();
      selectedBookId = quote['Book_ID'].toString();
      _quoteController.text = quote['Quote_Detail'];
      _pageController.text = quote['Page_of_Quote'].toString();
      _isPrivate = quote['Quote_Status'] == 1;
    });
  }

  Future<void> _updateQuote(String quoteId, String quote, String page,
      bool isPrivate, String? bookId) async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    if (userId == null ||
        bookId == null ||
        bookId.isEmpty ||
        quote.isEmpty ||
        page.isEmpty) {
      _showErrorPopup('กรุณากรอกข้อมูลให้ครบถ้วน');
      return;
    }

    print('Updating quote with Quote_ID: $quoteId');
    final url = Uri.parse('$baseUrl/add_quote.php');
    final response = await http.post(url, body: {
      'action': 'update',
      'Quote_ID': quoteId,
      'User_ID': userId,
      'Book_ID': bookId,
      'Quote_Detail': quote,
      'Page_of_Quote': page,
      'Quote_Status': isPrivate ? '1' : '2',
    });

    // ตรวจสอบสถานะของการตอบกลับจากเซิร์ฟเวอร์
    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['success']) {
        _showSuccessPopup(responseData['message'] ?? 'แก้ไขสำเร็จ');
        print('Quote updated successfully');
        setState(() {
          _quoteController.clear();
          _pageController.clear();
          _isPrivate = false;
          selectedBookId = '';
          _userQuotesFuture = _fetchUserQuotes();
        });
      } else {
        print('Failed to update quote: ${responseData['error']}');
        _showErrorPopup(responseData['error'] ?? 'การแก้ไขโควตล้มเหลว');
      }
    } else {
      print('Failed to update quote. Status code: ${response.statusCode}');
      _showErrorPopup('การเชื่อมต่อกับเซิร์ฟเวอร์ล้มเหลว');
    }
  }

  void _resetForm() {
    setState(() {
      _quoteController.clear();
      _pageController.clear();
      _isPrivate = false;
      selectedBookId = '';
      _isEditing = false;
      _editingQuoteId = null;
      _isAddingQuote = false;
    });
  }

  void _update_edit_Quote(String quoteId, String quote, String page,
      bool isPrivate, String? bookId) async {
    _resetForm();
  }

  Future<void> _confirmDeleteQuote(String quoteId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.pinkAccent,
              width: 2,
            ),
          ),
          title: Text(
            'ยืนยันการลบ',
            style: GoogleFonts.kodchasan(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'คุณต้องการลบโควตนี้หรือไม่?',
                  style: GoogleFonts.kodchasan(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'ยกเลิก',
                style: GoogleFonts.kodchasan(
                  color: Colors.pinkAccent,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                'ยืนยัน',
                style: GoogleFonts.kodchasan(
                  color: Colors.pinkAccent,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteQuote(quoteId);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteQuote(String quoteId) async {
    final url = Uri.parse('$baseUrl/add_quote.php');
    final response = await http.post(url, body: {
      'action': 'delete',
      'User_ID': userId,
      'Quote_ID': quoteId,
    });

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['success']) {
        print('Quote deleted successfully');

        setState(() {
          _userQuotesFuture = _fetchUserQuotes();
          _allQuotesFuture = _fetchAllQuotes();
        });

        _showSuccessDialog();
      } else {
        print('Failed to delete quote: ${responseData['error']}');
      }
    } else {
      print('Failed to delete quote. Status code: ${response.statusCode}');
    }
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.pinkAccent,
              width: 2,
            ),
          ),
          title: Text(
            'ลบโควตสำเร็จ',
            style: GoogleFonts.kodchasan(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'โควตนี้ถูกลบเรียบร้อยแล้ว.',
                  style: GoogleFonts.kodchasan(
                    fontSize: 16,
                  ),
                ),
              ],
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
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleLike(
    String quoteId,
    bool isLiked,
    int currentLikes,
    int index,
    List<Map<String, dynamic>> quotes,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    if (userId == null) {
      print('User not logged in');
      return;
    }

    // บันทึกตำแหน่งการเลื่อนปัจจุบันก่อนการอัปเดต
    double currentOffset = _scrollController.offset;

    setState(() {
      likedQuotes[quoteId] = !isLiked;
      quotes[index]['Number_of_Like'] =
          isLiked ? currentLikes - 1 : currentLikes + 1;
    });

    // รีเฟรชรายการแล้วเลื่อนกลับไปยังตำแหน่งเดิม
    await Future.delayed(Duration(milliseconds: 100));
    _scrollController.jumpTo(currentOffset);

    final url = Uri.parse('$baseUrl/toggle_like.php');
    final response = await http.post(url, body: {
      'Quote_ID': quoteId,
      'User_ID': userId,
      'Like_Status': isLiked ? '0' : '1', // เปลี่ยนสถานะไลก์
    });

    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);

      print('Decoded response: $responseData');

      if (!responseData['success']) {
        if (responseData['like_status'] == 1) {
          setState(() {
            likedQuotes[quoteId] = true;
            quotes[index]['Number_of_Like'] = currentLikes;
          });
        } else {
          // ถ้าไม่ใช่ like_status 1 ให้ย้อนสถานะกลับ
          setState(() {
            likedQuotes[quoteId] = isLiked;
            quotes[index]['Number_of_Like'] = currentLikes;
          });
        }
      }
    } else {
      setState(() {
        likedQuotes[quoteId] = isLiked;
        quotes[index]['Number_of_Like'] = currentLikes;
      });
      print('Failed to connect. Status code: ${response.statusCode}');
    }
  }

  Widget _buildAddQuoteForm() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _isAddingQuote = false;
                });
              },
            ),
            SizedBox(width: 16),
            Text(
              'เพิ่ม Quote จากเรื่อง',
              style: GoogleFonts.kodchasan(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchBooks(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  List<DropdownMenuItem<String>> dropdownItems = [
                    DropdownMenuItem<String>(
                      value: '',
                      child: Text('กรุณาเลือกหนังสือ',
                          style: GoogleFonts.kodchasan(
                            fontSize: 14,
                          )),
                    ),
                  ];
                  if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                    List<Map<String, dynamic>> books = snapshot.data!;
                    dropdownItems.addAll(
                      books.map((book) {
                        return DropdownMenuItem<String>(
                          value: book['Book_ID'].toString(),
                          child: Text(
                            book['Book_Name'],
                            style: GoogleFonts.kodchasan(
                              fontSize: 14,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }

                  return DropdownButtonFormField<String>(
                    value: selectedBookId,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide(
                          color: Colors.pinkAccent,
                          width: 2,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50),
                        borderSide: BorderSide(
                          color: Colors.pinkAccent,
                          width: 2,
                        ),
                      ),
                    ),
                    items: dropdownItems,
                    onChanged: (value) {
                      setState(() {
                        selectedBookId = value;
                      });

                      if (value == '') {
                        print('กรุณาเลือกหนังสือ');
                      } else {
                        print('เลือกหนังสือ: $value');
                      }
                    },
                  );
                },
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'หน้า : ',
                    style: GoogleFonts.kodchasan(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    width: 50,
                    child: TextField(
                      controller: _pageController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.kodchasan(fontSize: 14),
                      decoration: InputDecoration(
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.pinkAccent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.pinkAccent,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'โควต : ',
                style: GoogleFonts.kodchasan(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _quoteController,
                maxLines: 4,
                style: GoogleFonts.kodchasan(
                    fontSize: 15, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.pinkAccent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.pinkAccent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isPrivate,
                    onChanged: (value) {
                      setState(() {
                        _isPrivate = value!;
                      });
                    },
                    activeColor: Colors.pinkAccent,
                  ),
                  Text(
                    'ส่วนตัว',
                    style: GoogleFonts.kodchasan(),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (_isEditing) {
                      _updateQuote(
                        _editingQuoteId!,
                        _quoteController.text,
                        _pageController.text,
                        _isPrivate,
                        selectedBookId,
                      );
                    } else {
                      _addQuote(
                        _quoteController.text,
                        _pageController.text,
                        _isPrivate,
                        selectedBookId,
                      ).then((_) {
                        setState(() {
                          _allQuotesFuture = _fetchAllQuotes();
                        });
                      });
                    }
                  },
                  child: Text(
                    _isEditing ? 'บันทึก' : 'เพิ่ม',
                    style: GoogleFonts.kodchasan(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent[100],
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserQuotes() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _userQuotesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text('ยังไม่มีโควต', style: GoogleFonts.kodchasan()),
          );
        }

        List<Map<String, dynamic>> quotes = snapshot.data!;
        return ListView.builder(
          controller: _scrollController,
          itemCount: quotes.length,
          itemBuilder: (context, index) {
            final quote = quotes[index];
            String quoteId = quote['Quote_ID'].toString();
            int currentLikes = quote['Number_of_Like'] ?? 0;

            bool isLiked = likedQuotes[quoteId] ?? false;

            bool isPrivateQuote = quote['Quote_Status'] == 1;

            return StatefulBuilder(
              builder: (context, setStateItem) {
                return Stack(
                  children: [
                    Card(
                      margin:
                          EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: Colors.pink.shade300,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(15),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${quote['Book_Name']} - หน้า ${quote['Page_of_Quote']}',
                                  style: GoogleFonts.kodchasan(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            SizedBox(height: 10),
                            Center(
                              child: Text(
                                '${quote['Quote_Detail']}',
                                style: GoogleFonts.kodchasan(fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                  ),
                                  color: Colors.red,
                                  onPressed: () {
                                    _toggleLike(
                                      quoteId,
                                      isLiked,
                                      currentLikes,
                                      index,
                                      quotes,
                                    );
                                  },
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '$currentLikes', // แสดงจำนวนไลก์
                                  style: GoogleFonts.kodchasan(fontSize: 14),
                                ),
                                Spacer(),
                                if (isPrivateQuote) // แสดงสถานะถ้าเป็นโควตส่วนตัว
                                  Text(
                                    'สถานะ: ส่วนตัว',
                                    style: GoogleFonts.kodchasan(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 18,
                      right: 20,
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert),
                        onSelected: (String result) {
                          if (result == 'edit') {
                            _editQuote(quote);
                          } else if (result == 'delete') {
                            _confirmDeleteQuote(quoteId);
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'edit',
                            child:
                                Text('แก้ไข', style: GoogleFonts.kodchasan()),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('ลบ', style: GoogleFonts.kodchasan()),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAllQuotes() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _allQuotesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text('ยังไม่มีโควต', style: GoogleFonts.kodchasan()),
          );
        }

        List<Map<String, dynamic>> quotes = snapshot.data!;

        _quoteKeys = List.generate(quotes.length, (index) => GlobalKey());

        return FutureBuilder<String?>(
          future: _getUserId(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            String? currentUserId = userSnapshot.data;

            print('Current User_ID: $currentUserId');

            return ListView.builder(
              controller: _scrollController,
              itemCount: quotes.length,
              itemBuilder: (context, index) {
                final quote = quotes[index];

                print('Quote User_ID: ${quote['User_ID']}');

                String quoteId = quote['Quote_ID'].toString();
                int currentLikes = quote['Number_of_Like'] ?? 0;

                // ตรวจสอบว่า Quote เป็นของผู้ใช้ปัจจุบันหรือไม่
                bool isUserQuote = currentUserId == quote['User_ID'].toString();

                String? userProfilePicture = quote['User_Picture'];

                return StatefulBuilder(
                  builder: (context, setStateItem) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BookDetailsScreen(
                              book: {
                                'Book_ID': quote['Book_ID'],
                                'Book_Name': quote['Book_Name'],
                                'Author': quote['Author'],
                                'Book_Picture': quote['Book_Picture'],
                                'ISBN': quote['ISBN'],
                                'Number_of_Page': quote['Number_of_Page'],
                                'Score': quote['Score'],
                                'Printed': quote['Printed'],
                                'Publisher': quote['Publisher'],
                                'Category': quote['Category'],
                              },
                            ),
                          ),
                        );
                      },
                      child: Card(
                        key: _quoteKeys[index],
                        margin:
                            EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: isUserQuote
                                      ? Colors.pink.shade300
                                      : Colors.blue.shade300,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(15),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${quote['Book_Name']} - หน้า ${quote['Page_of_Quote']}',
                                    style: GoogleFonts.kodchasan(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              SizedBox(height: 10),
                              Center(
                                child: Text(
                                  '${quote['Quote_Detail']}',
                                  style: GoogleFonts.kodchasan(fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      likedQuotes[quoteId] ?? false
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                    ),
                                    color: Colors.red,
                                    onPressed: () {
                                      _toggleLike(
                                        quoteId,
                                        likedQuotes[quoteId] ?? false,
                                        currentLikes,
                                        index,
                                        quotes,
                                      );
                                    },
                                  ),
                                  Text(
                                    '$currentLikes',
                                    style: GoogleFonts.kodchasan(fontSize: 14),
                                  ),
                                  Spacer(),
                                  if (userProfilePicture != null)
                                    CircleAvatar(
                                      backgroundImage:
                                          NetworkImage(userProfilePicture),
                                      radius: 15,
                                    ),
                                  SizedBox(width: 8),
                                  Text(
                                    '${quote['User_Name']}',
                                    style: GoogleFonts.kodchasan(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.pinkAccent,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMyQuotesTab() {
    if (_isAddingQuote) {
      return _buildAddQuoteForm();
    } else {
      return Stack(
        children: [
          _buildUserQuotes(),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  _isAddingQuote = true;
                  _isEditing = false; // รีเซ็ตสถานะแก้ไข
                  _quoteController.clear(); // เคลียร์ฟิลด์
                  _pageController.clear();
                  selectedBookId = ''; // รีเซ็ตการเลือกหนังสือ
                  _isPrivate = false; // รีเซ็ตสถานะเป็นโควตสาธารณะ
                });
              },
              child: Icon(Icons.add),
              backgroundColor: Colors.pinkAccent[100],
              shape: CircleBorder(),
            ),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Quotes',
            style: GoogleFonts.kodchasan(
                color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Color.fromARGB(255, 254, 176, 216),
          actions: [
            IconButton(
              icon: Icon(Icons.filter_list, color: Colors.black),
              onPressed: () {
                _showCategoryFilterDialog();
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(50.0),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorPadding:
                  EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              tabs: [
                Tab(
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'โควต',
                      style: GoogleFonts.kodchasan(
                          color: Colors.black, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                Tab(
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'โควตของฉัน',
                      style: GoogleFonts.kodchasan(
                          color: Colors.black, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAllQuotes(),
            _buildMyQuotesTab(),
          ],
        ),
      ),
    );
  }
}
