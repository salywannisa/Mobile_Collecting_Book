import 'dart:async';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';
import 'package:collecting_book/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:wakelock/wakelock.dart';

class FocusScreen extends StatefulWidget {
  final int initialTabIndex;
  final String selectedBook;

  FocusScreen({required this.initialTabIndex, required this.selectedBook});

  _FocusScreenState createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _timer;
  DateTime? _startTime;
  int _seconds = 0;
  int Points = 0;
  int? goalTime;
  int initialSeconds = 0;
  int numberOfBooks = 0;
  int numberOfReads = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  bool isLoggedIn = false;
  bool isLoginAlertShowing = false;
  bool _isPrivate = false;
  String? selectedBook;
  String? selectedBookId;
  TextEditingController _quoteController = TextEditingController();
  TextEditingController _pageController = TextEditingController();
  List<Map<String, dynamic>> books = [];
  List<Map<String, dynamic>> recentBooks = [];
  List<ReadingGoal> data = [];
  List<BarChartGroupData> showingBarGroups = [];
  bool isLoading = true;
  double? maxYValue;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    selectedBook = widget.selectedBook;

    print("Initial Tab Index: ${widget.initialTabIndex}");
    print("Selected Book ID: ${widget.selectedBook}");

    selectedBookId = widget.selectedBook;

