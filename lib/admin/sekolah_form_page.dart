import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
// import 'package:freeluchapp/app_drawer.dart'; // AppDrawer tidak diperlukan di halaman form ini

class SekolahFormPage extends StatefulWidget {
  final String? schoolId; // ID dokumen sekolah jika dalam mode edit
  final Map<String, dynamic>?
      currentData; // Data sekolah saat ini jika dalam mode edit

  const SekolahFormPage({super.key, this.schoolId, this.currentData});

  @override
  State<SekolahFormPage> createState() => _SekolahFormPageState();
}

class _SekolahFormPageState extends State<SekolahFormPage> {
  final _formKey = GlobalKey<FormState>(); // Key untuk validasi form
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Instance Firestore
  bool _isLoading = false; // Status loading untuk operasi simpan

  @override
  void initState() {
    super.initState();
    // Isi field jika dalam mode edit (currentData tidak null)
    if (widget.currentData != null) {
      _nameController.text = widget.currentData!['name'] ?? '';
      _addressController.text = widget.currentData!['address'] ?? '';
      _cityController.text = widget.currentData!['city'] ?? '';
      _provinceController.text = widget.currentData!['province'] ?? '';
      _contactPersonController.text =
          widget.currentData!['contactPerson'] ?? '';
      _contactPhoneController.text = widget.currentData!['contactPhone'] ?? '';
    }
  }

  @override
  void dispose() {
    // Pastikan untuk membuang controller saat widget di-dispose
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _contactPersonController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  // Fungsi untuk menyimpan data sekolah ke Firestore (tambah atau edit)
  Future<void> _saveSchool() async {
    if (_formKey.currentState!.validate()) {
      // Validasi form
      setState(() {
        _isLoading = true; // Aktifkan loading indicator
      });

      // Siapkan data sekolah
      final schoolData = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'province': _provinceController.text.trim(),
        'contactPerson': _contactPersonController.text.trim(),
        'contactPhone': _contactPhoneController.text.trim(),
        'updatedAt': Timestamp.now(), // Selalu perbarui timestamp updatedAt
      };

      try {
        if (widget.schoolId == null) {
          // Mode Tambah: Tambahkan dokumen baru
          await _firestore.collection('schools').add({
            ...schoolData,
            'createdAt':
                Timestamp.now(), // Tambahkan createdAt hanya untuk dokumen baru
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sekolah berhasil ditambahkan!')),
            );
          }
        } else {
          // Mode Edit: Perbarui dokumen yang sudah ada
          await _firestore
              .collection('schools')
              .doc(widget.schoolId)
              .update(schoolData);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sekolah berhasil diperbarui!')),
            );
          }
        }
        if (mounted) {
          Navigator.pop(
              context); // Kembali ke halaman sebelumnya setelah sukses
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan sekolah: $e')),
          );
        }
        print('Error saving school: $e'); // Log error untuk debugging
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false; // Nonaktifkan loading indicator
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppDrawer biasanya tidak ada di halaman form, karena tombol kembali sudah disediakan AppBar
      // drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFFDDEEFF),
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          widget.schoolId == null
              ? 'Tambah Sekolah'
              : 'Edit Sekolah', // Judul dinamis
          style: const TextStyle(color: Colors.black, fontSize: 20),
        ),
        automaticallyImplyLeading: true, // Tombol kembali otomatis
      ),
      backgroundColor: const Color(0xFF1F355D),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          // Menggunakan Form untuk validasi input
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Nama Sekolah',
                  labelText: 'Nama Sekolah', // Menambahkan labelText
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama sekolah tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  hintText: 'Alamat',
                  labelText: 'Alamat',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Alamat tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: InputDecoration(
                  hintText: 'Kota/Kabupaten',
                  labelText: 'Kota/Kabupaten',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _provinceController,
                decoration: InputDecoration(
                  hintText: 'Provinsi',
                  labelText: 'Provinsi',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactPersonController,
                decoration: InputDecoration(
                  hintText: 'Kontak Person',
                  labelText: 'Kontak Person',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactPhoneController,
                keyboardType:
                    TextInputType.phone, // Tipe keyboard untuk nomor telepon
                decoration: InputDecoration(
                  hintText: 'No. Telepon',
                  labelText: 'No. Telepon',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child:
                    _isLoading // Tampilkan CircularProgressIndicator jika sedang loading
                        ? const Center(
                            child:
                                CircularProgressIndicator(color: Colors.white))
                        : ElevatedButton(
                            onPressed:
                                _saveSchool, // Panggil fungsi _saveSchool
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27496D),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(widget.schoolId == null
                                ? "Tambah"
                                : "Simpan"), // Teks dinamis
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
