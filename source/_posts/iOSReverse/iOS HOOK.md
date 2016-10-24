---
title: iOS HOOK
tags: [iOSReverse,IOS]
categories: iOSReverse
---
### 1.CydiaSubstrate Hook 

>CydiaSubstrate，iOS7越狱之前名为 MobileSubstrate（简称为MS或MS框架），作者为大名鼎鼎的Jay Freeman(saurik)。

在用`theos`开发中，`control`文件中的depend字段依赖库为`mobilesubstrate`，该工具实现CydiaSubstrate注入的关键所在，整个工具主要分为`MobileHooker`、`MobileLoader`以及`Safe mode`三部分。

`MobileHooker`，是`CydiaSubstrate`的一个组件，对`C`和`Objective-C`均有效。

`MobileHooker`组件主要提供了`MSHookMessageEx`和`MSHookFunction`两个函数针对不同语言的`inline hook`功能，其中`MSHookMessageEx`负责用来hook `Objective-C`函数，`MSHookFunction`负责用来hook `C/C++`函数。

`MSHookMessageEx`对于ObjC函数采用的也是`method swizzle`的方法，主要是Objetive-C的runtime机制，可以在ObjC方法时动态采用`class_replaceMethod`等runtime函数替换其实现。`MSHookFunction`对于C函数是在函数的开头修改了汇编指令，使其跳转到新的实现，执行完成后再返回执行原指令。

#### 1.1MSHookMessageEx函数 
MSHookMessageEx函数的作用对象是Objective-C函数，其原理是调用Objective-C中高等级的运行时函数API:`class_getInstanceMethod`、`method_setImplementation`、`method_exchangeImplementations`等来替换原函数的逻辑，比如`method_exchangeImplementations`函数在Objective-C官方文档中描述的作用便是交换两个函数的实现，其内部的调用逻辑类似于：

```Objective-C
IMP imp1 = method_getImplementation(m1);
IMP imp2 = method_getImplementation(m2);
method_setImplementation(m1, imp2);
method_setImplementation(m2, imp1);
```

因此，MSHookMessageEx就是利用Objective-C中运行时的API来替换原函数逻辑。

**MSHookMessageEx函数的使用方法，在CydiaSubstrate官网中该函数的描述如下：**

```Objective-C
void MSHookMessageEx(Class _class, SEL message, IMP hook, IMP *old);
```

>其中第一个参数_class为要Hook的Objective-C函数的类名；第二个参数message为要Hook的Objective-C函数的message；第三个参数hook为hook后新的对应该message的执行逻辑，即替换后的函数地址；第四个参数old为对应该message的原函数的地址，若无需调用原函数则该参数可以设为NULL。其官方的使用方法如下：

```Objective-C
NSString *(*oldDescription)(id self, SEL _cmd);

// implicit self and _cmd are explicit with IMP ABI
NSString *newDescription(id self, SEL _cmd) {
    NSString *description = (*oldDescription)(self, _cmd);
    description = [description stringByAppendingString:@"!"];
    return description;
}

MSHookMessageEx(
    [NSObject class], @selector(description),
    &newDescription, &oldDescription
);
```

以上的代码首先创建指针oldDescription用于保存原来的NSString类description方法的地址，随后实现了新的description方法，最后调用MSHookMessageEx函数来替换原来的description方法。

第一个参数为[NSObject class]类，第二个参数为方法description的message，第三个参数为替换后新的description方法地址，第四个参数为description方法的原地址。

