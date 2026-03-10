import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'auth/login_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final subtitleColor = isDark ? Colors.white60 : Colors.grey.shade600;
    
    return Scaffold(
      appBar: AppBar(
        title: Text("My Profile", style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue)),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.user;

          if (user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 80,
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("Not logged in",
                      style: TextStyle(fontSize: 18, color: subtitleColor)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    ),
                    child: const Text("Go to Login"),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // ─── Profile Header ───
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ThemeProvider.primaryDarkBlue,
                        ThemeProvider.primaryDarkBlue.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: ThemeProvider.primaryDarkBlue.withValues(alpha: 0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                    ]
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: Column(
                    children: [
                      // Avatar with ring
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          child: Text(
                            user.username.isNotEmpty
                                ? user.username[0].toUpperCase()
                                : "?",
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        user.username,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      if (user.country != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.public,
                                  color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                user.country!,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Edit button
                      OutlinedButton.icon(
                        onPressed: () => _showEditProfile(context, auth),
                        icon: const Icon(Icons.edit,
                            color: Colors.white, size: 16),
                        label: const Text("Edit Profile",
                            style: TextStyle(color: Colors.white, fontSize: 14)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Stats ───
                      Row(
                        children: [
                          _StatCard(
                            icon: Icons.star,
                            label: "Reputation",
                            value: user.reputationScore.toStringAsFixed(1),
                            color: Colors.orange,
                            cardColor: cardColor,
                          ),
                          const SizedBox(width: 12),
                          _StatCard(
                            icon: Icons.emoji_events,
                            label: "Contributions",
                            value: user.totalContributions.toString(),
                            color: Colors.green,
                            cardColor: cardColor,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ─── Account Details ───
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          "ACCOUNT DETAILS",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white54 : ThemeProvider.primaryDarkBlue.withValues(alpha: 0.7),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                            width: 1,
                          ),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _InfoRow(
                              icon: Icons.person_outline,
                              iconColor: ThemeProvider.primaryDarkBlue,
                              label: "Username",
                              value: user.username,
                              subtitleColor: subtitleColor,
                            ),
                            Divider(height: 1, indent: 64, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                            _InfoRow(
                              icon: Icons.email_outlined,
                              iconColor: Colors.teal,
                              label: "Email",
                              value: user.email,
                              subtitleColor: subtitleColor,
                            ),
                            Divider(height: 1, indent: 64, color: isDark ? const Color(0xFF334155) : Colors.grey.shade200),
                            _InfoRow(
                              icon: Icons.public,
                              iconColor: Colors.blue,
                              label: "Country",
                              value: user.country ?? "Not set",
                              subtitleColor: subtitleColor,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ─── App Settings ───
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          "PREFERENCES",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white54 : ThemeProvider.primaryDarkBlue.withValues(alpha: 0.7),
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                            width: 1,
                          ),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ThemeProvider.accentCyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.settings, color: ThemeProvider.accentCyan, size: 24),
                          ),
                          title: const Text("App Settings", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          subtitle: Text("Theme, notifications, & preferences", style: TextStyle(fontSize: 13, color: subtitleColor)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ─── Logout ───
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: () => _handleLogout(context, auth),
                          icon: const Icon(Icons.logout, color: Colors.redAccent, size: 22),
                          label: const Text("Logout",
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleLogout(BuildContext context, AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await auth.logout();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showEditProfile(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditProfileSheet(auth: auth),
    );
  }
}

// ──────────────────────────────────────
// Stat card
// ──────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color cardColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
            width: 1,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(value,
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: isDark ? Colors.white : color, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isDark ? Colors.white60 : Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────
// Info row
// ──────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color subtitleColor;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(label,
          style: TextStyle(fontSize: 13, color: subtitleColor, fontWeight: FontWeight.w500)),
      subtitle: Text(value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
    );
  }
}

// ──────────────────────────────────────
// Edit Profile Bottom Sheet
// ──────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final AuthProvider auth;
  const _EditProfileSheet({required this.auth});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _usernameController;
  String? _selectedCountry;
  bool _saving = false;
  String? _error;

  static const List<String> _countries = [
    "Afghanistan", "Albania", "Algeria", "Andorra", "Angola",
    "Argentina", "Armenia", "Australia", "Austria", "Azerbaijan",
    "Bahamas", "Bahrain", "Bangladesh", "Barbados", "Belarus",
    "Belgium", "Belize", "Benin", "Bhutan", "Bolivia",
    "Bosnia and Herzegovina", "Botswana", "Brazil", "Brunei", "Bulgaria",
    "Cambodia", "Cameroon", "Canada", "Chile", "China",
    "Colombia", "Costa Rica", "Croatia", "Cuba", "Cyprus",
    "Czech Republic", "Denmark", "Ecuador", "Egypt", "Estonia",
    "Ethiopia", "Fiji", "Finland", "France", "Georgia",
    "Germany", "Ghana", "Greece", "Guatemala", "Haiti",
    "Honduras", "Hungary", "Iceland", "India", "Indonesia",
    "Iran", "Iraq", "Ireland", "Israel", "Italy",
    "Jamaica", "Japan", "Jordan", "Kazakhstan", "Kenya",
    "Kuwait", "Laos", "Latvia", "Lebanon", "Libya",
    "Lithuania", "Luxembourg", "Madagascar", "Malaysia", "Maldives",
    "Mali", "Malta", "Mexico", "Moldova", "Mongolia",
    "Montenegro", "Morocco", "Mozambique", "Myanmar", "Namibia",
    "Nepal", "Netherlands", "New Zealand", "Nicaragua", "Nigeria",
    "North Macedonia", "Norway", "Oman", "Pakistan", "Palestine",
    "Panama", "Paraguay", "Peru", "Philippines", "Poland",
    "Portugal", "Qatar", "Romania", "Russia", "Rwanda",
    "Saudi Arabia", "Senegal", "Serbia", "Singapore", "Slovakia",
    "Slovenia", "Somalia", "South Africa", "South Korea", "Spain",
    "Sri Lanka", "Sudan", "Sweden", "Switzerland", "Syria",
    "Taiwan", "Tanzania", "Thailand", "Tunisia", "Turkey",
    "Uganda", "Ukraine", "United Arab Emirates", "United Kingdom",
    "United States", "Uruguay", "Uzbekistan", "Venezuela", "Vietnam",
    "Yemen", "Zambia", "Zimbabwe",
  ];

  @override
  void initState() {
    super.initState();
    _usernameController =
        TextEditingController(text: widget.auth.user?.username ?? '');
    _selectedCountry = widget.auth.user?.country;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim();
    if (username.length < 3) {
      setState(() => _error = "Username must be at least 3 characters");
      return;
    }

    setState(() { _saving = true; _error = null; });

    final success = await widget.auth.updateProfile(
      username, country: _selectedCountry,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile updated!"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      setState(() {
        _saving = false;
        _error = widget.auth.errorMessage ?? "Update failed";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 24, 24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text("Edit Profile",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: "Username",
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          GestureDetector(
            onTap: () => _showCountryPicker(context),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: "Country",
                prefixIcon: const Icon(Icons.public),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
              child: Text(
                _selectedCountry ?? "Select country",
                style: TextStyle(
                  fontSize: 16,
                  color: _selectedCountry != null ? null : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeProvider.primaryDarkBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _saving
                  ? const SizedBox(height: 24, width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text("Save Changes",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showCountryPicker(BuildContext context) {
    final searchController = TextEditingController();
    List<String> filtered = List.from(_countries);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.85,
            minChildSize: 0.3,
            expand: false,
            builder: (ctx, scrollController) {
              return Column(children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    autofocus: true,
                    onChanged: (q) {
                      setSheetState(() {
                        filtered = q.isEmpty
                            ? List.from(_countries)
                            : _countries.where((c) =>
                                c.toLowerCase().contains(q.toLowerCase())).toList();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search country...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final country = filtered[i];
                      final selected = country == _selectedCountry;
                      return ListTile(
                        title: Text(country,
                            style: TextStyle(
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              color: selected ? const Color(0xFF0E417A) : null,
                            )),
                        trailing: selected
                            ? const Icon(Icons.check_circle, color: Color(0xFF0E417A))
                            : null,
                        onTap: () {
                          setState(() => _selectedCountry = country);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ]);
            },
          );
        },
      ),
    );
  }
}
