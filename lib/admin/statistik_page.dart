import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:intl/intl.dart'; // PASTIKAN IMPORT INI ADA
import 'package:freeluchapp/app_drawer.dart';
import 'package:freeluchapp/admin/laporan_makan_siang_page.dart'; // PASTIKAN IMPORT INI BENAR
import 'package:freeluchapp/widgets/grafik_bar_chart.dart'; // <<< IMPORT WIDGET BARU

class StatistikPage extends StatefulWidget {
  const StatistikPage({super.key});

  @override
  State<StatistikPage> createState() => _StatistikPageState();
}

class _StatistikPageState extends State<StatistikPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Variabel untuk menyimpan data dashboard
  int _totalJadwalMakan = 0;
  int _totalTerkonfirmasi = 0;
  int _totalBelumKonfirmasi = 0;

  // Data untuk chart
  List<SchoolMealStats> _schoolStats = [];
  double _chartMaxYValue = 0; // Tambahkan variabel untuk maxYValue chart

  bool _isLoading = true;
  String _errorMessage = '';

  // Cache untuk nama sekolah agar tidak query berulang, juga digunakan untuk label chart
  final Map<String, String> _schoolIdToName = {};

  // Tambahkan variabel _jadwalTerbaru di sini
  List<Map<String, dynamic>> _jadwalTerbaru = [];

  @override
  void initState() {
    super.initState();
    _fetchStatistikData();
  }

  Future<void> _fetchStatistikData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Ambil semua sekolah dan cache namanya serta inisialisasi hitungan
      QuerySnapshot schoolSnapshot =
          await _firestore.collection('schools').get();
      Map<String, Map<String, int>> schoolMealCounts =
          {}; // {schoolId: {confirmed: X, unconfirmed: Y}}

      _schoolIdToName.clear(); // Bersihkan cache sebelum mengisi ulang

      for (var doc in schoolSnapshot.docs) {
        _schoolIdToName[doc.id] = doc.get('name') ?? 'Sekolah Tak Dikenal';
        schoolMealCounts[doc.id] = {
          'confirmed': 0,
          'unconfirmed': 0
        }; // Inisialisasi hitungan
      }

      // 2. Proses setiap catatan makan
      QuerySnapshot mealConfirmationSnapshot =
          await _firestore.collection('meal_confirmations').get();

      int totalConfirmed = 0;
      int totalPendingCancelled = 0;

      for (var doc in mealConfirmationSnapshot.docs) {
        String status = doc.get('status') ?? 'Pending';
        String schoolId = doc.get('schoolId') ?? '';

        if (schoolMealCounts.containsKey(schoolId)) {
          // Pastikan schoolId ada di daftar sekolah
          if (status == 'Confirmed') {
            totalConfirmed++;
            schoolMealCounts[schoolId]?['confirmed'] =
                (schoolMealCounts[schoolId]?['confirmed'] ?? 0) + 1;
          } else {
            totalPendingCancelled++;
            schoolMealCounts[schoolId]?['unconfirmed'] =
                (schoolMealCounts[schoolId]?['unconfirmed'] ?? 0) + 1;
          }
        }
      }

      // 3. Hitung total jadwal makan (ini bisa lebih akurat jika mengacu ke daily_menus)
      QuerySnapshot dailyMenuSnapshot =
          await _firestore.collection('daily_menus').get();
      _totalJadwalMakan = dailyMenuSnapshot
          .docs.length; // Setiap dokumen daily_menu dianggap 1 jadwal

      // 4. Buat data untuk chart dan hitung maxYValue
      List<SchoolMealStats> tempSchoolStats = [];
      double currentMaxY = 0;
      schoolMealCounts.forEach((schoolId, counts) {
        SchoolMealStats stat = SchoolMealStats(
          schoolId: schoolId,
          schoolName: _schoolIdToName[schoolId] ??
              'Sekolah Tak Dikenal', // Ambil nama dari cache
          confirmed: counts['confirmed'] ?? 0,
          unconfirmed: counts['unconfirmed'] ?? 0,
        );
        tempSchoolStats.add(stat);
        double totalHeight = (stat.confirmed + stat.unconfirmed).toDouble();
        if (totalHeight > currentMaxY) currentMaxY = totalHeight;
      });
      _chartMaxYValue =
          (currentMaxY == 0) ? 5 : currentMaxY; // Minimal 5 jika tidak ada data

      // 5. Ambil data jadwal terbaru untuk section Jadwal Terbaru
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
            ? DateFormat('dd MMM').format(dateTimestamp.toDate())
            : 'Tanggal Tidak Tersedia';

        String schoolId = data['schoolId'] ?? '';
        String sekolahName = _schoolIdToName[schoolId] ??
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

      if (mounted) {
        setState(() {
          _totalTerkonfirmasi = totalConfirmed;
          _totalBelumKonfirmasi = totalPendingCancelled;
          _schoolStats = tempSchoolStats;
          _jadwalTerbaru = tempJadwalTerbaru; // Assign ke variabel state
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching statistik data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data statistik: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFFDDEEFF),
        elevation: 2,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Statistik', style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _fetchStatistikData, // Tombol refresh data
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Container(
                  color: const Color(0xFF1F355D),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildStatBox(),
                      const SizedBox(height: 16),
                      // Memanggil widget Bar Chart yang baru
                      Expanded(
                        // Masih butuh Expanded karena SchoolMealBarChart juga Expanded
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white),
                            color: Colors.transparent,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Jadwal Makan per Sekolah',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: SchoolMealBarChart(
                                  // <<< PANGGIL WIDGET BARU DI SINI
                                  schoolStats: _schoolStats,
                                  maxYValue: _chartMaxYValue,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Legend
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  _LegendItem(
                                      color: Colors.greenAccent,
                                      label: 'Terkonfirmasi'),
                                  SizedBox(width: 16),
                                  _LegendItem(
                                      color: Colors.redAccent,
                                      label: 'Belum Konfirmasi'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white),
        color: Colors.transparent,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
              title: 'Total Jadwal Makan', value: _totalJadwalMakan.toString()),
          _StatItem(
              title: 'Terkonfirmasi', value: _totalTerkonfirmasi.toString()),
          _StatItem(
              title: 'Belum Konfirmasi',
              value: _totalBelumKonfirmasi.toString()),
        ],
      ),
    );
  }

  // _buildChartCard dihapus karena isinya dipindahkan ke SchoolMealBarChart widget

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
            padding: const EdgeInsets.all(16),
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
          if (_jadwalTerbaru.isEmpty)
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
            Column(
              children: _jadwalTerbaru.map((jadwal) {
                return _jadwalRow(
                  jadwal["tanggal"]!,
                  jadwal["sekolah"]!,
                  jadwal["menu"]!,
                  jadwal["status"]!,
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
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
      ),
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
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Class untuk menyimpan statistik makan per sekolah
class SchoolMealStats {
  final String schoolId;
  final String schoolName;
  final int confirmed;
  final int unconfirmed;

  SchoolMealStats({
    required this.schoolId,
    required this.schoolName,
    required this.confirmed,
    required this.unconfirmed,
  });
}

class _StatItem extends StatelessWidget {
  final String title;
  final String value;

  const _StatItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20)),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
