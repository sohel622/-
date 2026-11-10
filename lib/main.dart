// lib/main.dart
// জুনো মিনি — Android-এর জন্য Flutter চ্যাট অ্যাপ
// ডিজাইন: ছবির মতো — সাদা পেজ, উপরে বামে হ্যামবার্গার মেনু,
// মাঝখানে হালকা লোগো, নিচে গোল "Ask anything..." বক্স,
// বক্সে বামে + (ছবি), ডানে মাইক আর উপরের তীর (পাঠাও)।
//
// ধাপ ১: চ্যাট UI (ছবির মতো)
// ধাপ ২: লেখা পাঠানো + উত্তর দেখানো
// ধাপ ৩: + চেপে ছবি বেছে পাঠানো
// ধাপ ৪: API key না থাকলে ডেমো মোডে নিজে উত্তর দেয়
// ধাপ ৫: API key থাকলে আসল AI API-কে ডাকে (api_service.dart)
// সতর্কতা: API key এই কোডে কোথাও লেখা নেই। key শুধু
// অ্যাপের মেনু > Settings-এ লিখবে, ফোনেই সেভ থাকবে।

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

void main() {
  runApp(const JunoMiniApp());
}

class JunoMiniApp extends StatelessWidget {
  const JunoMiniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'জুনো মিনি',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
        useMaterial3: true,
      ),
      home: const ChatPage(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final String? imagePath;
  final DateTime time;
  ChatMessage({required this.text, required this.isUser, this.imagePath})
      : time = DateTime.now();
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isTyping = false;
  bool _hasUserMessage = false;

  // Settings — ফোনে সেভ থাকে, কোডে থাকে না
  String _apiKey = '';
  String _baseUrl = 'https://api.meta.ai/v1';
  String _model = 'muse-spark-1.3';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('api_key') ?? '';
      _baseUrl = prefs.getString('base_url') ?? 'https://api.meta.ai/v1';
      _model = prefs.getString('model') ?? 'muse-spark-1.3';
    });
  }

  Future<void> _saveSettings(String key, String baseUrl, String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', key);
    await prefs.setString('base_url', baseUrl);
    await prefs.setString('model', model);
    setState(() {
      _apiKey = key;
      _baseUrl = baseUrl;
      _model = model;
    });
  }

  void _newChat() {
    setState(() {
      _messages.clear();
      _hasUserMessage = false;
      _isTyping = false;
    });
    Navigator.pop(context); // ড্রয়ার বন্ধ করো
  }

  // Settings ডায়ালগ — এখানেই নতুন key লিখবে, চ্যাটে নয়
  Future<void> _showSettings() async {
    final keyCtrl = TextEditingController(text: _apiKey);
    final urlCtrl = TextEditingController(text: _baseUrl);
    final modelCtrl = TextEditingController(text: _model);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Settings — API'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'নতুন API key এখানে লিখো। পুরোনো key চ্যাটে পাঠানো থাকলে সেটা আর ব্যবহার কোরো না, নতুন key বানাও।',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.meta.ai/v1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'muse-spark-1.3',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'তোমার API অন্য কোম্পানির হলে Base URL আর Model তাদের ডকস অনুযায়ী বদলে নিও।',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _saveSettings('', _baseUrl, _model);
              Navigator.pop(ctx);
            },
            child: const Text('Key মুছো'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('বাতিল'),
          ),
          FilledButton(
            onPressed: () {
              _saveSettings(
                keyCtrl.text.trim(),
                urlCtrl.text.trim(),
                modelCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings সেভ হয়েছে।')),
              );
            },
            child: const Text('সেভ করো'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? file =
        await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      _hasUserMessage = true;
      _messages.add(ChatMessage(
        text: 'এই ছবিটা দেখো তো, এতে কী আছে?',
        isUser: true,
        imagePath: file.path,
      ));
      _isTyping = true;
    });
    if (_apiKey.isEmpty) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text:
              'ছবিটা পেয়েছি। ডেমো মোডে আমি ছবি পড়তে পারি না। মেনু > Settings-এ গিয়ে নতুন API key বসালে ছবি পড়ে বলতে পারবো এতে কী আছে।',
          isUser: false,
        ));
      });
      return;
    }
    try {
      final bytes = await File(file.path).readAsBytes();
      final reply = await ApiService.chat(
        apiKey: _apiKey,
        baseUrl: _baseUrl,
        model: _model,
        userText: 'এই ছবিতে কী আছে, বাংলায় ছোট করে বলো।',
        imageBase64: base64Encode(bytes),
      );
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(text: reply, isUser: false));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text:
              'ছবি পড়তে পারলাম না: $e\nKey, Base URL আর Model ঠিক আছে কিনা Settings-এ দেখো।',
          isUser: false,
        ));
      });
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() {
      _hasUserMessage = true;
      _messages.add(ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });
    if (_apiKey.isEmpty) {
      // ডেমো মোড: ইন্টারনেট ছাড়াই নিজে উত্তর দেয়
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _isTyping = false;
          _messages.add(ChatMessage(text: _localReply(text), isUser: false));
        });
      });
      return;
    }
    ApiService.chat(
      apiKey: _apiKey,
      baseUrl: _baseUrl,
      model: _model,
      userText: text,
    ).then((reply) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(text: reply, isUser: false));
      });
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text:
              'API থেকে উত্তর আসেনি: $e\nSettings-এ Key, Base URL আর Model দেখো।',
          isUser: false,
        ));
      });
    });
  }

  // ডেমো মোডের ছোট মগজ — chatbot.py-র মতোই
  String _localReply(String input) {
    final t = input.toLowerCase();
    if (t.contains('হ্যালো') ||
        t.contains('hello') ||
        t.contains('hi') ||
        t.contains('সালাম') ||
        t.contains('আসসালাম')) {
      return 'হ্যালো সোহেল! কেমন আছো? আমি জুনো মিনি, ডেমো মোডে আছি।';
    }
    if (t.contains('তোমার নাম')) {
      return 'আমার নাম জুনো মিনি। তুমি আমাকে এই নামে ডাকতে পারো।';
    }
    if (t.contains('কেমন আছ')) {
      return 'আমি ভালো আছি, ধন্যবাদ! তুমি কেমন আছো?';
    }
    if (t.contains('সময়') || t.contains('কটা বাজে')) {
      final now = DateTime.now();
      return 'এখন সময় ${now.hour}:${now.minute.toString().padLeft(2, '0')}।';
    }
    if (t.contains('তারিখ') || t.contains('আজ কত')) {
      final now = DateTime.now();
      return 'আজকের তারিখ ${now.day}/${now.month}/${now.year}।';
    }
    if (t.contains('জোক') || t.contains('হাসাও')) {
      return 'শিক্ষক: বলো তো, পৃথিবী গোল কেন?\nছাত্র: স্যার, গোল না হলে আমরা পড়ে যেতাম না?';
    }
    if (t.contains('ধন্যবাদ')) {
      return 'তোমাকেও ধন্যবাদ! আর কিছু জানতে চাও?';
    }
    if (t.contains('বিদায়') || t == 'bye') {
      return 'বিদায় সোহেল, আবার কথা হবে!';
    }
    final math = RegExp(r'(-?\d+(?:\.\d+)?)\s*([+\-*/x×÷])\s*(-?\d+(?:\.\d+)?)')
        .firstMatch(t);
    if (math != null) {
      final a = double.parse(math.group(1)!);
      final b = double.parse(math.group(3)!);
      final op = math.group(2)!;
      double result = 0;
      if (op == '+') result = a + b;
      if (op == '-') result = a - b;
      if (op == '*' || op == 'x' || op == '×') result = a * b;
      if (op == '/' || op == '÷') {
        if (b == 0) return 'শূন্য দিয়ে ভাগ করা যায় না।';
        result = a / b;
      }
      final out = result == result.truncateToDouble()
          ? result.toInt().toString()
          : result.toString();
      return '$a $op $b = $out';
    }
    if (t.contains('কি পারো') || t.contains('সাহায্য')) {
      return 'আমি আড্ডা দিতে পারি, সময়-তারিখ বলতে পারি, জোক বলতে পারি আর সহজ হিসাব করতে পারি। API key বসালে আরও অনেক কিছু পারবো।';
    }
    return 'বুঝেছি: "$input"\nডেমো মোডে আমি শুধু ছোট উত্তর দিতে পারি। আসল AI উত্তর পেতে মেনু > Settings-এ গিয়ে নতুন API key বসাও।';
  }

  Widget _bubble(ChatMessage m) {
    if (m.isUser) {
      // ব্যবহারকারীর মেসেজ: ডানে, হালকা ধূসর বাবল
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m.imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(m.imagePath!), height: 180),
                ),
              if (m.imagePath != null) const SizedBox(height: 8),
              Text(m.text, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      );
    }
    // বটের মেসেজ: বামে, সাদা পেজে সাধারণ লেখা
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Text(m.text, style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final demoMode = _apiKey.isEmpty;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      // উপরে: শুধু হ্যামবার্গার মেনু, ছবির মতো
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            tooltip: 'Settings — API Key',
            onPressed: _showSettings,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.white),
              child: Text(
                'জুনো মিনি',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('নতুন চ্যাট'),
              onTap: _newChat,
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings — API Key'),
              onTap: () {
                Navigator.pop(context);
                _showSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(demoMode
                  ? 'ডেমো মোড — API key বসানো নেই'
                  : 'API মোড — $_model'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _hasUserMessage
                ? ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      ..._messages.map(_bubble),
                      if (_isTyping)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('লিখছে...',
                              style: TextStyle(color: Colors.grey)),
                        ),
                    ],
                  )
                : Center(
                    // মাঝখানে হালকা লোগো, ছবির মতো
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_vintage,
                          size: 140,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'জুনো মিনি',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          demoMode
                              ? 'ডেমো মোড — নিচে লিখে শুরু করো'
                              : 'API মোড — নিচে লিখে শুরু করো',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          // নিচে: গোল "Ask anything..." বক্স, ছবির মতো
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Ask anything...',
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.black),
                          tooltip: 'ছবি দাও',
                          onPressed: _pickImage,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.mic, color: Colors.black),
                          tooltip: 'ভয়েস',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'ভয়েস এখনো আসেনি — এখন লিখে বলো।'),
                              ),
                            );
                          },
                        ),
                        CircleAvatar(
                          backgroundColor: Colors.grey.shade300,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_upward,
                                color: Colors.black),
                            onPressed: _sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
