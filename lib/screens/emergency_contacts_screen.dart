import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emergency Contacts',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const EmergencyContactsPage(),
    );
  }
}

class EmergencyContactsPage extends StatefulWidget {
  const EmergencyContactsPage({super.key});

  @override
  EmergencyContactsPageState createState() => EmergencyContactsPageState();
}

class EmergencyContactsPageState extends State<EmergencyContactsPage> {
  static const platform = MethodChannel('com.fearless.app/choose');

  // Updated the list to have a consistent type
  List<Map<String, String>> _emergencyContacts = [];

  final _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchContactsFromFirestore();
  }

  Future<void> _fetchContactsFromFirestore() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _emergencyContacts = snapshot.docs.map((doc) {
          return {
            'id': doc.id.toString(),
            'name': doc['name'].toString(),
            'phone': doc['phone'].toString(),
          };
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                "An error occurred while fetching contacts. Please try again later.")),
      );
    }
  }

  Future<void> _removeContact(String contactId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .doc(contactId)
          .delete();

      setState(() {
        _emergencyContacts
            .removeWhere((contact) => contact['id'] == contactId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contact removed successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Failed to remove contact. Please try again later.")),
      );
    }
  }

  Future<void> _pickContact() async {
    final status = await Permission.contacts.status;

    if (status.isGranted) {
      try {
        // Remove the generic type parameter
        final result = await platform.invokeMethod('pickContact');
        if (result != null) {
          // Safely cast the result to Map<String, dynamic>
          final Map<String, dynamic> resultMap = Map<String, dynamic>.from(result);

          String? name = resultMap['name'] as String?;
          String? number = resultMap['number'] as String?;

          // Check for null values
          if (name == null || number == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Invalid contact data.")),
            );
            return;
          }

          final userId = _auth.currentUser?.uid;
          if (userId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("User not logged in!")),
            );
            return;
          }

          final docRef = await _firestore
              .collection('users')
              .doc(userId)
              .collection('emergency_contacts')
              .add({
            'name': name,
            'phone': number,
            'timestamp': FieldValue.serverTimestamp(),
          });

          setState(() {
            Map<String, String> newContact = {
              'id': docRef.id.toString(),
              'name': name,
              'phone': number,
            };
            _emergencyContacts.add(newContact);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$name added to emergency contacts!")),
          );
        }
      } on PlatformException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to pick contact: ${e.message}")),
        );
      }
    } else if (status.isDenied) {
      final newStatus = await Permission.contacts.request();
      if (newStatus.isGranted) {
        _pickContact();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Permission is required to pick a contact."),
          ),
        );
      }
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contacts permission is not granted.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Emergency Contacts")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _emergencyContacts.isEmpty
                  ? const Center(child: Text("No contacts selected."))
                  : ListView.builder(
                itemCount: _emergencyContacts.length,
                itemBuilder: (context, index) {
                  final Map<String, String> contact =
                  _emergencyContacts[index];
                  final String name = contact['name'] ?? 'Unknown';
                  final String phone = contact['phone'] ?? 'No number';
                  return Card(
                    key: ValueKey(contact['id']),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.pink,
                        child: Text(
                          name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text("Mobile • $phone"),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeContact(contact['id']!),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickContact,
              icon: const Icon(Icons.add),
              label: const Text("Add contact"),
            ),
          ],
        ),
      ),
    );
  }
}
