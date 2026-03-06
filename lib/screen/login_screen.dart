import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/fcm_service.dart';
import 'package:manajemensekolah/services/local_cache_service.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  final String? initialError;

  const LoginScreen({super.key, this.initialError});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    clientId: kIsWeb
        ? '631663251271-q5fmm1j2r4hko6fkicn5mml5vt8r3cnb.apps.googleusercontent.com'
        : null,
  );

  bool _isLoading = false;
  bool _serverConnected = true;
  bool _showSchoolSelection = false;
  bool _showRoleSelection = false;
  List<dynamic> _schoolList = [];
  List<dynamic> _roleList = [];
  Map<String, dynamic>? _selectedSchool;
  Map<String, dynamic>? _userData;
  String? _selectedSchoolId;
  String? _otpCode;

  @override
  void initState() {
    super.initState();
    _checkServerConnection();

    // Show initial error if provided
    if (widget.initialError != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.initialError!),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      });
    }
  }

  Future<void> _checkServerConnection() async {
    try {
      await ApiService.checkHealth();
      setState(() {
        _serverConnected = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _serverConnected = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal terhubung ke server: ${ErrorUtils.getFriendlyMessage(e)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await LocalCacheService.clearAll();
    if (kDebugMode) {
      print('🗑️ All local data and cache cleared');
    }
  }

  void _handleTokenExpired() async {
    await _clearAllData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sesi telah berakhir. Silakan login kembali.'),
          duration: Duration(seconds: 3),
        ),
      );

      // Clear state
      setState(() {
        _isLoading = false;
        _showSchoolSelection = false;
        _showRoleSelection = false;
        _schoolList = [];
        _roleList = [];
        _selectedSchool = null;
        _userData = null;
        _selectedSchoolId = null;
      });

      // Clear form
      emailController.clear();
      passwordController.clear();
    }
  }

  Future<void> login() async {
    if (!_serverConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Server tidak terhubung. Tidak dapat login.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    // Clear local data and API cache at start of login to ensure session isolation
    await _clearAllData();

    final String email = emailController.text.trim();
    final String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan password harus diisi')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final responseData = await ApiService.login(
        email,
        password,
        schoolId: _selectedSchoolId,
      );

      // Debug logging
      if (kDebugMode) {
        print('🔐 Login Response: $responseData');
        print('📝 Response keys: ${responseData.keys}');
        print('🏫 Pilih sekolah: ${responseData['pilih_sekolah']}');
        print('🎭 Pilih role: ${responseData['pilih_role']}');
      }

      // Use refactored handler
      await _handleLoginResponse(responseData);
    } catch (error) {
      if (kDebugMode) {
        print('❌ Login error: $error');
      }

      String errorMessage = ErrorUtils.getFriendlyMessage(error);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }

      if (error.toString().toLowerCase().contains('expired') ||
          error.toString().toLowerCase().contains('token') ||
          error.toString().toLowerCase().contains('unauthorized')) {
        _handleTokenExpired();
      } else {
        // Clear data on any login failure to be safe
        await _clearAllData();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Ganti method _saveLoginData dengan:
  Future<void> _saveLoginData(Map<String, dynamic> responseData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', responseData['token']);
    await prefs.setString('user', json.encode(responseData['user']));

    // Clear force logout flag
    await prefs.setBool('force_logout', false);

    // Background FCM refresh - NOT awaited to ensure fast navigation
    _refreshFcmTokenInBackground();
  }

  void _refreshFcmTokenInBackground() {
    Future(() async {
      try {
        final fcmService = FCMService();
        if (kDebugMode) print('🔄 Force refreshing FCM token in background...');
        await fcmService.forceRefreshToken();
        if (kDebugMode) print('✅ FCM token refreshed in background');
      } catch (e) {
        if (kDebugMode) {
          print(
            '⚠️ Failed to refresh FCM token in background (non-critical): $e',
          );
        }
      }
    });
  }

  Future<void> _handleGoogleSignIn() async {
    if (!_serverConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Server tidak terhubung. Tidak dapat login.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Sign in with Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      // Use idToken (JWT) for server-side verification with Google tokeninfo API
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Gagal mendapatkan token Google. Coba lagi.');
      }

      if (kDebugMode) {
        print('📧 Google User: ${googleUser.email}');
        print(
          '🔑 Google ID Token: ${idToken.isNotEmpty ? "Present (${idToken.length} chars)" : "Missing"}',
        );
      }

      // 2. Send to Backend — kirim id_token untuk verifikasi server-side
      final responseData = await ApiService.googleLogin(
        email: googleUser.email,
        displayName: googleUser.displayName,
        photoUrl: googleUser.photoUrl,
        idToken: idToken,
      );

      // 3. Handle Response
      await _handleLoginResponse(responseData);
    } catch (error) {
      if (kDebugMode) {
        print('❌ Google Sign In Error: $error');
      }

      // Sign out from Google if app login failed to ensure fresh start next time
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        // ignore
      }

      String errorMessage = ErrorUtils.getFriendlyMessage(error);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }

      // Clear data on Google Sign In failure
      await _clearAllData();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectSchool(String? schoolId) async {
    if (schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID Sekolah tidak valid (null)')),
      );
      return;
    }

    if (kDebugMode) {
      print('🎯 Selecting school: $schoolId');
    }

    setState(() {
      _isLoading = true;
      _selectedSchoolId = schoolId;
    });

    try {
      Map<String, dynamic> responseData;
      if (_otpCode != null) {
        // Jika login pakai OTP (Email), gunakan verifyOtp
        responseData = await ApiService.verifyOtp(
          emailController.text.trim(),
          _otpCode!,
          schoolId: schoolId,
        );
      } else if (await ApiService.getToken() != null) {
        // Jika sudah ada token (misal dari Google Login), gunakan switchSchool
        responseData = await ApiService.switchSchool(schoolId);
      } else {
        // Fallback (misal Password biasa atau debug)
        responseData = await ApiService.login(
          emailController.text.trim(),
          passwordController.text,
          schoolId: schoolId,
        );
      }

      if (kDebugMode) {
        print('🔐 School Selection Response: $responseData');
      }

      await _handleLoginResponse(responseData);
    } catch (error) {
      if (kDebugMode) {
        print('❌ School selection error: $error');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.getFriendlyMessage(error)),
          backgroundColor: Colors.red.shade700,
        ),
      );

      setState(() {
        _isLoading = false;
        // Jangan reset _showSchoolSelection agar user bisa memilih sekolah lain
      });
    }
  }

  Future<void> _selectRole(String role) async {
    if (kDebugMode) {
      print('🎯 Selecting role: $role');
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> responseData;

      if (_otpCode != null) {
        responseData = await ApiService.verifyOtp(
          emailController.text.trim(),
          _otpCode!,
          schoolId: _selectedSchool?['id'] ?? _selectedSchoolId,
          role: role,
        );
      } else if (await ApiService.getToken() != null) {
        // Use switchSchool with role
        responseData = await ApiService.switchSchool(
          _selectedSchool?['id'] ?? _selectedSchoolId,
          role: role,
        );
      } else {
        responseData = await ApiService.login(
          emailController.text.trim(),
          passwordController.text,
          schoolId: _selectedSchool?['id'] ?? _selectedSchoolId,
          role: role,
        );
      }

      if (kDebugMode) {
        print('🔐 Role Selection Response: $responseData');
      }

      await _handleLoginResponse(responseData);
    } catch (error) {
      if (kDebugMode) {
        print('❌ Role selection error: $error');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.getFriendlyMessage(error)),
          backgroundColor: Colors.red.shade700,
        ),
      );

      setState(() {
        _isLoading = false;
        // Jangan reset _showRoleSelection agar user bisa memilih role lain
      });
    }
  }

  Widget _buildRoleSelection() {
    return Column(
      children: [
        if (_isLoading)
          const LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)),
          ),
        const SizedBox(height: 20),
        Text(
          'Pilih Role',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Text(
          'Halo ${_userData?['name'] ?? _userData?['nama'] ?? 'User'},',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        Text(
          'Sekolah: ${_selectedSchool?['school_name'] ?? _selectedSchool?['name'] ?? _selectedSchool?['nama_sekolah'] ?? _userData?['school_name'] ?? _userData?['nama_sekolah'] ?? '-'}',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _roleList.length,
          itemBuilder: (context, index) {
            final role = _roleList[index];
            return Card(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              child: ListTile(
                key: ValueKey('role_$role'),
                leading: _getRoleIcon(role),
                title: Text(_getRoleDisplayName(role)),
                subtitle: Text('Akses sebagai ${_getRoleDescription(role)}'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _isLoading ? null : () => _selectRole(role),
              ),
            );
          },
        ),
        SizedBox(height: 20),
        if (_schoolList.length > 1)
          TextButton(
            onPressed: () {
              setState(() {
                _showRoleSelection = false;
                _showSchoolSelection = true; // Kembali ke pemilihan sekolah
                _isLoading = false;
              });
            },
            child: const Text('Kembali ke Pilih Sekolah'),
          )
        else
          TextButton(
            onPressed: () {
              setState(() {
                _showRoleSelection = false;
                _showSchoolSelection = false; // Kembali ke login
                _isLoading = false;
              });
            },
            child: const Text('Kembali ke Login'),
          ),
      ],
    );
  }

  Widget _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icon(Icons.admin_panel_settings, color: Color(0xFF0D47A1));
      case 'guru':
        return Icon(Icons.school, color: Colors.green);
      case 'wali':
        return Icon(Icons.family_restroom, color: Colors.purple);
      case 'staff':
        return Icon(Icons.work, color: Colors.orange);
      default:
        return Icon(Icons.person, color: Colors.grey);
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return 'Administrator';
      case 'guru':
      case 'teacher':
        return 'Teacher';
      case 'wali':
      case 'parent':
      case 'walimurid':
      case 'wali murid':
        return 'Parent';
      case 'staff':
        return 'Staff';
      default:
        // Capitalize first letter if no match found
        if (role.isNotEmpty) {
          return role[0].toUpperCase() + role.substring(1);
        }
        return role;
    }
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'admin':
        return 'Pengelola sistem sekolah';
      case 'guru':
        return 'Pengajar dan pendidikan';
      case 'wali':
        return 'Orang tua/wali siswa';
      case 'staff':
        return 'Staff administrasi';
      default:
        return 'Pengguna sistem';
    }
  }

  Widget _buildSchoolSelection() {
    return Column(
      children: [
        if (_isLoading)
          const LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)),
          ),
        const SizedBox(height: 20),
        Text(
          'Pilih Sekolah',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Text(
          'Halo ${_userData?['name'] ?? _userData?['nama'] ?? 'User'}, silakan pilih sekolah:',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _schoolList.length,
          itemBuilder: (context, index) {
            final sekolah = _schoolList[index];
            return Card(
              margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              child: ListTile(
                key: ValueKey('school_${sekolah['school_id'] ?? index}'),
                leading: Icon(Icons.school, color: Color(0xFF0D47A1)),
                title: Text(sekolah['school_name'] ?? 'Sekolah Tanpa Nama'),
                subtitle: Text(sekolah['address'] ?? ''),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: _isLoading
                    ? null
                    : () => _selectSchool(sekolah['school_id']),
              ),
            );
          },
        ),
        SizedBox(height: 20),
        TextButton(
          onPressed: () {
            setState(() {
              _showSchoolSelection = false;
              _isLoading = false;
            });
          },
          child: Text('Kembali ke Login'),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/icon/KamilEdu.png', height: 80),
        SizedBox(height: 20),
        Text(
          'Kamil Edu',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        if (!_serverConnected) ...[
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Server tidak terhubung',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: 30),
        TextField(
          controller: emailController,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: 15),
        TextField(
          controller: passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock),
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          onSubmitted: (_) => login(),
        ),
        SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_serverConnected && !_isLoading) ? login : null,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 15),
              backgroundColor: const Color(0xFF0D47A1),
              disabledBackgroundColor: const Color(0xFF0D47A1).withOpacity(0.6),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('LOGIN', style: TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (_serverConnected && !_isLoading)
                ? _handleGoogleSignIn
                : null,
            icon: Image.asset(
              'assets/icon/google_logo.png',
              height: 24,
              errorBuilder: (c, o, s) => const Icon(Icons.login),
            ),
            label: Text(
              _isLoading ? 'Mohon Tunggu...' : 'Masuk dengan Google',
              style: TextStyle(
                color: _isLoading ? Colors.grey : const Color(0xFF0D47A1),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: BorderSide(
                color: _isLoading ? Colors.grey : const Color(0xFF0D47A1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D47A1), Color(0xFF002171)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 40,
                  ),
                  child: Center(
                    child: Card(
                      margin: EdgeInsets.symmetric(horizontal: 20),
                      elevation: 8,
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: _showSchoolSelection
                            ? _buildSchoolSelection()
                            : _showRoleSelection
                            ? _buildRoleSelection()
                            : _buildLoginForm(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _handleLoginResponse(Map<String, dynamic> responseData) async {
    // 1. Check OTP requirement
    if (responseData['require_otp'] == true ||
        responseData['otp_debug'] != null ||
        responseData['message'] == 'OTP sent to email') {
      if (kDebugMode) print('🔐 Need OTP verification');
      setState(() {
        _isLoading = false; // Stop loading to show dialog
      });
      _showOtpDialog(responseData['email']);
      // If we have otp_debug, we might want to pre-fill or show it in debug mode
      if (responseData['otp_debug'] != null) {
        _otpCode = responseData['otp_debug']; // Save for verify call
        print('Debug OTP: $_otpCode');
      }
      return;
    }

    // 2. School Selection
    if (responseData['pilih_sekolah'] == true) {
      if (responseData['sekolah_list'] == null ||
          (responseData['sekolah_list'] as List).isEmpty) {
        throw Exception('Akun Anda belum terdaftar pada sekolah manapun');
      }

      // Special handling for Google Login: Save token immediately if present
      // This allows using switchSchool endpoint later
      if (responseData['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', responseData['token']);
        if (kDebugMode) print('🔐 Token saved during school selection phase');
      }

      if (responseData['user'] == null) {
        throw Exception('Data user tidak ditemukan');
      }

      setState(() {
        _showSchoolSelection = true;
        _schoolList = responseData['sekolah_list'];
        _userData = responseData['user'];
        _isLoading = false;
      });
      if (kDebugMode) {
        print('🏫 School List Count: ${_schoolList.length}');
        for (var s in _schoolList) {
          print(' - ${s['school_name']} (${s['school_id']})');
        }
      }
      return;
    }

    // 3. Role Selection
    if (responseData['pilih_role'] == true) {
      // Special handling for Google Login: Save token immediately if present
      // This allows using switchSchool endpoint later
      if (responseData['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', responseData['token']);
        if (kDebugMode) print('🔐 Token saved during role selection phase');
      }

      if (responseData['role_list'] == null ||
          (responseData['role_list'] as List).isEmpty) {
        throw Exception('Daftar role tidak tersedia untuk akun Anda');
      }

      if (responseData['user'] == null) {
        throw Exception('Data user tidak ditemukan');
      }

      setState(() {
        _showSchoolSelection = false; // Fix: Hide school selection
        _showRoleSelection = true;
        _roleList = responseData['role_list'];
        _userData = responseData['user'];
        // Handle variations in key naming from backend (school vs sekolah)
        _selectedSchool =
            responseData['school'] ?? responseData['sekolah'] ?? {};
        _isLoading = false;
      });
      return;
    }

    // 4. Handle successful login (Token received)
    if (responseData['token'] == null) {
      throw Exception('Token tidak ditemukan dalam response server');
    }

    if (responseData['user'] == null) {
      throw Exception('Data user tidak ditemukan dalam response server');
    }

    // Simpan data login
    await _saveLoginData(responseData);

    // Validasi role sebelum navigasi
    final String userRole = responseData['user']['role']?.toString() ?? '';
    if (userRole.isEmpty) {
      throw Exception('Role user tidak ditemukan');
    }

    if (!mounted) return;

    // Navigate berdasarkan role
    Navigator.pushReplacementNamed(context, '/$userRole');

    String welcomeName = responseData['user']['nama'] ?? 'User';
    String schoolName =
        responseData['school']?['name'] ??
        responseData['school']?['nama_sekolah'] ??
        '';
    if (schoolName.isNotEmpty) welcomeName += ' di $schoolName';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Login berhasil! Selamat datang $welcomeName')),
    );
  }

  void _showOtpDialog(String email) {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Verifikasi OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kode OTP telah dikirim ke email:',
              style: TextStyle(fontSize: 12),
            ),
            Text(email, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('Masukkan 6 digit kode OTP:'),
            SizedBox(height: 8),
            TextField(
              controller: otpController,
              decoration: InputDecoration(
                labelText: 'Kode OTP',
                border: OutlineInputBorder(),
                counterText: '',
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, letterSpacing: 8),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              setState(() => _isLoading = false);
            },
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final otp = otpController.text.trim();
              if (otp.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Masukkan 6 digit kode OTP')),
                );
                return;
              }
              Navigator.pop(context); // Close dialog
              await _verifyOtp(email, otp);
            },
            child: Text('Verifikasi'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyOtp(String email, String otp) async {
    setState(() => _isLoading = true);
    try {
      // Call verifyOtp without school/role initially
      final response = await ApiService.verifyOtp(email, otp);

      // Save OTP only if successful (so we can use it for subsequent school/role selection)
      if (mounted) {
        setState(() => _otpCode = otp);
      }

      await _handleLoginResponse(response);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMsg = e.toString().replaceAll('Exception:', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verifikasi Gagal: $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
        // Re-open dialog to interpret retry
        _showOtpDialog(email);
      }
    }
  }
}
