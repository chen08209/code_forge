import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../LSP/lsp.dart';

/// Represents a foldable code region in the editor.
///
/// A fold range defines a region of code that can be collapsed (folded) to hide
/// its contents. This is typically used for code blocks like functions, classes,
/// or control structures.
///
/// Fold ranges are automatically detected based on code structure (braces,
/// indentation) when folding is enabled in the editor.
///
/// Example:
/// ```dart
/// // A fold range from line 5 to line 10
/// final foldRange = FoldRange(5, 10);
/// foldRange.isFolded = true; // Collapse the region
/// ```
class FoldRange {
  /// The starting line index (zero-based) of the fold range.
  ///
  /// This is the line where the fold indicator appears in the gutter.
  final int startIndex;

  /// The ending line index (zero-based) of the fold range.
  ///
  /// When folded, all lines from `startIndex + 1` to `endIndex` are hidden.
  final int endIndex;

  /// Whether this fold range is currently collapsed.
  ///
  /// When true, the contents of this range are hidden in the editor.
  bool isFolded = false;

  /// Child fold ranges that were originally folded when this range was unfolded.
  ///
  /// Used to restore the fold state of nested ranges when toggling folds.
  List<FoldRange> originallyFoldedChildren = [];

  /// Creates a [FoldRange] with the specified start and end line indices.
  FoldRange(this.startIndex, this.endIndex);

  /// Adds a child fold range that was originally folded.
  ///
  /// Used internally to track nested fold states.
  void addOriginallyFoldedChild(FoldRange child) {
    if (!originallyFoldedChildren.contains(child)) {
      originallyFoldedChildren.add(child);
    }
  }

  /// Clears the list of originally folded children.
  void clearOriginallyFoldedChildren() {
    originallyFoldedChildren.clear();
  }

  /// Checks if a line is contained within this fold range.
  ///
  /// Returns true if [line] is strictly greater than [startIndex] and
  /// less than or equal to [endIndex].
  bool containsLine(int line) {
    return line > startIndex && line <= endIndex;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FoldRange &&
        other.startIndex == startIndex &&
        other.endIndex == endIndex;
  }

  @override
  int get hashCode => startIndex.hashCode ^ endIndex.hashCode;
}

/// Custom scroll physics that reverses horizontal drag direction for RTL mode on mobile.
class RTLAwareScrollPhysics extends ClampingScrollPhysics {
  final bool isRTL;
  final bool isMobile;

  const RTLAwareScrollPhysics({
    super.parent,
    required this.isRTL,
    required this.isMobile,
  });

  @override
  RTLAwareScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return RTLAwareScrollPhysics(
      parent: buildParent(ancestor),
      isRTL: isRTL,
      isMobile: isMobile,
    );
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (isRTL && isMobile && position.axis == Axis.horizontal) {
      return super.applyPhysicsToUserOffset(position, -offset);
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (isRTL && isMobile && position.axis == Axis.horizontal) {
      return super.createBallisticSimulation(position, -velocity);
    }
    return super.createBallisticSimulation(position, velocity);
  }
}

/// Use the [GutterBuilder] to render custom content in the gutter.
/// eg:
/// ```dart
/// CodeForge(
///   gutterBuilder: GutterBuilder(
///     builder: (lineNumber, lineText) => if(lineNumber == 1) "[HEADER]" : null
///   )
/// )
/// ```
///
/// Result:
///
/// ```python
/// [HEADER]|   import os
///    2    |   import sys
///    3    |
///    4    |   def main():
///    5    |        pass
/// ```
/// -------------------------------------------------------------
///
/// To exclude the index from modified content. Set [includeReplacedIndex] to false.
/// <br> eg:
/// ```dart
/// CodeForge(
///   gutterBuilder: GutterBuilder(
///     includeReplacedIndex: false,
///     builder: (lineNumber, lineText) => if(lineNumber == 1) "[HEADER]" : null
///   )
/// )
/// ```
///
/// Result:
/// ```python
/// [HEADER]|   import os
///    1    |   import sys
///    2    |
///    3    |   def main():
///    4    |        pass
/// ```
class GutterBuilder {
  /// Builder that builds the custom gutter content.
  /// Takes the int lineNumber and String lineText parameters and returns the custom
  /// string content for the corresponding line.
  final String? Function(int, String) builder;

