/// App identity / attribution constants (open-source).
///
/// Author/contact fields mirror `AboutAuthor` in stackntrace-android-ui
/// (`dev.stackntrace.ui.about.AboutAuthor`) / stackntrace.dev — v1.1.1.
class AppInfo {
  static const String name = 'NFC Toolbox';
  static const String version = '1.0.0';
  static const String description =
      'FOSS NFC tag toolbox for Android — read, write, batch, tools, and tasks.';

  /// Canonical display name (stackntrace `AboutAuthor.NAME`).
  static const String authorName = 'helllguest';
  static const String authorAlias = 'helllguest';
  static const String authorEmail = 'info@stackntrace.dev';

  static const String websiteUrl = 'https://stackntrace.dev';
  static const String websiteLabel = 'stackntrace.dev';

  static const String license = 'MIT';
  static const String licenseLabel = 'MIT License';
  static const String copyrightYear = '2026';
  static const String copyrightFooter = '© 2026 helllguest · stackntrace.dev';
  static const String privacyFooter = 'Privacy-first · no analytics';

  /// Public repository (app-specific).
  static const String githubRepo = 'https://github.com/helllguest/nfc-tool';
  static const String githubProfile = 'https://github.com/helllguest';
  static const String githubHandle = 'helllguest';

  static String get copyrightLine =>
      'Copyright © $copyrightYear $authorName';
}
