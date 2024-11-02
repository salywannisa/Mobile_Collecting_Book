import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:collecting_book/config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class ChangeProfilePictureScreen extends StatefulWidget {
  @override
  _ChangeProfilePictureScreenState createState() =>
      _ChangeProfilePictureScreenState();
}

class _ChangeProfilePictureScreenState
    extends State<ChangeProfilePictureScreen> {
  List<dynamic> _profiles = [];
  int? _selectedProfileId;

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
  }

  Future<int> getUserId() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      int userId = int.tryParse(prefs.getString('User_ID') ?? '0') ?? 0;
      return userId;
    } catch (e) {
      print('Failed to fetch User_ID: $e');
      return 0;
    }
  }

  Future<void> _fetchProfiles() async {
    final userId = await getUserId();

    final response = await http.post(
      Uri.parse('$baseUrl/all_user_profile.php'),
      body: {'User_ID': userId.toString()},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List) {
        setState(() {
          _profiles = data; // ตั้งค่า _profiles ด้วยข้อมูลที่ได้รับ
        });
      } else {
        print('Error: Expected a list but got something else.');
      }
    } else {
      print('Error fetching profiles: ${response.statusCode}');
    }
  }

  Future<void> _updateProfilePicture() async {
    if (_selectedProfileId == null) return;
    final userId = await getUserId();

    final response = await http.post(
      Uri.parse('$baseUrl/update_profile_picture.php'),
      body: {
        'User_ID': userId.toString(),
        'Profile_ID': _selectedProfileId.toString(),
      },
    );

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      String message = '';
      if (result['success'] != null) {
        message = result['success'];
      } else if (result['error'] != null) {
        message = result['error'];
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              "สำเร็จ",
              style: GoogleFonts.kodchasan(color: Colors.pinkAccent),
            ),
            content: Text(
              message,
              style: GoogleFonts.kodchasan(
                  fontSize: 16, fontWeight: FontWeight.w500),
            ),
            actions: <Widget>[
              TextButton(
                child: Text(
                  "ตกลง",
                  style: GoogleFonts.kodchasan(color: Colors.pinkAccent),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pop(context, true);
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
    } else {
      print('Error with the request: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'เปลี่ยนรูปโปรไฟล์',
          style:
              GoogleFonts.kodchasan(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Color.fromARGB(255, 254, 176, 216),
      ),
      body: _profiles.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10.0,
                      mainAxisSpacing: 10.0,
                    ),
                    itemCount: _profiles.length,
                    itemBuilder: (context, index) {
                      final profile = _profiles[index];
                      final profileId = profile['Profile_ID'];
                      final profilePicture = profile['Profile_Picture'];

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedProfileId = profileId;
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            border: _selectedProfileId == profileId
                                ? Border.all(
                                    color: Colors.pinkAccent, width: 3.0)
                                : null,
                          ),
                          child: Image.network(profilePicture),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _updateProfilePicture,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent[100],
                    foregroundColor: Colors.black,
                    padding:
                        EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                  ),
                  child: Text(
                    'เปลี่ยนรูปโปรไฟล์',
                    style: GoogleFonts.kodchasan(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
    );
  }
}