  /// To exclude the index from modified content. Set [includeReplacedIndex] to false.
  /// <br> eg:
  /// ```dart
  /// CodeForge(
  ///   gutterBuilder: GutterBuilder(
  ///     includeReplacedIndex: false,
  ///     builder: (lineNumber, lineText) => if(lineNumber == 1) "[HEADER]" : null
  ///   )
  /// )
  /// ```
  ///
  /// Result:
  /// ```python
  /// [HEADER]|   import os
  ///    1    |   import sys  # index `1` is included in the gutter.
  ///    2    |
  ///    3    |   def main():
  ///    4    |        pass
  /// ```
  final bool includeReplacedIndex;

  GutterBuilder({required this.builder, this.includeReplacedIndex = true});
}

/// Keyboard shortcuts used by the [CodeForge].
/// Ovrride to use your own custom shortcuts.
/// <br>
/// The default constructor follows the Windows and Linux conventions, with
/// `Ctrl` as the primary modifier. [CodeForgeKeyboardShortcuts.apple] follows
/// the macOS and iOS conventions: `Cmd` as the primary modifier, `Option` for
/// word-wise movement and deletion, `Cmd + arrow` for line and document
/// boundaries. [CodeForge] picks one through [forPlatform] when no shortcuts
/// are passed.
///
/// eg:
/// ```dart
/// // Here the line duplicate shortcut `Ctrl + D` has beeb overriden by `Ctrl + B`.
/// CodeForge(
///   keyboardShotcuts: CodeForgeKeyboardShortcuts(
///     duplicate: SingleActivator(LogicalKeyboardKey.keyB, control: true)
///   ),
/// )
/// ```
///
/// Note: The LSP inlay hints shortcut `(Ctrl + Alt)` is not modifiable.
class CodeForgeKeyboardShortcuts {
  /// Place the cursor at the starting position of the current line.
  /// Defaults to `Ctrl + home`
  final ShortcutActivator jumpToDocumentStart;

  /// Place the cursor at the starting position of the current line.
  /// Defaults to `Ctrl + end`
  final ShortcutActivator jumpToDocumentEnd;

  /// Similar to [jumpToDocumentStart], place the cursor at the starting position of the current line
  /// and selecting the text from the start position to the document start.
  /// Defaults to `Ctrl + Shift + home`.
  final ShortcutActivator jumpToDocumentStartAndSelectText;

  /// Similar to [jumpToDocumentEnd], place the cursor at the starting position of the current line
  /// and selecting the text from the start position to the document end.
  /// Defaults to `Ctrl + Shift + end`.
  final ShortcutActivator jumpToDocumentEndAndSelectText;

  /// Duplicate the selection, if no active selectio, current line gets duplicated.
  /// Defaults to `Ctrl + D`
  final ShortcutActivator duplicate;

  /// Moves the current line upwards.
  /// Defaults to `Ctrl + Shift + arrowUp`
  final ShortcutActivator shiftLineUp;

  /// Moves the current line downwards.
  /// Defaults to `Ctrl + Shift + arrowUp`
  final ShortcutActivator shiftLineDown;

  /// Delete an entire word and moves the cursor backward.
  /// Defaults to `Ctrl + backspace`
  final ShortcutActivator deletWordBackward;

  /// Delete an entore word and moves the cursor forward.
  /// Defaults to `Ctrl + delete`
  final ShortcutActivator deletWordForward;

  /// Cursor jumps to the previous word.
  /// Defaults to `Ctrl + arrowLeft`
  final ShortcutActivator moveCursorToPreviousWord;

  /// Cursor jumps to the next word.
  /// Defaults to `Ctrl + arrowRight`
  final ShortcutActivator moveCursorToNextWord;

  /// Similar to [moveCursorToPreviousWord], but selection also jumps with the cursor.
  /// Defaults to `Ctrl + Shift + arrowLeft`
  final ShortcutActivator moveSelectionToPreviousWord;

  /// Extends the selection forward by one character at a time.
  /// Defaults to `Shift + arrowRight`
  final ShortcutActivator moveSelectionForward;

