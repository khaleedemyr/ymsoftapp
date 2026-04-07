import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_loading_indicator.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;
  
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isSaving = false;
  File? _selectedAvatar;
  File? _selectedFotoKtp;
  File? _selectedFotoKk;
  File? _selectedColorPhoto;
  
  final _formKey = GlobalKey<FormState>();
  
  // Personal Tab Controllers
  final _namaLengkapController = TextEditingController();
  final _namaPanggilanController = TextEditingController();
  final _emailController = TextEditingController();
  final _noHpController = TextEditingController();
  final _tempatLahirController = TextEditingController();
  final _sukuController = TextEditingController();
  
  String? _jenisKelamin;
  DateTime? _tanggalLahir;
  String? _agama;
  String? _statusPernikahan;
  String? _golonganDarah;
  
  // Work Tab Controllers
  final _pinPosController = TextEditingController();
  final _pinPayrollController = TextEditingController();
  final _imeiController = TextEditingController();
  
  // Contact Tab Controllers
  final _alamatController = TextEditingController();
  final _alamatKtpController = TextEditingController();
  final _namaKontakDaruratController = TextEditingController();
  final _noHpKontakDaruratController = TextEditingController();
  String? _hubunganKontakDarurat;
  
  // Documents Tab Controllers
  final _noKtpController = TextEditingController();
  final _nomorKkController = TextEditingController();
  final _npwpNumberController = TextEditingController();
  final _bpjsHealthNumberController = TextEditingController();
  final _bpjsEmploymentNumberController = TextEditingController();
  final _nameSchoolCollegeController = TextEditingController();
  final _schoolCollegeMajorController = TextEditingController();
  final _namaRekeningController = TextEditingController();
  final _noRekeningController = TextEditingController();
  String? _lastEducation;
  
  // Password Tab Controllers
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Preview URLs
  String? _avatarPreviewUrl;
  String? _fotoKtpPreviewUrl;
  String? _fotoKkPreviewUrl;
  String? _colorPhotoPreviewUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _namaLengkapController.dispose();
    _namaPanggilanController.dispose();
    _emailController.dispose();
    _noHpController.dispose();
    _tempatLahirController.dispose();
    _sukuController.dispose();
    _pinPosController.dispose();
    _pinPayrollController.dispose();
    _imeiController.dispose();
    _alamatController.dispose();
    _alamatKtpController.dispose();
    _namaKontakDaruratController.dispose();
    _noHpKontakDaruratController.dispose();
    _noKtpController.dispose();
    _nomorKkController.dispose();
    _npwpNumberController.dispose();
    _bpjsHealthNumberController.dispose();
    _bpjsEmploymentNumberController.dispose();
    _nameSchoolCollegeController.dispose();
    _schoolCollegeMajorController.dispose();
    _namaRekeningController.dispose();
    _noRekeningController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Helper function to safely convert value to String
  String _toString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is int || value is double) return value.toString();
    return value.toString();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userData = await _authService.getUserData();
      if (mounted) {
        setState(() {
          _userData = userData;
          
          // Personal
          _namaLengkapController.text = _toString(userData?['nama_lengkap']);
          _namaPanggilanController.text = _toString(userData?['nama_panggilan']);
          _emailController.text = _toString(userData?['email']);
          _noHpController.text = _toString(userData?['no_hp']);
          _tempatLahirController.text = _toString(userData?['tempat_lahir']);
          _sukuController.text = _toString(userData?['suku']);
          _jenisKelamin = userData?['jenis_kelamin']?.toString();
          _agama = userData?['agama']?.toString();
          _statusPernikahan = userData?['status_pernikahan']?.toString();
          _golonganDarah = userData?['golongan_darah']?.toString();
          
          if (userData?['tanggal_lahir'] != null) {
            try {
              _tanggalLahir = DateTime.parse(userData!['tanggal_lahir'].toString());
            } catch (e) {
              _tanggalLahir = null;
            }
          }
          
          // Work
          _pinPosController.text = _toString(userData?['pin_pos']);
          _pinPayrollController.text = _toString(userData?['pin_payroll']);
          _imeiController.text = _toString(userData?['imei']);
          
          // Contact
          _alamatController.text = _toString(userData?['alamat']);
          _alamatKtpController.text = _toString(userData?['alamat_ktp']);
          _namaKontakDaruratController.text = _toString(userData?['nama_kontak_darurat']);
          _noHpKontakDaruratController.text = _toString(userData?['no_hp_kontak_darurat']);
          _hubunganKontakDarurat = userData?['hubungan_kontak_darurat']?.toString();
          
          // Documents
          _noKtpController.text = _toString(userData?['no_ktp']);
          _nomorKkController.text = _toString(userData?['nomor_kk']);
          _npwpNumberController.text = _toString(userData?['npwp_number']);
          _bpjsHealthNumberController.text = _toString(userData?['bpjs_health_number']);
          _bpjsEmploymentNumberController.text = _toString(userData?['bpjs_employment_number']);
          _nameSchoolCollegeController.text = _toString(userData?['name_school_college']);
          _schoolCollegeMajorController.text = _toString(userData?['school_college_major']);
          _namaRekeningController.text = _toString(userData?['nama_rekening']);
          _noRekeningController.text = _toString(userData?['no_rekening']);
          _lastEducation = userData?['last_education']?.toString();
          
          // Preview URLs
          if (userData?['avatar'] != null) {
            _avatarPreviewUrl = '${AuthService.storageUrl}/storage/${userData!['avatar'].toString()}';
          }
          if (userData?['foto_ktp'] != null) {
            _fotoKtpPreviewUrl = '${AuthService.storageUrl}/storage/${userData!['foto_ktp'].toString()}';
          }
          if (userData?['foto_kk'] != null) {
            _fotoKkPreviewUrl = '${AuthService.storageUrl}/storage/${userData!['foto_kk'].toString()}';
          }
          if (userData?['upload_latest_color_photo'] != null) {
            _colorPhotoPreviewUrl = '${AuthService.storageUrl}/storage/${userData!['upload_latest_color_photo'].toString()}';
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          final file = File(pickedFile.path);
          switch (type) {
            case 'avatar':
              _selectedAvatar = file;
              break;
            case 'foto_ktp':
              _selectedFotoKtp = file;
              break;
            case 'foto_kk':
              _selectedFotoKk = file;
              break;
            case 'color_photo':
              _selectedColorPhoto = file;
              break;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggalLahir ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _tanggalLahir = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await _authService.updateProfile(
        namaLengkap: _namaLengkapController.text,
        namaPanggilan: _namaPanggilanController.text.isEmpty ? null : _namaPanggilanController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        noHp: _noHpController.text.isEmpty ? null : _noHpController.text,
        avatar: _selectedAvatar,
        // Personal
        jenisKelamin: _jenisKelamin,
        tempatLahir: _tempatLahirController.text.isEmpty ? null : _tempatLahirController.text,
        tanggalLahir: _tanggalLahir?.toIso8601String(),
        suku: _sukuController.text.isEmpty ? null : _sukuController.text,
        agama: _agama,
        statusPernikahan: _statusPernikahan,
        golonganDarah: _golonganDarah,
        // Work
        pinPos: _pinPosController.text.isEmpty ? null : _pinPosController.text,
        pinPayroll: _pinPayrollController.text.isEmpty ? null : _pinPayrollController.text,
        imei: _imeiController.text.isEmpty ? null : _imeiController.text,
        // Contact
        alamat: _alamatController.text.isEmpty ? null : _alamatController.text,
        alamatKtp: _alamatKtpController.text.isEmpty ? null : _alamatKtpController.text,
        namaKontakDarurat: _namaKontakDaruratController.text.isEmpty ? null : _namaKontakDaruratController.text,
        noHpKontakDarurat: _noHpKontakDaruratController.text.isEmpty ? null : _noHpKontakDaruratController.text,
        hubunganKontakDarurat: _hubunganKontakDarurat,
        // Documents
        noKtp: _noKtpController.text.isEmpty ? null : _noKtpController.text,
        nomorKk: _nomorKkController.text.isEmpty ? null : _nomorKkController.text,
        npwpNumber: _npwpNumberController.text.isEmpty ? null : _npwpNumberController.text,
        bpjsHealthNumber: _bpjsHealthNumberController.text.isEmpty ? null : _bpjsHealthNumberController.text,
        bpjsEmploymentNumber: _bpjsEmploymentNumberController.text.isEmpty ? null : _bpjsEmploymentNumberController.text,
        lastEducation: _lastEducation,
        nameSchoolCollege: _nameSchoolCollegeController.text.isEmpty ? null : _nameSchoolCollegeController.text,
        schoolCollegeMajor: _schoolCollegeMajorController.text.isEmpty ? null : _schoolCollegeMajorController.text,
        namaRekening: _namaRekeningController.text.isEmpty ? null : _namaRekeningController.text,
        noRekening: _noRekeningController.text.isEmpty ? null : _noRekeningController.text,
        fotoKtp: _selectedFotoKtp,
        fotoKk: _selectedFotoKk,
        colorPhoto: _selectedColorPhoto,
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile berhasil diperbarui'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal memperbarui profile'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _updatePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua field password harus diisi'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password baru dan konfirmasi password tidak sama'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await _authService.updatePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password berhasil diubah'),
              backgroundColor: Colors.green,
            ),
          );
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal mengubah password'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  String _getAvatarUrl() {
    if (_selectedAvatar != null) {
      return _selectedAvatar!.path;
    }
    return _avatarPreviewUrl ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Edit Profil',
      body: _isLoading
          ? const Center(
                            child: AppLoadingIndicator(),
            )
          : Column(
              children: [
                // Tab Bar
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: const Color(0xFF6366F1),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFF6366F1),
                    tabs: const [
                      Tab(text: 'Personal'),
                      Tab(text: 'Work'),
                      Tab(text: 'Contact'),
                      Tab(text: 'Documents'),
                      Tab(text: 'Password'),
                    ],
                  ),
                ),
                
                // Tab Content
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPersonalTab(),
                        _buildWorkTab(),
                        _buildContactTab(),
                        _buildDocumentsTab(),
                        _buildPasswordTab(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPersonalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar Section
          Center(
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6366F1),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _getAvatarUrl().isNotEmpty && _selectedAvatar == null
                        ? CachedNetworkImage(
                            imageUrl: _getAvatarUrl(),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => _buildAvatarPlaceholder(),
                            errorWidget: (context, url, error) => _buildAvatarPlaceholder(),
                          )
                        : _selectedAvatar != null
                            ? Image.file(
                                _selectedAvatar!,
                                fit: BoxFit.cover,
                              )
                            : _buildAvatarPlaceholder(),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => _showImageSourceDialog('avatar'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Form Fields
          _buildTextField(
            controller: _namaLengkapController,
            label: 'Nama Lengkap *',
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Nama lengkap harus diisi';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _namaPanggilanController,
            label: 'Nama Panggilan',
            icon: Icons.badge,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            label: 'Email',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                if (!value.contains('@')) {
                  return 'Email tidak valid';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _noHpController,
            label: 'No. HP',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            label: 'Jenis Kelamin',
            value: _jenisKelamin,
            items: const [
              DropdownMenuItem(value: 'L', child: Text('Laki-laki')),
              DropdownMenuItem(value: 'P', child: Text('Perempuan')),
            ],
            onChanged: (value) => setState(() => _jenisKelamin = value),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _tempatLahirController,
            label: 'Tempat Lahir',
            icon: Icons.location_city,
          ),
          const SizedBox(height: 16),
          _buildDateField(
            label: 'Tanggal Lahir',
            value: _tanggalLahir,
            onTap: _selectDate,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _sukuController,
            label: 'Suku',
            icon: Icons.people,
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            label: 'Agama',
            value: _agama,
            items: const [
              DropdownMenuItem(value: 'Islam', child: Text('Islam')),
              DropdownMenuItem(value: 'Kristen', child: Text('Kristen')),
              DropdownMenuItem(value: 'Katolik', child: Text('Katolik')),
              DropdownMenuItem(value: 'Hindu', child: Text('Hindu')),
              DropdownMenuItem(value: 'Buddha', child: Text('Buddha')),
              DropdownMenuItem(value: 'Konghucu', child: Text('Konghucu')),
            ],
            onChanged: (value) => setState(() => _agama = value),
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            label: 'Status Pernikahan',
            value: _statusPernikahan,
            items: const [
              DropdownMenuItem(value: 'single', child: Text('Single')),
              DropdownMenuItem(value: 'married', child: Text('Menikah')),
              DropdownMenuItem(value: 'divorced', child: Text('Cerai')),
            ],
            onChanged: (value) => setState(() => _statusPernikahan = value),
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            label: 'Golongan Darah',
            value: _golonganDarah,
            items: const [
              DropdownMenuItem(value: 'A', child: Text('A')),
              DropdownMenuItem(value: 'B', child: Text('B')),
              DropdownMenuItem(value: 'AB', child: Text('AB')),
              DropdownMenuItem(value: 'O', child: Text('O')),
            ],
            onChanged: (value) => setState(() => _golonganDarah = value),
          ),
          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Simpan Perubahan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Read-only Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Informasi Pekerjaan (Read-only)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  'Jabatan',
                  _toString(_userData?['jabatan_name'] ?? 
                  _userData?['jabatan']?['nama_jabatan']) != '' 
                    ? _toString(_userData?['jabatan_name'] ?? 
                        _userData?['jabatan']?['nama_jabatan'])
                    : 'N/A',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Level',
                  _toString(_userData?['jabatan']?['level']?['nama_level'] ?? 
                  _userData?['level_name']) != '' 
                    ? _toString(_userData?['jabatan']?['level']?['nama_level'] ?? 
                        _userData?['level_name'])
                    : 'N/A',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Divisi',
                  _toString(_userData?['division_name'] ?? 
                  _userData?['division']?['nama_divisi']) != '' 
                    ? _toString(_userData?['division_name'] ?? 
                        _userData?['division']?['nama_divisi'])
                    : 'N/A',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Outlet',
                  _toString(_userData?['outlet_name'] ?? 
                  _userData?['outlet']?['nama_outlet']) != '' 
                    ? _toString(_userData?['outlet_name'] ?? 
                        _userData?['outlet']?['nama_outlet'])
                    : 'N/A',
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Tanggal Masuk',
                  _userData?['tanggal_masuk'] != null
                      ? DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.parse(_userData!['tanggal_masuk'].toString()))
                      : 'N/A',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Editable Fields
          _buildTextField(
            controller: _pinPosController,
            label: 'PIN POS',
            icon: Icons.pin,
            maxLength: 10,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _pinPayrollController,
            label: 'PIN Payroll *',
            icon: Icons.payment,
            maxLength: 10,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'PIN Payroll harus diisi';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _imeiController,
            label: 'IMEI',
            icon: Icons.phone_android,
          ),
          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Simpan Perubahan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alamat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          _buildTextAreaField(
            controller: _alamatController,
            label: 'Alamat',
            icon: Icons.home,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildTextAreaField(
            controller: _alamatKtpController,
            label: 'Alamat KTP',
            icon: Icons.description,
            maxLines: 3,
          ),
          const SizedBox(height: 32),
          const Text(
            'Kontak Darurat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _namaKontakDaruratController,
            label: 'Nama Kontak Darurat',
            icon: Icons.person,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _noHpKontakDaruratController,
            label: 'No HP Kontak Darurat',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            label: 'Hubungan Kontak Darurat',
            value: _hubunganKontakDarurat,
            items: const [
              DropdownMenuItem(value: 'Ayah', child: Text('Ayah')),
              DropdownMenuItem(value: 'Ibu', child: Text('Ibu')),
              DropdownMenuItem(value: 'Suami', child: Text('Suami')),
              DropdownMenuItem(value: 'Istri', child: Text('Istri')),
              DropdownMenuItem(value: 'Anak', child: Text('Anak')),
              DropdownMenuItem(value: 'Saudara', child: Text('Saudara')),
              DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
            ],
            onChanged: (value) => setState(() => _hubunganKontakDarurat = value),
          ),
          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Simpan Perubahan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _noKtpController,
            label: 'No KTP',
            icon: Icons.badge,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _nomorKkController,
            label: 'Nomor KK',
            icon: Icons.family_restroom,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _npwpNumberController,
            label: 'NPWP Number',
            icon: Icons.receipt_long,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _bpjsHealthNumberController,
            label: 'BPJS Health Number',
            icon: Icons.health_and_safety,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _bpjsEmploymentNumberController,
            label: 'BPJS Employment Number',
            icon: Icons.work,
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            label: 'Pendidikan Terakhir',
            value: _lastEducation,
            items: const [
              DropdownMenuItem(value: 'SD', child: Text('SD')),
              DropdownMenuItem(value: 'SMP', child: Text('SMP')),
              DropdownMenuItem(value: 'SMA', child: Text('SMA')),
              DropdownMenuItem(value: 'D3', child: Text('D3')),
              DropdownMenuItem(value: 'S1', child: Text('S1')),
              DropdownMenuItem(value: 'S2', child: Text('S2')),
              DropdownMenuItem(value: 'S3', child: Text('S3')),
            ],
            onChanged: (value) => setState(() => _lastEducation = value),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _nameSchoolCollegeController,
            label: 'Nama Sekolah/Kampus',
            icon: Icons.school,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _schoolCollegeMajorController,
            label: 'Jurusan',
            icon: Icons.menu_book,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _namaRekeningController,
            label: 'Nama Rekening',
            icon: Icons.account_balance,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _noRekeningController,
            label: 'No Rekening',
            icon: Icons.credit_card,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),

          // File Uploads
          _buildFileUploadField(
            label: 'Foto KTP',
            file: _selectedFotoKtp,
            previewUrl: _fotoKtpPreviewUrl,
            onTap: () => _showImageSourceDialog('foto_ktp'),
          ),
          const SizedBox(height: 16),
          _buildFileUploadField(
            label: 'Foto KK',
            file: _selectedFotoKk,
            previewUrl: _fotoKkPreviewUrl,
            onTap: () => _showImageSourceDialog('foto_kk'),
          ),
          const SizedBox(height: 16),
          _buildFileUploadField(
            label: 'Upload Latest Color Photo',
            file: _selectedColorPhoto,
            previewUrl: _colorPhotoPreviewUrl,
            onTap: () => _showImageSourceDialog('color_photo'),
          ),
          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Simpan Perubahan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _currentPasswordController,
            label: 'Current Password *',
            icon: Icons.lock,
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Current password harus diisi';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _newPasswordController,
            label: 'New Password *',
            icon: Icons.lock_outline,
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'New password harus diisi';
              }
              if (value.length < 8) {
                return 'Password minimal 8 karakter';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password *',
            icon: Icons.lock_outline,
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirm password harus diisi';
              }
              if (value != _newPasswordController.text) {
                return 'Password tidak sama';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // Update Password Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _updatePassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: AppLoadingIndicator(size: 24, color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Update Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
          ],
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(_userData?['nama_lengkap']),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool obscureText = false,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      obscureText: obscureText,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildTextAreaField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 3,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Pilih...'),
        ),
        ...items,
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF6366F1)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Text(
          value != null
              ? DateFormat('dd MMMM yyyy', 'id_ID').format(value)
              : 'Pilih Tanggal',
          style: TextStyle(
            color: value != null ? Colors.black : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildFileUploadField({
    required String label,
    required File? file,
    required String? previewUrl,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                style: BorderStyle.solid,
              ),
            ),
            child: file != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      file,
                      fit: BoxFit.cover,
                    ),
                  )
                : previewUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: previewUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: AppLoadingIndicator(size: 24, color: Colors.white),
                          ),
                          errorWidget: (context, url, error) => _buildEmptyFilePlaceholder(),
                        ),
                      )
                    : _buildEmptyFilePlaceholder(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Format: JPG, PNG. Maksimal 2MB',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFilePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image,
          size: 48,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 8),
        Text(
          'Tap untuk memilih gambar',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _showImageSourceDialog(String type) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, type);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, type);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    );
  }
}
