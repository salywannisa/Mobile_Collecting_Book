import 'dart:convert';
import 'package:collecting_book/bottom_navigation_bar.dart';
import 'package:collecting_book/screens/book_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';
import 'login_screen.dart';

class BookshelfScreen extends StatefulWidget {
  @override
  _BookshelfScreenState createState() => _BookshelfScreenState();
}

class WeeklyStat {
  final String day;
  final int readingTime;

  WeeklyStat(this.day, this.readingTime);
}

class _BookshelfScreenState extends State<BookshelfScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<bool>? _loginStatusFuture;
  Future<List<Map<String, dynamic>>>? _bookshelvesFuture;
  Future<List<Map<String, dynamic>>>? _categoriesFuture;
  Future<List<Map<String, dynamic>>>? _userBooksFuture;
  final TextEditingController _bookNameController = TextEditingController();
  final TextEditingController _editBookNameController = TextEditingController();
  String _searchQuery = '';
  String? selectedCategoryId;

  Map<String, dynamic>? _selectedBookshelf;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _loginStatusFuture = _checkLoginStatus();
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        _loginStatusFuture?.then((isLoggedIn) {
          if (!isLoggedIn) {
            _tabController.animateTo(0);
            _showLoginAlert();
          } else {
            _userBooksFuture = _fetchUserBooks();
          }
        });
      }
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loginStatusFuture?.then((isLoggedIn) {
        if (!isLoggedIn) {
          _showLoginAlert();
        }
      });
    });

    _bookshelvesFuture = _fetchBookshelves();
    _categoriesFuture = _fetchCategories();
  }

  Future<bool> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');
    return userId != null && userId.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> _fetchBookshelves() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    if (userId == null) {
      return [];
    }

    final url = Uri.parse('$baseUrl/bookshelves.php');
    final response = await http.post(url, body: {
      'action': 'get',
      'User_ID': userId,
    });

    if (response.statusCode == 200) {
      if (response.body.isNotEmpty) {
        try {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            List<Map<String, dynamic>> bookshelves =
                List<Map<String, dynamic>>.from(responseData['data']);
            return bookshelves;
          } else {
            print('Failed to fetch bookshelves: ${responseData['error']}');
            return [];
          }
        } catch (e) {
          print('Error decoding JSON: $e');
          print('Response body: ${response.body}');
          return [];
        }
      } else {
        print('Response body is empty');
        return [];
      }
    } else {
      print('Failed to fetch bookshelves. Status code: ${response.statusCode}');
      return [];
    }
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

  Future<List<Map<String, dynamic>>> _fetchBooksInBookshelf(
      String bookshelfId, String? categoryId) async {
    final url = Uri.parse('$baseUrl/books_on_bookshelf.php');
    final response = await http.post(url, body: {
      'Bookshelf_ID': bookshelfId,
      'Category_ID': categoryId ?? '', // ส่ง Category_ID ถ้ามี
    });

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

  Future<void> addBookshelf(String name) async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    if (userId == null) {
      print('User not logged in');
      return;
    }
    // ดึงรายชื่อชั้นหนังสือที่มีอยู่เพื่อตรวจสอบว่าชื่อซ้ำกันหรือไม่
    final currentBookshelves = await _fetchBookshelves();

    // ตรวจสอบว่าชั้นหนังสือที่เพิ่มมามีชื่อซ้ำกันหรือไม่
    bool isDuplicate = currentBookshelves.any((bookshelf) =>
        bookshelf['Bookshelf_Name'].toString().toLowerCase() ==
        name.toLowerCase());

    if (isDuplicate) {
      _showErrorDialog(
          'ไม่สามารถเพิ่มชั้นหนังสือได้', 'ชั้นหนังสือชื่อนี้มีอยู่แล้ว');
      return;
    }

    final url = Uri.parse('$baseUrl/bookshelves.php');
    final response = await http.post(url, body: {
      'action': 'add',
      'User_ID': userId,
      'Bookshelf_Name': name,
    });

    if (response.statusCode == 200) {
      if (response.body.isNotEmpty) {
        try {
          final responseData = json.decode(response.body);
          if (responseData['success']) {
            print('Bookshelf added successfully');
            setState(() {
              _bookshelvesFuture = _fetchBookshelves();
            });
          } else {
            print('Failed to add bookshelf: ${responseData['error']}');
          }
        } catch (e) {
          print('Error decoding JSON: $e');
          print('Response body: ${response.body}');
        }
      } else {
        print('Response body is empty');
      }
    } else {
      print('Failed to add bookshelf. Status code: ${response.statusCode}');
    }
  }

  Future<void> _editBookshelf(String bookshelfId, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    if (userId == null) {
      print('User not logged in');
      return;
    }

    final url = Uri.parse('$baseUrl/bookshelves.php');
    final response = await http.post(url, body: {
      'action': 'rename',
      'User_ID': userId,
      'Bookshelf_ID': bookshelfId,
      'New_Name': newName,
    });

    if (response.statusCode == 200) {
      if (response.body.isNotEmpty) {
        try {
          final responseData = json.decode(response.body);
          if (responseData['success']) {
            print('Bookshelf renamed successfully');
            setState(() {
              _bookshelvesFuture = _fetchBookshelves();
            });
          } else {
            print('Failed to rename bookshelf: ${responseData['error']}');
          }
        } catch (e) {
          print('Error decoding JSON: $e');
          print('Response body: ${response.body}');
        }
      } else {
        print('Response body is empty');
      }
    } else {
      print('Failed to rename bookshelf. Status code: ${response.statusCode}');
    }
  }

  Future<void> _deleteBookshelf(String userId, String bookshelfId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bookshelves.php'),
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: {
        'action': 'delete',
        'User_ID': userId,
        'Bookshelf_ID': bookshelfId,
      },
    );

    if (response.statusCode == 200) {
      if (response.body.isNotEmpty) {
        try {
          var jsonResponse = jsonDecode(response.body);
          if (jsonResponse['success']) {
            print('ลบชั้นหนังสือสำเร็จ');
            setState(() {
              _bookshelvesFuture = _fetchBookshelves();
            });
          } else {
            if (jsonResponse['error'] ==
                'ไม่สามารถลบชั้นหนังสือได้ เนื่องจากมีหนังสืออยู่ในชั้นนี้') {
              _showCannotDeleteBookshelfDialog();
            } else {
              print('Error: ${jsonResponse['error']}');
            }
          }
        } catch (e) {
          print('Error parsing JSON: $e');
        }
      } else {
        print('Response body is empty');
      }
    } else {
      print('Request failed with status: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserBooks(
      {String? searchQuery, String? categoryId}) async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    if (userId == null) {
      return [];
    }

    final url = Uri.parse('$baseUrl/user_books.php');
    final response = await http.post(url, body: {
      'User_ID': userId,
      'search': searchQuery ?? '', // ส่ง searchQuery ถ้ามี
      'Category_ID': categoryId ?? '' // ส่ง Category_ID ถ้ามี
    });

    if (response.statusCode == 200) {
      if (response.body.isNotEmpty) {
        try {
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            List<Map<String, dynamic>> books =
                List<Map<String, dynamic>>.from(responseData['data']);
            return books;
          } else {
            print('Failed to fetch user books: ${responseData['error']}');
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
      print('Failed to fetch user books. Status code: ${response.statusCode}');
      return [];
    }
  }

  Future<bool> _checkPages(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    if (userId == null) {
      print('User_ID is null');
      return false;
    }

    final url = Uri.parse('$baseUrl/check_pages.php');

    final response = await http.post(
      url,
      body: {
        'Book_ID': bookId.toString(),
        'User_ID': userId.toString(),
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      print('Response Data: $responseData');

      if (responseData['success']) {
        int numberOfPages =
            int.tryParse(responseData['Number_of_Page'].toString()) ?? 0;
        int pageReadTo =
            int.tryParse(responseData['Page_read_to'].toString()) ?? 0;

        print('Number_of_Page: $numberOfPages, Page_read_to: $pageReadTo');

        // เปรียบเทียบค่า Number_of_Page และ Page_read_to
        return numberOfPages == pageReadTo;
      } else {
        print('Request failed: ${responseData['error']}');
      }
    } else {
      print('Server error with status code: ${response.statusCode}');
    }

    return false;
  }

  void _onBookshelfSelected(Map<String, dynamic> bookshelf) {
    setState(() {
      _selectedBookshelf = bookshelf;
    });
  }

  void _showLoginAlert() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Color.fromARGB(255, 255, 178, 251),
              width: 2,
            ),
          ),
          title: Center(child: Text('กรุณาลงชื่อเข้าใช้งาน')),
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
                child: Text('เข้าสู่ระบบ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: BorderSide(
                    color: Color.fromARGB(255, 255, 178, 251),
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

  void _showAddBookshelfDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: Colors.pinkAccent,
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(20.0),
          ),
          title: Text(
            'เพิ่มชั้นหนังสือใหม่',
            style: GoogleFonts.kodchasan(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: _bookNameController,
            decoration: InputDecoration(
              labelText: 'ชื่อ',
              labelStyle: GoogleFonts.kodchasan(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ),
          actions: <Widget>[
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
                if (_bookNameController.text.trim().isNotEmpty) {
                  addBookshelf(_bookNameController.text.trim());
                  _bookNameController.clear();
                  Navigator.of(context).pop();
                } else {
                  _showErrorDialog(
                      'ไม่สามารถสร้างชั้นหนังสือได้', 'โปรดใส่ชื่อชั้นหนังสือ');
                }
              },
              child: Text(
                'เพิ่ม',
                style: GoogleFonts.kodchasan(
                  color: Colors.pinkAccent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: GoogleFonts.kodchasan(fontSize: 20),
          ),
          content: Text(
            message,
            style: GoogleFonts.kodchasan(),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.pinkAccent,
              width: 2,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
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
  }

  void _showEditBookshelfDialog(String bookshelfId, String oldName) {
    _editBookNameController.text = oldName;

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
            'เปลี่ยนชื่อชั้นหนังสือ',
            style: GoogleFonts.kodchasan(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: _editBookNameController,
            decoration: InputDecoration(
              labelText: 'ชื่อใหม่',
              labelStyle: GoogleFonts.kodchasan(
                fontSize: 16,
                color: Colors.black54,
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.pinkAccent),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.pinkAccent),
              ),
            ),
          ),
          actions: <Widget>[
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
                if (_editBookNameController.text.isNotEmpty) {
                  _editBookshelf(
                      bookshelfId.toString(), _editBookNameController.text);
                  _editBookNameController.clear();
                  Navigator.of(context).pop();
                } else {
                  print('กรุณากรอกชื่อชั้นหนังสือใหม่');
                }
              },
              child: Text(
                'เปลี่ยนชื่อ',
                style: GoogleFonts.kodchasan(
                  color: Colors.pinkAccent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteBookshelfDialog(String bookshelfId) {
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
            'ยืนยันการลบ',
            style: GoogleFonts.kodchasan(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'คุณแน่ใจหรือไม่ว่าต้องการลบชั้นหนังสือนี้?',
            style: GoogleFonts.kodchasan(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          actions: <Widget>[
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
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                String? userId = prefs.getString('User_ID');
                if (userId != null) {
                  _deleteBookshelf(userId, bookshelfId.toString());
                }
                Navigator.of(context).pop();
              },
              child: Text(
                'ลบ',
                style: GoogleFonts.kodchasan(
                  color: Colors.pinkAccent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCannotDeleteBookshelfDialog() {
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
            'ไม่สามารถลบได้',
            style: GoogleFonts.kodchasan(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'เนื่องจากมีหนังสืออยู่ในชั้นนี้',
            style: GoogleFonts.kodchasan(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'ตกลง',
                style: GoogleFonts.kodchasan(
                  // ฟอนต์สำหรับปุ่ม
                  color: Colors.pinkAccent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCategoryFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _categoriesFuture, // ดึงข้อมูลหมวดหมู่
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                      child: Text('ไม่มีหมวดหมู่',
                          style: GoogleFonts.kodchasan()));
                }

                List<Map<String, dynamic>> categories = snapshot.data!;

                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.0),
                    side: BorderSide(
                      color: Colors.pinkAccent,
                      width: 2.0,
                    ),
                  ),
                  title: Text(
                    'กรองหมวดหมู่หนังสือ',
                    style: GoogleFonts.kodchasan(
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
                            groupValue: selectedCategoryId,
                            activeColor: Colors.pinkAccent,
                            onChanged: (String? value) {
                              setStateDialog(() {
                                selectedCategoryId = value;
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
                              selectedCategoryId = value;
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
                          _userBooksFuture = _fetchUserBooks(
                            searchQuery: _searchQuery,
                            categoryId: selectedCategoryId,
                          );
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

  void _showMoveDialog(Map<String, dynamic> book) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // กำหนด selectedBookshelf เป็น ID ของชั้นหนังสือปัจจุบัน
        String? selectedBookshelf = book['Current_Bookshelf_ID']
            ?.toString(); // หรือเปลี่ยนให้ตรงตามที่คุณเก็บ ID ชั้นหนังสือปัจจุบัน

        // ปริ้นค่าของ selectedBookshelf
        print("Current Bookshelf ID: $selectedBookshelf");

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchBookshelves(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                  side: BorderSide(
                    color: Colors.pinkAccent,
                    width: 2.0,
                  ),
                ),
                title: Text(
                  'ไม่พบชั้นหนังสือ',
                  style: GoogleFonts.kodchasan(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'ปิด',
                      style: GoogleFonts.kodchasan(
                        color: Colors.pinkAccent,
                      ),
                    ),
                  ),
                ],
              );
            }

            List<Map<String, dynamic>> bookshelves = snapshot.data!;

            // ปริ้นค่าของ bookshelves
            print("Bookshelves: $bookshelves");

            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(
                      color: Colors.pinkAccent,
                      width: 2.0,
                    ),
                  ),
                  title: Text(
                    'เปลี่ยนชั้นหนังสือ',
                    style: GoogleFonts.kodchasan(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: bookshelves.map((bookshelf) {
                      return RadioListTile<String>(
                        title: Text(
                          bookshelf['Bookshelf_Name'],
                          style: GoogleFonts.kodchasan(),
                        ),
                        value: bookshelf['Bookshelf_ID'].toString(),
                        groupValue:
                            selectedBookshelf, // ใช้ selectedBookshelf เป็น groupValue
                        activeColor: Colors.pinkAccent,
                        onChanged: (String? value) {
                          setState(() {
                            selectedBookshelf =
                                value; // เปลี่ยนค่า selectedBookshelf
                          });
                          // ปริ้นค่าที่เลือก
                          print("Selected Bookshelf ID: $selectedBookshelf");
                        },
                      );
                    }).toList(),
                  ),
                  actions: <Widget>[
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
                        if (selectedBookshelf != null) {
                          Navigator.of(context).pop();
                          _confirmMoveBook(book, selectedBookshelf);
                          // ปริ้นค่าเมื่อย้ายหนังสือ
                          print(
                              "Moving book ${book['Book_Name']} to bookshelf ID: $selectedBookshelf");
                        }
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

  void _confirmMoveBook(Map<String, dynamic> book, String? selectedBookshelf) {
    if (selectedBookshelf == null) {
      print('เลือกชั้นหนังสือก่อน');
      return;
    }

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
            'ยืนยันการย้ายหนังสือ',
            style: GoogleFonts.kodchasan(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'คุณต้องการย้ายหนังสือใช่มั้ย?',
            style: GoogleFonts.kodchasan(
              fontSize: 16,
            ),
          ),
          actions: <Widget>[
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
                _moveBookToBookshelf(book,
                    selectedBookshelf); // ย้ายหนังสือไปชั้นหนังสือที่เลือก
                Navigator.of(context).pop();
                _showSuccessDialog(); // แสดงป๊อปอัพยืนยันการย้ายสำเร็จ
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
  }

// ฟังก์ชันนี้ใช้เพื่อแสดงป๊อปอัพยืนยันการย้ายสำเร็จ
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
            'ย้ายหนังสือสำเร็จ',
            style: GoogleFonts.kodchasan(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'หนังสือถูกย้ายไปยังชั้นที่เลือกแล้ว',
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
              },
            ),
          ],
        );
      },
    );
  }

  // ฟังก์ชันสำหรับการย้ายหนังสือ
  void _moveBookToBookshelf(
      Map<String, dynamic> book, String? selectedBookshelf) async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    if (userId == null || selectedBookshelf == null) {
      print('ข้อมูลไม่ครบถ้วน');
      return;
    }

    final url = Uri.parse('$baseUrl/move_book.php');
    final response = await http.post(url, body: {
      'Book_ID': book['Book_ID'].toString(),
      'New_Bookshelf_ID': selectedBookshelf,
      'User_ID': userId,
    });

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['status'] == 'success') {
        print('ย้ายหนังสือเรียบร้อยแล้ว');
        setState(() {
          _bookshelvesFuture = _fetchBookshelves();
        });
      } else {
        print('เกิดข้อผิดพลาด: ${responseData['message']}');
      }
    } else {
      print('เกิดข้อผิดพลาดในการสื่อสารกับเซิร์ฟเวอร์');
    }
  }

  // ฟังก์ชันสำหรับการลบหนังสือ
  void _confirmDeleteBook(Map<String, dynamic> book) {
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
            'ยืนยันการลบ',
            style: GoogleFonts.kodchasan(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.pinkAccent,
            ),
          ),
          content: Text(
            'คุณแน่ใจหรือว่าต้องการลบหนังสือเล่มนี้?',
            style: GoogleFonts.kodchasan(fontSize: 16),
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
              onPressed: () async {
                Navigator.of(context).pop();
                // เรียกใช้ _deleteBook และแสดงป๊อปอัพยืนยันการลบเมื่อสำเร็จ
                await _deleteBook(book);
              },
            ),
          ],
        );
      },
    );
  }

// ฟังก์ชันนี้ใช้เพื่อแสดงป๊อปอัพยืนยันการลบสำเร็จ
  void _showDeleteSuccessDialog() {
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
            'ลบหนังสือสำเร็จ',
            style: GoogleFonts.kodchasan(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.pinkAccent),
          ),
          content: Text(
            'หนังสือเล่มนี้ถูกลบเรียบร้อยแล้ว',
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
              },
            ),
          ],
        );
      },
    );
  }

  // ฟังก์ชันที่ใช้ในการลบหนังสือ
  Future<void> _deleteBook(Map<String, dynamic> book) async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');
    String? bookshelfId = _selectedBookshelf?['Bookshelf_ID'].toString();

    if (userId == null || bookshelfId == null) {
      print('ข้อมูลไม่ครบถ้วน');
      return;
    }

    final url = Uri.parse('$baseUrl/move_book.php');
    final response = await http.post(url, body: {
      'Book_ID': book['Book_ID'].toString(),
      'Bookshelf_ID': bookshelfId,
      'User_ID': userId,
      'action': 'delete',
    });

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['status'] == 'success') {
        print('ลบหนังสือเรียบร้อยแล้ว');
        setState(() {
          _bookshelvesFuture = _fetchBookshelves();
        });
        _showDeleteSuccessDialog(); // แสดงป๊อปอัพการลบสำเร็จ
      } else if (responseData['message'] ==
          'หนังสือเล่มนี้มีการโควตไว้ ไม่สามารถลบได้') {
        _showCannotDeleteBookPopup();
      } else {
        print('เกิดข้อผิดพลาด: ${responseData['message']}');
      }
    } else {
      print('เกิดข้อผิดพลาดในการสื่อสารกับเซิร์ฟเวอร์');
    }
  }

  void _showCannotDeleteBookPopup() {
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
            'ไม่สามารถลบได้',
            style: GoogleFonts.kodchasan(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.pinkAccent,
            ),
          ),
          content: Text(
            'หนังสือเล่มนี้มีการโควตไว้ ไม่สามารถลบได้',
            style: GoogleFonts.kodchasan(fontSize: 16),
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

  // ฟังก์ชันสำหรับการอ่านหนังสือ
  void _readBook(Map<String, dynamic> book) {
    print("Book_ID ที่ถูกส่งไปยัง FocusScreen: ${book['Book_ID'].toString()}");

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          initialTabIndex: 1,
          selectedBook: book['Book_ID'].toString(),
        ),
      ),
      (Route<dynamic> route) => false,
    );
  }

  void _rateBook(Map<String, dynamic> book) async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    if (userId == null || userId.isEmpty) {
      print("User not logged in or User_ID is empty");
      return;
    }

    String bookId = book['Book_ID'].toString();

    if (bookId.isEmpty) {
      print("Book_ID is empty");
      return;
    }

    // ตรวจสอบว่าอ่านหนังสือจบหรือยัง
    final hasFinishedReading = await _checkPages(bookId);
    if (!hasFinishedReading) {
      print("User has not finished reading this book yet.");
      return;
    }

    // ตรวจสอบว่าผู้ใช้ให้คะแนนแล้วหรือยัง
    final result = await _checkIfRated(bookId);
    final bool hasRated = result['hasRated'] ?? false;

    if (hasRated) {
      print("User has already rated this book.");
      return;
    }

    // แสดง dialog ให้คะแนน
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int _rating = 0;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(
              color: Colors.pinkAccent,
              width: 2.0,
            ),
          ),
          title: Text(
            'ให้คะแนนหนังสือ',
            style: GoogleFonts.kodchasan(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.pinkAccent,
            ),
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return IconButton(
                    iconSize: 30.0,
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                  );
                }),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _saveRating(bookId, _rating, userId);

                setState(() {});
              },
              child: Text(
                'ส่ง',
                style: GoogleFonts.kodchasan(
                  color: Colors.pinkAccent,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveRating(String bookId, int rating, String userId) async {
    String currentDate = DateTime.now().toIso8601String();
    final url = Uri.parse('$baseUrl/rate_book.php');
    final response = await http.post(url, body: {
      'Book_ID': bookId,
      'Rating': rating.toString(),
      'User_ID': userId,
      'Date_Review': currentDate,
    });

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      print('Response data from rating: $responseData');

      if (responseData['success']) {
        print('Rating saved successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'คุณได้ให้คะแนนหนังสือเรียบร้อยแล้ว',
              style: GoogleFonts.kodchasan(
                fontSize: 14, // ขนาดฟอนต์
                color: Colors.white, // สีฟอนต์
              ),
            ),
          ),
        );
      } else {
        print('Failed to save rating: ${responseData['error']}');
      }
    } else {
      print('Failed to save rating. Status code: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> _checkIfRated(String? bookId) async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    print('Received Book_ID: $bookId');
    print('Received User_ID from SharedPreferences: $userId');

    if (bookId == null || bookId.isEmpty || userId == null || userId.isEmpty) {
      return {'hasRated': false, 'score': null};
    }

    try {
      final url = Uri.parse('$baseUrl/check_rating.php');
      final response = await http.post(url, body: {
        'Book_ID': bookId,
        'User_ID': userId,
      });

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        print('Response data from server: $responseData');

        print('Score received from server: ${responseData['score']}');

        return {
          'hasRated': responseData['hasRated'],
          'score': responseData['score']
        };
      } else {
        print(
            'Error checking rating status. Status code: ${response.statusCode}');
        return {'hasRated': false, 'score': null};
      }
    } catch (error) {
      print('Error occurred: $error');
      return {'hasRated': false, 'score': null};
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'ชั้นสะสม',
            style: GoogleFonts.kodchasan(
              fontWeight: FontWeight.w500,
            ),
          ),
          centerTitle: true,
          backgroundColor: Color.fromARGB(255, 254, 176, 216),
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
                      'ชั้นหนังสือ',
                      style: GoogleFonts.kodchasan(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Tab(
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      'หนังสือทั้งหมด',
                      style: GoogleFonts.kodchasan(
                        color: Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: FutureBuilder<bool>(
          future: _loginStatusFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            bool isLoggedIn = snapshot.data ?? false;

            return TabBarView(
              controller: _tabController,
              children: [
                _selectedBookshelf == null
                    ? Center(
                        child: isLoggedIn
                            ? FutureBuilder<List<Map<String, dynamic>>>(
                                future: _bookshelvesFuture,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return CircularProgressIndicator();
                                  }

                                  if (!snapshot.hasData ||
                                      snapshot.data!.isEmpty) {
                                    return Text(
                                      'ไม่มีชั้นหนังสือ',
                                      style: GoogleFonts.kodchasan(),
                                    );
                                  }

                                  List<Map<String, dynamic>> bookshelves =
                                      snapshot.data!;

                                  return ListView.builder(
                                    itemCount: bookshelves.length,
                                    itemBuilder: (context, index) {
                                      final bookshelf = bookshelves[index];
                                      return Container(
                                        margin: EdgeInsets.symmetric(
                                            vertical: 8.0, horizontal: 16.0),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          color: Colors.white,
                                          border: Border.all(
                                              color: Color.fromARGB(
                                                  255, 217, 217, 217),
                                              width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.grey.withOpacity(0.2),
                                              spreadRadius: 1,
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ListTile(
                                          title: Text(
                                              '${bookshelf['Bookshelf_Name']} (${bookshelf['Book_Count']})',
                                              style: GoogleFonts.kodchasan()),
                                          onTap: () {
                                            _onBookshelfSelected(bookshelf);
                                          },
                                          trailing: PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _showEditBookshelfDialog(
                                                    bookshelf['Bookshelf_ID']
                                                        .toString(),
                                                    bookshelf[
                                                        'Bookshelf_Name']);
                                              } else if (value == 'delete') {
                                                _showDeleteBookshelfDialog(
                                                    bookshelf['Bookshelf_ID']
                                                        .toString());
                                              }
                                            },
                                            itemBuilder:
                                                (BuildContext context) {
                                              return [
                                                PopupMenuItem<String>(
                                                  value: 'edit',
                                                  child: Text('เปลี่ยนชื่อ',
                                                      style: GoogleFonts
                                                          .kodchasan()),
                                                ),
                                                PopupMenuItem<String>(
                                                  value: 'delete',
                                                  child: Text('ลบ',
                                                      style: GoogleFonts
                                                          .kodchasan()),
                                                ),
                                              ];
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              )
                            : Text('กรุณาลงชื่อเข้าใช้งานเพื่อดูชั้นหนังสือ',
                                style: GoogleFonts.kodchasan()))
                    : _buildBooksInBookshelfView(),
                !isLoggedIn
                    ? Center(
                        child: Text(
                            'กรุณาลงชื่อเข้าใช้งานเพื่อดูหนังสือทั้งหมด',
                            style: GoogleFonts.kodchasan()))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 0, right: 5, bottom: 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // ส่วนแสดงจำนวนหนังสือทั้งหมด
                                Padding(
                                  padding: const EdgeInsets.only(left: 16.0),
                                  child:
                                      FutureBuilder<List<Map<String, dynamic>>>(
                                    future: _userBooksFuture,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return Text(
                                          'กำลังโหลด...',
                                          style: GoogleFonts.kodchasan(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      }

                                      if (!snapshot.hasData ||
                                          snapshot.data!.isEmpty) {
                                        return Text(
                                          'ไม่มีหนังสือ',
                                          style: GoogleFonts.kodchasan(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      }

                                      int bookCount = snapshot.data!
                                          .length; // ดึงจำนวนหนังสือทั้งหมด

                                      return Text(
                                        'หนังสือทั้งหมด: $bookCount เล่ม',
                                        style: GoogleFonts.kodchasan(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // ปุ่มกรอง
                                IconButton(
                                  icon: Icon(Icons.filter_list),
                                  onPressed: () {
                                    _showCategoryFilterDialog();
                                  },
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            color: Colors.pinkAccent,
                            height: 20,
                            thickness: 2,
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: TextField(
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                  _userBooksFuture = _fetchUserBooks(
                                    searchQuery: _searchQuery,
                                    categoryId: selectedCategoryId,
                                  );
                                });
                              },
                              decoration: InputDecoration(
                                hintText:
                                    'ชื่อหนังสือ, ชื่อผู้แต่ง, ชื่อสำนักพิมพ์',
                                hintStyle: GoogleFonts.kodchasan(
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 12.0,
                                  horizontal: 20.0,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Colors.pinkAccent),
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Colors.pinkAccent),
                                  borderRadius: BorderRadius.circular(30.0),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: FutureBuilder<List<Map<String, dynamic>>>(
                              future: _userBooksFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                      child: CircularProgressIndicator());
                                }

                                if (!snapshot.hasData ||
                                    snapshot.data!.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'ไม่มีหนังสือในฐานข้อมูล',
                                      style: GoogleFonts.kodchasan(),
                                    ),
                                  );
                                }

                                List<Map<String, dynamic>> books =
                                    snapshot.data!;

                                return ListView.builder(
                                  itemCount: books.length,
                                  itemBuilder: (context, index) {
                                    final book = books[index];
                                    return ListTile(
                                      leading: book['Book_Picture'] != null
                                          ? Image.network(
                                              book['Book_Picture'],
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                            )
                                          : Icon(Icons.book),
                                      title: Text(
                                        book['Book_Name'],
                                        style: GoogleFonts.kodchasan(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(
                                        book['Author'],
                                        style: GoogleFonts.kodchasan(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      trailing:
                                          FutureBuilder<Map<String, dynamic>>(
                                        future: _checkIfRated(book['Book_ID']
                                            .toString()), // เช็คว่าผู้ใช้ให้คะแนนหรือยัง
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return CircularProgressIndicator();
                                          }

                                          if (snapshot.hasError) {
                                            return Text(
                                                'Error: ${snapshot.error}');
                                          }

                                          if (snapshot.hasData) {
                                            final hasRated =
                                                snapshot.data!['hasRated'] ??
                                                    false;

                                            // เรียกใช้ _checkPages เพื่อดูว่าผู้ใช้อ่านจบหรือยัง
                                            return FutureBuilder<bool>(
                                              future: _checkPages(book[
                                                      'Book_ID']
                                                  .toString()), // เช็คว่าผู้ใช้อ่านจบหรือยัง
                                              builder: (context,
                                                  checkPagesSnapshot) {
                                                if (checkPagesSnapshot
                                                        .connectionState ==
                                                    ConnectionState.waiting) {
                                                  return CircularProgressIndicator();
                                                }

                                                if (checkPagesSnapshot
                                                    .hasError) {
                                                  return Text(
                                                      'Error: ${checkPagesSnapshot.error}');
                                                }

                                                final hasFinishedReading =
                                                    checkPagesSnapshot.data ??
                                                        false;

                                                // ซ่อนปุ่ม "ให้คะแนน" หากผู้ใช้ให้คะแนนแล้วหรือยังอ่านไม่จบ
                                                if (hasRated ||
                                                    !hasFinishedReading) {
                                                  return SizedBox
                                                      .shrink(); // ซ่อนปุ่ม
                                                }

                                                // แสดงปุ่ม "ให้คะแนน" หากผู้ใช้ยังไม่ได้ให้คะแนนและอ่านจบแล้ว
                                                return TextButton(
                                                  onPressed: () {
                                                    _rateBook(book);
                                                  },
                                                  child: Text(
                                                    'ให้คะแนน',
                                                    style:
                                                        GoogleFonts.kodchasan(
                                                      color: Colors.pinkAccent,
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          }

                                          return SizedBox.shrink();
                                        },
                                      ),
                                      onTap: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                BookDetailsScreen(
                                              book: book,
                                              fromBookshelfPage: true,
                                            ),
                                          ),
                                        );

                                        if (result == true) {
                                          setState(() {
                                            _bookshelvesFuture =
                                                _fetchBookshelves();
                                          });
                                        }
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ],
            );
          },
        ),
        floatingActionButton: (_tabController.index == 0 &&
                _selectedBookshelf == null)
            ? FutureBuilder<bool>(
                future: _loginStatusFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SizedBox
                        .shrink(); // ไม่แสดงปุ่มขณะรอผลการตรวจสอบสถานะการเข้าสู่ระบบ
                  }

                  bool isLoggedIn = snapshot.data ?? false;

                  return isLoggedIn
                      ? FloatingActionButton(
                          onPressed: () {
                            _showAddBookshelfDialog();
                          },
                          child: Icon(Icons.add),
                          backgroundColor: Colors.pinkAccent[100],
                          tooltip: 'เพิ่มชั้นหนังสือ',
                          shape: CircleBorder(),
                        )
                      : SizedBox.shrink(); // ซ่อนปุ่มถ้ายังไม่ได้เข้าสู่ระบบ
                },
              )
            : null, // ซ่อนปุ่มเมื่ออยู่ในแท็บอื่น
      ),
    );
  }

  Widget _buildBooksInBookshelfView() {
    return Stack(
      children: [
        Column(
          children: [
            ListTile(
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedBookshelf = null;
                  });
                },
              ),
              title: Text(
                _selectedBookshelf!['Bookshelf_Name'],
                style: GoogleFonts.kodchasan(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              trailing: IconButton(
                icon: Icon(Icons.filter_list),
                onPressed: () {
                  _showCategoryFilterDialog();
                },
              ),
            ),
            Divider(
              color: Colors.pinkAccent,
              height: 20,
              thickness: 2,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'ชื่อหนังสือ, ชื่อผู้แต่ง, ชื่อสำนักพิมพ์',
                  hintStyle: GoogleFonts.kodchasan(
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide(
                      color: Colors.pinkAccent,
                    ),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.pinkAccent),
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.pinkAccent),
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchBooksInBookshelf(
                    _selectedBookshelf!['Bookshelf_ID'].toString(),
                    selectedCategoryId ?? ''),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                        child: Text(
                      'ไม่มีหนังสือในชั้นหนังสือนี้',
                      style: GoogleFonts.kodchasan(),
                    ));
                  }

                  List<Map<String, dynamic>> books = snapshot.data!;

                  List<Map<String, dynamic>> filteredBooks =
                      books.where((book) {
                    final bookName = book['Book_Name']?.toLowerCase() ?? '';
                    final authorName = book['Author']?.toLowerCase() ?? '';
                    final isbn = book['ISBN']?.toLowerCase() ?? '';
                    final publisherName =
                        book['Publisher_Name']?.toLowerCase() ?? '';

                    return bookName.contains(_searchQuery) ||
                        authorName.contains(_searchQuery) ||
                        isbn.contains(
                            _searchQuery) || // เพิ่มเงื่อนไขการค้นหา ISBN
                        publisherName.contains(
                            _searchQuery); // เพิ่มเงื่อนไขการค้นหาสำนักพิมพ์
                  }).toList();

                  return ListView.builder(
                    itemCount: filteredBooks.length,
                    itemBuilder: (context, index) {
                      final book = filteredBooks[index];
                      return ListTile(
                        leading: book['Book_Picture'] != null
                            ? Image.network(
                                book['Book_Picture'],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : Icon(Icons.book),
                        title: Text(
                          book['Book_Name'],
                          style: GoogleFonts.kodchasan(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          book['Author'],
                          style: GoogleFonts.kodchasan(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'move') {
                              _showMoveDialog(book);
                            } else if (value == 'delete') {
                              _confirmDeleteBook(book);
                            } else if (value == 'read') {
                              _readBook(book);
                            }
                          },
                          itemBuilder: (BuildContext context) {
                            return [
                              PopupMenuItem<String>(
                                value: 'move',
                                child: Text(
                                  'ย้าย',
                                  style: GoogleFonts.kodchasan(),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text(
                                  'ลบ',
                                  style: GoogleFonts.kodchasan(),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'read',
                                child: Text(
                                  'อ่านหนังสือ',
                                  style: GoogleFonts.kodchasan(),
                                ),
                              ),
                            ];
                          },
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BookDetailsScreen(
                                  book: book, fromBookshelfPage: true),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
