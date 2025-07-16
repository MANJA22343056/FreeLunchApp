import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:intl/intl.dart'; // Untuk format tanggal
import 'package:freeluchapp/app_drawer.dart'; // Pastikan path ini benar untuk AppDrawer admin
import 'package:freeluchapp/admin/laporan_makan_siang_page.dart'; // Untuk navigasi "Lihat Semua"

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Variabel untuk menyimpan data dashboard
  int _totalSekolah = 0;
  int _totalJadwalMakan = 0;
  int _totalTerkonfirmasi = 0;
  int _totalBelumKonfirmasi = 0; // Mengganti nama variabel
  List<Map<String, dynamic>> _jadwalTerbaru =
      []; // Menggunakan dynamic untuk menuDetails

  bool _isLoading = true; // Mengganti nama variabel
  String _errorMessage = ''; // Mengganti nama variabel

  // Cache untuk nama sekolah agar tidak query berulang
  final Map<String, String> _schoolNamesCache = {};

  @override
  void initState() {
    super.initState();
    _fetchDashboardData(); // Panggil fungsi untuk mengambil data saat initState
  }

  // Fungsi async untuk mengambil data dashboard
  Future<void> _fetchDashboardData() async {
    if (!mounted) return; // Pastikan widget masih mounted sebelum setState

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Total Sekolah
      QuerySnapshot schoolSnapshot =
          await _firestore.collection('schools').get();
      _totalSekolah = schoolSnapshot.docs.length;

      // Cache nama sekolah
      for (var doc in schoolSnapshot.docs) {
        _schoolNamesCache[doc.id] =
            doc.get('name') ?? 'Nama Sekolah Tidak Tersedia';
      }

      // 2. Total Jadwal Makan (dari daily_menus)
      QuerySnapshot dailyMenuSnapshot =
          await _firestore.collection('daily_menus').get();
      _totalJadwalMakan = dailyMenuSnapshot.docs.length;

      // 3. Total Terkonfirmasi dan Belum Konfirmasi (dari meal_confirmations)
      QuerySnapshot mealConfirmationSnapshot =
          await _firestore.collection('meal_confirmations').get();
      int confirmedCount = 0;
      int pendingCancelledCount = 0;

      for (var doc in mealConfirmationSnapshot.docs) {
        String status = doc.get('status') ?? 'Pending';
        if (status == 'Confirmed') {
          confirmedCount++;
        } else {
          pendingCancelledCount++;
        }
      }
      _totalTerkonfirmasi = confirmedCount;
      _totalBelumKonfirmasi = pendingCancelledCount;

      // 4. Jadwal Terbaru (Ambil dari meal_confirmations dan daily_menus)
      // Ambil 5 konfirmasi makan terbaru, kemudian ambil detail menu dan sekolah
      QuerySnapshot latestConfirmations = await _firestore
          .collection('meal_confirmations')
          .orderBy('date', descending: true)
          .limit(5) // Ambil 5 data terbaru
          .get();

      List<Map<String, dynamic>> tempJadwalTerbaru = [];
      for (var doc in latestConfirmations.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        Timestamp? dateTimestamp = data['date'] as Timestamp?;
        String tanggal = dateTimestamp != null
            ? DateFormat('dd MMM yyyy').format(dateTimestamp.toDate())
            : 'Tanggal Tidak Tersedia';

        String schoolId = data['schoolId'] ?? '';
        String sekolahName = _schoolNamesCache[schoolId] ??
            'Memuat Sekolah...'; // Ambil dari cache

        Map<String, dynamic> menuDetails = data['menuDetails'] ?? {};
        String menu = menuDetails['foodName'] ?? 'Menu Tidak Tersedia';

        String status = data['status'] ?? 'Pending';

        tempJadwalTerbaru.add({
          "tanggal": tanggal,
          "sekolah": sekolahName,
          "menu": menu,
          "status": status,
        });
      }
      _jadwalTerbaru = tempJadwalTerbaru;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data dashboard: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFDDEEFF),
        elevation: 2,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: const Text('Dashboard', style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchDashboardData, // Tombol refresh data
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1F355D),
      drawer: const AppDrawer(), // Menggunakan AppDrawer (untuk Admin)
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Section Info Cards
                      _buildInfoCardsSection(),
                      const SizedBox(height: 24),

                      // Section Jadwal Terbaru
                      _jadwalTerbaruSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCardsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _infoCard(Icons.school, "Total Sekolah", _totalSekolah),
        _infoCard(
            Icons.calendar_today, "Total Jadwal Makan", _totalJadwalMakan),
        _infoCard(Icons.check_circle, "Terkonfirmasi", _totalTerkonfirmasi),
        _infoCard(Icons.cancel, "Belum Konfirmasi", _totalBelumKonfirmasi),
      ],
    );
  }

  Widget _infoCard(IconData icon, String label, int value) {
    return Expanded(
      // Gunakan Expanded agar kartu menyesuaikan lebar
      child: Card(
        color: const Color(0xFF2C4A7A), // Warna sedikit berbeda agar menonjol
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: Colors.white24,
            width: 0.5,
          ), // Border lebih halus
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 28,
              ), // Ukuran icon lebih besar
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ), // Warna teks lebih lembut
              ),
              const SizedBox(height: 4),
              Text(
                value.toString(), // Menampilkan nilai dinamis
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ), // Ukuran dan gaya nilai
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jadwalTerbaruSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF2C4A7A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 0.5),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16), // Padding lebih besar
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Jadwal Terbaru",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                InkWell(
                  onTap: () {
                    // Navigasi ke halaman Laporan Makan Siang
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LaporanMakanSiangPage(),
                      ),
                    );
                  },
                  child: const Text(
                    "Lihat Semua >",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          // Memastikan ada padding di bawah judul sebelum daftar jadwal
          const SizedBox(height: 8),
          // Menggunakan ListView.builder jika data jadwal banyak untuk performa
          if (_jadwalTerbaru.isEmpty) // Menggunakan _jadwalTerbaru
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'Tidak ada jadwal terbaru.',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            // Gunakan Column untuk menampilkan daftar widget, tidak perlu spread operator
            Column(
              children: _jadwalTerbaru.map((jadwal) {
                // Menggunakan _jadwalTerbaru
                return _jadwalRow(
                  jadwal["tanggal"]!,
                  jadwal["sekolah"]!,
                  jadwal["menu"]!,
                  jadwal["status"]!,
                );
              }).toList(), // Pastikan toList() dipanggil
            ),
          const SizedBox(height: 8), // Padding di bawah daftar jadwal
        ],
      ),
    );
  }

  Widget _jadwalRow(
    String tanggal,
    String sekolah,
    String menu,
    String status,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ), // Padding lebih besar
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              tanggal,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              sekolah,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              menu,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              status,
              style: TextStyle(
                color: status.toLowerCase().contains("belum")
                    ? Colors.redAccent
                    : Colors.greenAccent,
                fontSize: 13,
                fontWeight: FontWeight.bold, // Status lebih menonjol
              ),
            ),
          ),
        ],
      ),
    );
  }
}
