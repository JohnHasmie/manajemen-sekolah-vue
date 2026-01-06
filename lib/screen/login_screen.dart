import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/fcm_service.dart';
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

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

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
      setState(() {
        _serverConnected = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server tidak terhubung. Pastikan backend berjalan.'),
        ),
      );
    }
  }

  void _handleTokenExpired() {
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

      String errorMessage = 'Terjadi kesalahan saat login';
      if (error.toString().contains('Token tidak ditemukan')) {
        errorMessage = 'Token tidak valid dari server';
      } else if (error.toString().contains('Data user tidak ditemukan')) {
        errorMessage = 'Data user tidak valid dari server';
      } else {
        errorMessage = error.toString();
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));

      if (error.toString().contains('expired') ||
          error.toString().contains('token') ||
          error.toString().contains('Token')) {
        errorMessage = 'Sesi telah berakhir. Silakan login kembali.';
        _handleTokenExpired();
      } else if (error.toString().contains('Token tidak ditemukan')) {
        errorMessage = 'Token tidak valid dari server';
      } else if (error.toString().contains('Data user tidak ditemukan')) {
        errorMessage = 'Data user tidak valid dari server';
      } else {
        errorMessage = error.toString();
      }

      if (mounted) {
        if (!error.toString().contains('expired')) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }

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

    // Force refresh and send FCM token to backend after successful login
    try {
      final fcmService = FCMService();

      if (kDebugMode) {
        print('🔄 Force refreshing FCM token after login...');
      }

      // Force refresh to get new token (in case Firebase project changed)
      final fcmToken = await fcmService.forceRefreshToken();

      if (fcmToken != null) {
        if (kDebugMode) {
          print('✅ FCM token refreshed and sent successfully');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ No FCM token available after refresh');
        }
      }
    } catch (e) {
      // Don't fail login if FCM token sending fails
      if (kDebugMode) {
        print('⚠️ Failed to refresh FCM token (non-critical): $e');
      }
    }
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
      final String? token = googleAuth.accessToken; // or idToken

      if (kDebugMode) {
        print('📧 Google User: ${googleUser.email}');
        print('🔑 Google Token: ${token != null ? "Yes" : "No"}');
      }

      // 2. Send to Backend
      final responseData = await ApiService.googleLogin(
        email: googleUser.email,
        displayName: googleUser.displayName,
        photoUrl: googleUser.photoUrl,
        googleToken: token,
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

      String errorMessage = 'Gagal login dengan Google';
      if (error.toString().contains('404') ||
          error.toString().contains('tidak terdaftar')) {
        errorMessage = 'Email Google tidak terdaftar di sistem sekolah.';
      } else {
        errorMessage = error.toString().replaceAll('Exception:', '').trim();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));

      setState(() {
        _isLoading = false;
        // Jangan reset _showRoleSelection agar user bisa memilih role lain
      });
    }
  }

  Widget _buildRoleSelection() {
    return Column(
      children: [
        SizedBox(height: 20),
        Text(
          'Pilih Role',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Text(
          'Halo ${_userData?['nama']},',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        Text(
          'Sekolah: ${_selectedSchool?['nama_sekolah'] ?? _userData?['nama_sekolah']}',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            itemCount: _roleList.length,
            itemBuilder: (context, index) {
              final role = _roleList[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                child: ListTile(
                  leading: _getRoleIcon(role),
                  title: Text(_getRoleDisplayName(role)),
                  subtitle: Text('Akses sebagai ${_getRoleDescription(role)}'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _selectRole(role),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 20),
        TextButton(
          onPressed: () {
            setState(() {
              _showRoleSelection = false;
              _showSchoolSelection = true; // Kembali ke pemilihan sekolah
              _isLoading = false;
            });
          },
          child: Text('Kembali ke Pilih Sekolah'),
        ),
      ],
    );
  }

  Widget _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icon(Icons.admin_panel_settings, color: Colors.blue);
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
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'guru':
        return 'Guru';
      case 'wali':
        return 'Wali Murid';
      case 'staff':
        return 'Staff';
      default:
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
        SizedBox(height: 20),
        Text(
          'Pilih Sekolah',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Text(
          'Halo ${_userData?['nama']}, silakan pilih sekolah:',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            itemCount: _schoolList.length,
            itemBuilder: (context, index) {
              final sekolah = _schoolList[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                child: ListTile(
                  leading: Icon(Icons.school, color: Colors.blue),
                  title: Text(sekolah['school_name']),
                  subtitle: Text(sekolah['address'] ?? ''),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _selectSchool(sekolah['school_id']),
                ),
              );
            },
          ),
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
        Icon(Icons.school, size: 80, color: Colors.blue),
        SizedBox(height: 20),
        Text(
          'Sistem Manajemen Sekolah',
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
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _serverConnected ? login : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: Text('LOGIN'),
                ),
        ),
        SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: _isLoading
              ? SizedBox()
              : OutlinedButton.icon(
                  onPressed: _serverConnected ? _handleGoogleSignIn : null,
                  icon: Image.asset(
                    'assets/icon/app_icon.png',
                    height: 24,
                    errorBuilder: (c, o, s) => Icon(Icons.login),
                  ), // Fallback use simple icon
                  label: Text('Masuk dengan Google'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    side: BorderSide(color: Colors.blue),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[400]!, Colors.blue[800]!],
          ),
        ),
        child: Center(
          child: Card(
            margin: EdgeInsets.all(20),
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
          responseData['sekolah_list'].isEmpty) {
        throw Exception('Daftar sekolah tidak tersedia');
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
      return;
    }

    // 3. Role Selection
    if (responseData['pilih_role'] == true) {
      if (responseData['role_list'] == null ||
          responseData['role_list'].isEmpty) {
        throw Exception('Daftar role tidak tersedia');
      }

      if (responseData['user'] == null) {
        throw Exception('Data user tidak ditemukan');
      }

      setState(() {
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
