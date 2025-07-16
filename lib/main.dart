// main.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:flutter/material.dart';
import 'package:freeluchapp/firebase_options.dart'; // Pastikan path ini benar
import 'package:freeluchapp/guru/home_page_guru.dart'; // Import HomePageGuru
import 'package:freeluchapp/admin/dashboard_page.dart'; // Import DashboardPage
import 'package:freeluchapp/login.dart'; // Import SimpleLoginPage
import 'package:intl/date_symbol_data_local.dart'; // Import untuk inisialisasi data lokal
import 'package:flutter_localizations/flutter_localizations.dart'; // Import untuk delegates lokal

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('id', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Freen Lunch App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US'), Locale('id', 'ID')],
      home: const AuthWrapper(), // Gunakan AuthWrapper
    );
  }
}

class AuthWrapper extends StatefulWidget {
  // Mengubah menjadi StatefulWidget
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // Tambahkan variabel untuk role dan status loading
  String? _userRole;
  bool _isRoleLoading = true;
  String? _roleErrorMessage;

  // Listener untuk perubahan status autentikasi
  late Stream<User?> _authStateChanges;

  @override
  void initState() {
    super.initState();
    _authStateChanges = FirebaseAuth.instance.authStateChanges();
    // Panggil _fetchUserRole setiap kali status auth berubah
    _authStateChanges.listen((user) {
      if (user != null) {
        _fetchUserRole(user.uid);
      } else {
        // Jika user logout, reset state
        if (mounted) {
          setState(() {
            _userRole = null;
            _isRoleLoading = false;
            _roleErrorMessage = null;
          });
        }
      }
    });
  }

  Future<void> _fetchUserRole(String uid) async {
    print('AUTH_WRAPPER_DEBUG: Memuat peran pengguna untuk UID: $uid');
    if (!mounted) return;

    setState(() {
      _isRoleLoading = true;
      _roleErrorMessage = null;
    });

    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        String fetchedRole = userDoc.get('role') ?? 'unknown';
        print('AUTH_WRAPPER_DEBUG: Peran pengguna ditemukan: $fetchedRole');
        if (mounted) {
          setState(() {
            _userRole = fetchedRole
                .toLowerCase(); // Simpan dalam lowercase untuk konsistensi
          });
        }
      } else {
        print(
            'AUTH_WRAPPER_DEBUG: Dokumen pengguna tidak ditemukan untuk UID: $uid. Mengatur peran ke "unknown".');
        if (mounted) {
          setState(() {
            _userRole = 'unknown'; // Peran default jika dokumen tidak ada
            _roleErrorMessage =
                'Data profil Anda tidak ditemukan. Hubungi administrator.';
          });
        }
        // Opsional: Logout user jika profil Firestore tidak ada
        // await FirebaseAuth.instance.signOut();
      }
    } catch (e) {
      print('AUTH_WRAPPER_DEBUG: Error memuat peran pengguna: $e');
      if (mounted) {
        setState(() {
          _userRole = null;
          _roleErrorMessage = 'Gagal memuat peran pengguna: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRoleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Tentukan tipe StreamBuilder secara eksplisit
      stream: _authStateChanges, // Gunakan stream yang sudah di-listen
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            _isRoleLoading) {
          print(
              'AUTH_WRAPPER_DEBUG: Menunggu status autentikasi atau peran...');
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          print(
              'AUTH_WRAPPER_DEBUG: Terjadi error pada stream autentikasi: ${snapshot.error}');
          return Scaffold(
            body: Center(child: Text('Error Autentikasi: ${snapshot.error}')),
          );
        } else if (snapshot.hasData) {
          final user = snapshot.data;
          print(
              'AUTH_WRAPPER_DEBUG: Pengguna LOGIN: ${user?.email ?? 'Unknown User'}');

          if (_roleErrorMessage != null) {
            // Jika ada error dalam memuat peran
            return Scaffold(
              body: Center(
                  child: Text(_roleErrorMessage!, textAlign: TextAlign.center)),
            );
          } else if (_userRole == 'admin') {
            print('AUTH_WRAPPER_DEBUG: Mengarahkan ke Dashboard Admin.');
            return const DashboardPage();
          } else if (_userRole == 'guru') {
            print('AUTH_WRAPPER_DEBUG: Mengarahkan ke HomePage Guru.');
            return const HomePageGuru();
          } else {
            print(
                'AUTH_WRAPPER_DEBUG: Peran tidak dikenal atau kosong ($_userRole). Mengarahkan ke halaman login.');
            // Jika peran tidak ditemukan atau tidak valid, arahkan kembali ke login
            // Opsional: Lakukan logout otomatis di sini jika peran tidak valid
            // FirebaseAuth.instance.signOut();
            return SimpleLoginPage();
          }
        } else {
          print('AUTH_WRAPPER_DEBUG: Pengguna LOGOUT / BELUM LOGIN.');
          return SimpleLoginPage();
        }
      },
    );
  }
}
