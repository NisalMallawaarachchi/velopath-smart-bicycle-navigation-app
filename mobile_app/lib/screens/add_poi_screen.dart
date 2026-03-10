import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../widgets/device_helper.dart';
import '../config/api_config.dart';
import '../providers/theme_provider.dart';

class AddPOIScreen extends StatefulWidget {
  const AddPOIScreen({super.key});

  @override
  State<AddPOIScreen> createState() => _AddPOIScreenState();
}

class _AddPOIScreenState extends State<AddPOIScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController otherAmenityController = TextEditingController();

  File? pickedImage;
  double? lat;
  double? lon;
  bool _isSubmitting = false;

  String? selectedAmenity;
  List<String> amenityOptions = ['Waterfall', 'School', 'Park', 'Other'];

  String? selectedDistrict;
  List<String> districtOptions = [
    'Colombo', 'Gampaha', 'Kalutara', 'Kandy', 'Matale',
    'Nuwara Eliya', 'Galle', 'Matara', 'Hambantota', 'Jaffna',
    'Kilinochchi', 'Mannar', 'Vavuniya', 'Mullaitivu', 'Batticaloa',
    'Ampara', 'Trincomalee', 'Kurunegala', 'Puttalam', 'Anuradhapura',
    'Polonnaruwa', 'Badulla', 'Monaragala', 'Ratnapura', 'Kegalle',
  ];

  // ── Validation helpers ────────────────────────────────────────────────────

  /// Returns an error message if [value] contains digits, otherwise null.
  String? _noNumbersValidator(String? value, String fieldName, {bool required = true}) {
    if (required && (value == null || value.trim().isEmpty)) {
      return 'Enter $fieldName';
    }
    if (value != null && value.isNotEmpty && RegExp(r'\d').hasMatch(value)) {
      return '$fieldName must not contain numbers';
    }
    return null;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Location Required"),
          content: const Text("Please enable GPS to add a POI."),
          actions: [
            TextButton(
              child: const Text("OK"),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    Position pos = await Geolocator.getCurrentPosition();
    setState(() {
      lat = pos.latitude;
      lon = pos.longitude;
    });
  }

  // ── Loading dialog ────────────────────────────────────────────────────────

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // user cannot dismiss by tapping outside
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return PopScope(
          canPop: false, // prevent back-button dismiss
          child: Dialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated spinner with coloured ring
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? ThemeProvider.accentCyan : ThemeProvider.primaryDarkBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    "Creating New Place…",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    pickedImage != null
                        ? "Uploading your photo and saving details.\nThis may take a moment."
                        : "Saving place details.\nThis will only take a second.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _dismissLoadingDialog() {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> submitPOI() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    _showLoadingDialog();

    try {
      final deviceId = await getDeviceId();
      final uri = Uri.parse(ApiConfig.pois);
      final request = http.MultipartRequest("POST", uri)
        ..fields["name"] = nameController.text.trim()
        ..fields["amenity"] = selectedAmenity == "Other"
            ? otherAmenityController.text.trim()
            : selectedAmenity ?? ""
        ..fields["description"] = descriptionController.text.trim()
        ..fields["lat"] = lat.toString()
        ..fields["lon"] = lon.toString()
        ..fields["district"] = selectedDistrict ?? "Unknown"
        ..fields["deviceId"] = deviceId;

      if (pickedImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          pickedImage!.path,
        ));
      }

      final response = await request.send();

      _dismissLoadingDialog();
      setState(() => _isSubmitting = false);

      if (!mounted) return;

      if (response.statusCode == 201) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Failed to add place. Please try again."),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      _dismissLoadingDialog();
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Image picker ─────────────────────────────────────────────────────────

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      setState(() => pickedImage = File(file.path));
    }
  }

  // ── Input decoration ──────────────────────────────────────────────────────

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        fontSize: 15,
      ),
      prefixIcon: Icon(
        icon,
        color: isDark ? ThemeProvider.accentCyan : ThemeProvider.primaryDarkBlue,
        size: 22,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : ThemeProvider.primaryDarkBlue.withValues(alpha: 0.04),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? ThemeProvider.accentCyan : ThemeProvider.primaryDarkBlue,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New Place",
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ── Section: Place Details ──────────────────────────────────
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18,
                      color: isDark
                          ? ThemeProvider.accentCyan
                          : ThemeProvider.primaryDarkBlue),
                  const SizedBox(width: 8),
                  Text(
                    "Place Details",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? ThemeProvider.accentCyan
                          : ThemeProvider.primaryDarkBlue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Name ───────────────────────────────────────────────────
              TextFormField(
                controller: nameController,
                style: TextStyle(
                  color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue,
                ),
                decoration: _inputDecoration(
                  label: "Place Name",
                  icon: Icons.place_outlined,
                  isDark: isDark,
                ),
                validator: (v) => _noNumbersValidator(v, "Name"),
              ),
              const SizedBox(height: 14),

              // ── Amenity Dropdown ───────────────────────────────────────
              DropdownButtonFormField<String>(
                value: selectedAmenity,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue,
                  fontSize: 15,
                ),
                decoration: _inputDecoration(
                  label: "Amenity Type",
                  icon: Icons.category_outlined,
                  isDark: isDark,
                ),
                items: amenityOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => selectedAmenity = val),
                validator: (v) =>
                    v == null || v.isEmpty ? "Select amenity" : null,
              ),

              // ── Custom amenity (only shown when "Other" is selected) ───
              if (selectedAmenity == "Other") ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: otherAmenityController,
                  style: TextStyle(
                    color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue,
                  ),
                  decoration: _inputDecoration(
                    label: "Custom Amenity",
                    icon: Icons.edit_outlined,
                    isDark: isDark,
                  ),
                  validator: (v) => _noNumbersValidator(v, "Custom amenity"),
                ),
              ],

              const SizedBox(height: 14),

              // ── Description ────────────────────────────────────────────
              TextFormField(
                controller: descriptionController,
                maxLines: 3,
                style: TextStyle(
                  color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue,
                ),
                decoration: _inputDecoration(
                  label: "Description (optional)",
                  icon: Icons.description_outlined,
                  isDark: isDark,
                ),
                // optional field — only validate if something was typed
                validator: (v) =>
                    _noNumbersValidator(v, "Description", required: false),
              ),

              const SizedBox(height: 14),

              // ── District Dropdown ──────────────────────────────────────
              DropdownButtonFormField<String>(
                value: selectedDistrict,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(
                  color: isDark ? Colors.white : ThemeProvider.primaryDarkBlue,
                  fontSize: 15,
                ),
                decoration: _inputDecoration(
                  label: "District",
                  icon: Icons.map_outlined,
                  isDark: isDark,
                ),
                items: districtOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => selectedDistrict = val),
                validator: (v) =>
                    v == null || v.isEmpty ? "Select district" : null,
              ),

              const SizedBox(height: 14),

              // ── GPS indicator ──────────────────────────────────────────
              if (lat != null && lon != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? ThemeProvider.accentCyan.withValues(alpha: 0.08)
                        : ThemeProvider.primaryDarkBlue.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? ThemeProvider.accentCyan.withValues(alpha: 0.2)
                          : ThemeProvider.primaryDarkBlue.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.my_location,
                          size: 20,
                          color: isDark
                              ? ThemeProvider.accentCyan
                              : ThemeProvider.primaryDarkBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "GPS: ${lat!.toStringAsFixed(6)}, ${lon!.toStringAsFixed(6)}",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // ── Section: Photo ─────────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.photo_camera_outlined,
                      size: 18,
                      color: isDark
                          ? ThemeProvider.accentCyan
                          : ThemeProvider.primaryDarkBlue),
                  const SizedBox(width: 8),
                  Text(
                    "Photo",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? ThemeProvider.accentCyan
                          : ThemeProvider.primaryDarkBlue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Image capture / preview ────────────────────────────────
              pickedImage == null
                  ? InkWell(
                      onTap: pickImage,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : ThemeProvider.primaryDarkBlue
                                  .withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : ThemeProvider.primaryDarkBlue
                                    .withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? ThemeProvider.accentCyan
                                        .withValues(alpha: 0.1)
                                    : ThemeProvider.primaryDarkBlue
                                        .withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt_outlined,
                                size: 28,
                                color: isDark
                                    ? ThemeProvider.accentCyan
                                    : ThemeProvider.primaryDarkBlue,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Tap to capture photo",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            pickedImage!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => pickedImage = null),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),

              const SizedBox(height: 28),

              // ── Save button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : submitPOI,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? ThemeProvider.accentCyan
                        : ThemeProvider.primaryDarkBlue,
                    foregroundColor:
                        isDark ? ThemeProvider.primaryDarkBlue : Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_outlined, size: 22),
                            SizedBox(width: 10),
                            Text(
                              "Save Place",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}