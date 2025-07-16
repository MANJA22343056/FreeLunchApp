import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:intl/intl.dart'; // Untuk format tanggal
import 'package:freeluchapp/app_drawer.dart'; // Pastikan path ini benar untuk AppDrawer admin

// Mengganti MealReport class menjadi Map karena kita akan langsung bekerja dengan Map dari Firestore
// class MealReport {
//   MealReport({
//     required this.date,
//     required this.school,
//     required this.menu,
//     this.status = 'Dikonfirmasi',
//   });

//   DateTime date;
//   String school;
//   String menu;
//   String status;
// }

class LaporanMakanSiangPage extends StatefulWidget {
  const LaporanMakanSiangPage({super.key});

  @override
  State<LaporanMakanSiangPage> createState() => _LaporanMakanSiangPageState();
}

class _LaporanMakanSiangPageState extends State<LaporanMakanSiangPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _allReports = []; // Data laporan dari Firestore
  List<Map<String, dynamic>> _filteredReports =
      []; // Data laporan yang sudah difilter
  List<Map<String, String>> _schools =
      []; // Daftar sekolah untuk dropdown filter
  String? _selectedSchoolId; // ID sekolah yang dipilih dari dropdown

  bool _isLoading = true;
  String _errorMessage = '';

  // Cache untuk nama sekolah agar tidak query berulang
  final Map<String, String> _schoolNamesCache = {};
  // Cache untuk menu harian (daily_menus) agar tidak query berulang saat membuat laporan
  final Map<String, Map<String, dynamic>> _dailyMenusCache = {};

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  // Mengambil data awal (daftar sekolah dan semua laporan)
  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Ambil daftar sekolah
      QuerySnapshot schoolSnapshot =
          await _firestore.collection('schools').get();
      List<Map<String, String>> fetchedSchools = [];
      for (var doc in schoolSnapshot.docs) {
        _schoolNamesCache[doc.id] = doc.get('name') ?? 'Nama Tidak Tersedia';
        fetchedSchools.add(
            {'id': doc.id, 'name': doc.get('name') ?? 'Nama Tidak Tersedia'});
      }

      // 2. Ambil semua daily_menus untuk cache
      QuerySnapshot dailyMenuSnapshot =
          await _firestore.collection('daily_menus').get();
      for (var doc in dailyMenuSnapshot.docs) {
        _dailyMenusCache[doc.id] = doc.data() as Map<String, dynamic>;
      }

      if (!mounted) return;
      setState(() {
        _schools = fetchedSchools;
      });

      // 3. Ambil semua laporan makan siang
      await _fetchMealReports();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data awal: ${e.toString()}';
        });
      }
      print('Error fetching initial data: $e');
    }
  }

  // Mengambil semua laporan makan siang dari Firestore
  Future<void> _fetchMealReports() async {
    try {
      Query query = _firestore
          .collection('meal_confirmations')
          .orderBy('date', descending: true);

      // Jika filter sekolah dipilih
      if (_selectedSchoolId != null && _selectedSchoolId!.isNotEmpty) {
        query = query.where('schoolId', isEqualTo: _selectedSchoolId);
      }

      QuerySnapshot mealReportsSnapshot = await query.get();

      List<Map<String, dynamic>> tempReports = [];
      for (var doc in mealReportsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        Timestamp? dateTimestamp = data['date'] as Timestamp?;
        String formattedDate = dateTimestamp != null
            ? DateFormat('dd-MM-yyyy').format(dateTimestamp.toDate())
            : 'Tanggal Tidak Tersedia';

        String schoolId = data['schoolId'] ?? '';
        String sekolahName = _schoolNamesCache[schoolId] ?? 'Memuat Sekolah...';

        Map<String, dynamic> menuDetails = data['menuDetails'] ?? {};
        String menu = menuDetails['foodName'] ?? 'Menu Tidak Tersedia';

        String status = data['status'] ?? 'Pending';

        tempReports.add({
          "id": doc.id, // Simpan ID dokumen untuk operasi CRUD
          "date": dateTimestamp?.toDate(), // Simpan DateTime objek untuk dialog
          "formattedDate": formattedDate,
          "schoolId": schoolId,
          "schoolName": sekolahName,
          "menu": menu,
          "status": status,
          "menuDetails": menuDetails, // Simpan detail menu lengkap
          "studentId": data['studentId'], // Simpan studentId
        });
      }

      if (mounted) {
        setState(() {
          _allReports = tempReports;
          _filteredReports =
              List.from(_allReports); // Awalnya, semua laporan adalah filter
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat laporan: ${e.toString()}';
        });
      }
      print('Error fetching meal reports: $e');
    }
  }

  // Fungsi yang dipanggil saat aksi menu dipilih
  void _onMenuAction(String action, Map<String, dynamic> report) async {
    switch (action) {
      case 'edit':
        await _openMealDialog(initial: report);
        _fetchMealReports(); // Refresh data setelah edit
        break;
      case 'add':
        await _openMealDialog();
        _fetchMealReports(); // Refresh data setelah tambah
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Hapus Catatan Makan'),
            content: Text(
                'Yakin ingin menghapus catatan makan untuk ${report['schoolName']} - ${report['formattedDate']}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) {
          await _deleteMealReport(report['id']);
          _fetchMealReports(); // Refresh data setelah hapus
        }
        break;
    }
  }

  // Fungsi untuk menghapus catatan makan dari Firestore
  Future<void> _deleteMealReport(String docId) async {
    try {
      await _firestore.collection('meal_confirmations').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Catatan makan berhasil dihapus!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus catatan makan: $e')),
        );
      }
      print('Error deleting meal report: $e');
    }
  }

  // Dialog untuk menambah/mengedit catatan makan
  Future<void> _openMealDialog({Map<String, dynamic>? initial}) async {
    final formKey = GlobalKey<FormState>();
    // Untuk dialog, kita akan ambil ulang daftar sekolah dan menu yang tersedia
    List<Map<String, String>> dialogSchools =
        List.from(_schools); // Gunakan daftar sekolah yang sudah diambil
    String? dialogSelectedSchoolId = initial?['schoolId'] ??
        (_selectedSchoolId ?? dialogSchools.first['id']);

    DateTime dialogDate = initial?['date'] ?? DateTime.now();
    TextEditingController menuController =
        TextEditingController(text: initial?['menuDetails']?['foodName']);
    String? dialogSelectedStatus =
        initial?['status'] ?? 'Pending'; // Default 'Pending'

    List<Map<String, dynamic>> dialogAvailableMenus = [];
    String? dialogSelectedMenuItemString;
    Map<String, dynamic>? dialogSelectedMenuItemDetails;

    // Load menus for the selected date in the dialog
    Future<void> loadDialogMenus(
        String currentSchoolId, DateTime currentDate) async {
      DateTime startOfDay =
          DateTime(currentDate.year, currentDate.month, currentDate.day);
      DateTime endOfDay = DateTime(
          currentDate.year, currentDate.month, currentDate.day, 23, 59, 59);

      try {
        QuerySnapshot menuSnapshot = await _firestore
            .collection('daily_menus')
            .where('schoolId', isEqualTo: currentSchoolId)
            .where('date', isGreaterThanOrEqualTo: startOfDay)
            .where('date', isLessThanOrEqualTo: endOfDay)
            .limit(1)
            .get();

        if (menuSnapshot.docs.isNotEmpty) {
          List<dynamic>? items = menuSnapshot.docs.first.get('menuItems');
          if (items != null) {
            dialogAvailableMenus =
                items.map((item) => item as Map<String, dynamic>).toList();
            if (initial?['menuDetails'] != null &&
                initial!['menuDetails']['foodName'] != null) {
              // Coba cocokkan menu awal jika ada di mode edit
              String initialMenuDisplay =
                  "${initial['menuDetails']['foodName']} (${initial['menuDetails']['time'] ?? initial['menuDetails']['mealType']})";
              if (dialogAvailableMenus.any((element) =>
                  "${element['foodName']} (${element['time'] ?? element['mealType']})" ==
                  initialMenuDisplay)) {
                dialogSelectedMenuItemString = initialMenuDisplay;
                dialogSelectedMenuItemDetails = initial['menuDetails'];
              }
            } else if (dialogAvailableMenus.isNotEmpty) {
              dialogSelectedMenuItemDetails = dialogAvailableMenus.first;
              dialogSelectedMenuItemString =
                  "${dialogAvailableMenus.first['foodName']} (${dialogAvailableMenus.first['time'] ?? dialogAvailableMenus.first['mealType']})";
            }
          }
        }
      } catch (e) {
        print("Error loading dialog menus: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal memuat menu untuk dialog: $e')));
        }
      }
    }

    await loadDialogMenus(dialogSelectedSchoolId!, dialogDate);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1D3354),
      builder: (ctx) {
        return StatefulBuilder(
          // Gunakan StatefulBuilder untuk mengelola state di dalam BottomSheet
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dropdown Pilih Sekolah
                    DropdownButtonFormField<String>(
                      value: dialogSelectedSchoolId,
                      items: dialogSchools.map((s) {
                        return DropdownMenuItem(
                          value: s['id'],
                          child: Text(s['name']!,
                              style: const TextStyle(color: Colors.black)),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setModalState(() {
                          dialogSelectedSchoolId = v;
                          // Muat ulang menu yang tersedia untuk sekolah yang baru dipilih
                          loadDialogMenus(dialogSelectedSchoolId!, dialogDate)
                              .then((_) {
                            setModalState(
                                () {}); // Refresh UI setelah menu dimuat
                          });
                        });
                      },
                      dropdownColor: const Color(
                          0xFF1D3354), // Sesuaikan warna dropdown item
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Sekolah',
                        labelStyle: TextStyle(color: Colors.white),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Date Picker dalam dialog
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          initialDate: dialogDate,
                        );
                        if (picked != null) {
                          setModalState(() {
                            dialogDate = picked;
                            // Muat ulang menu yang tersedia untuk tanggal yang baru dipilih
                            loadDialogMenus(dialogSelectedSchoolId!, dialogDate)
                                .then((_) {
                              setModalState(
                                  () {}); // Refresh UI setelah menu dimuat
                            });
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 15),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white),
                          borderRadius: BorderRadius.circular(4),
                          color: Colors
                              .transparent, // Transparan agar terlihat background
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tanggal: ${DateFormat('dd-MM-yyyy').format(dialogDate)}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const Icon(Icons.calendar_today,
                                color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Dropdown Pilih Menu
                    DropdownButtonFormField<String>(
                      value: dialogSelectedMenuItemString,
                      hint: const Text("Pilih Menu",
                          style: TextStyle(color: Colors.white)),
                      decoration: const InputDecoration(
                        labelText: 'Menu',
                        labelStyle: TextStyle(color: Colors.white),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                      items: dialogAvailableMenus.map((menuItem) {
                        String displayString =
                            "${menuItem['foodName']} (${menuItem['time'] ?? menuItem['mealType']})";
                        return DropdownMenuItem<String>(
                          value: displayString,
                          child: Text(displayString,
                              style: const TextStyle(
                                  color: Colors
                                      .black)), // Warna teks item dropdown
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setModalState(() {
                          dialogSelectedMenuItemString = newValue;
                          // Cari detail menu yang dipilih
                          Map<String, dynamic>? foundItem;
                          for (var item in dialogAvailableMenus) {
                            if ("${item['foodName']} (${item['time'] ?? item['mealType']})" ==
                                newValue) {
                              foundItem = item;
                              break;
                            }
                          }
                          dialogSelectedMenuItemDetails = foundItem;
                        });
                      },
                      dropdownColor:
                          const Color(0xFF1D3354), // Warna dropdown itu sendiri
                      style: const TextStyle(color: Colors.white),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Mohon pilih menu';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Dropdown untuk Status (jika relevan untuk admin)
                    DropdownButtonFormField<String>(
                      value: dialogSelectedStatus,
                      items: <String>['Confirmed', 'Cancelled', 'Pending']
                          .map((status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status,
                              style: const TextStyle(color: Colors.black)),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setModalState(() => dialogSelectedStatus = v!),
                      dropdownColor: const Color(0xFF1D3354),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        labelStyle: TextStyle(color: Colors.white),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          if (dialogSelectedSchoolId == null ||
                              dialogSelectedMenuItemDetails == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Mohon lengkapi semua pilihan.')));
                            return;
                          }
                          // Simpan atau update ke Firestore
                          final newReportData = {
                            'schoolId': dialogSelectedSchoolId,
                            'date': Timestamp.fromDate(dialogDate),
                            'menuDetails': dialogSelectedMenuItemDetails,
                            'status': dialogSelectedStatus,
                            'updatedAt': Timestamp.now(),
                          };

                          try {
                            if (initial == null) {
                              // Tambah baru
                              newReportData['createdAt'] = Timestamp.now();
                              newReportData['studentId'] =
                                  'UNKNOWN_STUDENT_ID'; // Placeholder: Perlu logika untuk memilih siswa
                              await _firestore
                                  .collection('meal_confirmations')
                                  .add(newReportData);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Catatan makan berhasil ditambahkan!')));
                            } else {
                              // Edit yang sudah ada
                              await _firestore
                                  .collection('meal_confirmations')
                                  .doc(initial['id'])
                                  .update(newReportData);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Catatan makan berhasil diperbarui!')));
                            }
                            Navigator.pop(ctx); // Tutup dialog
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Gagal menyimpan catatan: $e')));
                            print('Error saving meal report in dialog: $e');
                          }
                        }
                      },
                      child: Text(initial == null ? 'Tambah' : 'Simpan'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text(
          'Laporan Makan Siang',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: const Color(0xFFCCE0F5),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task), // Ikon untuk tambah catatan makan
            onPressed: () => _onMenuAction('add', {}), // Arahkan ke aksi 'add'
            tooltip: 'Tambah Catatan Makan',
          )
        ],
      ),
      backgroundColor: const Color(0xFF1D3354),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    hint: const Text(
                      'Pilih Sekolah',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _selectedSchoolId,
                    items: _schools
                        .map(
                          (s) => DropdownMenuItem(
                            value: s['id'],
                            child: Text(
                              s['name']!,
                              style: const TextStyle(
                                  color: Colors
                                      .black), // Ubah warna teks item dropdown
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedSchoolId = val;
                        _isLoading = true; // Set loading saat filter berubah
                      });
                      _fetchMealReports(); // Muat ulang laporan sesuai filter sekolah
                    },
                    dropdownColor: const Color(0xFF1D3354),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)))
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Text(_errorMessage,
                              style: const TextStyle(color: Colors.redAccent)))
                      : SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(
                              const Color(0xFF27496D),
                            ),
                            dataRowColor: MaterialStateProperty.all(
                              const Color(0xFF1D3354),
                            ),
                            border: TableBorder.all(color: Colors.white),
                            columnSpacing: 12,
                            columns: const [
                              DataColumn(
                                label: Text('Tanggal',
                                    style: TextStyle(color: Colors.white)),
                              ),
                              DataColumn(
                                label: Text('Sekolah',
                                    style: TextStyle(color: Colors.white)),
                              ),
                              DataColumn(
                                label: Text('Menu',
                                    style: TextStyle(color: Colors.white)),
                              ),
                              DataColumn(
                                label: Text('Status',
                                    style: TextStyle(color: Colors.white)),
                              ),
                              DataColumn(
                                label: Text('Aksi',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                            rows: _filteredReports.map((report) {
                              Color statusColor;
                              switch (report['status']) {
                                case 'Confirmed':
                                  statusColor = Colors.green;
                                  break;
                                case 'Cancelled':
                                  statusColor = Colors.red;
                                  break;
                                default: // Pending
                                  statusColor = Colors.orange;
                                  break;
                              }
                              return DataRow(
                                cells: [
                                  DataCell(Text(
                                    report['formattedDate'],
                                    style: const TextStyle(color: Colors.white),
                                  )),
                                  DataCell(Text(
                                    report['schoolName'],
                                    style: const TextStyle(color: Colors.white),
                                  )),
                                  DataCell(Text(
                                    report['menu'],
                                    style: const TextStyle(color: Colors.white),
                                  )),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        report['status'],
                                        style: TextStyle(
                                            fontSize: 12, color: statusColor),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    PopupMenuButton<String>(
                                      color: const Color(0xFF1D3354),
                                      icon: const Icon(Icons.more_vert,
                                          color: Colors.white),
                                      onSelected: (value) =>
                                          _onMenuAction(value, report),
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Hapus',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
