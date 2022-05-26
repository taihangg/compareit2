import 'dart:io';
import 'dart:math';
// import 'package:compareit2/compareMgr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter/services.dart';
// import 'package:file_picker/file_picker.dart';
import 'package:tuple/tuple.dart';
import 'dataType.dart';
import 'boundingTextSize.dart';

typedef ReplaceTextCallback = bool Function(int index, int len, Object? data);

class EditorMgr_t {
  late final TextStyle style;

  late final quill.QuillController ctrl;

  final BoundingTextSize boundingTextSize;
  disableEditorCallback() {
    ctrl.onReplaceText = null;
    return;
  }

  void enableEditorCallback() {
    ctrl.onReplaceText = onReplaceText;
    return;
  }

  late final quill.Document doc;

  late final FocusNode focusNode;
  late GlobalKey globalKey;
  late final quill.QuillEditor editor;
  final scrollCtrl = ScrollController();

  String docStr = ""; // doc中的所有文本
  // List<String> lineStrArr = []; // 一行一个String，不包括换行符
  // List<List<int>> lineCharArr = []; // 从 lineStrArr 转换而来
  // List<int> allChar = [];

  List<LineInfo_t> lineInfoArr = [
    LineInfo_t("", 1, BlockType_e.same)
  ]; // 至少有一个值
  List<Anchor_t> anchorList = [];
  // int? lastAnchorIdx;
  void Function(int editorId, int lineIdx, AnchorType_e oldStatus)
      onAnchorChange;

  void Function(int editorId, int lineIdx) clearAnchorPairCallback;

  String? path;
  final void Function(int editorId) onDocDataChange;

  final int editorId;
  EditorMgr_t(this.editorId, this.style, this.boundingTextSize,
      this.onDocDataChange, this.onAnchorChange, this.clearAnchorPairCallback) {
    doc = quill.Document();
    ctrl = quill.QuillController(
      document: doc,
      selection: TextSelection.collapsed(offset: 0),
      onDelete: (int cursorPosition, bool forward) {
        print("onDelete ${cursorPosition} ${forward}");
        return;
      },
      // onReplaceText: onReplaceText,
    );
    // ctrl.onReplaceText = onReplaceText;
    focusNode = FocusNode();
    globalKey = GlobalKey();
    editor = makeEditor(ctrl, focusNode);

    // 开始没有内容，操作一下
    // disableEditorCallback();
    doc.insert(0, "a");
    ctrl.clear();
    enableEditorCallback();

    return;
  }

