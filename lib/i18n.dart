/// Lingua dell'app: italiano (predefinito) o inglese (impostazioni → Lingua).
/// La traduzione inglese copre le parti principali; il resto resta in italiano.
bool appEnglish = false;

/// Testo nella lingua scelta.
String tr(String it, String en) => appEnglish ? en : it;
