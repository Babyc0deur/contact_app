import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _siteController = TextEditingController();
  String? _selectedObject;

  final List<String> _objectOptions = [
    "Clé d'activation",
    "Fichier de donnée",
    "Accces Owncloud",
    "Acces Dropbox",
    "Acces synd",
  ];

  @override
  void dispose() {
    _siteController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (_formKey.currentState!.validate()) {
      final String site = _siteController.text;
      final String objet = _selectedObject!;
      
      final String subject = "Demande de $objet - Site $site";
      final String body = '''
Bonjour cher Support,

Suite à une défaillance constatée sur le serveur du site $site en objet, nous sollicitons votre assistance afin d’obtenir le $objet nécessaire à son rétablissement.

Nous vous remercions par avance pour votre diligence et restons dans l’attente de votre retour.

Cordialement,
''';

      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: 'support@msupply.foundation',
        query: _encodeQueryParameters(<String, String>{
          'subject': subject,
          'body': body,
          'cc': 'noel@msupply.foundation,josias@msupply.foundation,djire@msupply.foundation,mathurin@msupply.foundation,fh.akaffou@outlook.fr,ksylvain@dap.ci,yarnaud@dap.ci,ouattaraidriss69@gmail.com',
        }),
      );

      try {
        if (!await launchUrl(emailLaunchUri)) {
          throw Exception('Could not launch email client');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de l\'ouverture de l\'email: $e')),
          );
        }
      }
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faire une demande'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nouvelle Demande',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3748),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Remplissez le formulaire ci-dessous pour générer l\'email de demande.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 32),
              
              // Site Field
              TextFormField(
                controller: _siteController,
                decoration: const InputDecoration(
                  labelText: 'Site',
                  hintText: 'Ex: Abidjan',
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le nom du site';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Object Dropdown
              DropdownButtonFormField<String>(
                value: _selectedObject,
                decoration: const InputDecoration(
                  labelText: 'Objet de la demande',
                  prefixIcon: Icon(Icons.subject),
                ),
                items: _objectOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedObject = newValue;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez sélectionner un objet';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _sendEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Envoyer la demande',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
