import '../models/contact.dart';

class ContactService {
  static final ContactService _instance = ContactService._internal();
  
  factory ContactService() {
    return _instance;
  }

  ContactService._internal();

  final List<Contact> _contacts = [];

  List<Contact> getContacts() {
    return List.unmodifiable(_contacts);
  }

  void addContact(Contact contact) {
    _contacts.add(contact);
  }

  void deleteContact(String id) {
    _contacts.removeWhere((c) => c.id == id);
  }
}
