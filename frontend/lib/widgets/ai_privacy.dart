import 'package:flutter/material.dart';

import '../core/app_theme.dart';

const aiPrivacyPolicyVersion = '2026-11-v1';

const _aiPrivacyPolicy = '''
MEMORA AI AND UPLOADED-CONTENT PRIVACY

Images and AI
When you accept this notice and use image scanning, camera ingestion, or Ask MEMORA, the backend may send the relevant image or saved visual-memory context to the configured Muse-compatible third-party provider to perform the requested analysis or answer. MEMORA does not use your images or documents to train MEMORA-owned AI models, and uses image content for the requested MEMORA features only. The provider's processing, retention, and training practices are controlled by that provider's terms. MEMORA cannot guarantee that a third-party provider will not retain or use submitted content. Do not continue unless you have reviewed and accept the provider's applicable terms; avoid submitting highly sensitive images if those terms are not suitable for you.

Upkeep documents
PDF and DOCX documents uploaded to Upkeep are stored in the workspace backend. Their extracted text is searched locally by MEMORA and is not sent to the AI provider. Document questions return matching passages rather than AI-generated answers. Legacy DOC files must be converted to DOCX. Scanned/image-only PDFs may not contain searchable text. Workspace members with access can view document details, ask local-search questions about, and delete these documents.

Storage and deletion
Uploaded files are stored by the backend until deleted through MEMORA or removed according to the hosting storage configuration. Deleting a document in Upkeep removes its record and stored file. Image captures can be deleted from their respective MEMORA screens. Hosting providers may have their own backup and retention policies.

Consent
Image analysis and Ask MEMORA require your consent. You can withdraw AI consent in Upkeep; image-based AI features will then stop until you consent again. Withdrawing consent does not delete content already uploaded or remove prior AI results; delete those separately where available.

Only upload files and images you are authorized to store. This notice describes MEMORA's current implementation and is not a substitute for the third-party provider's terms or legal advice.
''';

Future<void> showAiPrivacyPolicy(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MemoraColors.panel,
        title: const Text('Privacy policy'),
        content: const SingleChildScrollView(
          child: SelectableText(
            _aiPrivacyPolicy,
            style: TextStyle(fontSize: 12, height: 1.55),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

Future<bool> showAiPrivacyConsent(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: MemoraColors.panel,
        title: const Text('Before using MEMORA AI'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'To scan images or ask MEMORA, relevant images or saved visual-memory context are sent to the configured external AI provider. MEMORA does not train its own AI models on your content, but the provider controls its own data handling and MEMORA cannot guarantee the provider’s retention or training practices.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Upkeep documents are different: they are searched locally and their extracted text is not sent to the AI provider.',
                  style: TextStyle(
                      color: MemoraColors.muted, fontSize: 12, height: 1.5),
                ),
                TextButton(
                  onPressed: () => showAiPrivacyPolicy(context),
                  child: const Text('Read the full privacy policy'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Agree and continue'),
          ),
        ],
      ),
    ) ??
    false;