  /// Extends the selection backward by one character at a time.
  /// Defaults to `Shift + arrowLeft
  final ShortcutActivator moveSelectionBackward;

  /// Extends the text selection to upward lines.
  /// Defaults tp `Shift + arrowUp`.
  final ShortcutActivator moveSelectionUpward;

  /// Extends the text selection to downward lines.
  /// Defaults tp `Shift + arrowDown`.
  final ShortcutActivator moveSelectionDownward;

  /// Similar to [moveCursorToNextWord], but selection also jumps with the cursor.
  /// Defaults to `Ctrl + Shift + arrowRight`
  final ShortcutActivator moveSelectionToNextWord;

  /// Shows the [LSP code actions](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_codeAction) if available.
  /// Defaults to `Ctrl + .`
  final ShortcutActivator lspCodeActions;

  /// Shows [LSP signature help](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_signatureHelp) if available.
  /// Defaults to `Ctrl + Shift + space`
  final ShortcutActivator lspSignatureHelp;

  /// Show the word finder bar if provided.
  /// Defaults to `Ctrl + F`
  final ShortcutActivator showFindBar;

  /// Show the finder bar along with the replace bar.
  /// Defaults to `Ctrl + H`
  final ShortcutActivator showFindAndReplaceBar;

  /// Jumps the cursor to the start of the current line by selecting the line text.
  /// Defaults to `Shift + home`.
  final ShortcutActivator selectToLineStart;

  /// Jumps the cursor to the end of the current line by selecting the line text.
  /// Defaults to `Shift + end`.
  final ShortcutActivator selectToLineEnd;

  /// Creates mutlicursor to the same column and downward rows/lines.
  final ShortcutActivator extendMutliCursorDownward;

  /// Creates mutlicursor to the same column and upward rows/lines.
  final ShortcutActivator extendMutliCursorUpward;

  /// Copies the selection. Defaults to `Ctrl + C`.
  final ShortcutActivator copy;

  /// Cuts the selection. Defaults to `Ctrl + X`.
  final ShortcutActivator cut;

  /// Pastes the clipboard text. Defaults to `Ctrl + V`.
  final ShortcutActivator paste;

  /// Selects the whole document. Defaults to `Ctrl + A`.
  final ShortcutActivator selectAll;

  /// Undoes the last edit. Defaults to `Ctrl + Z`.
  final ShortcutActivator undo;

  /// Redoes the last undone edit. Defaults to `Ctrl + Y` or `Ctrl + Shift + Z`.
  final ShortcutActivator redo;

  /// Places the cursor at the start of the current line.
  /// Defaults to `home`.
  final ShortcutActivator jumpToLineStart;

  /// Places the cursor at the end of the current line.
  /// Defaults to `end`.
  final ShortcutActivator jumpToLineEnd;

  /// Deletes from the cursor back to the start of the current line.
  /// Unbound by default; `Cmd + backspace` on Apple platforms.
  final ShortcutActivator? deleteToLineStart;

