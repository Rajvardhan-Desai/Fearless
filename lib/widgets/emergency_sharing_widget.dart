import 'package:flutter/material.dart';

class EmergencySharingWidget extends StatefulWidget {
  final List<Map<String, String>> emergencyContacts;
  final Function(Map<String, bool>) onShare;

  const EmergencySharingWidget({
    super.key,
    required this.emergencyContacts,
    required this.onShare,
  });

  @override
  State<EmergencySharingWidget> createState() => _EmergencySharingWidgetState();
}

class _EmergencySharingWidgetState extends State<EmergencySharingWidget> {
  final Map<String, bool> contactSelection = {};
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (var contact in widget.emergencyContacts) {
      contactSelection[contact['phone']!] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool anyContactSelected =
    contactSelection.values.any((isSelected) => isSelected);

    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share status and real-time location?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18.0,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                maxLength: 40,
                decoration: InputDecoration(
                  hintText: 'Reason for sharing (optional)',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...widget.emergencyContacts.map((contact) {
                final phone = contact['phone']!;
                return CheckboxListTile(
                  title: Text(contact['name']!),
                  subtitle: Text(phone),
                  value: contactSelection[phone],
                  onChanged: (value) {
                    setState(() {
                      contactSelection[phone] = value ?? false;
                    });
                  },
                );
              }).toList(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: anyContactSelected
                        ? () {
                      widget.onShare(contactSelection);
                      Navigator.of(context).pop();
                    }
                        : null,
                    child: const Text('Share'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
