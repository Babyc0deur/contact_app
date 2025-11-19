class Contact {
  final String id;
  final String name;
  final String phoneNumber;
  final String? email;

  Contact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
  });
}