  bool onReplaceText(int start, int len, Object? data) {
    // print("onReplaceText index:${start} len:${len} data:[${data}]");

    String head = "", tail = "";
    int startLineIdx = 0, endLineIdx = 0;

    EditCursorType_e startCType = EditCursorType_e.unknown,
        endCType = EditCursorType_e.unknown;

    int charIdx = 0;

    for (int i = 0; i < lineInfoArr.length; i++) {
      if (start <
          charIdx +
              lineInfoArr[i].headVirtualLineCount +
              lineInfoArr[i].text.length +
              1) {
        startLineIdx = i;

        if (start < charIdx + lineInfoArr[i].headVirtualLineCount) {
          startCType = EditCursorType_e.virtual;
          // head = "";
        } else {
          assert(start <
              charIdx +
                  lineInfoArr[i].headVirtualLineCount +
                  lineInfoArr[i].text.length +
                  1);
          startCType = EditCursorType_e.real;
          int inlineCharStart = start - charIdx;
          head = lineInfoArr[i].text.substring(0, inlineCharStart);
        }

        break;
      }

      charIdx += lineInfoArr[i].headVirtualLineCount +
          lineInfoArr[i].text.length +
          1; //包括换行符
    }

    int end = start + len;
    for (int i = startLineIdx; i < lineInfoArr.length; i++) {
      if (start <
          charIdx +
              lineInfoArr[i].headVirtualLineCount +
              lineInfoArr[i].text.length +
              1) {
        endLineIdx = i;

        if (start < charIdx + lineInfoArr[i].headVirtualLineCount) {
          endCType = EditCursorType_e.virtual;
          // tail = "";
        } else {
          assert(start <
              charIdx +
                  lineInfoArr[i].headVirtualLineCount +
                  lineInfoArr[i].text.length +
                  1);
          endCType = EditCursorType_e.real;
          int inlineCharEnd = end - charIdx;
          tail = lineInfoArr[i].text.substring(inlineCharEnd);
        }
        break;
      }

      if (i != startLineIdx) {
        // lineStart行在上面已经加过headVirtualLineCount了
        charIdx += lineInfoArr[i].headVirtualLineCount;
      }
      charIdx += lineInfoArr[i].text.length + 1; //包括换行符
    }

    if (startLineIdx == endLineIdx) {
      // 单行内编辑，不修改锚点信息
    } else {
      // 多行操作，清除[lineStart,lineEnd]闭区间内所有锚点对信息
      for (int lineIdx = startLineIdx; lineIdx <= endLineIdx; lineIdx++) {
        if (AnchorType_e.paired == lineInfoArr[lineIdx].anchorType) {
          clearAnchorPairCallback(editorId, lineIdx);
        }
      }
    }

    // print("head:[${head}] tail:[${tail}]");

    // lineStrArr.sublist(0,lineStart)
    String dataStr = (data as String)
      ..replaceAll("\r\n", "\n").replaceAll("\r", "\n");

    List<LineInfo_t> headBlock = lineInfoArr.sublist(0, startLineIdx);
    List<LineInfo_t> newBlock = (head + dataStr + tail)
        .split("\n")
        .map((String e) => LineInfo_t(e))
        .toList();
    List<LineInfo_t> tailBlock = (endLineIdx + 1 < lineInfoArr.length)
        ? lineInfoArr.sublist(endLineIdx + 1)
        : [];

    lineInfoArr = headBlock + newBlock + tailBlock;
    if (lineInfoArr.isEmpty) {
      lineInfoArr = [LineInfo_t("", 1 /*, BlockType_e.same*/)];
    }

    docStr = lineInfoArr.map((LineInfo_t e) => e.text).join("\n");

    // ，把光标重定位到固定的行里？
    int lineIdx = endLineIdx;
    int offset = newBlock.last.text.length - tail.length;
    int cursorPos = 0;
    for (int i = 0; i < lineIdx; i++) {
      cursorPos +=
          lineInfoArr[i].headVirtualLineCount + lineInfoArr[i].text.length + 1;
    }
    cursorPos += offset;

    // Future(() {
    onDocDataChange(editorId); // compare操作会修改doc的内容
    ctrl.moveCursorToPosition(cursorPos);
    // });

    // 返回true，与本回调函数内直接增删editor文本的操作会冲突
    // 要么返回false，要么在Future里调用compare
    return false;
  }

  quill.QuillEditor makeEditor(
      quill.QuillController ctrl, FocusNode focusNode) {
    final style = TextStyle(fontSize: 50);
    final dtbStyle = quill.DefaultTextBlockStyle(
        const TextStyle(
          fontSize: 50,
          color: Colors.black,
          height: 1.15,
          fontWeight: FontWeight.w300,
        ),
        const Tuple2(16, 0),
        const Tuple2(0, 0),
        null);
    return quill.QuillEditor(
      key: globalKey,
      controller: ctrl,
      scrollController: ScrollController(),
      scrollable: false,
      focusNode: focusNode,
      autoFocus: false,
      readOnly: false,
      // placeholder: '正在加载，请稍等...',
      expands: false,
      padding: EdgeInsets.zero,
      // showCursor: true,
      paintCursorAboveText: true,
      // floatingCursorDisabled: true,
      // customStyles: quill.DefaultStyles(
      //   h1: dtbStyle,
      //   color: Colors.purpleAccent,
      //   small: style,
      //   sizeSmall: style,
      //   sizeLarge: style,
      //   sizeHuge: style,
      // ),
    );
  }

