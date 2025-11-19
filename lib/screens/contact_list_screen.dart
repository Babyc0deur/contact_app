import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/contact_service.dart';
import 'add_contact_screen.dart';

class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

  @override
  State<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends State<ContactListScreen> {
  final ContactService _contactService = ContactService();
  List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _refreshContacts();
  }

  void _refreshContacts() {
    setState(() {
      _contacts = _contactService.getContacts();
    });
  }

  void _deleteContact(String id) {
    _contactService.deleteContact(id);
    _refreshContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
      ),
      body: _contacts.isEmpty
          ? const Center(child: Text('No contacts yet.'))
          : ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(contact.name[0].toUpperCase()),
                  ),
                  title: Text(contact.name),
                  subtitle: Text(contact.phoneNumber),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteContact(contact.id),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddContactScreen()),
          );
          _refreshContacts();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
