enum BlockType_e { unknown, diff, same }

class LineBlock_t {
  // 多行块
  int lineStart; // 开始行的索引
  int lineCount;

  int charStart; // 首行开始字符在doc中的索引，用于着色
  int allLineLen; // 所有字符长度，包括换行符，以及最后一行的换行符

  LineBlock_t(
      {this.lineStart = 0,
      this.lineCount = 0,
      this.charStart = 0,
      this.allLineLen = 0});

  LineBlock_t.fromData(
      {required this.lineStart,
      required this.lineCount,
      required this.charStart,
      required this.allLineLen});

  int get charEnd => (charStart + allLineLen);
  int get lineEnd => (lineStart + lineCount);

  @override
  String toString() {
    return """lineBlock_t {
    lineIdxStart : ${lineStart},
    lineCount : ${lineCount},
    charIdxStart : ${charStart},
    allLineLen : ${allLineLen},
}""";
  }
}

class lineBlockPair_t {
  BlockType_e type = BlockType_e.unknown;
  List<LineBlock_t> block = [LineBlock_t(), LineBlock_t()];

  @override
  String toString() {
    return """blockPairInfo_t {
    type : ${type},
    block[0] : ${block[0]},
    block[1] : ${block[1]},
}""";
  }
}

// class Line_t {
//   String text;
//   int idx;
//   int charStart;
//   int strLen;
//
//   Line_t({
//     this.text = "",
//     this.idx = 0,
//     this.charStart = 0,
//     this.strLen = 0,
//   });
// }

class CharBlock_t {
  // 行内字符块描述

  int lineIdx; // 行索引
  int lineCharStart; // 行开始字符在doc中的索引，用于着色
  int lineStrLen; // 行长度，不包括本行的换行符

  int inlineBlockStart; // 行内偏移，不是全局
  int inlineBlockLen; // 行内相同块的长度

  CharBlock_t(
      {this.lineIdx = 0,
      this.lineCharStart = 0,
      this.lineStrLen = 0,
      this.inlineBlockStart = 0,
      this.inlineBlockLen = 0});

  CharBlock_t.fromData(
      {required this.lineCharStart,
      required this.lineStrLen,
      required this.lineIdx,
      required this.inlineBlockStart,
      required this.inlineBlockLen});

  int get lineCharEnd => (lineCharStart + lineStrLen); // 行结束符的全局索引
  int get inLineOffsetEnd => (inlineBlockStart + inlineBlockLen);

  @override
  String toString() {
    return """charBlock_t {
    lineIdx : ${lineIdx},
    lineCharStart : ${lineCharStart},
    lineCharEnd : ${lineCharEnd},
    inlineBlockStart : ${inlineBlockStart},
    inlineBlockLen : ${inlineBlockLen},
}""";
    // return "charIdx : ${charIdx}, lineStart : ${lineStart}, lineEnd : ${lineEnd}, strLen: ${strLen}";
  }
}

class charBlockPair_t {
  List<CharBlock_t> block = [CharBlock_t(), CharBlock_t()];

  @override
  String toString() {
    return """charBlockPair_t {
    block[0] : ${block[0]},
    block[1] : ${block[1]},
}""";
  }
}

class AlignmentBlock_t {
  int lineStart;
  int lineCount;

  int charStart;
  int allLineLen; // 包括最后一行的换行符

  int get lineEnd => (lineStart + lineCount);
  int get charEnd => (charStart + allLineLen);

  AlignmentBlock_t(
      {this.lineStart = 0,
      this.lineCount = 0,
      this.charStart = 0,
      this.allLineLen = 0});

  AlignmentBlock_t.fromLineBlock(LineBlock_t lineBlock)
      : this.lineStart = lineBlock.lineStart,
        this.lineCount = lineBlock.lineCount,
        this.charStart = lineBlock.charStart,
        this.allLineLen = lineBlock.allLineLen {}

  AlignmentBlock_t.fromCharBlock(CharBlock_t charBlock)
      : this.lineStart = charBlock.lineIdx,
        this.lineCount = 1,
        this.charStart = charBlock.lineCharStart,
        this.allLineLen = charBlock.lineStrLen + 1 // 加上换行符
  {}

  @override
  String toString() {
    return "AlignmentBlock_t { ${lineCount} [ ${lineStart} : ${lineEnd} ] }";
  }
}

class AlignmentBlockPair_t {
  BlockType_e type = BlockType_e.unknown;
  List<AlignmentBlock_t> block = [AlignmentBlock_t(), AlignmentBlock_t()];

  AlignmentBlockPair_t();

  AlignmentBlockPair_t.fromLineBlockPair(
      lineBlockPair_t pair, BlockType_e type) {
    this.block[0] = AlignmentBlock_t.fromLineBlock(pair.block[0]);
    this.block[1] = AlignmentBlock_t.fromLineBlock(pair.block[1]);
    this.type = type;
    return;
  }

  AlignmentBlockPair_t.fromCharBlockPair(
      charBlockPair_t lineCharPair, BlockType_e type) {
    this.block[0] = AlignmentBlock_t.fromCharBlock(lineCharPair.block[0]);
    this.block[1] = AlignmentBlock_t.fromCharBlock(lineCharPair.block[1]);
    this.type = type;
    return;
  }

  @override
  String toString() {
    return "AlignmentBlockPair_t { type : ${type}, "
        "block[0] : ${block[0]}, block[1] : ${block[1]} }";
  }
}

enum AnchorType_e { noAnchor, single, paired }

class Anchor_t {
  int lineIdx;
  AnchorType_e type;
  Anchor_t([this.lineIdx = 0, this.type = AnchorType_e.noAnchor]);
}

class AnchorPair_t {
  List<Anchor_t> anchor = [Anchor_t(), Anchor_t()];
}

class LineInfo_t {
  // 用于显示的行信息

  String text = ""; // 文本行，不包括换行符
  List<int> charArr;
  // int lineIdx = 0; // 需要吗?
  // int charStart = 0; // 起始字符在全文件中的索引

  // int lineStart = 0; // 需要吗?
  // int lineCount = 0;

  BlockType_e diffType = BlockType_e.diff;

  int showingLineCount = 1; // 显示出来的行数
  int headVirtualLineCount = 0; // 为了对齐效果，在(首部/末尾)添加的虚拟行的数量

  AnchorType_e anchorType = AnchorType_e.noAnchor;

  List<InlineBlockInfo_t> inlineSameBlockList =
      []; // 单行行内相同块信息，blockType 为 diff 时需要；

  LineInfo_t(this.text,
      [this.showingLineCount = 1, this.diffType = BlockType_e.diff])
      : charArr = text.codeUnits;

  reinit(int showingLineCount) {
    this.showingLineCount = showingLineCount;
    this.headVirtualLineCount = 0;
    this.diffType = BlockType_e.unknown;
    this.inlineSameBlockList = [];
    return;
  }
}

class InlineBlockInfo_t {
  int start;
  int len;
  InlineBlockInfo_t({this.start = 0, this.len = 0});
}

class PosInfo_t {
  int pos = -1;
  bool cover = false;
}

enum EditCursorType_e {
  unknown,
  virtual, // 虚拟行
  real, // 实际文本行
}
