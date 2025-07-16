import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:freeluchapp/app_drawer_guru.dart'; // Pastikan path ini benar

class KonfirmasiMakanSiswa extends StatefulWidget {
  const KonfirmasiMakanSiswa({super.key});

  @override
  State<KonfirmasiMakanSiswa> createState() => _KonfirmasiMakanSiswaState();
}

class _KonfirmasiMakanSiswaState extends State<KonfirmasiMakanSiswa> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _userSchoolId = '';
  DateTime _selectedDate =
      DateTime.now(); // Tanggal yang dipilih untuk melihat konfirmasi
  Stream<QuerySnapshot>?
      _mealConfirmationsStream; // Stream untuk data konfirmasi makan

  // Mengganti _isLoadingInitialData menjadi _isLoadingSchoolId
  bool _isLoadingSchoolId = true; // Untuk memuat schoolId awal

  final Map<String, String> _studentNamesCache = {}; // Cache untuk nama siswa

  final TextEditingController _searchController =
      TextEditingController(); // Controller untuk search bar

  @override
  void initState() {
    super.initState();
    print('DEBUG: initState dimulai.');
    _loadUserSchoolIdAndInitialStream();
    _searchController.addListener(_onSearchChanged);
    print('DEBUG: initState selesai.');
  }

  @override
  void dispose() {
    print('DEBUG: dispose dimulai.');
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
    print('DEBUG: dispose selesai.');
  }

  void _onSearchChanged() {
    print(
        'DEBUG: _onSearchChanged dipicu. Query saat ini: ${_searchController.text}');
    if (mounted) {
      setState(() {
        // Cukup panggil setState untuk memicu pembangunan ulang dan pemfilteran
        // Data akan difilter ulang berdasarkan _searchController.text
      });
    }
  }

  Future<void> _loadUserSchoolIdAndInitialStream() async {
    print('DEBUG: _loadUserSchoolIdAndInitialStream dimulai.');
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      print(
          "DEBUG: Tidak ada pengguna yang login. Mengatur _isLoadingSchoolId ke false.");
      if (mounted) {
        setState(() {
          _isLoadingSchoolId = false; // Mengatur _isLoadingSchoolId
        });
      }
      return;
    }

    try {
      print("DEBUG: Mencoba mendapatkan userDoc untuk UID: ${currentUser.uid}");
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (userDoc.exists && userDoc.data() != null) {
        String fetchedSchoolId = userDoc.get('schoolId') ?? '';
        print("DEBUG: userDoc ditemukan. schoolId: $fetchedSchoolId");
        if (mounted) {
          setState(() {
            _userSchoolId = fetchedSchoolId;
            _isLoadingSchoolId = false; // Mengatur _isLoadingSchoolId
          });
        }
        if (_userSchoolId.isNotEmpty) {
          print(
              "DEBUG: schoolId ditemukan. Memperbarui meal confirmation stream.");
          _updateMealConfirmationStream(_selectedDate);
        } else {
          print(
              "DEBUG: Guru tidak terhubung ke sekolah mana pun. Mengatur _isLoadingSchoolId ke false.");
          if (mounted) {
            setState(() {
              _isLoadingSchoolId = false; // Mengatur _isLoadingSchoolId
            });
          }
        }
      } else {
        print(
            "DEBUG: Dokumen user tidak ditemukan untuk UID: ${currentUser.uid}. Mengatur _isLoadingSchoolId ke false.");
        if (mounted) {
          setState(() {
            _isLoadingSchoolId = false; // Mengatur _isLoadingSchoolId
          });
        }
      }
    } catch (e) {
      print("DEBUG ERROR: Error memuat ID sekolah pengguna: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data awal: $e')),
        );
        setState(() {
          _isLoadingSchoolId = false; // Mengatur _isLoadingSchoolId
        });
      }
    }
  }

  void _updateMealConfirmationStream(DateTime date) {
    print('DEBUG: _updateMealConfirmationStream dimulai untuk tanggal: $date');
    if (_userSchoolId.isEmpty) {
      print(
          'DEBUG: _userSchoolId kosong di _updateMealConfirmationStream. Mengatur _isLoadingSchoolId ke false.');
      if (mounted) {
        setState(() {
          _mealConfirmationsStream = null;
          // Tidak perlu mengubah _isLoadingSchoolId di sini, itu sudah diurus oleh _loadUserSchoolIdAndInitialStream
        });
      }
      return;
    }

    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    print(
        'DEBUG: Mencari konfirmasi makan antara $startOfDay dan $endOfDay untuk schoolId: $_userSchoolId');

    // Hapus setState(_isLoadingInitialData = true) di sini
    // if (mounted) {
    //   setState(() {
    //     _isLoadingInitialData = true;
    //   });
    // }

    try {
      Query query = _firestore
          .collection('meal_confirmations')
          .where('schoolId', isEqualTo: _userSchoolId)
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThanOrEqualTo: endOfDay);

      _mealConfirmationsStream = query.snapshots();
      print(
          'DEBUG: Stream meal_confirmations diinisialisasi. Menunggu snapshot...');

      _mealConfirmationsStream!.listen((snapshot) async {
        print(
            'DEBUG: Snapshot meal_confirmations diterima! Jumlah dokumen: ${snapshot.docs.length}');
        if (snapshot.docs.isNotEmpty) {
          Set<String> uniqueStudentIds = {};
          for (var doc in snapshot.docs) {
            String studentId = doc.get('studentId') ?? '';
            if (studentId.isNotEmpty) {
              uniqueStudentIds.add(studentId);
            }
          }
          print(
              'DEBUG: Ditemukan ${uniqueStudentIds.length} ID siswa unik. Memulai pre-fetching nama siswa.');
          await _fetchStudentNamesBatch(uniqueStudentIds.toList());
          print('DEBUG: Pre-fetching nama siswa selesai.');
        } else {
          print('DEBUG: Snapshot meal_confirmations kosong.');
        }

        if (mounted) {
          setState(() {
            // Hapus _isLoadingInitialData = false di sini, StreamBuilder akan menangani loading
            print(
                'DEBUG: setState dipanggil setelah stream listener (untuk memicu rebuild).');
          });
        }
      }).onError((error) {
        print("DEBUG ERROR: Error di stream konfirmasi makan: $error");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat konfirmasi makan: $error')),
          );
          setState(() {
            // Tidak perlu mengubah _isLoadingSchoolId di sini
            print('DEBUG: setState dipanggil karena error stream.');
          });
        }
      });
    } catch (e) {
      print(
          "DEBUG ERROR: Error mengatur stream konfirmasi makan (di luar listen): $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat konfirmasi makan: $e')),
        );
        setState(() {
          // Tidak perlu mengubah _isLoadingSchoolId di sini
          print('DEBUG: setState dipanggil karena error pengaturan stream.');
        });
      }
    }
  }

  Future<void> _fetchStudentNamesBatch(List<String> studentIds) async {
    print(
        'DEBUG: _fetchStudentNamesBatch dimulai. Jumlah ID siswa: ${studentIds.length}');
    if (studentIds.isEmpty) {
      print('DEBUG: studentIds kosong, tidak ada nama siswa untuk diambil.');
      return;
    }

    const int batchSize = 10;
    List<Future<QuerySnapshot>> futures = [];

    for (int i = 0; i < studentIds.length; i += batchSize) {
      final end = (i + batchSize < studentIds.length)
          ? i + batchSize
          : studentIds.length;
      final batchIds = studentIds.sublist(i, end);
      if (batchIds.isNotEmpty) {
        print(
            'DEBUG: Menambahkan batch kueri students dengan ${batchIds.length} ID: $batchIds'); // Log IDs being queried
        futures.add(_firestore
            .collection('students')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get());
      }
    }

    try {
      List<QuerySnapshot> snapshots = await Future.wait(futures);
      print(
          'DEBUG: Semua batch kueri students selesai. Memproses snapshots...');
      if (mounted) {
        setState(() {
          for (var snapshot in snapshots) {
            for (var doc in snapshot.docs) {
              _studentNamesCache[doc.id] =
                  doc.get('name') ?? 'Nama Tidak Ditemukan';
              print(
                  'DEBUG: Menambahkan ke cache: ${doc.id} -> ${doc.get('name') ?? 'Nama Tidak Ditemukan'}'); // Log each addition
            }
          }
          print(
              'DEBUG: studentNamesCache diperbarui. Cache size: ${_studentNamesCache.length}');
          _studentNamesCache.forEach((key, value) {
            print(
                'DEBUG: Cache content: $key = $value'); // Log full cache content
          });
        });
      }
    } catch (e) {
      print("DEBUG ERROR: Error fetching student names in batch: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat nama siswa: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    print('DEBUG: _selectDate dipicu. Tanggal saat ini: $_selectedDate');
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null && picked != _selectedDate) {
      print('DEBUG: Tanggal baru dipilih: $picked');
      if (mounted) {
        setState(() {
          _selectedDate = picked;
        });
      }
      _updateMealConfirmationStream(_selectedDate);
    } else {
      print('DEBUG: Pemilihan tanggal dibatalkan atau tanggal tidak berubah.');
    }
  }

  Future<void> _updateMealStatus(String docId, String newStatus) async {
    print(
        'DEBUG: Memperbarui status makan untuk docId: $docId menjadi: $newStatus');
    final String currentUserId = _auth.currentUser?.uid ?? 'unknown';
    try {
      await _firestore.collection('meal_confirmations').doc(docId).update({
        'status': newStatus,
        'confirmedBy': currentUserId,
        'confirmedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      print('DEBUG: Status makan berhasil diperbarui.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Status makan berhasil diubah menjadi "$newStatus"!')),
        );
      }
    } catch (e) {
      print('DEBUG ERROR: Gagal memperbarui status makan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate =
        DateFormat('EEEE, dd MMMM \u2022', 'id_ID').format(_selectedDate);
    print(
        'DEBUG: Widget build dipicu. _isLoadingSchoolId (sebelum Expanded): $_isLoadingSchoolId'); // Perbarui nama variabel

    return Scaffold(
      backgroundColor: const Color(0xFF1F365D),
      appBar: AppBar(
        backgroundColor: const Color(0xFFCCE6FF),
        title: const Text(
          'Konfirmasi Makan Siswa',
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
      drawer: const AppDrawerGuru(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) => _onSearchChanged(),
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Cari Siswa',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tanggal: $formattedDate',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.blueGrey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: () {
                // Using an IIFE to log which branch is taken
                if (_isLoadingSchoolId) {
                  // Perbarui nama variabel
                  print(
                      'DEBUG: Expanded showing initial CircularProgressIndicator (from _isLoadingSchoolId).');
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.white));
                } else if (_userSchoolId.isEmpty) {
                  print(
                      'DEBUG: Expanded showing "Guru tidak terhubung..." message.');
                  return const Center(
                      child: Text('Guru tidak terhubung ke sekolah mana pun.',
                          style: TextStyle(color: Colors.white)));
                } else {
                  print('DEBUG: Expanded showing StreamBuilder.');
                  return StreamBuilder<QuerySnapshot>(
                    stream: _mealConfirmationsStream,
                    builder: (context, snapshot) {
                      print(
                          'DEBUG: StreamBuilder ConnectionState di builder: ${snapshot.connectionState}');
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        print(
                            'DEBUG: StreamBuilder showing CircularProgressIndicator (ConnectionState.waiting).');
                        return const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white));
                      }
                      if (snapshot.hasError) {
                        print(
                            'DEBUG ERROR: StreamBuilder error: ${snapshot.error}');
                        return Center(
                            child: Text('Error: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red)));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        print(
                            'DEBUG: StreamBuilder has no data or empty docs.');
                        return Center(
                            child: Text(
                                'Tidak ada catatan makan siswa untuk tanggal ini. Pastikan jadwal menu telah dibuat dan catatan makan otomatis telah digenerate (jika ada).',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.8))));
                      }

                      List<DocumentSnapshot> filteredDocs =
                          snapshot.data!.docs.where((doc) {
                        String studentId = doc.get('studentId') ?? '';
                        // Cek langsung apakah ada di cache, jika tidak ada, log dan filter
                        if (!_studentNamesCache.containsKey(studentId)) {
                          print(
                              'DEBUG: Filtering out item: Student ID "$studentId" not found in cache.');
                          return false; // Filter keluar jika nama tidak ada di cache
                        }
                        String studentName =
                            _studentNamesCache[studentId]!.toLowerCase();
                        return studentName.contains(
                            _searchController.text.trim().toLowerCase());
                      }).toList();

                      if (filteredDocs.isEmpty) {
                        print(
                            'DEBUG: filteredDocs kosong setelah filter. Menampilkan pesan.');
                        return const Center(
                            child: Text(
                                'Tidak ada siswa yang cocok dengan pencarian Anda.',
                                style: TextStyle(color: Colors.white)));
                      }

                      print(
                          'DEBUG: filteredDocs memiliki ${filteredDocs.length} dokumen untuk ditampilkan.');

                      return ListView.builder(
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          DocumentSnapshot doc = filteredDocs[index];
                          Map<String, dynamic> data =
                              doc.data() as Map<String, dynamic>;

                          String studentId = data['studentId'] ?? '';
                          String studentName = _studentNamesCache[studentId] ??
                              'Nama Tidak Ditemukan (Cache Missing)';
                          print(
                              'DEBUG: Rendering item index $index: studentId=$studentId, studentName="$studentName"');

                          String menu = (data['menuDetails'] != null &&
                                  data['menuDetails']['foodName'] != null)
                              ? data['menuDetails']['foodName']
                              : 'Menu Tidak Tersedia';
                          String mealTime = (data['menuDetails'] != null &&
                                  (data['menuDetails']['time'] != null ||
                                      data['menuDetails']['mealType'] != null))
                              ? "${data['menuDetails']['time'] ?? ''} (${data['menuDetails']['mealType'] ?? ''})"
                                  .trim()
                              : 'Waktu/Jenis Makan Tidak Tersedia';
                          String status = data['status'] ?? 'Pending';

                          Color statusBackgroundColor;
                          Color statusTextColor;
                          switch (status) {
                            case 'Confirmed':
                              statusBackgroundColor = Colors.green.shade200;
                              statusTextColor = Colors.green.shade800;
                              break;
                            case 'Cancelled':
                              statusBackgroundColor = Colors.red.shade200;
                              statusTextColor = Colors.red.shade800;
                              break;
                            case 'Pending':
                            default:
                              statusBackgroundColor = Colors.orange.shade200;
                              statusTextColor = Colors.orange.shade800;
                              break;
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            color: const Color(0xFF2C4A7A),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    studentName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Menu: $menu $mealTime',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.8)),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Chip(
                                        label: Text(status),
                                        backgroundColor: statusBackgroundColor,
                                        labelStyle: TextStyle(
                                            color: statusTextColor,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Row(
                                        children: [
                                          ElevatedButton(
                                            onPressed: status == 'Confirmed'
                                                ? null
                                                : () => _updateMealStatus(
                                                    doc.id, 'Confirmed'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8),
                                            ),
                                            child: const Text('Konfirmasi'),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: status == 'Cancelled'
                                                ? null
                                                : () => _updateMealStatus(
                                                    doc.id, 'Cancelled'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8),
                                            ),
                                            child: const Text('Batalkan'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                }
              }(), // Call the IIFE
            ),
          ],
        ),
      ),
    );
  }
}
