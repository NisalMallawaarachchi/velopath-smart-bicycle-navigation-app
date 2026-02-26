import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../widgets/device_helper.dart';
import '../config/api_config.dart';



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

  
  String? selectedAmenity;
  List<String> amenityOptions = ['Waterfall', 'School', 'Park', 'Other'];

  
  String? selectedDistrict;
  List<String> districtOptions = [
    'Colombo',
    'Gampaha',
    'Kalutara',
    'Kandy',
    'Matale',
    'Nuwara Eliya',
    'Galle',
    'Matara',
    'Hambantota',
    'Jaffna',
    'Kilinochchi',
    'Mannar',
    'Vavuniya',
    'Mullaitivu',
    'Batticaloa',
    'Ampara',
    'Trincomalee',
    'Kurunegala',
    'Puttalam',
    'Anuradhapura',
    'Polonnaruwa',
    'Badulla',
    'Monaragala',
    'Ratnapura',
    'Kegalle'
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); 
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
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

  // Submit POI
 Future<void> submitPOI() async {
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

  if (response.statusCode == 201) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add a new place")),
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
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => selectedAmenity = val),
                validator: (v) =>
                    v == null || v.isEmpty ? "Select amenity" : null,
              ),

              if (selectedAmenity == "Other")
                TextFormField(
                  controller: otherAmenityController,
                  decoration:
                      const InputDecoration(labelText: "Other Amenity"),
                  validator: (v) =>
                      v!.isEmpty ? "Enter custom amenity" : null,
                ),

              const SizedBox(height: 12),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: "Description"),
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: selectedDistrict,
                decoration: const InputDecoration(labelText: "District"),
                items: districtOptions
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setState(() => selectedDistrict = val),
                validator: (v) =>
                    v == null || v.isEmpty ? "Select district" : null,
              ),

              const SizedBox(height: 20),

              // CAPTURE BUTTON
              pickedImage == null
                  ? ElevatedButton(
                      onPressed: pickImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor:
                            const Color.fromARGB(255, 34, 76, 84),
                        side: const BorderSide(
                            color: Color.fromARGB(255, 34, 76, 84), width: 2),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt),
                          SizedBox(width: 8),
                          Text(
                            "Capture Image",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        pickedImage!,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),

              const SizedBox(height: 20),

              // SAVE BUTTON
              ElevatedButton(
                onPressed: submitPOI,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 34, 76, 84),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  "SAVE POI",
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