  const CodeForgeKeyboardShortcuts({
    this.duplicate = const SingleActivator(
      LogicalKeyboardKey.keyD,
      control: true,
    ),
    this.shiftLineUp = const SingleActivator(
      LogicalKeyboardKey.arrowUp,
      control: true,
      shift: true,
    ),
    this.shiftLineDown = const SingleActivator(
      LogicalKeyboardKey.arrowDown,
      control: true,
      shift: true,
    ),
    this.deletWordBackward = const SingleActivator(
      LogicalKeyboardKey.backspace,
      control: true,
    ),
    this.deletWordForward = const SingleActivator(
      LogicalKeyboardKey.delete,
      control: true,
    ),
    this.moveCursorToNextWord = const SingleActivator(
      LogicalKeyboardKey.arrowRight,
      control: true,
    ),
    this.moveCursorToPreviousWord = const SingleActivator(
      LogicalKeyboardKey.arrowLeft,
      control: true,
    ),
    this.moveSelectionToNextWord = const SingleActivator(
      LogicalKeyboardKey.arrowRight,
      control: true,
      shift: true,
    ),
    this.moveSelectionToPreviousWord = const SingleActivator(
      LogicalKeyboardKey.arrowLeft,
      control: true,
      shift: true,
    ),
    this.moveSelectionUpward = const SingleActivator(
      LogicalKeyboardKey.arrowUp,
      shift: true,
    ),
    this.moveSelectionDownward = const SingleActivator(
      LogicalKeyboardKey.arrowDown,
      shift: true,
    ),
    this.moveSelectionForward = const SingleActivator(
      LogicalKeyboardKey.arrowRight,
      shift: true,
    ),
    this.moveSelectionBackward = const SingleActivator(
      LogicalKeyboardKey.arrowLeft,
      shift: true,
    ),
    this.lspCodeActions = const SingleActivator(
      LogicalKeyboardKey.period,
      control: true,
    ),
    this.lspSignatureHelp = const SingleActivator(
      LogicalKeyboardKey.space,
      control: true,
      shift: true,
    ),
    this.showFindBar = const SingleActivator(
      LogicalKeyboardKey.keyF,
      control: true,
    ),
    this.showFindAndReplaceBar = const SingleActivator(
      LogicalKeyboardKey.keyH,
      control: true,
    ),
    this.jumpToDocumentStart = const SingleActivator(
      LogicalKeyboardKey.home,
      control: true,
    ),
    this.jumpToDocumentEnd = const SingleActivator(
      LogicalKeyboardKey.end,
      control: true,
    ),
    this.jumpToDocumentStartAndSelectText = const SingleActivator(
      LogicalKeyboardKey.home,
      control: true,
      shift: true,
    ),
    this.jumpToDocumentEndAndSelectText = const SingleActivator(
      LogicalKeyboardKey.end,
      control: true,
      shift: true,
    ),
    this.selectToLineStart = const SingleActivator(
      LogicalKeyboardKey.home,
      shift: true,
    ),
    this.selectToLineEnd = const SingleActivator(
      LogicalKeyboardKey.end,
      shift: true,
    ),
    this.extendMutliCursorDownward = const SingleActivator(
      LogicalKeyboardKey.arrowDown,
      alt: true,
      shift: true,
    ),
    this.extendMutliCursorUpward = const SingleActivator(
      LogicalKeyboardKey.arrowUp,
      alt: true,
      shift: true,
    ),
    this.copy = const SingleActivator(LogicalKeyboardKey.keyC, control: true),
    this.cut = const SingleActivator(LogicalKeyboardKey.keyX, control: true),
    this.paste = const SingleActivator(LogicalKeyboardKey.keyV, control: true),
    this.selectAll = const SingleActivator(
      LogicalKeyboardKey.keyA,
      control: true,
    ),
    this.undo = const SingleActivator(LogicalKeyboardKey.keyZ, control: true),
    this.redo = const AnyShortcutActivator([
      SingleActivator(LogicalKeyboardKey.keyY, control: true),
      SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true),
    ]),
    this.jumpToLineStart = const SingleActivator(LogicalKeyboardKey.home),
    this.jumpToLineEnd = const SingleActivator(LogicalKeyboardKey.end),
    this.deleteToLineStart,
  });

  /// The macOS and iOS conventions.
  const CodeForgeKeyboardShortcuts.apple({
    this.duplicate = const SingleActivator(LogicalKeyboardKey.keyD, meta: true),
    this.shiftLineUp = const SingleActivator(
      LogicalKeyboardKey.arrowUp,
      alt: true,
    ),
    this.shiftLineDown = const SingleActivator(
      LogicalKeyboardKey.arrowDown,
      alt: true,
    ),
    this.deletWordBackward = const SingleActivator(
      LogicalKeyboardKey.backspace,
      alt: true,
    ),
    this.deletWordForward = const SingleActivator(
      LogicalKeyboardKey.delete,
      alt: true,
    ),
    this.moveCursorToNextWord = const SingleActivator(
      LogicalKeyboardKey.arrowRight,
      alt: true,
    ),
    this.moveCursorToPreviousWord = const SingleActivator(
      LogicalKeyboardKey.arrowLeft,
      alt: true,
    ),
    this.moveSelectionToNextWord = const SingleActivator(
      LogicalKeyboardKey.arrowRight,
      alt: true,
      shift: true,
    ),
    this.moveSelectionToPreviousWord = const SingleActivator(
      LogicalKeyboardKey.arrowLeft,
      alt: true,
      shift: true,
    ),
    this.moveSelectionUpward = const SingleActivator(
      LogicalKeyboardKey.arrowUp,
      shift: true,
    ),
    this.moveSelectionDownward = const SingleActivator(
      LogicalKeyboardKey.arrowDown,
      shift: true,
    ),
    this.moveSelectionForward = const SingleActivator(
      LogicalKeyboardKey.arrowRight,
      shift: true,
    ),
    this.moveSelectionBackward = const SingleActivator(
      LogicalKeyboardKey.arrowLeft,
      shift: true,
    ),
    this.lspCodeActions = const SingleActivator(
      LogicalKeyboardKey.period,
      meta: true,
    ),
    this.lspSignatureHelp = const SingleActivator(
      LogicalKeyboardKey.space,
      meta: true,
      shift: true,
    ),
    this.showFindBar = const SingleActivator(
      LogicalKeyboardKey.keyF,
      meta: true,
    ),
    // `Cmd + H` hides the application on macOS before the editor sees it.
    this.showFindAndReplaceBar = const SingleActivator(
      LogicalKeyboardKey.keyF,
      meta: true,
      alt: true,
    ),
    this.jumpToDocumentStart = const SingleActivator(
      LogicalKeyboardKey.arrowUp,
      meta: true,
    ),
    this.jumpToDocumentEnd = const SingleActivator(
      LogicalKeyboardKey.arrowDown,
      meta: true,
    ),
    this.jumpToDocumentStartAndSelectText = const SingleActivator(
      LogicalKeyboardKey.arrowUp,
      meta: true,
      shift: true,
    ),
    this.jumpToDocumentEndAndSelectText = const SingleActivator(
      LogicalKeyboardKey.arrowDown,
      meta: true,
      shift: true,
    ),
    this.selectToLineStart = const AnyShortcutActivator([
      SingleActivator(LogicalKeyboardKey.home, shift: true),
      SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true, shift: true),
    ]),
    this.selectToLineEnd = const AnyShortcutActivator([
      SingleActivator(LogicalKeyboardKey.end, shift: true),
      SingleActivator(LogicalKeyboardKey.arrowRight, meta: true, shift: true),
    ]),
    this.extendMutliCursorDownward = const SingleActivator(
      LogicalKeyboardKey.arrowDown,
      alt: true,
      shift: true,
    ),
    this.extendMutliCursorUpward = const SingleActivator(
      LogicalKeyboardKey.arrowUp,
      alt: true,
      shift: true,
    ),
    this.copy = const SingleActivator(LogicalKeyboardKey.keyC, meta: true),
    this.cut = const SingleActivator(LogicalKeyboardKey.keyX, meta: true),
    this.paste = const SingleActivator(LogicalKeyboardKey.keyV, meta: true),
    this.selectAll = const SingleActivator(LogicalKeyboardKey.keyA, meta: true),
    this.undo = const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
    this.redo = const SingleActivator(
      LogicalKeyboardKey.keyZ,
      meta: true,
      shift: true,
    ),
    this.jumpToLineStart = const AnyShortcutActivator([
      SingleActivator(LogicalKeyboardKey.home),
      SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true),
    ]),
    this.jumpToLineEnd = const AnyShortcutActivator([
      SingleActivator(LogicalKeyboardKey.end),
      SingleActivator(LogicalKeyboardKey.arrowRight, meta: true),
    ]),
    this.deleteToLineStart = const SingleActivator(
      LogicalKeyboardKey.backspace,
      meta: true,
    ),
  });

  /// The shortcuts that follow the conventions of [platform].
  static CodeForgeKeyboardShortcuts forPlatform(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.macOS ||
      TargetPlatform.iOS => const CodeForgeKeyboardShortcuts.apple(),
      _ => const CodeForgeKeyboardShortcuts(),
    };
  }
}

