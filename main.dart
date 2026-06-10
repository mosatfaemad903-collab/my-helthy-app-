import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  cameras = await availableCameras();
  tz.initializeTimeZones();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تطبيق الأدوية والصحه - مصطفى',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Cairo',
        useMaterial3: true,
      ),
      home: AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  String? _verificationId;
  bool _codeSent = false;
  bool _loading = false;

  Future<void> _verifyPhone() async {
    setState(() => _loading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: '+2${_phoneController.text}',
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.message}')));
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _loading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> _signInWithCode() async {
    setState(() => _loading = true);
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: _codeController.text,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('تسجيل الدخول'), centerTitle: true),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services, size: 80, color: Colors.teal),
            SizedBox(height: 20),
            Text('تطبيق الأدوية والصحه', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('مرحباً مصطفى', style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 40),
            if (!_codeSent)
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'رقم الموبايل',
                  prefixText: '+20 ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.phone,
              )
            else
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'كود التحقق',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.number,
              ),
            SizedBox(height: 20),
            _loading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _codeSent ? _signInWithCode : _verifyPhone,
                    child: Text(_codeSent ? 'تأكيد الكود' : 'إرسال الكود'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _waterCount = 0;
  String _userName = 'مصطفى';

  final List<Widget> _screens = [
    MedicationsScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  void _addWater() async {
    setState(() => _waterCount++);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('water_${DateTime.now().day}', _waterCount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مرحباً $_userName 👋'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AuthScreen()));
            },
          )
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.teal,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.medication), label: 'الأدوية'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'الإحصائيات'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'water',
                  onPressed: _addWater,
                  child: Icon(Icons.water_drop),
                  backgroundColor: Colors.blue,
                  tooltip: 'شربت مياه $_waterCount كوب',
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CameraScreen())),
                  child: Icon(Icons.camera_alt),
                ),
              ],
            )
          : null,
    );
  }
}

class MedicationsScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _firestore.collection('users').doc(userId).collection('medications').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var med = snapshot.data!.docs[index];
            return Card(
              margin: EdgeInsets.all(8),
              child: ListTile(
                leading: Icon(Icons.pill, color: Colors.teal),
                title: Text(med['name']),
                subtitle: Text('${med['dosage']} - ${med['time']}'),
                trailing: Checkbox(
                  value: med['taken'] ?? false,
                  onChanged: (val) {
                    _firestore.collection('users').doc(userId).collection('medications').doc(med.id).update({'taken': val});
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class StatsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 100, color: Colors.teal),
          SizedBox(height: 20),
          Text('إحصائياتك اليومية', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Text('نسبة الالتزام: 85%', style: TextStyle(fontSize: 18)),
          Text('أكواب المياه: 6', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: Icon(Icons.person),
          title: Text('تعديل الاسم'),
          subtitle: Text('مصطفى'),
          onTap: () {},
        ),
        ListTile(
          leading: Icon(Icons.notifications),
          title: Text('إعدادات التنبيهات'),
          onTap: () {},
        ),
        ListTile(
          leading: Icon(Icons.info),
          title: Text('حول التطبيق'),
          subtitle: Text('الإصدار 1.0.0'),
        ),
      ],
    );
  }
}

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(cameras[0], ResolutionPreset.medium);
    await _controller.initialize();
    setState(() => _isReady = true);
  }

  Future<void> _scanText() async {
    final image = await _controller.takePicture();
    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    String text = recognizedText.text;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم التعرف على: $text')));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text('مسح علبة الدواء')),
      body: CameraPreview(_controller),
      floatingActionButton: FloatingActionButton(
        onPressed: _scanText,
        child: Icon(Icons.camera),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
