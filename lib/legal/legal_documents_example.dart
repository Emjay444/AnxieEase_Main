import 'package:flutter/material.dart';
import 'legal_documents_dialog.dart';

class LegalDocumentsExample extends StatelessWidget {
  const LegalDocumentsExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal Documents Example'),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'AnxieEase Legal Documents',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 30),

            // Terms of Service Button
            ElevatedButton.icon(
              onPressed: () => LegalDocumentDialog.showTermsOfService(context),
              icon: const Icon(Icons.article),
              label: const Text('View Terms of Service'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                minimumSize: const Size(200, 50),
              ),
            ),

            const SizedBox(height: 15),

            // Privacy Policy Button
            ElevatedButton.icon(
              onPressed: () => LegalDocumentDialog.showPrivacyPolicy(context),
              icon: const Icon(Icons.privacy_tip),
              label: const Text('View Privacy Policy'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                minimumSize: const Size(200, 50),
              ),
            ),

            const SizedBox(height: 30),

            // Example of clickable text (like in registration)
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[50],
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: true,
                    onChanged: null,
                    activeColor: Colors.green,
                  ),
                  const Expanded(
                    child: ClickableTermsText(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              'Click on "Terms of Service" or "Privacy Policy" above to view the documents',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
