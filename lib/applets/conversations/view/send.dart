import 'package:flutter_quill/quill_delta.dart';

/// Fork: Von der Vorlage bleibt nur die Umwandlung des Editorinhalts in den
/// Lanis-Nachrichtentext. Ursache (Prüfung 27.10.26): Die Vollbild-Eingabe
/// (Widget und State) öffnete keine Seite mehr – der einzige Aufrufer war
/// parseText aus rich_chat_text_editor.dart.
abstract final class ConversationMessageText {
  static String parseText(Delta delta) {
    String text = "";

    List<Operation> operations = delta.operations;
    for (int i = 0; i < delta.length; i++) {
      final Operation operation = operations[i];
      String current = operation.value;

      if (operation.attributes == null) {
        current = operation.value;
      } else {
        for (MapEntry attribute in operation.attributes!.entries) {
          switch (attribute.key) {
            case "bold":
              current = "**$current**";
              break;

            case "underline":
              current = "__${current}__";
              break;

            case "italic":
              current = "~~$current~~";
              break;

            case "strike":
              current = "--$current--";
              break;

            case "code":
              current = "`$current`";
              break;

            case "script":
              if (attribute.value == "super") {
                current = "^($current)";
              } else if (attribute.value == "sub") {
                current = "_($current)";
              }
              break;

            default:
              break;
          }
        }
      }

      if (i != operations.length - 1) {
        final Map<String, dynamic>? nextAttributes =
            operations[i + 1].attributes;

        if (nextAttributes != null && nextAttributes.containsKey("list")) {
          if (current.contains("\u000A")) {
            final String temp = current.toString();
            current = temp.substring(0, temp.indexOf("\u000A") + 1);
            current += "- ${temp.substring(temp.indexOf("\u000A") + 1)}";
          } else {
            current = "- $current";
          }
        }
      }

      text += current;
    }

    return text.substring(0, text.length - 1);
  }

  /// Fork: nur Leerzeichen/Zeilenumbrüche – nicht senden. Ursache (Prüfung
  /// 27.10.26): Der Senden-Knopf prüfte nur `text.isEmpty`, eine Nachricht
  /// aus Leerzeilen ging als leere Antwort an alle Empfänger. Grenze:
  /// fett gesetzte Leerzeichen („**  **“) gelten als Inhalt.
  static bool isBlank(String text) => text.trim().isEmpty;
}
