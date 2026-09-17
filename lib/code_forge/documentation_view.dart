import 'package:flutter/material.dart';
import 'package:re_highlight/re_highlight.dart';

import 'syntax_highlighter.dart';

/// Shows LSP documentation. Fenced code blocks in the editor's language are
/// highlighted with its grammar; everything else is shown as plain text.
class DocumentationView extends StatelessWidget {
  const DocumentationView({
    super.key,
    required this.data,
    required this.language,
    required this.extraLanguages,
    required this.languageId,
    required this.editorTheme,
    required this.textStyle,
  });

  final String data;
  final Mode language;
  final List<Mode> extraLanguages;
  final String? languageId;
  final Map<String, TextStyle> editorTheme;
  final TextStyle textStyle;

  static final _codeFence = RegExp(
    r'^ {0,3}(`{3,}|~{3,})[ \t]*([^\s`]*)[^\n]*\n([\s\S]*?)^ {0,3}\1[ \t]*$',
    multiLine: true,
  );

  bool _isEditorLanguage(String tag) {
    return tag.isEmpty ||
        tag == languageId?.toLowerCase() ||
        tag == language.name?.toLowerCase() ||
        (language.aliases?.contains(tag) ?? false);
  }

  void _addText(List<Widget> children, String text) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      children.add(Text(trimmed, style: textStyle));
    }
  }

  Widget _buildCode(String tag, String code) {
    final root = editorTheme['root'];
    final style = TextStyle(fontSize: textStyle.fontSize, color: root?.color);
    final highlighter = _isEditorLanguage(tag)
        ? SyntaxHighlighter(
            language: language,
            editorTheme: editorTheme,
            baseTextStyle: style,
            languageId: languageId,
            extraLanguages: extraLanguages,
          )
        : null;
    final lines = code.trimRight().split('\n');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: root?.backgroundColor,
        border: Border.all(width: 0.2, color: root?.color ?? Colors.grey),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text.rich(
          TextSpan(
            style: style,
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0) const TextSpan(text: '\n'),
                highlighter?.getLineSpan(i, lines[i]) ??
                    TextSpan(text: lines[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    var start = 0;
    for (final match in _codeFence.allMatches(data)) {
      _addText(children, data.substring(start, match.start));
      children.add(_buildCode(match.group(2)!.toLowerCase(), match.group(3)!));
      start = match.end;
    }
    _addText(children, data.substring(start));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
