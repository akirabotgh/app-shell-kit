/// Shared application shell for the Rodin app fleet.
///
/// An app built from `app-shell-template` gets its standard pages, theme,
/// branding and legal surfaces from this package, and its live configuration
/// from `app-shell-config`. See the README for the fleet update model.
library;

export 'src/shell_version.dart';
export 'src/shell_config.dart';
export 'src/shell_config_client.dart';
export 'src/shell_app.dart';
export 'src/theme/shell_theme.dart';
export 'src/pages/shell_about_page.dart';
export 'src/pages/shell_legal_page.dart';
export 'src/pages/shell_settings_page.dart';
export 'src/widgets/shell_notice_banner.dart';
export 'src/widgets/markdown_lite.dart';
