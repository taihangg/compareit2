import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'editorMgr.dart';
import 'boundingTextSize.dart';
import 'dataType.dart';

class CompareMgr {
  final style = TextStyle(fontSize: 16);
  late final BoundingTextSize boundingTextSize;

  final List<EditorMgr_t> editor = [];

  List<AnchorPair_t> anchorPairList = [];

  // late Size singleLineSize;
  late void Function() refresh;
  late BuildContext ctx;

  initRuntimeData(BuildContext ctx, Function() refresh) {
    // singleLineSize = mgr1.globalKey.currentContext!.size!;
    boundingTextSize = BoundingTextSize(ctx, style);

    editor.add(EditorMgr_t(0, style, boundingTextSize, compare, onAnchorChange,
        clearAnchorPairCallback));
    editor.add(EditorMgr_t(1, style, boundingTextSize, compare, onAnchorChange,
        clearAnchorPairCallback));

    this.refresh = refresh;
    return;
  }

  List<int?> tmpAnchorLineArr = List.filled(2, null);
  void onAnchorChange(int editorIdx, int lineIdx, AnchorType_e oldStatus) {
    assert((null == tmpAnchorLineArr[0]) || (null == tmpAnchorLineArr[1]));

    if ((null == tmpAnchorLineArr[0]) && (null == tmpAnchorLineArr[1])) {
      // 两侧都没有单点
      switch (oldStatus) {
        case AnchorType_e.noAnchor:
          {
            tmpAnchorLineArr[editorIdx] = lineIdx;
            break;
          }
        case AnchorType_e.single:
          {
            tmpAnchorLineArr[editorIdx] = null;
            break;
          }
        case AnchorType_e.paired:
          {
            // 取消已有配对，两侧的锚点一起取消
            for (int i = 0; i < anchorPairList.length; i++) {
              final pair = anchorPairList[i];
              if (lineIdx == pair.anchor[editorIdx].lineIdx) {
                editor[0].clearAnchor(pair.anchor[0].lineIdx);
                editor[1].clearAnchor(pair.anchor[1].lineIdx);
                anchorPairList.removeAt(i);
                compare();
                break;
              }
            }
            break;
          }
      }
    } else if (null != tmpAnchorLineArr[editorIdx]) {
      // 本侧有单点
      switch (oldStatus) {
        case AnchorType_e.noAnchor:
          {
            editor[0].clearAnchor(tmpAnchorLineArr[editorIdx]!);
            tmpAnchorLineArr[editorIdx] = lineIdx;
            break;
          }
        case AnchorType_e.single:
          {
            assert(lineIdx == tmpAnchorLineArr[editorIdx]);
            tmpAnchorLineArr[editorIdx] = null;
            break;
          }
        case AnchorType_e.paired:
          {
            tmpAnchorLineArr[editorIdx] = null;
            break;
          }
      }
    } else if (null != tmpAnchorLineArr[editorIdx ^ 1]) {
      // 对侧有单点
      switch (oldStatus) {
        case AnchorType_e.noAnchor:
          {
            // 配对
            tmpAnchorLineArr[editorIdx] = lineIdx;

            addAnchorPair(tmpAnchorLineArr);
            compare();
            tmpAnchorLineArr[0] = tmpAnchorLineArr[1] = null;
            break;
          }
        case AnchorType_e.single:
          {
            assert(false);
            break;
          }
        case AnchorType_e.paired:
          {
            tmpAnchorLineArr[editorIdx] = lineIdx;
            addAnchorPair(tmpAnchorLineArr);
            compare();
            tmpAnchorLineArr[0] = tmpAnchorLineArr[1] = null;
            break;
          }
      }
    }

    return;
  }

  void clearAnchorPairCallback(int editorIdx, int lineIdx) {
    for (int i = 0; i < anchorPairList.length; i++) {
      if (anchorPairList[i].anchor[editorIdx].lineIdx <= lineIdx) {
        if (anchorPairList[i].anchor[editorIdx].lineIdx == lineIdx) {
          editor[editorIdx ^ 1].clearAnchor(lineIdx);
          anchorPairList.removeAt(i);
        }
        break;
      }
    }
    return;
  }

