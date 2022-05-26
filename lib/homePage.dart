import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'editorMgr.dart';
// import 'boundingTextSize.dart';
import 'compareMgr.dart';

// 可运行第一版

class homePage extends StatefulWidget {
  homePage() {
    return;
  }

  @override
  homePageState createState() => homePageState();
}

class homePageState extends State<homePage> {
  final CompareMgr cmpMgr = CompareMgr();
  bool initCmpMgr = false;

  @override
  void initState() {
    super.initState();

    return;
  }

  @override
  void dispose() {
    super.dispose();
    return;
  }

  reloadAllFiles() {
    cmpMgr.editor[0].loadFile();
    cmpMgr.editor[1].loadFile();

    if ((null != cmpMgr.editor[0].path) && (null != cmpMgr.editor[1].path)) {
      cmpMgr.compare();
    } else {
      setState(() {});
    }

    // if (mounted) {
    //   setState(() {});
    // }
    return;
  }

  pickFile0() async {
    doPickFile(0);
    return;

    // try {
    //   FilePickerResult? result = await FilePicker.platform.pickFiles();
    //   if (null != result) {
    //     // File file = File(result.files.single.path!);
    //     cmpMgr.editorArr[0].path = result.files.single.path;
    //     cmpMgr.editorArr[0].loadFile();
    //     if (null != cmpMgr.editorArr[1].path) {
    //       cmpMgr.compare();
    //     } else {
    //       setState(() {});
    //     }
    //   } else {
    //     // User canceled the picker
    //   }
    // } on PlatformException catch (e) {
    //   print("不支持的操作：" + e.toString());
    // } catch (ex) {
    //   print(ex);
    // }
    // return;
  }

  pickFile1() async {
    doPickFile(1);
    return;

    // try {
    //   FilePickerResult? result = await FilePicker.platform.pickFiles();
    //   if (null != result) {
    //     // File file = File(result.files.single.path!);
    //     cmpMgr.mgr2.path = result.files.single.path;
    //     cmpMgr.mgr2.loadFile();
    //     if (null != cmpMgr.mgr1.path) {
    //       cmpMgr.compare();
    //     } else {
    //       setState(() {});
    //     }
    //   } else {
    //     // User canceled the picker
    //   }
    // } on PlatformException catch (e) {
    //   print("不支持的操作：" + e.toString());
    // } catch (ex) {
    //   print(ex);
    // }
    // return;
  }

  doPickFile(int editorIdx) async {
    // String? path;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (null != result) {
        // File file = File(result.files.single.path!);
        cmpMgr.editor[editorIdx].path = result.files.single.path;
        cmpMgr.editor[editorIdx].loadFile();
        if (null != cmpMgr.editor[editorIdx ^ 1].path) {
          cmpMgr.compare();
        } else {
          setState(() {});
        }
      } else {
        // User canceled the picker
      }
    } on PlatformException catch (e) {
      print("不支持的操作：" + e.toString());
    } catch (ex) {
      print(ex);
    }
    return;
  }

  Widget makeButton_openFile(Function() _onPressed, String title) {
    // 带框按钮
    return TextButton.icon(
      onPressed: _onPressed,
      icon: Icon(Icons.file_open),
      label: Text(title),
      style: ButtonStyle(
          // shadowColor: MaterialStateProperty.all(Colors.blue),
          side: MaterialStateProperty.all(BorderSide(color: Colors.orange))),
    );
  }

  Widget makeButton_reload() {
    // 带框按钮
    return TextButton.icon(
      onPressed: () {
        reloadAllFiles();

        // setState(() {});
        return;
      },
      icon: Icon(Icons.file_copy_outlined),
      label: Text("(F3) 重新加载文件"),
      style: ButtonStyle(
        // shadowColor: MaterialStateProperty.all(Colors.blue),
        side: MaterialStateProperty.all(
          BorderSide(
            color: Colors.orange,
            // width: 4,
          ),
        ),
      ),
    );
  }

  Widget makeButton_recompare() {
    // 带框按钮
    return TextButton.icon(
      onPressed: () {
        cmpMgr.compare();
        // setState(() {});
        return;
      },
      icon: Icon(Icons.refresh_outlined),
      label: Text("(F5) 重新比较"),
      style: ButtonStyle(
        // shadowColor: MaterialStateProperty.all(Colors.blue),
        side: MaterialStateProperty.all(
          BorderSide(
            color: Colors.orange,
            // width: 4,
          ),
        ),
      ),
    );
  }

  Widget makeButton_clearAnchor() {
    return TextButton.icon(
      onPressed: () {
        cmpMgr.clearAllAnchor();
        cmpMgr.compare();
        // setState(() {});
        return;
      },
      icon: Icon(Icons.cleaning_services_rounded),
      label: Text("清除所有手动对齐"),
      style: ButtonStyle(
        // shadowColor: MaterialStateProperty.all(Colors.blue),
        side: MaterialStateProperty.all(
          BorderSide(
            color: Colors.orange,
            // width: 4,
          ),
        ),
      ),
    );
  }

  Widget makeToolBar() {
    return Container(
        child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Spacer(),
        SizedBox(width: 5),
        makeButton_openFile(pickFile0, "打开文件1"),
        Spacer(),
        makeButton_reload(),
        SizedBox(width: 5.0),
        makeButton_recompare(),
        SizedBox(width: 5.0),
        makeButton_clearAnchor(),
        SizedBox(width: 5.0),
        makeButton_openFile(pickFile1, "打开文件2"),
        Spacer(),
      ],
    ));
  }

  Widget makeLineNum(ScrollController ctrl) {
    return Expanded(
      child: Container(
        child: ListView.builder(
          controller: ctrl,
          itemBuilder: (BuildContext context, int index) {
            return Text("${index + 1}");
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // compare();
    if (false == initCmpMgr) {
      initCmpMgr = true;
      cmpMgr.initRuntimeData(context, () {
        if (mounted) {
          setState(() {});
        }
        return;
      });
    }

    Widget child = Column(children: [
      makeToolBar(),
      Divider(),
      cmpMgr.buildEditorPair(),
    ]);

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.f3): Reload(),
        LogicalKeySet(LogicalKeyboardKey.f5): Recompare(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
            Undo(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift,
            LogicalKeyboardKey.keyZ): Redo(),
      },
      child: Actions(
        actions: {
          Reload:
              CallbackAction<Reload>(onInvoke: (intent) => reloadAllFiles()),
          Recompare:
              CallbackAction<Recompare>(onInvoke: (intent) => cmpMgr.compare()),
          Undo: CallbackAction<Undo>(onInvoke: (intent) => cmpMgr.undo()),
          Redo: CallbackAction<Recompare>(onInvoke: (intent) => cmpMgr.redo()),
        },
        child: child,
      ),
    );
  }
}

class Reload extends Intent {}

class Recompare extends Intent {}

class Undo extends Intent {}

class Redo extends Intent {}
