import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:collecting_book/config.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MessageScreen extends StatefulWidget {
  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> messages = [];
  String filter = 'all';

  List<Map<String, dynamic>> get filteredMessages {
    if (filter == 'all') return messages;
    return messages.where((msg) => msg['type'] == filter).toList();
  }

  @override
  void initState() {
    super.initState();
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('User_ID');

    final response = await http.post(
      Uri.parse('$baseUrl/msg.php'),
      body: {'User_ID': userId},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        isLoading = false;
        messages =
            List<Map<String, dynamic>>.from(data['messages']).map((message) {
          String prefix = message['type'] == 'reports'
              ? 'แจ้งปัญหา'
              : 'คำร้องขอเพิ่มหนังสือ';
          return {...message, 'prefix': prefix};
        }).toList();
      });
    } else {
      setState(() {
        isLoading = false;
        messages = [
          {
            'type': 'error',
            'message': 'ไม่สามารถดึงข้อมูลได้',
            'status': '',
            'prefix': 'Error'
          }
        ];
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ดำเนินการแล้ว':
        return Color.fromARGB(255, 0, 188, 140);
      case 'ยังไม่ดำเนินการ':
        return Color.fromARGB(255, 241, 156, 16);
      case 'ปฏิเสธ':
        return Color.fromARGB(255, 232, 76, 61);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'กล่องข้อความ',
          style: GoogleFonts.kodchasan(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        backgroundColor: Color.fromARGB(255, 254, 176, 216),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              value: filter,
              onChanged: (value) {
                setState(() {
                  filter = value ?? 'all';
                });
              },
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(
                    'ทั้งหมด',
                    style: GoogleFonts.kodchasan(),
                  ),
                ),
                DropdownMenuItem(
                  value: 'reports',
                  child: Text(
                    'แจ้งปัญหา',
                    style: GoogleFonts.kodchasan(),
                  ),
                ),
                DropdownMenuItem(
                  value: 'requests',
                  child: Text(
                    'คำร้องขอเพิ่มหนังสือ',
                    style: GoogleFonts.kodchasan(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: EdgeInsets.all(16.0),
                    itemCount: filteredMessages.length,
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          ListTile(
                            title: Text(
                              '${filteredMessages[index]['prefix']}: ${filteredMessages[index]['message']}',
                              style: GoogleFonts.kodchasan(
                                fontSize: 16.0,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'สถานะ: ${filteredMessages[index]['status']}',
                                  style: GoogleFonts.kodchasan(
                                    color: _getStatusColor(
                                        filteredMessages[index]['status']),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'วันที่: ${filteredMessages[index]['date']}',
                                  style: GoogleFonts.kodchasan(
                                    fontSize: 14.0,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {},
                          ),
                          Divider(),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
