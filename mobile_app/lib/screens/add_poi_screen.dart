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

  Future<void> submitPOI() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final deviceId = await getDeviceId();
    final uri = Uri.parse(ApiConfig.pois);
    final request = http.MultipartRequest("POST", uri)
      ..fields["name"] = nameController.text
      ..fields["amenity"] = selectedAmenity == "Other"
          ? otherAmenityController.text
          : selectedAmenity ?? ""
      ..fields["description"] = descriptionController.text
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

    setState(() => _isSubmitting = false);

    if (response.statusCode == 201 && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      setState(() => pickedImage = File(file.path));
    }
  }

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
      prefixIcon: Icon(icon,
          color: isDark ? ThemeProvider.accentCyan : ThemeProvider.primaryDarkBlue,
          size: 22),
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
              // Section header
              Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18,
                      color: isDark ? ThemeProvider.accentCyan : ThemeProvider.primaryDarkBlue),
                  const SizedBox(width: 8),
                  Text(
                    "Place Details",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? ThemeProvider.accentCyan : ThemeProvider.primaryDarkBlue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Name
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
                validator: (v) => v!.isEmpty ? "Enter name" : null,
              ),
              const SizedBox(height: 14),

              // Amenity Dropdown
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
                validator: (v) => v == null || v.isEmpty ? "Select amenity" : null,
              ),

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
                  validator: (v) => v!.isEmpty ? "Enter custom amenity" : null,
                ),
              ],

              const SizedBox(height: 14),

              // Description
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
              ),

              const SizedBox(height: 14),

              // District Dropdown
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
                validator: (v) => v == null || v.isEmpty ? "Select district" : null,
              ),

              const SizedBox(height: 14),

              // GPS location indicator
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
                          color: isDark ? ThemeProvider.accentCyan : ThemeProvider.primaryDarkBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "GPS: ${lat!.toStringAsFixed(6)}, ${lon!.toStringAsFixed(6)}",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Section header for image
              Row(
                children: [
                  Icon(Icons.photo_camera_outlined,
                      size: 18,
                      color: isDark ? ThemeProvider.accentCyan : ThemeProvider.primaryDarkBlue),
                  const SizedBox(width: 8),
                  Text(
                    "Photo",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? ThemeProvider.accentCyan : ThemeProvider.primaryDarkBlue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Capture button / Image preview
              pickedImage == null
                  ? InkWell(
                      onTap: pickImage,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : ThemeProvider.primaryDarkBlue.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : ThemeProvider.primaryDarkBlue.withValues(alpha: 0.15),
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
                                    ? ThemeProvider.accentCyan.withValues(alpha: 0.1)
                                    : ThemeProvider.primaryDarkBlue.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt_outlined,
                                size: 28,
                                color: isDark ? ThemeProvider.accentCyan : ThemeProvider.primaryDarkBlue,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Tap to capture photo",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),

              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : submitPOI,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? ThemeProvider.accentCyan
                        : ThemeProvider.primaryDarkBlue,
                    foregroundColor: isDark
                        ? ThemeProvider.primaryDarkBlue
                        : Colors.white,
                    disabledBackgroundColor: Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22, width: 22,
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