按照官网的示例可以在Tweak工程的Tweak.xm源文件中调用MSHookMessageEx函数来hook想要hook的方法，也可以使用Logos语法来hook相关函数，实际上Logos语法只是对MSHookMessageEx函数进行了封装，实际上其调用的还是MSHookMessageEx函数。[官方链接](http://www.cydiasubstrate.com/api/c/MSHookMessageEx/)

#### 1.2MSHookFunction函数
`MSHookFunction`函数的作用对象是C/C++函数，因为C/C++并不提供`runtime`这种高级的API来直接替换方法实现，因此实现Hook要更加困难一些。MSHookFunction实现Hook采用的是在内存中写入汇编指令来达到目的：简单说来就是首先修改要Hook函数的前N个字节的内存，使其跳转到替换后的函数头，这样就能执行自己的代码；同时会保存原函数的前N个字节的内容以便执行完自己的逻辑后能正确执行原函数的逻辑。具体的汇编实现可以参考这篇[分析文章](http://bbs.pediy.com/showthread.php?t=185014)。

**MSHookFunction的使用方法，在CydiaSubstrate官网中函数的描述如下：**

```Objective-C
void MSHookFunction(void *symbol, void *hook, void **old);
```

>其中第一个参数为所要Hook的函数地址，值得注意的是该地址不一定限于函数头，也可以是函数内部的任一代码地址；第二个参数为Hook后要替换的函数地址；第三个参数为指向Hook地址的指针，用来保存被Hook函数替换掉的汇编指令方便执行完自己的代码逻辑后能够继续执行原函数的逻辑，若不需要调用原函数，则此处可以设为“NULL”。MSHookFunction官方给出的使用方法如下：

```C
void *(*oldConnect)(int, const sockaddr *, socklen_t);

void *newConnect(
    int socket, const sockaddr *address, socklen_t length
) {
    if (address->sa_family == AF_INET) {
        sockaddr_in *address_in = address;
        if (address_in->sin_port == htons(6667)) {
            sockaddr_in copy = *address_in;
            address_in->sin_port = htons(7001);
            return oldConnect(socket, &copy, length);
        }
    }

    return oldConnect(socket, address, length);
}

MSHookFunction(&connect, &newConnect, &oldConnect);
```

这段代码首先定义了一个名为oldConnect的指针用于保存要Hook函数被替换的指令；然后实现了新的newConnect方法，即Hook后实际想要执行的代码逻辑；最后使用MSHookFunction来对目标函数进行Hook。

第一个参数为原方法connect的地址，第二个参数为实现的新方法地址，第三个参数为用于保存connect被替换的汇编指令的地址。其中“&connect”是`MSHookFunction`内部调用了CydiaSubstrate的另一个`MSFindSymbol`函数来实现根据函数名查找其函数地址，更多的`MSHookFunction`实现原理可以参考[以下链接](http://www.cydiasubstrate.com/api/c/MSHookFunction/)。

#### 1.3MobileLoader 
该组件的作用是让应用程序加载第三方的dylib，theos工程编译后生成的dylib就需要MobileLoader组件来加载。

MobileLoader的原理主要是在系统启动时由launchd进程将MobileLoader加载进内存，随后MobileLoader会利用`DYLD_INSERT_LIBRARIES`环境变量将自己加载进设备的各个进程中，并会遍历`/Library/MobileSubstrate/DynamicLibraries/`目录下的文件，根据和每个dylib同名的plist文件来确定该dylib的作用范围，若当前进程满足该作用范围，则会使用`dlopen`函数动态加载对应的`dylib`。

比如实验设备/Library/MobileSubstrate/DynamicLibraries/目录下便可已看到以下文件：

```bash
XXXX-iPhone:~ root# ls /Library/MobileSubstrate/DynamicLibraries/
MobileSafety.dylib  MobileSafety.plist test.dylib  test.plist
```

其中test.plist文件便是plist工程配置文件，MobileLoader读取该文件内容如下：

```bash
XXXX-iPhone:~ root# cat /Library/MobileSubstrate/DynamicLibraries/test.plist
{
Filter = {
Bundles = (
"com.apple.springboard",
);
};
```

即进程`Bundles`为`com.apple.springboard`时便会加载对应的`test.dylib`。值得注意的是，MobileLoader加载完每个dylib后会首先调用dylib中用`__attribute__((constructor))`声明的入口函数，官网给出的示例代码如下：

```C
__attribute__((constructor))
static void initialize() {
  NSLog(@"MyExt: Loaded");
  MSHookFunction(CFShow, replaced_CFShow, &original_CFShow);
}
```

以上代码便用`__attribute__((constructor))`声明了入口函数initialize()，MobileLoader加载完该dylib后便会调用initialize()方法打印log并使用MSHookFunction Hook CFShow函数。之前的demo中并未用`__attribute__((constructor))`声明是因为Logos语法中%hook便封装了该声明，因此会直接进行hook操作。

#### 1.4SafeMode 
注入别的进程并改变其逻辑一定存在风险，难免会造成程序崩溃的现象，如果崩溃的是SpringBoard等系统进程，则会造成系统瘫痪。为了避免这类情况，SafeMode会捕获`SIGABRT、SIGILL、SIGBUS、SIGSEGV、SIGSYS`这几种信号，捕获到目标信号后SafeMode会使设备进入安全模式，在安全模式下所有第三方插件(即dylib)都会被禁用，便于修复系统。

### 2.fishhook

>对C函数有效，对Objective-C不知道是否有效。

fishhook的原理是替换mach-o里的符号表，符号表的作用可以简单理解成，代码在执行到一个函数符号时，不知道这个符号对应的函数实现在内存的哪个地址，需要去一个表里查找这个地址。如果你更改了这个地址，那么函数实现就被改变了。

### 3.method swizzle

>仅针对Objective-C方法有效。

method swizzle的原理主要是Objetive-C的runtime机制，可以在ObjC方法时动态采用class_replaceMethod等runtime函数替换其实现。