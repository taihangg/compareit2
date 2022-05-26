# compareit2
看到一个富文本插件flutter_quill，就想写一个文本比较工具玩玩。

基本算法打通了：
想法比较简单粗暴，就是找最大的子块，先是以行为单位，满足不了行的区域就在行内以字为基本单位去匹配。不是网上的那个文本比较算法。

对编辑的支持还没写完，EditorMgr_t.onReplaceText方法需要进一步完善。

![例图](https://github.com/taihangg/compareit2/blob/main/img/img1.png)

TODO：
快捷键操作
复制块/行到对侧
保存
编辑回退
下一处差异
目录比较

现在不想写了，有兴趣的可以接着玩。
