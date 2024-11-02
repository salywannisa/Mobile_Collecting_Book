import 'dart:convert';
import 'dart:io';
import 'package:collecting_book/screens/goals_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:intl/intl.dart';

class TimeGoalsScreen extends StatefulWidget {
  final bool fromProfile;

  TimeGoalsScreen({this.fromProfile = false});

  @override
  _TimeGoalsScreenState createState() => _TimeGoalsScreenState();
}

class _TimeGoalsScreenState extends State<TimeGoalsScreen> {
  List<String> days = [
    'อาทิตย์',
    'จันทร์',
    'อังคาร',
    'พุธ',
    'พฤหัสบดี',
    'ศุกร์',
    'เสาร์'
  ];
  List<bool> checkedDays = List.filled(7, false);
  List<int> goalstime = List.filled(7, 0);
  List<TextEditingController> timeControllers = [];
  List<TextEditingController> goalTimeControllers = [];

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < days.length; i++) {
      timeControllers.add(TextEditingController(text: "00:00"));
      goalTimeControllers
          .add(TextEditingController(text: goalstime[i].toString()));
    }

    _initializeNotifications();
    _getGoalsFromServer();

    if (isAndroid12OrHigher()) {
      checkExactAlarmPermission();
    }
  }

  bool isAndroid12OrHigher() {
    return Platform.isAndroid &&
        (Platform.operatingSystemVersion.contains('31') ||
            Platform.operatingSystemVersion.contains('32'));
  }

  void checkExactAlarmPermission() {
    openAlarmPermissionSettings();
  }

  void openAlarmPermissionSettings() {
    final intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
    );
    intent.launch();
  }

  Future<String?> getUserID() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('User_ID');
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(alwaysUse24HourFormat: true), // ใช้รูปแบบ 24 ชั่วโมง
          child: child!,
        );
      },
    );

    if (picked != null) {
      // แปลงเวลาให้อยู่ในรูปแบบ 24 ชั่วโมง
      final now = DateTime.now();
      final formattedTime =
          DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      final timeString = DateFormat.Hm().format(formattedTime);

      setState(() {
        timeControllers[index].text = timeString; // แสดงในฟอร์แมต 24 ชั่วโมง
      });
    }
  }

  Future<void> _saveTimeGoals() async {
    String? userId = await getUserID();

    if (userId == null) {
      print('User_ID not found');
      return;
    }

    for (int i = 0; i < days.length; i++) {
      if (checkedDays[i]) {
        var timeOfNotification = timeControllers[i].text;
        var goalTime = int.tryParse(goalTimeControllers[i].text) ?? 0;

        var response = await http.post(
          Uri.parse('$baseUrl/time_goals.php'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, dynamic>{
            'User_ID': userId,
            'Day': i + 1,
            'Time_of_Notification': timeOfNotification,
            'Goal_Time': goalTime,
          }),
        );

        if (response.statusCode == 200) {
          var jsonResponse = jsonDecode(response.body);
          if (jsonResponse['error'] != null) {
            print('Error: ${jsonResponse['error']}');
          } else {
            print('Success: ${jsonResponse['message']}');
            await _scheduleNotification(i, timeOfNotification);
          }
        } else {
          print('Server error: ${response.statusCode}');
        }
      } else {
        var response = await http.post(
          Uri.parse('$baseUrl/time_goals.php'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, dynamic>{
            'User_ID': userId,
            'Day': i + 1,
          }),
        );

        if (response.statusCode == 200) {
          var jsonResponse = jsonDecode(response.body);
          if (jsonResponse['error'] != null) {
            print('Error: ${jsonResponse['error']}');
          } else {
            print('Success: ${jsonResponse['message']}');
            // ลบการแจ้งเตือนที่เคยตั้งไว้
            await flutterLocalNotificationsPlugin.cancel(i);
          }
        } else {
          print('Failed to delete goal for day ${i + 1}');
        }
      }
    }
  }

  Future<void> _getGoalsFromServer() async {
    String? userId = await getUserID();

    if (userId == null) {
      print('User_ID not found');
      return;
    }

    var url = Uri.parse('$baseUrl/get_time_goals.php');

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {'User_ID': userId},
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        List<dynamic> goals = responseData['goals'];
        for (var goal in goals) {
          int dayIndex = goal['Day'] - 1;
          String time = goal['Time_of_Notification'];
          int goalTime = goal['Goal_Time'];

          setState(() {
            checkedDays[dayIndex] = true;
            timeControllers[dayIndex].text = time;
            goalTimeControllers[dayIndex].text = goalTime.toString();
          });

          await _scheduleNotification(dayIndex, time);
        }
      } else {
        print('Failed to get time goals: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error occurred while getting time goals: $e');
    }
  }

  Future<void> _scheduleNotification(
      int dayIndex, String timeOfNotification) async {
    try {
      DateFormat dateFormat = DateFormat.Hm(); // ใช้รูปแบบ 24 ชั่วโมง
      DateTime parsedTime = dateFormat.parse(timeOfNotification);

      DateTime now = DateTime.now();
      DateTime scheduledTime = DateTime(
          now.year, now.month, now.day, parsedTime.hour, parsedTime.minute);

      // ตรวจสอบว่าเวลาที่กำหนดมานั้นยังอยู่ในอนาคตหรือไม่
      if (scheduledTime.isBefore(now)) {
        print('Scheduled time is in the past: $scheduledTime');
        return;
      }

      print('Current time: $now');
      print('Scheduled time: $scheduledTime');

      var androidDetails = AndroidNotificationDetails(
        'goal_reminder_channel',
        'Goal Reminder',
        channelDescription: 'Channel for goal reminder notifications',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableLights: true,
        enableVibration: true,
        sound: null,
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );

      var platformDetails = NotificationDetails(android: androidDetails);

      await flutterLocalNotificationsPlugin.schedule(
        dayIndex,
        'collecting_book',
        'ถึงเวลาที่จะอ่านหนังสือแล้ว!',
        scheduledTime,
        platformDetails,
      );

      print('Notification scheduled successfully for $scheduledTime');
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  void _initializeNotifications() async {
    var initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'เป้าหมาย',
          style: GoogleFonts.kodchasan(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 254, 176, 216),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(5),
              children: <Widget>[
                SizedBox(height: 5),
                Image.asset('assets/images/timer.png', width: 100, height: 100),
                SizedBox(height: 10),
                Text(
                  'กรุณาตั้งเวลาที่ต้องการอ่านต่อวัน \nและเวลาแจ้งเตือนอ่านหนังสือ',
                  style: GoogleFonts.kodchasan(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(days.length, (index) {
                    return Container(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Transform.scale(
                            scale: 1,
                            child: Checkbox(
                              value: checkedDays[index],
                              onChanged: (bool? value) {
                                setState(() {
                                  checkedDays[index] = value ?? false;
                                });
                              },
                              activeColor: Colors.pinkAccent,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              days[index],
                              style: GoogleFonts.kodchasan(
                                fontSize: 16.0,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                "เป้าหมาย (นาที)",
                                style: GoogleFonts.kodchasan(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                              Container(
                                width: 70,
                                height: 50,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.pinkAccent, width: 2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: TextField(
                                  controller: goalTimeControllers[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.kodchasan(
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      goalstime[index] =
                                          int.tryParse(value) ?? 0;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                "แจ้งเตือน (นาฬิกา)",
                                style: GoogleFonts.kodchasan(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                              Container(
                                width: 100,
                                height: 50,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.pinkAccent, width: 2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: timeControllers[index],
                                        keyboardType: TextInputType.datetime,
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.kodchasan(
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                        ),
                                        readOnly: true,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.access_time),
                                      onPressed: () =>
                                          _selectTime(context, index),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
          SizedBox(
              width: 300,
              height: 40,
              child: ElevatedButton(
                onPressed: () async {
                  await _saveTimeGoals();

                  if (widget.fromProfile) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        'บันทึกการแก้ไขเป้าหมายเรียบร้อยแล้ว',
                        style: GoogleFonts.kodchasan(
                          fontSize: 14,
                        ),
                      ),
                      duration: Duration(seconds: 2),
                    ));
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => GoalsScreen()),
                    );
                  }
                },
                child: Text(
                  widget.fromProfile ? 'บันทึก' : 'ถัดไป',
                  style: GoogleFonts.kodchasan(
                    fontSize: 16,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent[100],
                  textStyle: TextStyle(fontSize: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              )),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}
