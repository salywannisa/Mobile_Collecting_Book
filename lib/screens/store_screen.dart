import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:collecting_book/config.dart';

class StoreScreen extends StatefulWidget {
  @override
  _StoreScreenState createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int points = 0;
  List profiles = [];
  bool isLoading = true;

  String userName = '';
  String yearOfBirth = '';
  String email = '';
  int totalPoints = 0;
  String profilePictureUrl = '';

  @override
  void initState() {
    super.initState();
    _loadPoints();
    _loadProfiles();
    _loadUserProfile();
  }

  Future<int> getUserId() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userIdString = prefs.getString('User_ID');
      int userId = int.tryParse(userIdString ?? '') ?? 0;
      return userId;
    } catch (e) {
      print('Failed to fetch User_ID: $e');
      return 0;
    }
  }

  void _loadUserProfile() async {
    final userId = await getUserId();
    final response = await http.post(
      Uri.parse('$baseUrl/user_profile.php'),
      body: {'User_ID': userId.toString()},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['status'] != "User not found") {
        setState(() {
          userName = data['User_Name'];
          yearOfBirth = data['Year_of_Birth'].toString();
          email = data['Email'];
          totalPoints = int.parse(data['Total_Points'].toString());
          profilePictureUrl = data['Profile_Picture'];
        });
      } else {
        print(data['status']);
      }
    } else {
      print('Server error: ${response.statusCode}');
    }
  }

  Future<void> _loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      points = prefs.getInt('Points') ?? 0;
    });
  }

  Future<void> _loadProfiles() async {
    int userId = await getUserId();
    try {
      final response = await http.get(Uri.parse('$baseUrl/get_profiles.php'));
      final ownedResponse = await http.post(
        Uri.parse('$baseUrl/check_owned_profiles.php'),
        body: {'User_ID': userId.toString()},
      );

      if (response.statusCode == 200 && ownedResponse.statusCode == 200) {
        final data = jsonDecode(response.body);
        final ownedData = (jsonDecode(ownedResponse.body) as List<dynamic>)
            .map((e) => e.toString())
            .toList();

        setState(() {
          profiles = data.map((profile) {
            return {
              ...profile,
              'owned': ownedData.contains(profile['Profile_ID'].toString()),
              'Points': int.parse(profile['Points'].toString()),
            };
          }).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load profiles');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching profiles data: $e');
    }
  }

  void _showPurchaseConfirmation(BuildContext context, Map profile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'ยืนยันการซื้อ',
            style: GoogleFonts.kodchasan(
              fontWeight: FontWeight.bold,
              color: Colors.pinkAccent,
            ),
          ),
          content: Text(
            'คุณต้องการซื้อ ${profile['Profile_Name']} ใช่หรือไม่?',
            style: GoogleFonts.kodchasan(
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
                'ตกลง',
                style: GoogleFonts.kodchasan(
                  color: Colors.pinkAccent,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _purchaseProfile(
                    context, int.parse(profile['Profile_ID'].toString()));
              },
            ),
          ],
        );
      },
    );
  }

  void _purchaseProfile(BuildContext context, int profileId) async {
    int userId = await getUserId();
    http.post(
      Uri.parse('$baseUrl/purchase_profile.php'),
      body: {'User_ID': userId.toString(), 'Profile_ID': profileId.toString()},
    ).then((response) {
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String message = data['message'];

        _showPurchaseResultDialog(context, 'สถานะการซื้อ', message);

        if (data['status'] == 'success') {
          _loadProfiles();
          _loadUserProfile();
        }
      } else {
        _showPurchaseResultDialog(context, 'สถานะการซื้อ',
            'มีข้อผิดพลาดในการเชื่อมต่อกับเซิร์ฟเวอร์.');
      }
    }).catchError((error) {
      _showPurchaseResultDialog(
          context, 'สถานะการซื้อ', 'เกิดข้อผิดพลาด: $error');
    });
  }

  void _showPurchaseResultDialog(
      BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: GoogleFonts.kodchasan(
              fontWeight: FontWeight.bold,
              color: Colors.pinkAccent,
            ),
          ),
          content: Text(
            content,
            style: GoogleFonts.kodchasan(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ร้านค้าโปรไฟล์',
          style: GoogleFonts.kodchasan(
              color: Colors.black, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Color.fromARGB(255, 254, 176, 216),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    Text(
                      'คะแนนของฉัน: ${NumberFormat("#,###").format(totalPoints)}',
                      style: GoogleFonts.kodchasan(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.pinkAccent,
                      ),
                    ),
                    SizedBox(height: 10),
                    Divider(),
                    SizedBox(height: 20),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1,
                      ),
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        bool isOwned = profile['owned'] == true;
                        return Card(
                          elevation: 2,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipOval(
                                child: Container(
                                  width: 70.0,
                                  height: 70.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: CircleAvatar(
                                    radius: 20,
                                    backgroundImage: NetworkImage(
                                        profile['Profile_Picture']),
                                    backgroundColor: Colors.transparent,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Flexible(
                                child: Text(
                                  profile['Profile_Name'],
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.kodchasan(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'ราคา: ${NumberFormat("#,###").format(profile['Points'])}',
                                style: GoogleFonts.kodchasan(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 8),
                              isOwned
                                  ? Text(
                                      'ซื้อแล้ว',
                                      style: GoogleFonts.kodchasan(
                                          color: Colors.pinkAccent),
                                    )
                                  : ElevatedButton(
                                      onPressed: () =>
                                          _showPurchaseConfirmation(
                                              context, profile),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.pinkAccent[100],
                                        foregroundColor: Colors.black,
                                        textStyle: GoogleFonts.kodchasan(),
                                      ),
                                      child: Text(
                                        'ซื้อ',
                                        style: TextStyle(color: Colors.black),
                                      ),
                                    ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