  void addAnchorPair(List<int?> lineIdxArr) {
    assert((null != lineIdxArr[0]) && (null != lineIdxArr[1]));

    // TODO: 扫描锚点对形成的区域是否有相互覆盖的情况，并处理
    // TODO: 交叉区域检测

    List<PosInfo_t> posArr = [PosInfo_t(), PosInfo_t()];
    findPos(int editorIdx) {
      posArr[editorIdx].pos = 0;
      for (int idx = 0;
          idx < anchorPairList.length;
          idx++, posArr[editorIdx].pos++) {
        if (lineIdxArr[editorIdx]! <=
            anchorPairList[idx].anchor[editorIdx].lineIdx) {
          if (lineIdxArr[editorIdx]! ==
              anchorPairList[idx].anchor[editorIdx].lineIdx) {
            posArr[editorIdx].cover = true;
          }
          break;
        }
      }
      return;
    }

    findPos(0);
    findPos(1);

    if (posArr[0].pos != posArr[1].pos) {
      int getMinIdx(int a, int b) => (a < b) ? 0 : 1;
      int getMaxIdx(int a, int b) => (a < b) ? 1 : 0;

      int minIdx = getMinIdx(posArr[0].pos, posArr[1].pos);
      int maxIdx = minIdx ^ 1;

      int start = posArr[minIdx].pos;
      int end = posArr[maxIdx].pos;
      if (posArr[maxIdx].cover) {
        end++;
      }

      for (int i = start; i < end; i++) {
        final pair = anchorPairList[i];
        editor[0].clearAnchor(pair.anchor[0].lineIdx);
        editor[1].clearAnchor(pair.anchor[1].lineIdx);
      }
      anchorPairList =
          anchorPairList.sublist(0, start) + anchorPairList.sublist(end);
    } else {}

    final anchorPair = AnchorPair_t();
    anchorPair.anchor[0] = Anchor_t(lineIdxArr[0]!, AnchorType_e.paired);
    anchorPair.anchor[1] = Anchor_t(lineIdxArr[1]!, AnchorType_e.paired);

    anchorPairList.add(anchorPair);
    anchorPairList.sort((AnchorPair_t a, AnchorPair_t b) {
      if (a.anchor[0].lineIdx < b.anchor[0].lineIdx) {
        return -1;
      } else if (a.anchor[0].lineIdx == b.anchor[0].lineIdx) {
        return 0;
      } else {
        return 1;
      }
    });

    editor[0].setAnchorStatusPaired(lineIdxArr[0]!);
    editor[1].setAnchorStatusPaired(lineIdxArr[1]!);

    return;
  }