  Widget buildLineNum(void Function() refresh) {
    // if (lineInfoArr.isEmpty) {
    //   return Container(child: Text("1", style: style));
    // }

    final size = boundingTextSize.getTextSize("${lineInfoArr.length}");
    final blank = Container(
        height: size.height,
        width: size.width + size.height,
        color: Colors.grey.shade400);
    final empty = Row(children: [
      Container(
          height: size.height, width: size.width, color: Colors.grey.shade400),
      Container(height: size.height, width: size.height),
    ]);

    List<Widget> children = [];
    for (int lineIdx = 0; lineIdx < lineInfoArr.length; lineIdx++) {
      LineInfo_t e = lineInfoArr[lineIdx];
      children.addAll(List.filled(e.headVirtualLineCount, blank));
      final text = Container(
          height: size.height,
          width: size.width,
          color: (BlockType_e.diff == e.diffType)
              ? Colors.red
              : Colors.transparent,
          alignment: Alignment.centerRight,
          child: Text("${lineIdx + 1}", style: style));
      Widget? anchor;
      switch (e.anchorType) {
        case AnchorType_e.single:
          {
            anchor = Icon(Icons.anchor, color: Colors.blue, size: size.height);
            break;
          }
        case AnchorType_e.paired:
          {
            anchor = Icon(Icons.anchor,
                color: Colors.orangeAccent, size: size.height);
            break;
          }
        case AnchorType_e.noAnchor:
          {
            // do nothing
            break;
          }
        default:
          {
            assert(false);
          }
      }

      final gesture = GestureDetector(
        child: Container(
          height: size.height,
          width: size.height,
          color: Colors.transparent,
          child: anchor,
          // decoration: BoxDecoration(
          //   color: Colors.transparent,
          //   // border: Border.all(width: 0.5, color: Colors.red),
          //   borderRadius: BorderRadius.all(Radius.circular(10.0)),
          // ),
        ),
        onTap: () {
          // 加锚点，不支持取消；可由cmpmgr确定重新确定行索引

          // if (e.anchor) {
          //   return;
          // }
          final oldStatus = e.anchorType;
          if (AnchorType_e.noAnchor == oldStatus) {
            e.anchorType = AnchorType_e.single;
            // final anchor = Anchor_t(lineIdx, AnchorType_e.single);
            // anchorList.add(anchor);
          } else {
            e.anchorType = AnchorType_e.noAnchor;
            // final anchor = Anchor_t(lineIdx, AnchorType_e.noAnchor);
            // anchorList.remove(anchor);
          }

          onAnchorChange(editorId, lineIdx, oldStatus);

          refresh();

          return;
        },
      );
      children
          .add(Row(mainAxisSize: MainAxisSize.min, children: [text, gesture]));
      children.addAll(List.filled(
          // e.headVirtualLineCount +
          e.showingLineCount - 1,
          blank));
    }

    final decoration = BoxDecoration(
      //color: Colors.redAccent,
      border: Border(
        left: BorderSide(width: 0.5, color: Colors.black),
        right: BorderSide(width: 0.5, color: Colors.black),
      ),
      // borderRadius: BorderRadius.all(Radius.circular(8.0)),
    );

    return Container(
        decoration: decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          // mainAxisSize: MainAxisSize.min,
          children: children,
        ));
  }

  void clearAnchor(int lineIdx) {
    lineInfoArr[lineIdx].anchorType = AnchorType_e.noAnchor;
    // for (int i = 0; i < anchorList.length; i++) {
    //   if (lineIdx == anchorList[i].lineIdx) {
    //     anchorList.removeAt(i);
    //     break;
    //   }
    // }
    return;
  }

  Widget buildEditor() {
    Future(() {
      boundingTextSize.updateWitdh(globalKey.currentContext!.size!.width);
    });

    return Expanded(
        child: Container(
            // decoration: BoxDecoration(
            //   //color: Colors.redAccent,
            //   border: Border(
            //     left: BorderSide(width: 0.5, color: Colors.black),
            //     right: BorderSide(width: 0.5, color: Colors.black),
            //   ),
            //   // borderRadius: BorderRadius.all(Radius.circular(8.0)),
            // ),
            child: editor));

    return Expanded(
        child: Scrollbar(
            controller: scrollCtrl,
            isAlwaysShown: true,
            // scrollbarOrientation: ScrollbarOrientation.left,
            child: ListView(controller: scrollCtrl, children: [
              Container(child: editor),
            ])));

    // return Expanded(
    //     child: ListView(
    //         controller: scrollCtrl, children: [Container(child: editor)]));

    // return Expanded(
    //     child: SingleChildScrollView(
    //         controller: scrollCtrl, child: Container(child: editor)));
  }

  loadFile() async {
    if (null == path) {
      return;
    }

    // List<int> bytes = File(path).readAsBytesSync();
    try {
      docStr = File(path!).readAsStringSync();
      docStr = docStr.replaceAll("\r\n", "\n").replaceAll("\r", "\n");
      // str = str.replaceAll(g_reg, "\n");

      initData();
    } catch (err) {
      doc.insert(0, "打开文件失败：$path\n${err.toString()}");
      print("打开文件失败：$path");
    }
    return;
  }

  static final RegExp g_reg = RegExp(r'(\r\n|\r)');

  initData() {
    disableEditorCallback(); // 关闭编辑回调

    // editor会自动在内容末尾加一个换行符，这里去掉一下
    // final allChar = docStr.codeUnits;
    // if (allChar.isNotEmpty) {
    //   if ("\n" == String.fromCharCode(allChar.last)) {
    //     docStr = docStr.substring(0, docStr.length - 1);
    //   }
    // }

    // str = doc.toPlainText();
    // str = str.replaceAll(g_reg, "\n");

    // boundingTextSize.updateWitdh(globalKey.currentContext!.size!.width);

    List<String> lineStrArr = docStr.split("\n"); // 结果中不包括换行符
    lineInfoArr = lineStrArr
        .map((e) => LineInfo_t(e, boundingTextSize.getTextLineCount(e)))
        .toList();
    if (lineInfoArr.isEmpty) {
      lineInfoArr = [LineInfo_t("", 1 /*, BlockType_e.same*/)];
    }

    assert(null == ctrl.onReplaceText);
    ctrl.clear(); // 会触发编辑回调
    doc.insert(0, docStr); // 不会触发编辑回调
    doc.format(0, docStr.length, colorToAttr(Colors.red));

    enableEditorCallback(); // 恢复编辑回调

    return;
  }

  beforeCompare() {
    assert(null == ctrl.onReplaceText);

    assert(lineInfoArr.map((e) => e.text).toList().join("\n") == docStr);
    // 更新showingLineCount
    for (var e in lineInfoArr) {
      e.reinit(boundingTextSize.getTextLineCount(e.text));
    }

    // 比较算法依赖没有虚拟空行的原始文本，恢复一下数据
    assert(null == ctrl.onReplaceText);
    ctrl.clear(); // 会触发编辑回调
    doc.insert(0, docStr); // 不会触发编辑回调
    doc.format(0, docStr.length, colorToAttr(Colors.red));

    return;
  }

  // resetAnchorStatus() {
  // for (Anchor_t e in anchorList) {
  //   lineInfoArr[e.lineIdx].anchorType = e.type;
  // }
  // return;
  // }

  void clearAllAnchor() {
    // for (Anchor_t e in anchorList) {
    //   lineInfoArr[e.lineIdx].anchorType = AnchorType_e.noAnchor;
    // }
    // anchorList = [];
    for (var e in lineInfoArr) {
      if (AnchorType_e.noAnchor != e.anchorType) {
        e.anchorType = AnchorType_e.noAnchor;
      }
    }
    return;
  }

  void setAnchorStatusPaired(int lineIdx) {
    lineInfoArr[lineIdx].anchorType = AnchorType_e.paired;
    // bool ok = false;
    // for (final e in anchorList) {
    //   if (e.lineIdx == lineIdx) {
    //     e.type = AnchorType_e.paired;
    //     ok = true;
    //     break;
    //   }
    // }
    // if (!ok) {
    //   anchorList.add(Anchor_t(lineIdx, AnchorType_e.paired));
    // }
    return;
  }
}

quill.BackgroundAttribute colorToAttr(Color color) {
  var hex = color.value.toRadixString(16);
  if (hex.startsWith('ff')) {
    hex = hex.substring(2);
  }
  hex = '#$hex';
  return quill.BackgroundAttribute(hex);
}
