import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:collecting_book/config.dart';
import 'change_profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String userName = "Loading...";
  String birthYear = "Loading...";
  String email = "Loading...";
  String profilePictureUrl = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    if (userId != null) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/user_profile.php'),
          body: {
            'User_ID': userId,
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (mounted) {
            setState(() {
              userName = data['User_Name'] ?? "No Name";
              birthYear = data['Year_of_Birth']?.toString() ?? "No Birth Year";
              email = data['Email'] ?? "No Email";
              profilePictureUrl = data['Profile_Picture']?.isNotEmpty == true
                  ? data['Profile_Picture']
                  : '';
            });
          }
        } else {
          if (mounted) {
            setState(() {
              userName = "Error loading data";
              birthYear = "Error loading data";
              email = "Error loading data";
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            userName = "Error: $e";
            birthYear = "Error";
            email = "Error";
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          userName = "User_ID not found";
          birthYear = "User_ID not found";
          email = "User_ID not found";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ข้อมูลผู้ใช้งาน',
          style: GoogleFonts.kodchasan(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        backgroundColor: Color.fromARGB(255, 254, 176, 216),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true);
          },
        ),
      ),
      body: ListView(
        children: <Widget>[
          SizedBox(height: 40.0),
          Center(
            child: CircleAvatar(
              radius: 50.0,
              backgroundColor: Colors.white,
              backgroundImage: profilePictureUrl.isNotEmpty
                  ? NetworkImage(profilePictureUrl)
                  : null,
            ),
          ),
          SizedBox(height: 20.0),
          Center(
            child: Text(
              'ชื่อผู้ใช้: $userName',
              style: GoogleFonts.kodchasan(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          SizedBox(height: 20.0),
          Center(
            child: ElevatedButton(
              onPressed: () async {
                bool? isProfileChanged = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ChangeProfilePictureScreen()),
                );
                if (isProfileChanged == true) {
                  _loadUserInfo();
                }
              },
              child: Text(
                'เปลี่ยนรูปโปรไฟล์',
                style: GoogleFonts.kodchasan(
                    fontSize: 16, fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent[100],
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
              ),
            ),
          ),
          SizedBox(height: 20.0),
          Divider(),
          ListTile(
            title: Text(
              'ปีเกิด: $birthYear',
              style: GoogleFonts.kodchasan(
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            onTap: () {},
          ),
          Divider(),
          ListTile(
            title: Text(
              'อีเมล: $email',
              style: GoogleFonts.kodchasan(
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            onTap: () {},
          ),
          Divider(),
        ],
      ),
    );
  }
}
