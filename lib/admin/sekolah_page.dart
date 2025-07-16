import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:freeluchapp/admin/sekolah_form_page.dart'; // Untuk form tambah/edit sekolah
import 'package:freeluchapp/app_drawer.dart'; // Pastikan path ini benar untuk AppDrawer admin

class SekolahPage extends StatefulWidget {
  const SekolahPage({super.key});

  @override
  State<SekolahPage> createState() => _SekolahPageState();
}

class _SekolahPageState extends State<SekolahPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
        title: const Text('Sekolah', style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () {
              // Navigasi ke form tambah sekolah
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SekolahFormPage()),
              );
            },
            tooltip: 'Tambah Sekolah',
          ),
        ],
      ),
      backgroundColor: const Color(0xFF1F355D),
      drawer: const AppDrawer(), // Menggunakan AppDrawer (untuk Admin)
      body: StreamBuilder<QuerySnapshot>(
        // Mendengarkan perubahan data di koleksi 'schools' secara real-time
        stream: _firestore.collection('schools').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white)));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
                child: Text('Belum ada data sekolah.',
                    style: TextStyle(color: Colors.white)));
          }

          // Tampilkan daftar sekolah dalam ListView
          return SingleChildScrollView(
            // Tambahkan SingleChildScrollView untuk konten tabel
            scrollDirection: Axis
                .horizontal, // Memungkinkan scroll horizontal jika tabel lebar
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
                  label: Text('Nama', style: TextStyle(color: Colors.white)),
                ),
                DataColumn(
                  label: Text('Alamat', style: TextStyle(color: Colors.white)),
                ),
                DataColumn(
                  label: Text('Kota/Kabupaten',
                      style: TextStyle(color: Colors.white)),
                ),
                DataColumn(
                  label:
                      Text('Provinsi', style: TextStyle(color: Colors.white)),
                ),
                DataColumn(
                  label: Text('Kontak Person',
                      style: TextStyle(color: Colors.white)),
                ),
                DataColumn(
                  label: Text('No. Telepon',
                      style: TextStyle(color: Colors.white)),
                ),
                DataColumn(
                  label: Text('Aksi', style: TextStyle(color: Colors.white)),
                ),
              ],
              rows: snapshot.data!.docs.map((document) {
                Map<String, dynamic> data =
                    document.data() as Map<String, dynamic>;
                return DataRow(
                  cells: [
                    DataCell(Text(data['name'] ?? '',
                        style: const TextStyle(color: Colors.white))),
                    DataCell(Text(data['address'] ?? '',
                        style: const TextStyle(color: Colors.white))),
                    DataCell(Text(data['city'] ?? '',
                        style: const TextStyle(color: Colors.white))),
                    DataCell(Text(data['province'] ?? '',
                        style: const TextStyle(color: Colors.white))),
                    DataCell(Text(data['contactPerson'] ?? '',
                        style: const TextStyle(color: Colors.white))),
                    DataCell(Text(data['contactPhone'] ?? '',
                        style: const TextStyle(color: Colors.white))),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () {
                              // Navigasi ke form edit sekolah dengan membawa data sekolah
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SekolahFormPage(
                                    schoolId: document.id, // ID dokumen sekolah
                                    currentData: data, // Data lengkap sekolah
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              // Tampilkan dialog konfirmasi sebelum menghapus
                              _confirmDelete(
                                  context, document.id, data['name']);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  // Fungsi untuk menampilkan dialog konfirmasi penghapusan
  void _confirmDelete(
      BuildContext context, String schoolId, String? schoolName) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus'),
          content: Text(
              'Apakah Anda yakin ingin menghapus sekolah "${schoolName ?? 'ini'}"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(), // Tutup dialog
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                _deleteSchool(schoolId);
                Navigator.of(dialogContext).pop(); // Tutup dialog setelah hapus
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Fungsi untuk menghapus dokumen sekolah dari Firestore
  Future<void> _deleteSchool(String schoolId) async {
    try {
      await _firestore.collection('schools').doc(schoolId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sekolah berhasil dihapus!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus sekolah: $e')),
        );
      }
      print('Error deleting school: $e');
    }
  }
}
