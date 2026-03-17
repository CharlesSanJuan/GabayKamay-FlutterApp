import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {

  List data = [];
  bool isLoading = true;
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    fetchDictionary();
  }

  Future<void> fetchDictionary() async {

    final url = Uri.parse(
      "https://YOUR_PROJECT_ID.supabase.co/rest/v1/gesture_dictionary?select=*"
    );

    try {
      final response = await http.get(
        url,
        headers: {
          "apikey": "YOUR_ANON_PUBLIC_KEY",
          "Authorization": "Bearer YOUR_ANON_PUBLIC_KEY",
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          data = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Server error: ${response.statusCode}";
          isLoading = false;
        });
      }

    } catch (e) {
      setState(() {
        errorMessage = "Connection error. Check internet or URL.";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Text(
          errorMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (data.isEmpty) {
      return const Center(child: Text("No data found"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.length,
      itemBuilder: (context, index) {

        final item = data[index];

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              item['word'] ?? "No word",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              item['meaning'] ?? "No meaning",
            ),
          ),
        );
      },
    );
  }
}