  Widget buildEditorPair() {
    final scrollCtrl = ScrollController();
    final divider = Container(
        decoration: BoxDecoration(
          //color: Colors.redAccent,
          border: Border.all(width: 0.5, color: Colors.red),
          // borderRadius: BorderRadius.all(Radius.circular(8.0)),
        ),
        child: VerticalDivider(width: 1, thickness: 1, color: Colors.black));
    return Expanded(
      child: Scrollbar(
        controller: scrollCtrl,
        isAlwaysShown: true,
        // scrollbarOrientation: ScrollbarOrientation.left,
        child: ListView(controller: scrollCtrl, children: [
          Container(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // divider,
                editor[0].buildLineNum(refresh),
                // divider,
                editor[0].buildEditor(),
                // divider,
                editor[1].buildLineNum(refresh),
                // divider,
                editor[1].buildEditor(),
              ],
            ),
          ),
        ]),
      ),
    );

    // return Expanded(
    //   child: Container(
    //     child: Row(
    //       crossAxisAlignment: CrossAxisAlignment.start,
    //       children: [
    //         VerticalDivider(),
    //         mgrArr[0].buildEditor(),
    //         VerticalDivider(),
    //         mgrArr[1].buildEditor(),
    //       ],
    //     ),
    //   ),
    // );
  }

  compare([int]) async {
    // 比较对齐会使增加删除填充行，现在的做法是完全重新构建editor的文本

    // 关闭编辑回调
    editor[0].disableEditorCallback();
    editor[1].disableEditorCallback();

    boundingTextSize
        .updateWitdh(editor[0].globalKey.currentContext!.size!.width);

    // final list = widget._doc1.toPlainText().codeUnits;
    //窗口大小可能变化，boundingTextSize会更新witdh，每次重算都用最新的

    editor[0].beforeCompare();
    editor[1].beforeCompare();

    // editor[0].resetAnchorStatus();
    // editor[1].resetAnchorStatus();

    List<AlignmentBlockPair_t> alignmentBlockList = [];
    List<lineBlockPair_t> diffBlockList = [];
    setSameLineBlock(diffBlockList, alignmentBlockList);

    // 深度比较不同行块的详细内容
    setSameCharBlock(diffBlockList, alignmentBlockList);

    // setState(() {});

    applyAlignment(alignmentBlockList);

    // 恢复编辑回调
    editor[0].enableEditorCallback();
    editor[1].enableEditorCallback();

    refresh();

    return;
  }

  void clearAllAnchor() {
    editor[0].clearAllAnchor();
    editor[1].clearAllAnchor();
    return;
  }

  applyAlignment(List<AlignmentBlockPair_t> alignmentBlockList) {
    // 按block1的行号排序
    alignmentBlockList.sort((AlignmentBlockPair_t a, AlignmentBlockPair_t b) {
      if (a.block[0].lineStart < b.block[0].lineStart) {
        return -1;
      } else if (b.block[0].lineStart < a.block[0].lineStart) {
        return 1;
      } else {
        // 再比行数，有某一侧行数为0的情况
        if (a.block[0].lineCount < b.block[0].lineCount) {
          return -1;
        } else if (b.block[0].lineCount < a.block[0].lineCount) {
          return 1;
        } else {
          return 0;
        }
      }
    });

    List<int> lineIdx = [0, 0];
    List<int> offset = [0, 0];

    for (int i = 0; i < alignmentBlockList.length; i++) {
      final alignmentInfo = alignmentBlockList[i];
      final block = alignmentInfo.block;

      // print("i=${i} lineIdx1=${lineIdx1} lineIdx2=${lineIdx2}\n"
      //     "${alignmentInfo}");

      assert(block[0].lineStart == lineIdx[0]);
      lineIdx[0] = block[0].lineEnd;

      assert(block[1].lineStart == lineIdx[1]);
      lineIdx[1] = block[1].lineEnd;

      if (BlockType_e.same == alignmentInfo.type) {
        for (int j = block[0].lineStart, k = block[1].lineStart;
            j < block[0].lineEnd;
            j++, k++) {
          // int showLineCount =
          //     boundingTextSize.getTextLineCount(mgr1.lineStrArr[j]);

          editor[0].lineInfoArr[j].diffType = BlockType_e.same;
          // fillLineNum_withShowLineCount(mgr1, j, showLineCount);

          editor[1].lineInfoArr[k].diffType = BlockType_e.same;
          // fillLineNum_withShowLineCount(mgr2, k, showLineCount);
        }

        // print("\n");
        continue;
      }

      List<int> showLineCount = [0, 0];
      getShowLinecount(int editorIdx) {
        for (int j = block[editorIdx].lineStart;
            j < block[editorIdx].lineEnd;
            j++) {
          editor[editorIdx].lineInfoArr[j].diffType = BlockType_e.diff;
          // int k = fillLineNum(mgr1, j);
          // assert(k == mgr1.lineInfoArr[j].showingLineCount);
          showLineCount[editorIdx] +=
              editor[editorIdx].lineInfoArr[j].showingLineCount;
        }
      }

      getShowLinecount(0);
      getShowLinecount(1);

      if (showLineCount[0] < showLineCount[1]) {
        int incLineCount = showLineCount[1] - showLineCount[0];
        if (block[0].lineEnd < editor[0].lineInfoArr.length) {
          // 下一块的第一行之前加上虚拟行
          editor[0].lineInfoArr[block[0].lineEnd].headVirtualLineCount =
              incLineCount;
        }

        String insertStr = List.filled(incLineCount, "\n").join();
        editor[0].doc.insert(block[0].charEnd + offset[0], insertStr);
        offset[0] += incLineCount;
      } else if (showLineCount[1] < showLineCount[0]) {
        int incLineCount = showLineCount[0] - showLineCount[1];
        if (block[1].lineEnd < editor[1].lineInfoArr.length) {
          editor[1].lineInfoArr[block[1].lineEnd].headVirtualLineCount =
              incLineCount;
        }
        String insertStr = List.filled(incLineCount, "\n").join();
        editor[1].doc.insert(block[1].charEnd + offset[1], insertStr);
        offset[1] += incLineCount;
      }
    }

    return;
  }

  setSameLineBlock(List<lineBlockPair_t> diffBlockList,
      List<AlignmentBlockPair_t> alignmentBlockList) async {
    // 以行为基本单位，找到连续相同的多行（块）

    List<lineBlockPair_t> stack = getInitBlockPair();

    while (stack.isNotEmpty) {
      // 找到当前区域中，最大的相同块，
      // 刷新颜色，
      // 前后剩余部分放进 blockPairList 中，下次处理

      final lineBlockPair_t lineBlockPair = stack.removeLast();
      // print("blockPair:${blockPair}");

      List<lineBlockPair_t> blockList = [];
      final lineBlockPair_t? maxSameBlock =
          findMaxSameLineBlock(lineBlockPair, blockList);

      if (null == maxSameBlock) {
        lineBlockPair.type = BlockType_e.diff;
        diffBlockList.add(lineBlockPair);
        continue;
      }

      alignmentBlockList.add(AlignmentBlockPair_t.fromLineBlockPair(
          maxSameBlock, BlockType_e.same));

      setDocColorByLineBlockPair(lineBlockPair_t blockPair) {
        setDocColorByLineBlock(EditorMgr_t mgr, LineBlock_t block) {
          mgr.doc.format(
              block.charStart, block.allLineLen, colorToAttr(Colors.white));
          return;
        }

        setDocColorByLineBlock(editor[0], blockPair.block[0]);
        setDocColorByLineBlock(editor[1], blockPair.block[1]);
        return;
      }

      setDocColorByLineBlockPair(maxSameBlock);

      if ((lineBlockPair.block[0].lineStart <
              maxSameBlock.block[0].lineStart) &&
          (lineBlockPair.block[1].lineStart <
              maxSameBlock.block[1].lineStart)) {
        // 前面有剩余区域
        final lineBlockPair_t head = lineBlockPair_t();

        makeHeadLineBlock(int editorIdx) {
          LineBlock_t initBlock = lineBlockPair.block[editorIdx];
          LineBlock_t sameBlock = maxSameBlock.block[editorIdx];

          head.block[editorIdx] = LineBlock_t.fromData(
              lineStart: initBlock.lineStart,
              lineCount: sameBlock.lineStart - initBlock.lineStart,
              charStart: initBlock.charStart,
              allLineLen: sameBlock.charStart - initBlock.charStart);
          return;
        }

        makeHeadLineBlock(0);
        makeHeadLineBlock(1);

        stack.add(head);
      } else if ((lineBlockPair.block[0].lineStart <
              maxSameBlock.block[0].lineStart) ||
          (lineBlockPair.block[1].lineStart <
              maxSameBlock.block[1].lineStart)) {
        final AlignmentBlockPair_t headAlignmentBlockPair =
            AlignmentBlockPair_t();

        makeHeadAlignmentBlock(int editorIdx) {
          LineBlock_t initBlock = lineBlockPair.block[editorIdx];
          LineBlock_t sameBlock = maxSameBlock.block[editorIdx];

          headAlignmentBlockPair.block[editorIdx] = AlignmentBlock_t(
              lineStart: initBlock.lineStart,
              lineCount: sameBlock.lineStart - initBlock.lineStart,
              charStart: initBlock.charStart,
              allLineLen: sameBlock.charStart - initBlock.charStart);
          return;
        }

        makeHeadAlignmentBlock(0);
        makeHeadAlignmentBlock(1);

        headAlignmentBlockPair.type = BlockType_e.diff;
        alignmentBlockList.add(headAlignmentBlockPair);
      }

      if ((maxSameBlock.block[0].lineEnd < lineBlockPair.block[0].lineEnd) &&
          (maxSameBlock.block[1].lineEnd < lineBlockPair.block[1].lineEnd)) {
        // 尾部有剩余区域
        final tail = lineBlockPair_t();

        makeTailLineBlock(int editorIdx) {
          LineBlock_t initBlock = lineBlockPair.block[editorIdx];
          LineBlock_t sameBlock = maxSameBlock.block[editorIdx];

          tail.block[editorIdx] = LineBlock_t.fromData(
              lineStart: sameBlock.lineEnd,
              lineCount: initBlock.lineEnd - sameBlock.lineEnd,
              charStart: sameBlock.charEnd,
              allLineLen: initBlock.charEnd - sameBlock.charEnd);
          return;
        }

        makeTailLineBlock(0);
        makeTailLineBlock(1);

        stack.add(tail);
      } else if ((maxSameBlock.block[0].lineEnd <
              lineBlockPair.block[0].lineEnd) ||
          (maxSameBlock.block[1].lineEnd < lineBlockPair.block[1].lineEnd)) {
        final AlignmentBlockPair_t tailAlignmentBlockPair =
            AlignmentBlockPair_t();

        makeTailAlignmentBlock(int editorIdx) {
          LineBlock_t initBlock = lineBlockPair.block[editorIdx];
          LineBlock_t sameBlock = maxSameBlock.block[editorIdx];

          tailAlignmentBlockPair.block[editorIdx] = AlignmentBlock_t(
              lineStart: sameBlock.lineEnd,
              lineCount: initBlock.lineEnd - sameBlock.lineEnd,
              charStart: sameBlock.charEnd,
              allLineLen: initBlock.charEnd - sameBlock.charEnd);
          return;
        }

        makeTailAlignmentBlock(0);
        makeTailAlignmentBlock(1);

        tailAlignmentBlockPair.type = BlockType_e.diff;
        alignmentBlockList.add(tailAlignmentBlockPair);
      }
    }

    return;
  }

  List<lineBlockPair_t> getInitBlockPair() {
    if (anchorPairList.isEmpty) {
      lineBlockPair_t initBlockPair = lineBlockPair_t();

      makeInitBlock(int editorIdx) {
        initBlockPair.block[editorIdx] = LineBlock_t.fromData(
            charStart: 0,
            allLineLen: editor[editorIdx].docStr.length,
            lineStart: 0,
            lineCount: editor[editorIdx].lineInfoArr.length);
      }

      makeInitBlock(0);
      makeInitBlock(1);

      return [initBlockPair];
    }

    int getStrLen(EditorMgr_t mgr, int lineStart, int lineEnd) {
      int len = 0;
      for (int i = lineStart; i < lineEnd; i++) {
        len += mgr.lineInfoArr[i].text.length + 1;
      }
      return len;
    }

    List<lineBlockPair_t> blockPairList = [];

    List<int> lineIdx = [0, 0];
    List<int> charIdx = [0, 0];

    for (int i = 0; i < anchorPairList.length; i++) {
      List<int> anchorLineIdx = [0, 0];

      // 锚点行之前的块
      lineBlockPair_t headPair = lineBlockPair_t();
      List<int> headLen = [0, 0];

      // 锚点行本身作为一个块
      lineBlockPair_t anchorLinePair = lineBlockPair_t();
      List<int> anchorLineLen = [0, 0];

      makeBLock(int editorIdx) {
        anchorLineIdx[editorIdx] = anchorPairList[i].anchor[editorIdx].lineIdx;

        headLen[editorIdx] = getStrLen(
            editor[editorIdx], lineIdx[editorIdx], anchorLineIdx[editorIdx]);
        headPair.block[editorIdx] = LineBlock_t.fromData(
            charStart: charIdx[editorIdx],
            allLineLen: headLen[editorIdx],
            lineStart: lineIdx[editorIdx],
            lineCount: anchorLineIdx[editorIdx] - lineIdx[editorIdx]);

        anchorLineLen[editorIdx] = editor[editorIdx]
                .lineInfoArr[anchorLineIdx[editorIdx]]
                .text
                .length +
            1;
        anchorLinePair.block[editorIdx] = LineBlock_t.fromData(
            charStart: charIdx[editorIdx] + headLen[editorIdx],
            allLineLen: anchorLineLen[editorIdx],
            lineStart: anchorLineIdx[editorIdx],
            lineCount: 1);

        lineIdx[editorIdx] = anchorLineIdx[editorIdx] + 1;
        charIdx[editorIdx] += headLen[editorIdx] + anchorLineLen[editorIdx];

        return;
      }

      makeBLock(0);
      makeBLock(1);

      blockPairList.add(headPair);

      blockPairList.add(anchorLinePair);
    }

    // 加上剩余部分
    if ((lineIdx[0] < editor[0].lineInfoArr.length) ||
        (lineIdx[1] < editor[1].lineInfoArr.length)) {
      lineBlockPair_t endPair = lineBlockPair_t();

      List<int> endLen = [0, 0];

      makeTailBlock(int editorIdx) {
        endLen[editorIdx] = getStrLen(editor[editorIdx], lineIdx[editorIdx],
            editor[editorIdx].lineInfoArr.length);

        if (0 < endLen[editorIdx]) {
          // 最后一行也会被加一个换行符
          endLen[editorIdx]--;
        }
        endPair.block[editorIdx] = LineBlock_t.fromData(
            charStart: charIdx[editorIdx],
            allLineLen: endLen[editorIdx],
            lineStart: lineIdx[editorIdx],
            lineCount:
                editor[editorIdx].lineInfoArr.length - lineIdx[editorIdx]);

        return;
      }

      makeTailBlock(0);
      makeTailBlock(1);

      blockPairList.add(endPair);
    }

    return blockPairList;
  }

  setSameCharBlock(List<lineBlockPair_t> diffBlockList,
      List<AlignmentBlockPair_t> alignmentBlockList) async {
    for (int i = 0; i < diffBlockList.length; i++) {
      final pair = diffBlockList[i];

      List<lineBlockPair_t> lineBlockStack = [pair];
      while (lineBlockStack.isNotEmpty) {
        final lineBlockPair_t lineBlockPair = lineBlockStack.removeLast();

        // List<charBlockPair_t> blockList = [];

        final charBlockPair_t? maxSameCharBlockFromLineBlock =
            findMaxSameCharBlockByLineBlock(lineBlockPair);

        if (null == maxSameCharBlockFromLineBlock) {
          alignmentBlockList.add(AlignmentBlockPair_t.fromLineBlockPair(
              lineBlockPair, BlockType_e.diff));
          continue;
        }

        alignmentBlockList.add(AlignmentBlockPair_t.fromCharBlockPair(
            maxSameCharBlockFromLineBlock, BlockType_e.diff)); // 已经不是完全相同的行了

        setDocColorByCharBlockPair(maxSameCharBlockFromLineBlock);

        if ((lineBlockPair.block[0].lineStart <
                maxSameCharBlockFromLineBlock.block[0].lineIdx) &&
            (lineBlockPair.block[1].lineStart <
                maxSameCharBlockFromLineBlock.block[1].lineIdx)) {
          // 前面有剩余行

          final lineBlockPair_t head = lineBlockPair_t();

          makeHeadLineBlock(int editorIdx) {
            LineBlock_t initBlock = lineBlockPair.block[editorIdx];
            CharBlock_t sameBlock =
                maxSameCharBlockFromLineBlock.block[editorIdx];

            head.block[editorIdx] = LineBlock_t.fromData(
                lineStart: initBlock.lineStart,
                lineCount: sameBlock.lineIdx - initBlock.lineStart,
                charStart: initBlock.charStart,
                allLineLen: sameBlock.lineCharStart - initBlock.charStart);

            return;
          }

          makeHeadLineBlock(0);
          makeHeadLineBlock(1);

          lineBlockStack.add(head);
        } else if ((lineBlockPair.block[0].lineStart <
                maxSameCharBlockFromLineBlock.block[0].lineIdx) ||
            (lineBlockPair.block[1].lineStart <
                maxSameCharBlockFromLineBlock.block[1].lineIdx)) {
          // 仅某一侧有剩余行

          final headAlignmentPair = AlignmentBlockPair_t();

          makeHeadAlignmentBlock(int editorIdx) {
            LineBlock_t lineBlock = lineBlockPair.block[editorIdx];
            CharBlock_t charBlock =
                maxSameCharBlockFromLineBlock.block[editorIdx];

            headAlignmentPair.block[editorIdx] = AlignmentBlock_t(
              lineStart: lineBlock.lineStart,
              lineCount: charBlock.lineIdx - lineBlock.lineStart,
              charStart: lineBlock.charStart,
              allLineLen: charBlock.lineCharStart - lineBlock.charStart,
            );
            return;
          }

          makeHeadAlignmentBlock(0);
          makeHeadAlignmentBlock(1);

          headAlignmentPair.type = BlockType_e.diff;
          alignmentBlockList.add(headAlignmentPair);
        }

        if ((maxSameCharBlockFromLineBlock.block[0].lineIdx + 1 <
                lineBlockPair.block[0].lineEnd) &&
            (maxSameCharBlockFromLineBlock.block[1].lineIdx + 1 <
                lineBlockPair.block[1].lineEnd)) {
          // 尾部有剩余行

          final tail = lineBlockPair_t();

          makeTailLineBlock(int editorIdx) {
            LineBlock_t initBlock = lineBlockPair.block[editorIdx];
            CharBlock_t sameBlock =
                maxSameCharBlockFromLineBlock.block[editorIdx];

            tail.block[editorIdx] = LineBlock_t.fromData(
                lineStart: sameBlock.lineIdx + 1,
                lineCount: initBlock.lineEnd - (sameBlock.lineIdx + 1),
                charStart: sameBlock.lineCharEnd + 1, // 跳过换行符
                allLineLen: initBlock.charEnd - (sameBlock.lineCharEnd + 1));
            return;
          }

          makeTailLineBlock(0);
          makeTailLineBlock(1);

          lineBlockStack.add(tail);
        } else if ((maxSameCharBlockFromLineBlock.block[0].lineIdx + 1 <
                lineBlockPair.block[0].lineEnd) ||
            (maxSameCharBlockFromLineBlock.block[1].lineIdx + 1 <
                lineBlockPair.block[1].lineEnd)) {
          // 仅某一侧有剩余行

          final tailAlignmentPair = AlignmentBlockPair_t();

          makeTailAlignmentBlock(int editorIdx) {
            LineBlock_t lineBlock = lineBlockPair.block[editorIdx];
            CharBlock_t charBlock =
                maxSameCharBlockFromLineBlock.block[editorIdx];

            tailAlignmentPair.block[editorIdx] = AlignmentBlock_t(
                lineStart: charBlock.lineIdx + 1,
                lineCount: lineBlock.lineEnd - (charBlock.lineIdx + 1),
                charStart: charBlock.lineCharEnd + 1, // 跳过换行符
                allLineLen: lineBlock.charEnd - (charBlock.lineCharEnd + 1));
            return;
          }

          makeTailAlignmentBlock(0);
          makeTailAlignmentBlock(1);

          tailAlignmentPair.type = BlockType_e.diff;
          alignmentBlockList.add(tailAlignmentPair);
        }

        // 同一行内，前后可能还有相同字符串
        List<charBlockPair_t> charBlockStack = [];

        if ((0 < maxSameCharBlockFromLineBlock.block[0].inlineBlockStart) &&
            (0 < maxSameCharBlockFromLineBlock.block[1].inlineBlockStart)) {
          final head = charBlockPair_t();
          makeHeadCharBlockFromLineCharBlock(int editorIdx) {
            CharBlock_t block = maxSameCharBlockFromLineBlock.block[editorIdx];

            head.block[editorIdx] = CharBlock_t.fromData(
                lineCharStart: block.lineCharStart,
                lineStrLen: block.lineStrLen,
                lineIdx: block.lineIdx,
                inlineBlockStart: 0,
                inlineBlockLen: block.inlineBlockStart);
            return;
          }

          makeHeadCharBlockFromLineCharBlock(0);
          makeHeadCharBlockFromLineCharBlock(1);

          charBlockStack.add(head);
        }

        if ((maxSameCharBlockFromLineBlock.block[0].inLineOffsetEnd <
                maxSameCharBlockFromLineBlock.block[0].lineCharEnd) &&
            (maxSameCharBlockFromLineBlock.block[1].inLineOffsetEnd <
                maxSameCharBlockFromLineBlock.block[1].lineCharEnd)) {
          final tail = charBlockPair_t();

          makeTailCharBlockFromLineCharBlock(int editorIdx) {
            CharBlock_t sameBlock =
                maxSameCharBlockFromLineBlock.block[editorIdx];

            tail.block[editorIdx] = CharBlock_t.fromData(
                lineCharStart: sameBlock.lineCharStart,
                lineStrLen: sameBlock.lineStrLen,
                lineIdx: sameBlock.lineIdx,
                inlineBlockStart: sameBlock.inLineOffsetEnd,
                inlineBlockLen:
                    sameBlock.lineStrLen - sameBlock.inLineOffsetEnd);
            return;
          }

          makeTailCharBlockFromLineCharBlock(0);
          makeTailCharBlockFromLineCharBlock(1);

          charBlockStack.add(tail);
        }

        while (charBlockStack.isNotEmpty) {
          final charBlockPair = charBlockStack.removeLast();

          final charBlockPair_t? sameCharBlockPair =
              findMaxSameCharBlockByCharBlock(charBlockPair);

          if (null == sameCharBlockPair) {
            continue;
          }

          setDocColorByCharBlockPair(sameCharBlockPair);

          // 检查块内的前后是否还有剩余区域
          if ((charBlockPair.block[0].inlineBlockStart <
                  sameCharBlockPair.block[0].inlineBlockStart) &&
              (charBlockPair.block[1].inlineBlockStart <
                  sameCharBlockPair.block[1].inlineBlockStart)) {
            final head = charBlockPair_t();

            makeHeadCharBlockByCharBlock(int editorIdx) {
              CharBlock_t initBlock = charBlockPair.block[editorIdx];
              CharBlock_t sameBlock = sameCharBlockPair.block[editorIdx];

              return CharBlock_t.fromData(
                  lineCharStart: initBlock.lineCharStart,
                  lineStrLen: initBlock.lineStrLen,
                  lineIdx: initBlock.lineIdx,
                  inlineBlockStart: initBlock.inlineBlockStart,
                  inlineBlockLen:
                      sameBlock.inlineBlockStart - initBlock.inlineBlockStart);
            }

            makeHeadCharBlockByCharBlock(0);
            makeHeadCharBlockByCharBlock(1);

            charBlockStack.add(head);
          }

          if ((sameCharBlockPair.block[0].inLineOffsetEnd <
                  charBlockPair.block[0].inLineOffsetEnd) &&
              (sameCharBlockPair.block[0].inLineOffsetEnd <
                  charBlockPair.block[0].inLineOffsetEnd)) {
            final tail = charBlockPair_t();

            makeTailCharBlockFromCharBlock(int editorIdx) {
              CharBlock_t initBlock = charBlockPair.block[editorIdx];
              CharBlock_t sameBlock = sameCharBlockPair.block[editorIdx];

              tail.block[editorIdx] = CharBlock_t.fromData(
                  lineCharStart: initBlock.lineCharStart,
                  lineStrLen: initBlock.lineStrLen,
                  lineIdx: initBlock.lineIdx,
                  inlineBlockStart: sameBlock.inLineOffsetEnd,
                  inlineBlockLen:
                      initBlock.inLineOffsetEnd - sameBlock.inLineOffsetEnd);
              return;
            }

            makeTailCharBlockFromCharBlock(0);
            makeTailCharBlockFromCharBlock(1);

            charBlockStack.add(tail);
          }
        }
      }
    }

    return;
  }

  setDocColorByCharBlockPair(charBlockPair_t blockPair) {
    setDocColorByCharBlock(EditorMgr_t editor, CharBlock_t block) {
      editor.doc.format(block.lineCharStart + block.inlineBlockStart,
          block.inlineBlockLen, colorToAttr(Colors.red.shade100));
      return;
    }

    setDocColorByCharBlock(editor[0], blockPair.block[0]);
    setDocColorByCharBlock(editor[1], blockPair.block[1]);
    return;
  }

  lineBlockPair_t? findMaxSameLineBlock(
      lineBlockPair_t blockPair, List<lineBlockPair_t> blockList) {
    int maxLineCount = 0;

    List<int> charIdx = [blockPair.block[0].charStart, 0];

    var maxBlock = lineBlockPair_t();

    List<int> lineIdx = [0, 0];

    for (lineIdx[0] = blockPair.block[0].lineStart;
        lineIdx[0] < blockPair.block[0].lineEnd;
        lineIdx[0]++) {
      charIdx[1] = blockPair.block[1].charStart;
      for (lineIdx[1] = blockPair.block[1].lineStart;
          lineIdx[1] < blockPair.block[1].lineEnd;
          lineIdx[1]++) {
        int sameLineCount = 0;
        int textLen = 0;

        // 连续的左右相同的块
        List<int> cursor = [lineIdx[0], lineIdx[1]];

        for (;
            (cursor[0] < blockPair.block[0].lineEnd) &&
                (cursor[1] < blockPair.block[1].lineEnd);
            cursor[0]++, cursor[1]++) {
          if (editor[0].lineInfoArr[cursor[0]].text !=
              editor[1].lineInfoArr[cursor[1]].text) {
            break;
          }
          sameLineCount++;
          textLen +=
              editor[0].lineInfoArr[cursor[0]].text.length + 1; // 包括一个换行符"\n"
        }

        if (maxLineCount < sameLineCount) {
          maxLineCount = sameLineCount;
          // maxBlock = block;
          // makeLineBlock(
          //     int charIdx, int textLen, int lineIdxStart, int lineIdxEnd) {
          //   return LineBlock_t.fromData(
          //       charStart: charIdx,
          //       // charIdxEnd: charIdx + textLen,
          //       allLineLen: textLen,
          //       lineStart: lineIdxStart,
          //       // lineIdxEnd: lineIdxEnd,
          //       lineCount: lineIdxEnd - lineIdxStart);
          // }

          makeLineBlock(int editorIdx) {
            maxBlock.block[editorIdx] = LineBlock_t.fromData(
                charStart: charIdx[editorIdx],
                allLineLen: textLen,
                lineStart: lineIdx[editorIdx],
                lineCount: cursor[editorIdx] - lineIdx[editorIdx]);
            return;
          }

          makeLineBlock(0);
          makeLineBlock(1);
        }

        charIdx[1] +=
            editor[1].lineInfoArr[lineIdx[1]].text.length + 1; // 包括一个换行符"\n"
      }

      charIdx[0] +=
          editor[0].lineInfoArr[lineIdx[0]].text.length + 1; // 包括一个换行符"\n"
    }

    if (0 == maxLineCount) {
      return null;
    }
    return maxBlock;
  }

  charBlockPair_t? findMaxSameCharBlockByLineBlock(
      lineBlockPair_t lineBlockPair) {
    int maxCharCount = 0;
    List<int> allCharIdx = [lineBlockPair.block[0].charStart, 0];

    var maxBlock = charBlockPair_t();

    List<int> lineIdx = [0, 0];

    for (lineIdx[0] = lineBlockPair.block[0].lineStart;
        lineIdx[0] < lineBlockPair.block[0].lineEnd;
        lineIdx[0]++) {
      allCharIdx[1] = lineBlockPair.block[1].charStart;

      List<List<int>> line = [editor[0].lineInfoArr[lineIdx[0]].charArr, []];

      for (lineIdx[1] = lineBlockPair.block[1].lineStart;
          lineIdx[1] < lineBlockPair.block[1].lineEnd;
          lineIdx[1]++) {
        line[1] = editor[1].lineInfoArr[lineIdx[1]].charArr;

        // int textLen = 0;

        // 连续的左右相同的块
        List<int> inlineCharIdx = [0, 0];
        for (inlineCharIdx[0] = 0;
            inlineCharIdx[0] < line[0].length;
            inlineCharIdx[0]++) {
          for (inlineCharIdx[1] = 0;
              inlineCharIdx[1] < line[0].length;
              inlineCharIdx[1]++) {
            int sameCharCount = 0;

            List<int> cursor = [inlineCharIdx[0], inlineCharIdx[1]];

            for (;
                (cursor[0] < line[0].length) && (cursor[1] < line[1].length);
                cursor[0]++, cursor[1]++) {
              if (line[0][cursor[0]] != line[1][cursor[1]]) {
                break;
              }
              sameCharCount++;
              // textLen += lineArr1[cursor1].length + 1; // 包括一个换行符"\n"
            }

            if (maxCharCount < sameCharCount) {
              // 首次出现的最大块，也记录一下？

              maxCharCount = sameCharCount;

              makeCharBlockByLineBlock(int editorIdx) {
                maxBlock.block[editorIdx] = CharBlock_t.fromData(
                    lineCharStart: allCharIdx[editorIdx],
                    lineStrLen: line[editorIdx].length,
                    lineIdx: lineIdx[editorIdx],
                    inlineBlockStart: inlineCharIdx[editorIdx],
                    inlineBlockLen:
                        cursor[editorIdx] - inlineCharIdx[editorIdx]);
                return;
              }

              makeCharBlockByLineBlock(0);
              makeCharBlockByLineBlock(1);
            }
          }
        }

        allCharIdx[1] +=
            editor[1].lineInfoArr[lineIdx[1]].charArr.length + 1; // 包括一个换行符"\n"
      }

      allCharIdx[0] +=
          editor[0].lineInfoArr[lineIdx[0]].charArr.length + 1; // 包括一个换行符"\n"
    }

    if (0 == maxCharCount) {
      return null;
    }
    return maxBlock;
  }

  charBlockPair_t? findMaxSameCharBlockByCharBlock(
    // List<List<int>> lineCharArr1,
    // List<List<int>> lineCharArr2,
    charBlockPair_t charBlockPair,
  ) {
    int maxCharCount = 0;
    final maxBlock = charBlockPair_t();
    List<List<int>> line = [
      editor[0].lineInfoArr[charBlockPair.block[0].lineIdx].charArr,
      editor[1].lineInfoArr[charBlockPair.block[1].lineIdx].charArr,
    ];

    // int textLen = 0;

    // 连续的左右相同的块
    List<int> charIdx = [0, 0];
    for (charIdx[0] = charBlockPair.block[0].inlineBlockStart;
        charIdx[0] < charBlockPair.block[0].inLineOffsetEnd;
        charIdx[0]++) {
      for (charIdx[1] = charBlockPair.block[1].inlineBlockStart;
          charIdx[1] < charBlockPair.block[1].inLineOffsetEnd;
          charIdx[1]++) {
        int sameCharCount = 0;

        List<int> cursor = [charIdx[0], charIdx[1]];
        for (;
            (cursor[0] < line[0].length) && (cursor[1] < line[1].length);
            cursor[0]++, cursor[1]++) {
          if (line[0][cursor[0]] != line[1][cursor[1]]) {
            break;
          }
          sameCharCount++;
          // textLen += lineArr1[cursor1].length + 1; // 包括一个换行符"\n"
        }

        if (maxCharCount < sameCharCount) {
          maxCharCount = sameCharCount;

          makeCharBlockFromCharBlock(int editorIdx) {
            CharBlock_t block = charBlockPair.block[editorIdx];

            maxBlock.block[editorIdx] = CharBlock_t.fromData(
                lineCharStart: block.lineCharStart,
                lineStrLen: block.lineStrLen,
                lineIdx: block.lineIdx,
                inlineBlockStart: charIdx[editorIdx],
                inlineBlockLen: sameCharCount);
            return;
          }

          makeCharBlockFromCharBlock(0);
          makeCharBlockFromCharBlock(1);
        }
      }
    }

    if (0 == maxCharCount) {
      return null;
    }
    return maxBlock;
  }

  undo() {
    for (int i = 0; i < 2; i++) {
      if (editor[i].focusNode.hasFocus) {
        editor[i].doc.undo();
        // compare();
        refresh();
        // break;
      }
    }
    return;
  }

  redo() {
    for (int i = 0; i < 2; i++) {
      if (editor[i].focusNode.hasFocus) {
        editor[i].doc.redo();
        refresh();
        // compare();
        // break;
      }
    }
    return;
  }

  String getLine(List<int> allChar, int start, int end) {
    return String.fromCharCodes(allChar.sublist(start, end));
  }

  String getLine_byCharBlock(List<int> allChar, CharBlock_t block) {
    return getLine(allChar, block.lineCharStart, block.lineCharEnd);
  }

  String getRight_byCharBlock(List<int> allChar, CharBlock_t block) {
    return getLine(allChar, block.lineCharStart + block.inlineBlockStart,
        block.lineCharEnd);
  }

  String showCharBlock(List<int> allChar, CharBlock_t block) {
    final line = getLine(allChar, block.lineCharStart, block.lineCharEnd);
    final right = getRight_byCharBlock(allChar, block);

    final leftSpace = List<String>.filled(block.inlineBlockStart, " ").join();

    print(
        "line:${block.lineIdx}:${block.inLineOffsetEnd - block.inlineBlockStart}\n${line}\n${leftSpace}${right}\n");
    return line;
  }

  String getFirstLine_byLineBlock(
      List<int> allChar, List<String> strArr, LineBlock_t block) {
    return getLine(allChar, block.charStart,
        block.charStart + strArr[block.lineStart].length);
  }

  showLine(List<int> allChar, CharBlock_t block) {
    print("line=" + getLine_byCharBlock(allChar, block));
    return;
  }
}
