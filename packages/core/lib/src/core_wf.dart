import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:html/dom.dart' as dom;

import 'data_classes.dart';
import 'parser.dart' as parser;

part 'ops/style_bg_color.dart';
part 'ops/style_margin.dart';
part 'ops/style_text_align.dart';
part 'ops/tag_code.dart';
part 'ops/tag_img.dart';
part 'ops/tag_table.dart';
part 'ops/text.dart';

final _dataUriRegExp = RegExp(r'^data:image/\w+;base64,');

class WidgetFactory {
  final BuildContext context;

  BuildOp _styleBgColor;
  BuildOp _styleMargin;
  BuildOp _styleTextAlign;
  BuildOp _tagBr;
  BuildOp _tagCode;
  BuildOp _tagHr;
  BuildOp _tagImg;
  BuildOp _tagQ;
  BuildOp _tagTable;

  WidgetFactory(this.context);

  double get defaultFontSize => defaultTextStyle.fontSize;
  TextStyle get defaultTextStyle => DefaultTextStyle.of(context).style;

  Widget buildAlign(Widget child, Alignment alignment) {
    if (alignment == null) return child;
    return child != null ? Align(alignment: alignment, child: child) : null;
  }

  Widget buildBody(List<Widget> children) =>
      buildColumn(children, fixPadding: true);