/// A shortcut that fires when any of [activators] accepts the key event,
/// for commands bound to more than one key combination.
class AnyShortcutActivator extends ShortcutActivator {
  final List<ShortcutActivator> activators;

  const AnyShortcutActivator(this.activators);

  @override
  Iterable<LogicalKeyboardKey>? get triggers {
    final keys = <LogicalKeyboardKey>{};
    for (final activator in activators) {
      final triggers = activator.triggers;
      if (triggers == null) return null;
      keys.addAll(triggers);
    }
    return keys;
  }

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    return activators.any((activator) => activator.accepts(event, state));
  }

  @override
  String debugDescribeKeys() {
    return activators
        .map((activator) => activator.debugDescribeKeys())
        .join(' | ');
  }
}

/// A request to show the context menu, passed to [CodeForge.onContextMenu].
class CodeForgeContextMenuRequest {
  /// Where the menu was requested, in global coordinates.
  final Offset globalPosition;

  /// Whether the editor has a non-empty selection.
  final bool hasSelection;

  /// Whether the whole document is selected.
  final bool isAllSelected;

  /// Whether the editor is read-only.
  final bool readOnly;

  final VoidCallback copy;
  final VoidCallback cut;
  final VoidCallback paste;
  final VoidCallback selectAll;

  const CodeForgeContextMenuRequest({
    required this.globalPosition,
    required this.hasSelection,
    required this.isAllSelected,
    required this.readOnly,
    required this.copy,
    required this.cut,
    required this.paste,
    required this.selectAll,
  });
}

