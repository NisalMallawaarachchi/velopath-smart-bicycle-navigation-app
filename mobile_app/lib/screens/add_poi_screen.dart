import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';

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

  // Amenity dropdown
  String? selectedAmenity;
  List<String> amenityOptions = ['Waterfall', 'School', 'Park', 'Other'];

  // District dropdown
  String? selectedDistrict;
  List<String> districtOptions = [
    'Colombo',
    'Gampaha',
    'Kandy',
    'Galle',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // fetch GPS automatically
  }

Future<void> _getCurrentLocation() async {
  // 1️⃣ Check if GPS/location service is enabled
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Location Required"),
        content: const Text("Please enable GPS to add a POI."),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
    return; // stop execution if GPS is off
  }

  // 2️⃣ Request location permission
  LocationPermission permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.deniedForever ||
      permission == LocationPermission.denied) {
    // Optionally show another dialog telling user they must grant permission
    return;
  }

  // 3️⃣ Get current position
  Position pos = await Geolocator.getCurrentPosition();
  setState(() {
    lat = pos.latitude;
    lon = pos.longitude;
  });
}


Future<void> submitPOI() async {
  if (!_formKey.currentState!.validate()) return;

  if (lat == null || lon == null) {
    await _getCurrentLocation();
    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Cannot add POI. Location is required. Please enable GPS.")));
      return;
    }
  }

  final uri = Uri.parse("http://10.75.197.44:5001/api/pois");

  final request = http.MultipartRequest("POST", uri)
    ..fields["name"] = nameController.text
    ..fields["amenity"] = selectedAmenity == "Other"
        ? otherAmenityController.text
        : selectedAmenity ?? ""
    ..fields["description"] = descriptionController.text
    ..fields["lat"] = lat.toString()
    ..fields["lon"] = lon.toString()
    ..fields["district"] = selectedDistrict ?? "Unknown";

  if (pickedImage != null) {
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      pickedImage!.path,
      contentType: MediaType('image', 'jpeg'),
    ));
  }

  final response = await request.send();

  if (response.statusCode == 201) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("POI Added Successfully")));
    Navigator.pop(context, true);
  } else {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Failed to add POI")));
  }
}

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file != null) {
      setState(() => pickedImage = File(file.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add POI")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
                validator: (v) => v!.isEmpty ? "Enter name" : null,
              ),
              const SizedBox(height: 12),

              // Amenity Dropdown
              DropdownButtonFormField<String>(
                value: selectedAmenity,
                decoration: const InputDecoration(labelText: "Amenity"),
                items: amenityOptions
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => selectedAmenity = val),
                validator: (v) => v == null || v.isEmpty ? "Select amenity" : null,
              ),
              if (selectedAmenity == "Other")
                TextFormField(
                  controller: otherAmenityController,
                  decoration: const InputDecoration(labelText: "Other Amenity"),
                  validator: (v) =>
                      v!.isEmpty ? "Enter custom amenity" : null,
                ),

              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: "Description"),
              ),
              const SizedBox(height: 12),

              // District Dropdown
              DropdownButtonFormField<String>(
                value: selectedDistrict,
                decoration: const InputDecoration(labelText: "District"),
                items: districtOptions
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => selectedDistrict = val),
                validator: (v) => v == null || v.isEmpty ? "Select district" : null,
              ),

              const SizedBox(height: 20),

              pickedImage == null
                  ? ElevatedButton(
                      onPressed: pickImage,
                      child: const Text("Capture Image"),
                    )
                  : Image.file(pickedImage!, height: 150),

              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: submitPOI,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text("SAVE POI"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
