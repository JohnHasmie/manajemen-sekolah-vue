import 'package:flutter/material.dart';
import 'package:manajemensekolah/screen/admin/admin_class_management.dart';
import 'package:manajemensekolah/screen/admin/student_management.dart';
import 'package:manajemensekolah/screen/admin/subject_management.dart';
import 'package:manajemensekolah/screen/admin/teacher_admin.dart';
import 'package:manajemensekolah/utils/language_utils.dart'; // Assuming this is where AppLocalizations is

class AdminDataManagementScreen extends StatelessWidget {
  const AdminDataManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Kelola Data',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2563EB), Color(0xFF2563EB).withOpacity(0.8)],
            ),
          ),
        ),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.1,
          children: [
            _buildDashboardCard(
              AppLocalizations.manageStudents.tr,
              Icons.people_alt_outlined,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentManagementScreen(),
                ),
              ),
            ),
            _buildDashboardCard(
              AppLocalizations.manageTeachers.tr,
              Icons.person_outline,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TeacherAdminScreen()),
              ),
            ),
            _buildDashboardCard(
              AppLocalizations.manageClasses.tr,
              Icons.class_outlined,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminClassManagementScreen(),
                ),
              ),
            ),
            _buildDashboardCard(
              AppLocalizations.manageSubjects.tr,
              Icons.book_outlined,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubjectManagementScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    String title,
    dynamic icon,
    VoidCallback onTap, {
    int? badgeCount,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 5,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Strip biru di pinggir kiri
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: Color(0xFF2563EB), // Admin Blue
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              ),

              // Background pattern effect
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Notification Badge
              if (badgeCount != null && badgeCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : badgeCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Content - di tengah dengan icon di atas text
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon Container
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: Color(0xFF2563EB), size: 24),
                      ),
                      SizedBox(height: 12),
                      // Title - di bawah icon
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center, // Text di tengah
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