/// What [CodeForge.scrollbarBuilder] needs to build the vertical scrollbar.
class CodeForgeScrollbarDetails {
  /// The vertical scroll controller of the editor.
  final ScrollController controller;

  /// The 1-based line at the top of the viewport.
  final ValueListenable<int> firstVisibleLine;

  const CodeForgeScrollbarDetails({
    required this.controller,
    required this.firstVisibleLine,
  });
}

/// Where a completion suggestion comes from.
enum CodeForgeSuggestionKind {
  /// A word collected from the document.
  word,

  /// One of [CodeForge.customCodeSnippets].
  snippet,

  /// An item returned by the language server.
  lsp,
}

/// One entry of the completion popup, as [CodeForge.suggestionPopupBuilder]
/// sees it.
class CodeForgeSuggestion {
  final String label;
  final CodeForgeSuggestionKind kind;

  /// The item type the language server reported; null unless [kind] is
  /// [CodeForgeSuggestionKind.lsp].
  final CompletionItemType? type;

  /// Where an LSP item is imported from, when the server says.
  final String? detail;

  const CodeForgeSuggestion({
    required this.label,
    required this.kind,
    this.type,
    this.detail,
  });
}

/// What [CodeForge.suggestionPopupBuilder] needs to build the completion
/// popup.
class CodeForgeSuggestionDetails {
  final List<CodeForgeSuggestion> suggestions;

  /// The entry Enter or Tab accepts, or null when none is highlighted.
  final int? selectedIndex;

  /// Inserts the entry at the index, as tapping it in the built-in popup
  /// does.
  final ValueChanged<int> onAccept;

  const CodeForgeSuggestionDetails({
    required this.suggestions,
    required this.selectedIndex,
    required this.onAccept,
  });
}

/// Create a custom entry for the context menu (The menu that appears on right click).
/// Pass it to the [CodeForge] class to add the custom entry to the context menu.
/// eg:
/// ```dart
/// CodeForge(
///   customContextMenuItems: [
///     CustomContextMenu(
///        label: "Goto defenition",
///        desciption: "Ctrl + Shift + .",
///        onPress: ()=> goToDefinition()
///     ),
///     CustomContextMenu(
///        label: "Code actions",
///        desciption: "Ctrl + .",
///        onPress: ()=> getCodeActions()
///     ),
///   ]
/// )
/// ```
class CustomContextMenu {
  /// The label that shown in the context menu
  final String label;

  /// The description for the context item.
  /// Shown at the right end of the menu.
  final String description;

  /// The action to be performed on pressing the context menu item.
  final VoidCallback onPress;

  const CustomContextMenu({
    required this.label,
    required this.description,
    required this.onPress,
  });
}

/// Use it to display error lints (wavy underlines) in [CodeForge].
class DiagnosticLine extends LspErrors {
  DiagnosticLine({
    required super.severity,
    required super.range,
    required super.message,
  });
}