    _checkLoginStatus();
    _fetchData().then((_) {
      if (mounted) {
        setState(() {
          showingBarGroups = createChartData(data);
        });
      }
    });
    _fetchBooks();
    _fetchGoalTime();
    _fetchNumberOfBooks();
    _fetchRecentBooks();
    _checkAndResetTimeIfNewDay();
  }

  // ฟังก์ชันปรับวันในสัปดาห์
  int adjustWeekday(int originalWeekday) {
    return originalWeekday == 7 ? 1 : originalWeekday + 1;
  }

  double calculateMaxYValue(List<ReadingGoal> data) {
    if (data.isEmpty) return 0;
    double maxValue = 0;

    // วนลูปเพื่อหาค่าสูงสุดระหว่าง goalMinutes และ readMinutes
    for (var goal in data) {
      if (goal.goalMinutes > maxValue) {
        maxValue = goal.goalMinutes.toDouble();
      }
      if (goal.readMinutes > maxValue) {
        maxValue = goal.readMinutes.toDouble();
      }
    }

    return maxValue;
  }

  Future<void> _loadPoints() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int savedPoints = prefs.getInt('Points') ?? 0;
    setState(() {
      Points = savedPoints;
    });
  }

  // ฟังก์ชันดึงข้อมูลจำนวนหนังสือที่อ่าน
  Future<void> _fetchNumberOfBooks() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('User_ID');

      if (userId == null) {
        throw Exception('User_ID not found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/fetch_user_books.php'),
        body: {
          'User_ID': userId,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        setState(() {
          numberOfBooks =
              jsonResponse['Number_of_Books'] ?? 0; // เช็คว่ามีค่าหรือไม่
          numberOfReads =
              jsonResponse['Number_of_Reads'] ?? 0; // เช็คว่ามีค่าหรือไม่
        });
      } else {
        throw Exception('Failed to load number of books');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _fetchRecentBooks() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('User_ID');
      if (userId == null) {
        throw Exception('User_ID not found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/fetch_recent_books.php'),
        body: {
          'User_ID': userId,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse is List) {
          List<Map<String, dynamic>> books =
              List<Map<String, dynamic>>.from(jsonResponse);

          books.sort((a, b) => a['Last_Read'].compareTo(b['Last_Read']));

          setState(() {
            recentBooks = books;
          });
        } else {
          throw Exception('Expected a list response');
        }
      } else {
        throw Exception('Failed to load recent books: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // ฟังก์ชันสำหรับดึงข้อมูลหนังสือ
  Future<void> _fetchBooks() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('User_ID');

      if (userId == null) {
        throw Exception('User_ID not found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/fetch_books.php'),
        body: {
          'User_ID': userId,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        setState(() {
          books = List<Map<String, dynamic>>.from(jsonResponse['data']);

          books.insert(
              0, {'Book_ID': 'default', 'Book_Name': 'กรุณาเลือกหนังสือ'});

          if (books.any(
              (book) => book['Book_ID'].toString() == widget.selectedBook)) {
            selectedBook = widget.selectedBook;
            selectedBookId = widget.selectedBook;
          } else {
            selectedBook = 'default';
            selectedBookId = null;
          }

          print('selectedBook หลังจากอัปเดต: $selectedBook');
        });
      } else {
        throw Exception('Failed to load books');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // ฟังก์ชันสำหรับดึงข้อมูลเวลาเป้าหมาย
  Future<void> _fetchGoalTime() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('User_ID');

      if (userId == null) {
        throw Exception('User_ID not found');
      }

      int todayAdjusted = adjustWeekday(DateTime.now().weekday);

      final response = await http.post(
        Uri.parse('$baseUrl/fetch_goal_time.php'),
        body: {
          'User_ID': userId,
          'Day': todayAdjusted.toString(),
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        setState(() {
          if (jsonResponse['Goal_Time'] != null) {
            initialSeconds = (jsonResponse['Goal_Time'] as int) * 60;
            goalTime = initialSeconds;
          } else {
            initialSeconds = 0;
            goalTime = null;
          }
          _seconds = 0;
        });

        print('Adjusted Day: $todayAdjusted');
        print('Goal_Time: ${jsonResponse['Goal_Time']}');
      } else {
        throw Exception('Failed to load goal time');
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        initialSeconds = 0;
        _seconds = 0;
        goalTime = null;
      });
    }
  }

  Future<bool> _addQuote(
      String quote, String page, bool isPrivate, String? bookId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('User_ID');

      if (userId == null) {
        throw Exception('User_ID not found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/add_quote.php'),
        body: {
          'action': 'add',
          'User_ID': userId,
          'Book_ID': bookId,
          'Quote_Detail': quote,
          'Page_of_Quote': page,
          'Quote_Status': isPrivate ? '1' : '2',
        },
      );

      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to add quote');
      }
    } catch (e) {
      print('Error: $e');
      return false;
    }
  }

  Future<void> _fetchData() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('User_ID');

      if (userId == null) {
        throw Exception('User_ID not found in SharedPreferences');
      }

      print('User_ID ที่ส่งไปยังเซิร์ฟเวอร์: $userId');

      final response =
          await http.get(Uri.parse('$baseUrl/bar_chart.php?User_ID=$userId'));

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);

        if (jsonResponse.isNotEmpty) {
          data =
              jsonResponse.map((data) => ReadingGoal.fromJson(data)).toList();
          maxYValue = calculateMaxYValue(data);
        } else {
          print('No data found for User_ID: $userId');
          data = [];
          maxYValue = 0;
        }
      } else {
        throw Exception(
            'Failed to load data, status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<DateTime?> _fetchLastPointDate() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    if (userId == null) {
      return null;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/get_last_point_date.php'),
      body: {'User_ID': userId},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      String? lastPointDateString = data['Last_Point_Date'];

      print('Last Point Date String: $lastPointDateString');

      if (lastPointDateString != null && lastPointDateString.isNotEmpty) {
        return DateTime.parse(lastPointDateString);
      }
    }

    return null;
  }

  void _savePoints(int newPoints) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int currentPoints = prefs.getInt('Points') ?? 0;
    currentPoints += newPoints;
    await prefs.setInt('Points', currentPoints);
    setState(() {
      Points = currentPoints;
    });
  }

  void _savePagereadto(int bookId, int pageReadTo, BuildContext context) async {
    try {
      print('กำลังส่งข้อมูล: Book_ID: $bookId, Page_read_to: $pageReadTo');

      final response = await http.post(
        Uri.parse('$baseUrl/update_page_read_to.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'Book_ID': bookId,
          'Page_read_to': pageReadTo,
        }),
      );

      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = json.decode(response.body);
        print('Response data: $responseBody');

        if (responseBody['status'] == 'success') {
          print('อัปเดตหน้าที่อ่านได้สำเร็จสำหรับ book ID: $bookId');
          _showSaveSuccessPopup(responseBody['message'], context);
        } else {
          _showErrorPopup(responseBody['message'], context);
        }
      } else {
        throw Exception(
            'ไม่สามารถอัปเดตหน้าที่อ่านได้ status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      _showErrorPopup('เกิดข้อผิดพลาดในการบันทึก: $e', context);
    }
  }

  Future<void> _checkAndResetTimeIfNewDay() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lastDate = prefs.getString('last_date');
    String currentDate = DateTime.now().toIso8601String().substring(0, 10);

    if (lastDate != currentDate) {
      setState(() {
        _seconds = 0;
      });
      await prefs.setString('last_date', currentDate);
    }
  }

  void _saveStartTime(String bookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('User_ID');

      if (userId == null) {
        print('User ID not found');
        return;
      }

      final now = DateTime.now().toIso8601String();

      final response = await http.post(
        Uri.parse('$baseUrl/add_statistics.php'),
        body: {
          'User_ID': userId,
          'Book_ID': bookId,
          'Datetime_Start': now,
          'action': 'start',
        },
      );

      if (response.statusCode == 200) {
        print('Start time saved successfully');
      } else {
        print('Failed to save start time. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void _saveEndTime(
      String bookId, int readingPoints, DateTime? lastPointDate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('User_ID');

      if (userId == null) {
        print('User ID not found');
        return;
      }

      final now = DateTime.now().toIso8601String();

      final pointDate = (lastPointDate?.year ?? 0) > 1970
          ? lastPointDate?.toIso8601String()
          : now;

      final response = await http.post(
        Uri.parse('$baseUrl/add_statistics.php'),
        body: {
          'User_ID': userId,
          'Book_ID': bookId,
          'Datetime_End': now,
          'Reading_Points': readingPoints.toString(),
          'Last_Point_Date': pointDate,
          'action': 'end',
        },
      );

      if (response.statusCode == 200) {
        print('End time and reading points saved successfully');
      } else {
        print(
            'Failed to save end time and reading points. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void _showSaveSuccessPopup(String message, BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(color: Colors.pinkAccent, width: 2.0),
          ),
          title: Text('สำเร็จ',
              style: GoogleFonts.kodchasan(color: Colors.pinkAccent)),
          content: Text(message,
              style: GoogleFonts.kodchasan(fontWeight: FontWeight.w500)),
          actions: <Widget>[
            TextButton(
              child: Text('ตกลง',
                  style: GoogleFonts.kodchasan(color: Colors.pinkAccent)),
              onPressed: () {
                Navigator.of(context).pop(); // ปิดป๊อปอัพ
                Navigator.of(context).pop(); // ปิดป๊อปอัพสรุป
              },
            ),
          ],
        );
      },
    );
  }

  void _showErrorPopup(String errorMessage, BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(color: Colors.pinkAccent, width: 2.0),
          ),
          title: Text('เกิดข้อผิดพลาด',
              style: GoogleFonts.kodchasan(color: Colors.pinkAccent)),
          content: Text(errorMessage,
              style: GoogleFonts.kodchasan(fontWeight: FontWeight.w500)),
          actions: <Widget>[
            TextButton(
              child: Text('ตกลง',
                  style: GoogleFonts.kodchasan(color: Colors.pinkAccent)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isLoggedIn = prefs.getString('User_ID') != null;
    });

    if (isLoggedIn) {
      if (isLoginAlertShowing) {
        Navigator.of(context, rootNavigator: true).pop();
        isLoginAlertShowing = false;
      }
    } else {
      _showLoginAlert();
    }
  }

  void _startTimer() {
    if (selectedBookId == null ||
        selectedBookId!.isEmpty ||
        selectedBookId == 'default') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('กรุณาเลือกหนังสือก่อนเริ่มจับเวลา',
              style: GoogleFonts.kodchasan()),
        ),
      );
      return;
    }

    Wakelock.enable();

    if (!_isRunning && !_isPaused) {
      _startTime = DateTime.now();
      _saveStartTime(selectedBookId!);

      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          final now = DateTime.now();
          _seconds =
              now.difference(_startTime!).inSeconds; // คำนวณเวลาที่ผ่านไปจริง

          if (initialSeconds > 0 && _seconds >= initialSeconds) {}
        });
      });

      setState(() {
        _isRunning = true;
      });
    }
  }

  void _pauseTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() {
        _isPaused = true;
        _isRunning = false;
      });
    }
  }

  void _resumeTimer() {
    if (!_isRunning && _isPaused) {
      _startTime = DateTime.now().subtract(Duration(
          seconds: _seconds)); // ตั้งค่าให้เวลาเริ่มต้นเป็นตอนที่หยุดไว้

      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _seconds = DateTime.now().difference(_startTime!).inSeconds;
        });
      });

      setState(() {
        _isPaused = false;
        _isRunning = true;
      });
    }
  }

  void _stopTimer() async {
    if (_isRunning || _isPaused) {
      if (selectedBookId != null) {
        int finalSeconds = _seconds;
        int timeElapsedInMinutes = finalSeconds ~/ 60;
        int totalPoints = timeElapsedInMinutes;

        DateTime? lastPointDate = await _fetchLastPointDate();

        bool isLastPointDateValid =
            lastPointDate != null && lastPointDate.year > 1970;

        if (goalTime != null && finalSeconds >= goalTime!) {
          if (!isLastPointDateValid) {
            totalPoints += 20;
            lastPointDate = DateTime.now();
            print('คะแนน +20');
          }
        }

        _saveEndTime(selectedBookId!, totalPoints, lastPointDate);
        _timer?.cancel();

        if (mounted) {
          setState(() {
            _isRunning = false;
            _isPaused = false;
            _seconds = 0;
          });
        }

        Wakelock.disable();

        if (mounted) {
          _showSummaryPopup(totalPoints, timeElapsedInMinutes,
              finalSeconds % 60, goalTime! ~/ 60, lastPointDate);
        }
      } else {
        print('selectedBookId is null');
      }
    }
  }

  void _confirmStopTimer() {
    String contentText;

    // ตรวจสอบว่าเวลาครบตามเป้าหมายหรือยัง
    if (_seconds < initialSeconds) {
      contentText = 'ยังจับเวลาไม่ครบตามเป้าหมาย ต้องการหยุดจับเวลามั้ย?';
    } else {
      contentText = 'คุณแน่ใจหรือไม่ว่าต้องการหยุดเวลา?';
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.pinkAccent, width: 2),
          ),
          title: Text(
            'ยืนยันการหยุดเวลา',
            style: GoogleFonts.kodchasan(
              fontWeight: FontWeight.bold,
              color: Colors.pinkAccent,
            ),
          ),
          content: Text(
            contentText,
            style: GoogleFonts.kodchasan(
              fontWeight: FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('ยกเลิก',
                  style: GoogleFonts.kodchasan(color: Colors.pinkAccent)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('ตกลง',
                  style: GoogleFonts.kodchasan(color: Colors.pinkAccent)),
              onPressed: () {
                Navigator.of(context).pop();
                _stopTimer();
              },
            ),
          ],
        );
      },
    );
  }

  void _showSummaryPopup(
      int points,
      int timeElapsedInMinutes,
      int timeElapsedInSeconds,
      int targetTimeInMinutes,
      DateTime? lastPointDate) {
    TextEditingController _pageController = TextEditingController();
    int bonusPoints = 0;

    if (timeElapsedInMinutes >= targetTimeInMinutes) {
      bonusPoints = 20;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.pinkAccent, width: 2.0),
            borderRadius: BorderRadius.circular(10.0),
          ),
          title: Text('สรุปการจับเวลา', style: GoogleFonts.kodchasan()),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                if (bonusPoints > 0 ||
                    (lastPointDate != null && lastPointDate.year > 1970))
                  Text(
                    'ยินดีด้วย🎉\nคุณทำตามเป้าหมายการอ่านได้สำเร็จ!\nรับโบนัสเพิ่ม $bonusPoints คะแนน!',
                    style: GoogleFonts.kodchasan(
                        fontSize: 16, color: Colors.pinkAccent),
                  ),
                SizedBox(height: 10),
                Text(
                  'เวลาที่จับได้: $timeElapsedInMinutes นาที $timeElapsedInSeconds วินาที',
                  style: GoogleFonts.kodchasan(),
                ),
                Text(
                  'คะแนนที่ได้รับ: $points คะแนน',
                  style: GoogleFonts.kodchasan(),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Text('อ่านถึงหน้า: ',
                        style: GoogleFonts.kodchasan(fontSize: 16)),
                    Container(
                      width: 60,
                      child: TextField(
                        controller: _pageController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.pinkAccent),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.pinkAccent),
                          ),
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.pinkAccent,
              ),
              child: Text('บันทึก', style: GoogleFonts.kodchasan()),
              onPressed: () {
                if (_pageController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'กรุณากรอกหมายเลขหน้าที่คุณอ่านถึง',
                        style: GoogleFonts.kodchasan(),
                      ),
                    ),
                  );
                  return;
                }

                int pageReadTo = int.parse(_pageController.text);
                int bookId = int.parse(selectedBookId!);

                _savePagereadto(bookId, pageReadTo, context);
              },
            ),
          ],
        );
      },
    );
  }

  void _showLoginAlert() {
    isLoginAlertShowing = true;
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
              child: Text('กรุณาลงชื่อเข้าใช้งาน',
                  style: GoogleFonts.kodchasan())),
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
                  isLoginAlertShowing = false;
                },
                child: Text('เข้าสู่ระบบ', style: GoogleFonts.kodchasan()),
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
    ).then((_) {
      isLoginAlertShowing = false;
    });
  }

  void _onTabChange() {
    if (_tabController.index == 0 && !isLoggedIn) {
      _showLoginAlert();
      Future.delayed(Duration(milliseconds: 100), () {
        _tabController.index = 1;
      });
    }
  }

  List<BarChartGroupData> createChartData(List<ReadingGoal> data) {
    return data.asMap().entries.map((entry) {
      int index = entry.key;
      ReadingGoal goal = entry.value;
      return makeGroupData(
          index, goal.goalMinutes.toDouble(), goal.readMinutes.toDouble());
    }).toList();
  }

  BarChartGroupData makeGroupData(int x, double y1, double y2) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(toY: y1, color: Colors.blueAccent),
        BarChartRodData(toY: y2, color: Colors.pinkAccent)
      ],
    );
  }

  Widget bottomTitles(double value, TitleMeta meta) {
    final style = GoogleFonts.kodchasan(
      color: Color(0xff7589a2),
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );

    // ดึงชื่อวันจากเซิร์ฟเวอร์โดยตรง
    if (value.toInt() < data.length) {
      return SideTitleWidget(
        axisSide: meta.axisSide,
        child: Text(data[value.toInt()].day, style: style),
      );
    } else {
      return SideTitleWidget(
        axisSide: meta.axisSide,
        child: Text('', style: style),
      );
    }
  }

  Widget leftTitles(double value, TitleMeta meta) {
    final style = GoogleFonts.kodchasan(
      color: Color(0xff7589a2),
      fontWeight: FontWeight.bold,
      fontSize: 10,
    );
    if (value % 10 == 0) {
      return SideTitleWidget(
        axisSide: meta.axisSide,
        child: Text(value.toInt().toString(), style: style),
      );
    } else {
      return Container();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Focus',
          style: GoogleFonts.kodchasan(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Color.fromARGB(255, 254, 176, 216),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
          ),
          indicatorPadding: EdgeInsets.symmetric(vertical: 8.0),
          tabs: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                height: 30.0,
                alignment: Alignment.center,
                child: Text(
                  'สถิติประจำสัปดาห์',
                  style: GoogleFonts.kodchasan(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                if (isLoggedIn) {
                  _tabController.index = 1;
                } else {
                  _showLoginAlert();
                }
              },
              child: AbsorbPointer(
                absorbing: !isLoggedIn,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    height: 30.0,
                    alignment: Alignment.center,
                    child: Text(
                      'จับเวลา',
                      style: GoogleFonts.kodchasan(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        child: TabBarView(
          controller: _tabController,
          children: [
            Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: isLoggedIn
                      ? Center(
                          child: ListView(
                            padding: EdgeInsets.all(16.0),
                            shrinkWrap: true,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'เป้าหมายใน 1 ปี :',
                                    style: GoogleFonts.kodchasan(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    'อ่านไปแล้ว $numberOfReads เล่ม จาก $numberOfBooks เล่ม',
                                    style: GoogleFonts.kodchasan(
                                      fontSize: 18,
                                      color: Colors.pinkAccent,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),

                                  SizedBox(height: 20),

                                  // รายการหนังสือที่อ่านล่าสุด
                                  ListView.builder(
                                    physics: NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: recentBooks.length,
                                    itemBuilder: (context, index) {
                                      return ListTile(
                                        leading: Text(
                                            style: GoogleFonts.kodchasan(
                                              fontSize: 16.0,
                                            ),
                                            '${index + 1}'),
                                        title: Text(
                                          recentBooks[index]['Book_Name'],
                                          style: GoogleFonts.kodchasan(
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'อ่านเมื่อ: ${recentBooks[index]['Last_Read']} (${recentBooks[index]['Read_Minutes']})',
                                          style: GoogleFonts.kodchasan(
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  SizedBox(height: 20),

                                  Center(
                                    child: Text(
                                      'สถิติการอ่านประจำวัน',
                                      style: GoogleFonts.kodchasan(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w500,
                                        color: Color.fromARGB(255, 0, 0, 0),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SizedBox(height: 20),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Container(
                                        width: 24,
                                        height: 24,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      Text(
                                        'เป้าหมาย',
                                        style: GoogleFonts.kodchasan(
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                      Container(
                                        width: 24,
                                        height: 24,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.pinkAccent,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      Text(
                                        'ที่ทำได้',
                                        style: GoogleFonts.kodchasan(
                                            color: Colors.pinkAccent),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 20),

                                  // กราฟ
                                  SizedBox(
                                    height: 300,
                                    child: showingBarGroups.isNotEmpty
                                        ? BarChart(
                                            BarChartData(
                                              maxY:
                                                  maxYValue, // ใช้ค่า maxYValue ที่คำนวณได้
                                              barGroups: showingBarGroups,
                                              titlesData: FlTitlesData(
                                                show: true,
                                                rightTitles: AxisTitles(
                                                    sideTitles: SideTitles(
                                                        showTitles: false)),
                                                topTitles: AxisTitles(
                                                    sideTitles: SideTitles(
                                                        showTitles: false)),
                                                bottomTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: true,
                                                    getTitlesWidget:
                                                        bottomTitles,
                                                    reservedSize: 42,
                                                  ),
                                                ),
                                                leftTitles: AxisTitles(
                                                  sideTitles: SideTitles(
                                                    showTitles: true,
                                                    reservedSize: 28,
                                                    interval: 10,
                                                    getTitlesWidget: leftTitles,
                                                  ),
                                                ),
                                              ),
                                              gridData: FlGridData(
                                                show: true,
                                                drawVerticalLine: true,
                                                getDrawingVerticalLine:
                                                    (value) {
                                                  return FlLine(
                                                    color:
                                                        const Color(0xffe7e8ec),
                                                    strokeWidth: 2,
                                                    dashArray: [5, 5],
                                                  );
                                                },
                                                drawHorizontalLine: true,
                                                getDrawingHorizontalLine:
                                                    (value) {
                                                  return FlLine(
                                                    color: Color.fromARGB(
                                                        255, 210, 214, 231),
                                                    strokeWidth: 1,
                                                  );
                                                },
                                              ),
                                              borderData: FlBorderData(
                                                show: true,
                                                border: Border.all(
                                                    color:
                                                        const Color(0xff37434d),
                                                    width: 1),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: CircularProgressIndicator()),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: Text('กรุณาลงชื่อเข้าใช้งาน',
                              style: GoogleFonts.kodchasan())),
                ),
              ],
            ),
            // แท็บจับเวลา
            isLoggedIn
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Text('หนังสือ : ',
                                style: GoogleFonts.kodchasan(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                )),
                            SizedBox(width: 10),
                            Expanded(
                              child: books.isEmpty
                                  ? CircularProgressIndicator()
                                  : DropdownButtonFormField<String>(
                                      decoration: InputDecoration(
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.pinkAccent,
                                            width: 2.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10.0),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.pinkAccent,
                                            width: 2.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(10.0),
                                        ),
                                      ),
                                      value: selectedBook,
                                      items: books.map((book) {
                                        return DropdownMenuItem<String>(
                                          value: book['Book_ID'].toString(),
                                          child: Text(
                                            book['Book_Name'],
                                            style: GoogleFonts.kodchasan(
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.normal,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          selectedBook = newValue;
                                          selectedBookId = newValue;
                                        });
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          children: [
                            SizedBox(height: 20),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 200,
                                      height: 200,
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween(
                                            begin: 0.0,
                                            end: initialSeconds > 0
                                                ? _seconds / initialSeconds
                                                : 0.0),
                                        duration: Duration(seconds: 1),
                                        builder: (context, value, _) =>
                                            CircularProgressIndicator(
                                          value: value,
                                          strokeWidth: 8,
                                          backgroundColor:
                                              Colors.grey.withOpacity(0.2),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.pinkAccent,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}",
                                      style: GoogleFonts.kodchasan(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.pinkAccent[100],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 20),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 30.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      ElevatedButton(
                                        onPressed: (_isRunning || _isPaused)
                                            ? _confirmStopTimer
                                            : null,
                                        child: Text(
                                          'หยุด',
                                          style: GoogleFonts.kodchasan(
                                            fontWeight: FontWeight.bold,
                                            color: (_isRunning || _isPaused)
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.pinkAccent[100],
                                        ),
                                      ),
                                      Spacer(),
                                      ElevatedButton(
                                        onPressed: () {
                                          if (!_isRunning && !_isPaused) {
                                            _startTimer();
                                          } else if (_isPaused) {
                                            _resumeTimer();
                                          } else {
                                            _pauseTimer();
                                          }
                                        },
                                        child: Text(
                                          _isPaused
                                              ? 'นับต่อ'
                                              : (_isRunning
                                                  ? 'หยุดชั่วคราว'
                                                  : 'เริ่ม'),
                                          style: GoogleFonts.kodchasan(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.pinkAccent[100],
                                          foregroundColor: Colors.black,
                                          textStyle: GoogleFonts.kodchasan(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 30),
                                _buildAddQuoteForm(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Text(''),
          ],
        ),
      ),
    );
  }

  Widget _buildAddQuoteForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'เพิ่ม Quote',
            style: GoogleFonts.kodchasan(
                fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text('หน้า:',
                  style: GoogleFonts.kodchasan(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(width: 10),
              Container(
                width: 50,
                child: TextField(
                  controller: _pageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('โควต:',
                  style: GoogleFonts.kodchasan(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              TextField(
                controller: _quoteController,
                maxLines: 4,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.all(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Theme(
                data: Theme.of(context).copyWith(
                  checkboxTheme: CheckboxThemeData(
                    fillColor: MaterialStateProperty.resolveWith<Color>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.selected)) {
                          return Colors.pinkAccent;
                        }
                        return const Color.fromARGB(255, 255, 255, 255);
                      },
                    ),
                    checkColor: MaterialStateProperty.all(Colors.white),
                  ),
                ),
                child: Checkbox(
                  value: _isPrivate,
                  onChanged: (value) {
                    setState(() {
                      _isPrivate = value!;
                    });
                  },
                ),
              ),
              Text('ส่วนตัว', style: GoogleFonts.kodchasan()),
            ],
          ),
        ),
        SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: () {
              // ตรวจสอบว่ากรอกข้อมูลในช่องโควตและหมายเลขหน้าหรือไม่
              if (_pageController.text.isEmpty ||
                  _quoteController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'กรุณากรอกข้อมูลให้ครบถ้วน',
                      style: GoogleFonts.kodchasan(
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                );

                return; // หยุดการทำงานต่อหากข้อมูลไม่ครบ
              }

              // ถ้าข้อมูลครบแล้ว จึงทำการบันทึก
              _addQuote(
                _quoteController.text,
                _pageController.text,
                _isPrivate,
                selectedBookId,
              ).then((success) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'เพิ่มโควตสำเร็จ!',
                        style: GoogleFonts.kodchasan(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );

                  _quoteController.clear();
                  _pageController.clear();
                  setState(() {
                    _isPrivate = false;
                  });
                }
              });
            },
            child: Text(
              'เพิ่ม',
              style: GoogleFonts.kodchasan(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent[100],
              foregroundColor: Colors.black,
            ),
          ),
        ),
        SizedBox(height: 10),
      ],
    );
  }
}

class ReadingGoal {
  final String day; // เก็บเป็น String ของชื่อวัน
  final int goalMinutes;
  final int readMinutes;

  ReadingGoal(
      {required this.day,
      required this.goalMinutes,
      required this.readMinutes});

  factory ReadingGoal.fromJson(Map<String, dynamic> json) {
    return ReadingGoal(
      day: json['day'] ?? '',
      goalMinutes: json['goalMinutes'] != null ? json['goalMinutes'] as int : 0,
      readMinutes: json['readMinutes'] != null ? json['readMinutes'] as int : 0,
    );
  }
}
