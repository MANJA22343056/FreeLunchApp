import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Untuk format tanggal
import 'package:freeluchapp/app_drawer_guru.dart'; // Drawer untuk navigasi guru
// import 'package:freeluchapp/chatbot_screen.dart'; // Jika ChatBotScreen digunakan, pastikan import ini ada

class HomePageGuru extends StatefulWidget {
  const HomePageGuru({super.key});

  @override
  State<HomePageGuru> createState() => _HomePageGuruState();
}

class _HomePageGuruState extends State<HomePageGuru> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _userName = 'Pengguna';
  String _userSchoolId = '';
  int _confirmedStudentsToday = 0;
  String _menuToday = 'Memuat menu...'; // Ubah initial state
  List<Map<String, dynamic>> _confirmedMealListToday =
      []; // Daftar siswa yang sudah dikonfirmasi makan
  final Map<String, String> _studentNamesCache = {}; // Cache untuk nama siswa

  bool _isLoading = true; // State untuk loading dashboard

  @override
  void initState() {
    super.initState();
    _loadUserDataAndDashboard();
  }

  // Fungsi untuk memuat data pengguna dan data dashboard
  Future<void> _loadUserDataAndDashboard() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      print("Tidak ada pengguna yang login.");
      // TODO: Tambahkan logika navigasi ke halaman login jika user tidak login
      return;
    }

    try {
      // 1. Ambil data user dari Firestore untuk mendapatkan nama dan schoolId
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          _userName = userDoc.get('name') ?? currentUser.email ?? 'Pengguna';
          _userSchoolId = userDoc.get('schoolId') ?? '';
        });

        if (_userSchoolId.isNotEmpty) {
          await _fetchDashboardData(
              _userSchoolId); // Ambil data dashboard jika schoolId ditemukan
        } else {
          setState(() {
            _menuToday = 'Anda belum terhubung ke sekolah mana pun.';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _userName = currentUser.email ?? 'Pengguna';
          _menuToday = 'Data profil Anda tidak ditemukan.';
          _isLoading = false;
        });
        print(
            "Dokumen user tidak ditemukan di Firestore untuk UID: ${currentUser.uid}");
      }
    } catch (e) {
      print("Error memuat data pengguna atau dashboard: $e");
      if (mounted) {
        setState(() {
          _userName = currentUser.email ?? 'Pengguna';
          _menuToday = 'Gagal memuat data dashboard.';
          _isLoading = false;
        });
      }
    }
  }

  // Fungsi untuk mengambil data dashboard (jumlah siswa makan dan menu hari ini)
  Future<void> _fetchDashboardData(String schoolId) async {
    DateTime now = DateTime.now();
    // Atur tanggal ke awal hari ini untuk kueri yang akurat
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    try {
      // 1. Ambil konfirmasi makan hari ini (status Confirmed)
      QuerySnapshot confirmedMealsSnapshot = await _firestore
          .collection('meal_confirmations')
          .where('schoolId', isEqualTo: schoolId)
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThanOrEqualTo: endOfDay)
          .where('status', isEqualTo: 'Confirmed')
          .get();

      // 2. Ambil daftar menu hari ini
      QuerySnapshot dailyMenuSnapshot = await _firestore
          .collection('daily_menus')
          .where('schoolId', isEqualTo: schoolId)
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThanOrEqualTo: endOfDay)
          .limit(1) // Harusnya hanya ada 1 dokumen menu per sekolah per hari
          .get();

      // 3. Ambil nama siswa yang dikonfirmasi
      List<String> confirmedStudentIds = confirmedMealsSnapshot.docs
          .map((doc) => doc.get('studentId') as String)
          .toList();
      await _fetchStudentNamesBatch(
          confirmedStudentIds); // Pre-fetch nama siswa

      List<Map<String, dynamic>> tempConfirmedMealList = [];
      for (var doc in confirmedMealsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String studentId = data['studentId'] ?? '';
        String studentName = _studentNamesCache[studentId] ?? 'Memuat Nama...';

        Map<String, dynamic> menuDetails = data['menuDetails'] ?? {};
        String menuFoodName = menuDetails['foodName'] ?? 'Menu Tidak Tersedia';

        tempConfirmedMealList.add({
          'studentName': studentName,
          'menuFoodName': menuFoodName,
        });
      }

      if (mounted) {
        setState(() {
          _confirmedStudentsToday = confirmedMealsSnapshot.docs.length;
          _confirmedMealListToday = tempConfirmedMealList;

          if (dailyMenuSnapshot.docs.isNotEmpty) {
            List<dynamic> menuItems =
                dailyMenuSnapshot.docs.first.get('menuItems');
            if (menuItems.isNotEmpty) {
              _menuToday = menuItems
                  .map((item) => item['foodName']?.toString() ?? '')
                  .join(', ');
              if (_menuToday.isEmpty) {
                _menuToday = 'Menu belum tersedia.';
              }
            } else {
              _menuToday = 'Menu belum tersedia.';
            }
          } else {
            _menuToday = 'Menu belum tersedia.';
          }
          _isLoading = false; // Selesai loading
        });
      }
    } catch (e) {
      print("Error mengambil data dashboard: $e");
      if (mounted) {
        setState(() {
          _confirmedStudentsToday = 0;
          _menuToday = 'Gagal memuat menu atau jumlah siswa.';
          _confirmedMealListToday = []; // Clear list on error
          _isLoading = false;
        });
      }
    }
  }

  // Fungsi untuk mengambil nama siswa dalam batch
  Future<void> _fetchStudentNamesBatch(List<String> studentIds) async {
    if (studentIds.isEmpty) return;

    const int batchSize = 10; // Firebase `whereIn` limit
    List<Future<QuerySnapshot>> futures = [];

    for (int i = 0; i < studentIds.length; i += batchSize) {
      final end = (i + batchSize < studentIds.length)
          ? i + batchSize
          : studentIds.length;
      final batchIds = studentIds.sublist(i, end);
      if (batchIds.isNotEmpty) {
        futures.add(_firestore
            .collection('students')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get());
      }
    }

    try {
      List<QuerySnapshot> snapshots = await Future.wait(futures);
      if (mounted) {
        setState(() {
          // setState di sini untuk update cache
          for (var snapshot in snapshots) {
            for (var doc in snapshot.docs) {
              _studentNamesCache[doc.id] =
                  doc.get('name') ?? 'Nama Tidak Tersedia';
            }
          }
        });
      }
    } catch (e) {
      print("Error fetching student names in batch: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Free Lunch App'),
        backgroundColor: Colors.blueAccent,
        actions: [
          // IconButton( // Komen atau hapus jika ChatBotScreen tidak ada
          //   icon: const Icon(Icons.chat_bubble_outline), // Ikon chat
          //   onPressed: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (context) => const ChatBotScreen()),
          //     );
          //   },
          // ),
        ],
      ),
      drawer: const AppDrawerGuru(), // Menggunakan drawer untuk navigasi guru
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator()) // Tampilkan loading indicator
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat Datang, $_userName !',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          color: Colors.blue[100],
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.people,
                                    size: 40, color: Colors.blue),
                                const SizedBox(height: 10),
                                const Text('Siswa Makan Hari Ini',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 5),
                                Text('$_confirmedStudentsToday Siswa',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          color: Colors.lightGreen[100],
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.restaurant_menu,
                                    size: 40, color: Colors.lightGreen),
                                const SizedBox(height: 10),
                                const Text('Menu Hari Ini',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 5),
                                Text(_menuToday,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.lightGreen)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Informasi Terkini (Daftar siswa yang sudah makan)
                  const Text(
                    'Siswa Terkonfirmasi Makan Hari Ini:',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _confirmedMealListToday.isEmpty
                        ? Center(
                            child: Text(
                            'Tidak ada siswa yang terkonfirmasi makan hari ini.',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ))
                        : ListView.builder(
                            itemCount: _confirmedMealListToday.length,
                            itemBuilder: (context, index) {
                              final meal = _confirmedMealListToday[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                elevation: 2,
                                child: ListTile(
                                  leading: const Icon(Icons.person,
                                      color: Colors.blue),
                                  title: Text(meal['studentName'] ??
                                      'Siswa Tidak Dikenal'),
                                  subtitle: Text(
                                      'Menu: ${meal['menuFoodName'] ?? 'Tidak Tersedia'}'),
                                  trailing: const Icon(Icons.check_circle,
                                      color: Colors.green),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
