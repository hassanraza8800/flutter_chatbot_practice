import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ProfilePage/profile_page.dart';
import 'Setting/settings_page.dart';
import 'Logout/logout.dart';
import 'services/openrouter_service.dart';
import 'services/openrouter_VisionService.dart';
// ignore: unused_import
import 'Login/login_page.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('userBox');

  final box = Hive.box('userBox');
  final bool isLoggedIn = box.get("isLoggedIn", defaultValue: false);

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: isLoggedIn ? const HomePage() : const LoginPage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _message = [];

  final OpenRouterService _openRouterService = OpenRouterService();
  final OpenRouterVisionService _visionService = OpenRouterVisionService();

  bool _isLoading = false;
  bool _showCamera = false;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  // 🧠 Initialize Camera
  // Future<void> _initCamera() async {
  //   try {
  //     final cameras = await availableCameras();
  //     _cameraController = CameraController(
  //       cameras.first,
  //       ResolutionPreset.medium,
  //     );
  //     await _cameraController!.initialize();
  //     if (mounted) setState(() => _isCameraInitialized = true);
  //   } catch (e) {
  //     debugPrint("Camera init error: $e");
  //   }
  // }

  // // 📸 Take Picture + Analyze + Send to Chat
  // Future<void> _takePicture() async {
  //   if (!_cameraController!.value.isInitialized) return;

  //   try {
  //     setState(() => _isLoading = true);
  //     final image = await _cameraController!.takePicture();

  //     final result = await _visionService.analyzeImage(File(image.path));

  //     // Add camera result as user message
  //     setState(() {
  //       _message.add({'sender': 'user', 'text': '$result  (📸)'});
  //       _showCamera = false;
  //       _isLoading = false;
  //     });

  //     _scrollToBottom();
  //     await _sendMessage(result);
  //   } catch (e) {
  //     setState(() => _isLoading = false);
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text('Error: $e')));
  //   }
  // }
  // image compressor for reducing input tokens
  Future<File> _compressImage(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return file;

    // Resize large images (e.g., 512px wide)
    final resized = img.copyResize(image, width: 512);

    // Compress and overwrite file
    final compressedBytes = img.encodeJpg(resized, quality: 80);
    final newFile = File(file.path)..writeAsBytesSync(compressedBytes);
    return newFile;
  }

  // 📸 Take picture and choose
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: const Text('Would you like to pick an image or capture one?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Camera'),
          ),
        ],
      ),
    );

    if (source == null) return;

    final XFile? picked = await picker.pickImage(source: source);
    if (picked == null) return;

    File imgFile = File(picked.path);

    // ✅ Await compression properly
    imgFile = await _compressImage(imgFile);

    try {
      // ✅ Await result safely
      final result = await _visionService.analyzeImage(imgFile);

      if (!context.mounted) return;

      // ✅ Use mounted check and await showDialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Your Result'),
          content: Text(result ?? 'No response received'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to analyze image: $e'),
        ),
      );
    }
  }

  // 💬 Send Message to Chat API
  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    setState(() {
      _message.add({'sender': 'user', 'text': '$text  (👤)'});
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final botReply = await _openRouterService.sendMessage(text);
      setState(() {
        _message.add({"sender": "bot", "text": "🤖 Unity Bot: $botReply"});
      });
    } catch (e) {
      setState(() {
        _message.add({
          "sender": "bot",
          "text": "⚠️ Error: Unable to fetch response.\n$e",
        });
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  // 🔽 Scroll to Bottom
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _visionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 32),
            const SizedBox(width: 8),
            const Text(
              'Unity',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton(
            icon: Image.asset('assets/ToggleMenu.png', height: 32),
            offset: const Offset(0, 52),
            onSelected: (value) {
              if (value == 'Coupen Generator') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              } else if (value == 'Settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              } else if (value == 'Logout') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LogoutPage()),
                );
              }
            },
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem(
                value: 'Coupen Generator',
                child: Text('Coupen Generator'),
              ),
              PopupMenuItem(value: 'Settings', child: Text('Settings')),
              PopupMenuItem(value: 'Logout', child: Text('Logout')),
            ],
          ),
        ],
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // 👁️ Camera View (Shown inline)
          if (_showCamera)
            Expanded(
              flex: 3,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  if (_isCameraInitialized)
                    CameraPreview(_cameraController!)
                  else
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: FloatingActionButton(
                      backgroundColor: Colors.blueAccent,
                      onPressed: _isLoading ? null : _pickImage,
                      child: const Icon(Icons.camera_alt),
                    ),
                  ),
                ],
              ),
            ),

          // 🧠 Chat Area
          Expanded(
            flex: _showCamera ? 2 : 1,
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _message.length,
              itemBuilder: (context, index) {
                final msg = _message[index];
                final isUser = msg['sender'] == 'user';

                if (isUser) {
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg['text']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }

                // 🤖 Bot message - check for coupon JSON
                List<dynamic>? coupons;
                try {
                  final text = msg['text']!;
                  final jsonStart = text.indexOf('[');
                  final jsonEnd = text.lastIndexOf(']');
                  if (jsonStart != -1 && jsonEnd != -1) {
                    final jsonString = text.substring(jsonStart, jsonEnd + 1);
                    coupons = List<Map<String, dynamic>>.from(
                      jsonDecode(jsonString),
                    );
                  }
                } catch (e) {
                  coupons = null;
                }

                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: coupons == null
                        ? SelectableText(msg['text']!)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '🎟️ Active Coupons',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...coupons.map((coupon) {
                                return Card(
                                  elevation: 3,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(
                                      color: Colors.blueAccent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Code: ${coupon['code'] ?? ''}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          coupon['description'] ?? '',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.blueAccent,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                "${coupon['discount']}% OFF",
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                final url = coupon['link'];
                                                if (url != null &&
                                                    url.isNotEmpty) {
                                                  final uri = Uri.tryParse(url);
                                                  if (uri != null &&
                                                      await canLaunchUrl(uri)) {
                                                    await launchUrl(
                                                      uri,
                                                      mode: LaunchMode
                                                          .externalApplication,
                                                    );
                                                  }
                                                }
                                              },
                                              child: const Text(
                                                "Apply Now",
                                                style: TextStyle(
                                                  color: Colors.blueAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),

          // 📝 Input Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type your message ....',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(_controller.text),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed:
                      _isLoading ? null : () => _sendMessage(_controller.text),
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.blueAccent),
                  onPressed: _isLoading ? null : _pickImage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
