import 'dart:convert';
import 'package:collecting_book/bottom_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'user_profile_screen.dart';
import 'message_screen.dart';
import 'store_screen.dart';
import 'edit_password_screen.dart';
import 'time_goals_screen.dart';
import 'requests_screen.dart';
import 'reports_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userName = 'ผู้ใช้';
  int totalPoints = 0;
  String profilePictureUrl = '';

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<bool> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');
    return userId != null && userId.isNotEmpty;
  }

  Future<void> _getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    if (userId != null) {
      final response = await http.post(
        Uri.parse('$baseUrl/user_profile.php'),
        body: {'User_ID': userId},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == null || data['status'] != "User not found") {
          if (mounted) {
            setState(() {
              userName = data['User_Name'];
              totalPoints = data['Total_Points'];
              profilePictureUrl = data['Profile_Picture'] ?? '';
              print('Profile Picture URL: $profilePictureUrl');
            });
          }
        } else {
          print('Error: ${data['status']}');
        }
      } else {
        print('Failed to load user data');
      }
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('User_ID');
    await prefs.remove('User_Name');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (context) => HomeScreen(
                initialTabIndex: 1,
                selectedBook: '',
              )),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'โปรไฟล์',
          style: GoogleFonts.kodchasan(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Color.fromARGB(255, 254, 176, 216),
      ),
      body: FutureBuilder<bool>(
        future: _checkLoginStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด'));
          } else {
            bool isLoggedIn = snapshot.data ?? false;
            return ListView(
              children: [
                SizedBox(height: 20),
                if (isLoggedIn) ...[
                  _buildProfileHeader(userName, totalPoints),
                  Divider(),
                  _buildProfileOption(
                    context,
                    title: 'ข้อมูลผู้ใช้งาน',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => UserProfileScreen()),
                      ).then((isProfileUpdated) {
                        if (isProfileUpdated == true) {
                          _getUserData();
                        }
                      });
                    },
                  ),
                  Divider(),
                  _buildProfileOption(
                    context,
                    title: 'กล่องข้อความ',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => MessageScreen()),
                      );
                    },
                  ),
                  Divider(),
                  _buildProfileOption(
                    context,
                    title: 'ร้านค้าโปรไฟล์',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => StoreScreen()),
                      );
                    },
                  ),
                  Divider(),
                  _buildProfileOption(
                    context,
                    title: 'แก้ไขรหัสผ่าน',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => EditPasswordScreen()),
                      );
                    },
                  ),
                  Divider(),
                  _buildProfileOption(
                    context,
                    title: 'แก้ไขเวลาเป้าหมาย',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TimeGoalsScreen(fromProfile: true),
                        ),
                      );
                    },
                  ),
                  Divider(),
                  _buildProfileOption(
                    context,
                    title: 'แจ้งคำร้องขอเพิ่มหนังสือ',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => RequestsScreen()),
                      );
                    },
                  ),
                  Divider(),
                  _buildProfileOption(
                    context,
                    title: 'แจ้งปัญหาการใช้งาน',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ReportsScreen()),
                      );
                    },
                  ),
                  Divider(),
                  _buildProfileOption(
                    context,
                    title: 'ออกจากระบบ',
                    onTap: _logout,
                  ),
                ] else ...[
                  ListTile(
                    leading: Icon(
                      Icons.account_circle,
                      size: 50,
                      color: Colors.pinkAccent,
                    ),
                    title: Text(
                      'เข้าสู่ระบบ',
                      style: GoogleFonts.kodchasan(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      ).then((value) {
                        if (value == true) {
                          setState(() {});
                        }
                      });
                    },
                  ),
                  Divider(),
                ],
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildProfileHeader(String userName, int totalPoints) {
    final formattedPoints = NumberFormat('#,###').format(totalPoints);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (profilePictureUrl.isNotEmpty) ...[
                CircleAvatar(
                  backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                  backgroundImage: NetworkImage(profilePictureUrl),
                  radius: 30,
                ),
                SizedBox(width: 10),
              ],
              Text(
                userName,
                style: GoogleFonts.kodchasan(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.pinkAccent,
                ),
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star,
                    color: Color.fromARGB(255, 255, 215, 0), size: 20),
                SizedBox(width: 5),
                Text(
                  formattedPoints,
                  style: GoogleFonts.kodchasan(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.pinkAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption(BuildContext context,
      {required String title, required Function onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      title: Text(
        title,
        style: GoogleFonts.kodchasan(
          fontSize: 18,
          color: Colors.pinkAccent,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () => onTap(),
    );
  }
}
