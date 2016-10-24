---
title: LLDB
tags: [iOSReverse,IOS]
categories: iOSReverse
---
### 查看ASLR偏移

```bash
(lldb) image list -o -f
[  0] 0x00035000 /private/var/db/stash/_.29LMeZ/Applications/MobileNotes.app/MobileNotes(0x0000000000039000)
[  1] 0x00197000 /Library/MobileSubstrate/MobileSubstrate.dylib (0x0000000000197000)
[  2] 0x06db3000 /Users/snakeninny/Library/Developer/Xcode/iOS DeviceSupport/8.1 (12B411)/Symbols/System/Library/Frameworks/QuickLook.framework/QuickLook
……
```

---

### 设置断点

`b function`

`br s –a address`

`br s –a 'ASLROffset+address'`

```
(lldb) br s -a 0x4BE70
Breakpoint 1: where = MobileNotes`___lldb_unnamed_function382$$MobileNotes, address = 0x0004be70
```

当进程停下来之后，可以用“c”命令让进程继续运行。

---

### 断点处运行指令

`(lldb) br com add 1`

执行这条命令后，LLDB会要求我们设置一系列指令，以“DONE”结束，如下:

```
Enter your debugger command(s).  Type 'DONE' to end.
> po [$r0 class]
> p (char *)$r1
> c
> DONE
```

---