  Widget buildColumn(
    List<Widget> children, {
    bool fixPadding = false,
  }) {
    if (children?.isNotEmpty != true) return null;
    final fixed = fixPadding ? fixOverlappingPaddings(children) : children;

    return fixed.length == 1
        ? fixed.first
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: fixed,
          );
  }

  Widget buildDecoratedBox(
    Widget child, {
    Color color,
  }) =>
      child != null
          ? DecoratedBox(
              child: child,
              decoration: BoxDecoration(
                color: color,
              ),
            )
          : null;

  Widget buildDivider() => DecoratedBox(
        decoration: BoxDecoration(color: Color.fromRGBO(0, 0, 0, 1)),
        child: SizedBox(height: 1),
      );

  FontStyle buildFontSize(NodeMetadata meta) => meta?.hasFontStyle == true
      ? (meta.fontStyleItalic == true ? FontStyle.italic : FontStyle.normal)
      : null;

  Widget buildImage(String src, {int height, String text, int width}) {
    final imageWidget = src?.startsWith('data:image') == true
        ? buildImageFromDataUri(src)
        : buildImageFromUrl(src);
    if (imageWidget == null) return buildText(text: text);

    height ??= 0;
    width ??= 0;
    if (height <= 0 || width <= 0) return imageWidget;

    return AspectRatio(
      aspectRatio: width / height,
      child: imageWidget,
    );
  }

  List buildImageBytes(String dataUri) {
    final match = _dataUriRegExp.matchAsPrefix(dataUri);
    if (match == null) return null;

    final prefix = match[0];
    final bytes = base64.decode(dataUri.substring(prefix.length));
    if (bytes.length == 0) return null;

    return bytes;
  }

  Widget buildImageFromDataUri(String dataUri) {
    final bytes = buildImageBytes(dataUri);
    if (bytes == null) return null;

    return Image.memory(bytes, fit: BoxFit.cover);
  }

  Widget buildImageFromUrl(String url) =>
      url?.isNotEmpty == true ? Image.network(url, fit: BoxFit.cover) : null;

  Widget buildPadding(Widget child, EdgeInsets padding) {
    if (child == null) return null;
    if (padding == null || padding == const EdgeInsets.all(0)) return child;

    if (child is Padding) {
      final p = child as Padding;
      final pp = p.padding as EdgeInsets;
      child = p.child;
      padding = EdgeInsets.fromLTRB(
        pp.left + padding.left,
        pp.top > padding.top ? pp.top : padding.top,
        pp.right + padding.right,
        pp.bottom > padding.bottom ? pp.bottom : padding.bottom,
      );
    }

    return Padding(child: child, padding: padding);
  }

  Widget buildScrollView(List<Widget> widgets) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: widgets.length == 1 ? widgets.first : buildColumn(widgets),
      );

  Widget buildTable(List<TableRow> rows, {TableBorder border}) => Table(
        border: border,
        children: rows,
      );

  Widget buildTableCell(Widget child) => TableCell(child: child);

  Widget buildText({
    TextBlock block,
    String text,
    TextAlign textAlign,
  }) {
    assert((text == null) != (block == null));
    final _textAlign = textAlign ?? TextAlign.start;

    if (block?.hasStyle == true) {
      final span = compileToTextSpan(block, defaultTextStyle);
      if (span != null) return RichText(text: span, textAlign: _textAlign);
    }

    final data = compileToString(block) ?? text;
    if (data != null) return Text(data, textAlign: _textAlign);

    return null;
  }

  TextDecoration buildTextDecoration(NodeMetadata meta, TextStyle parent) {
    if (meta.hasDecoration != true) return null;

    final pd = parent.decoration;
    final pdLineThough = pd?.contains(TextDecoration.lineThrough) == true;
    final pdOverline = pd?.contains(TextDecoration.overline) == true;
    final pdUnderline = pd?.contains(TextDecoration.underline) == true;

    final List<TextDecoration> list = [];
    if (meta.decorationLineThrough == true ||
        (pdLineThough && meta.decorationLineThrough != false)) {
      list.add(TextDecoration.lineThrough);
    }
    if (meta.decorationOverline == true ||
        (pdOverline && meta.decorationOverline != false)) {
      list.add(TextDecoration.overline);
    }
    if (meta.decorationUnderline == true ||
        (pdUnderline && meta.decorationUnderline != false)) {
      list.add(TextDecoration.underline);
    }

    return TextDecoration.combine(list);
  }

  double buildTextFontSize(String value, TextStyle parent) {
    final parsed = parser.lengthParseValue(value);
    if (parsed != null) return parsed.getValue(parent);

    switch (value) {
      case 'xx-large':
        return defaultFontSize * 2.0;
      case 'x-large':
        return defaultFontSize * 1.5;
      case 'large':
        return defaultFontSize * 1.125;
      case 'medium':
        return defaultFontSize;
      case 'small':
        return defaultFontSize * .8125;
      case 'x-small':
        return defaultFontSize * .625;
      case 'xx-small':
        return defaultFontSize * .5625;

      case 'larger':
        return parent.fontSize * 1.2;
      case 'smaller':
        return parent.fontSize * (15 / 18);
    }

    return null;
  }

  TextStyle buildTextStyle(NodeMetadata meta, TextStyle parent) {
    if (meta?.hasStyling != true) return null;

    return parent.copyWith(
      color: meta.color,
      decoration: buildTextDecoration(meta, parent),
      decorationStyle: meta.decorationStyle,
      fontFamily: meta.fontFamily,
      fontSize: buildTextFontSize(meta.fontSize, parent),
      fontStyle: buildFontSize(meta),
      fontWeight: meta.fontWeight,
    );
  }

  NodeMetadata parseElement(NodeMetadata meta, dom.Element e) {
    switch (e.localName) {
      case 'br':
        meta = lazySet(meta, buildOp: tagBr());
        break;

      case kTagCode:
      case kTagPre:
      case kTagTt:
        meta = lazySet(meta, buildOp: tagCode());
        break;

      case 'hr':
        meta = lazySet(meta, buildOp: tagHr());
        break;

      case 'img':
        meta = lazySet(meta, buildOp: tagImg());
        break;

      case 'q':
        meta = lazySet(meta, buildOp: tagQ());
        break;

      case kTagTable:
      case kTagTableBody:
      case kTagTableCaption:
      case kTagTableCell:
      case kTagTableFoot:
      case kTagTableHead:
      case kTagTableHeader:
      case kTagTableRow:
        meta = lazySet(meta, buildOp: tagTable());
        break;
    }

    return parser.parseElement(meta, e);
  }

  NodeMetadata parseElementStyle(NodeMetadata meta, String key, String value) {
    switch (key) {
      case kCssBackgroundColor:
        meta = lazySet(meta, buildOp: styleBgColor());
        break;

      case kCssMargin:
      case kCssMarginBottom:
      case kCssMarginLeft:
      case kCssMarginRight:
      case kCssMarginTop:
        meta = lazySet(meta, buildOp: styleMargin());
        break;

      case kCssTextAlign:
        meta = lazySet(meta, buildOp: styleTextAlign());
        break;
    }

    return parser.parseElementStyle(meta, key, value);
  }

  BuildOp styleBgColor() {
    _styleBgColor ??= StyleBgColor(this).buildOp;
    return _styleBgColor;
  }

  BuildOp styleMargin() {
    _styleMargin ??= StyleMargin(this).buildOp;
    return _styleMargin;
  }

  BuildOp styleTextAlign() {
    _styleTextAlign ??= StyleTextAlign(this).buildOp;
    return _styleTextAlign;
  }

  BuildOp tagBr() {
    _tagBr ??= BuildOp(
      getInlineStyles: (_) => ['margin-bottom', '1em'],
      onWidgets: (_, __) => Container(),
    );
    return _tagBr;
  }

  BuildOp tagCode() {
    _tagCode ??= TagCode(this).buildOp;
    return _tagCode;
  }

  BuildOp tagHr() {
    _tagHr ??= BuildOp(
      getInlineStyles: (e) => const [kCssMarginBottom, '1em'],
      onWidgets: (_, __) => buildDivider(),
    );
    return _tagHr;
  }

  BuildOp tagImg() {
    _tagImg ??= TagImg(this).buildOp;
    return _tagImg;
  }

  BuildOp tagQ() {
    _tagQ ??= BuildOp(onPieces: (_, pieces) {
      final first = pieces.first;
      final last = pieces.last;

      if (!first.hasWidgets && !last.hasWidgets) {
        final firstBlock = first.block;
        final firstBit = firstBlock.iterable.first;
        firstBlock.rebuildBits(
          (b) => b == firstBit ? b.rebuild(data: '“' + b.data) : b,
        );

        final lastBlock = last.block;
        final lastBit = lastBlock.iterable.last;
        lastBlock.rebuildBits(
          (b) => b == lastBit ? b.rebuild(data: b.data + '”') : b,
        );
      }

      return pieces;
    });
    return _tagQ;
  }

  BuildOp tagTable() {
    _tagTable ??= TagTable(this).buildOp;
    return _tagTable;
  }
}