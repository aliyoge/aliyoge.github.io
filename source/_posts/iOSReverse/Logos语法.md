---
title: Logos语法
tags: [iOSReverse,IOS]
categories: iOSReverse
---
### %hook

>指定需要hook的class,必须以％end结尾。

```Objective-C
// hook SpringBoard类里面的_menuButtonDown函数,先打印一句话,再之子那个函数原始的操作
%hook SpringBorad
- (void)_menuButtonDown:(id)down
{
    NSLog(@"111111");
   %orig; // 调用原始的_menuButtonDown函数
}
%end
```

---
### %log

>该指令在%hook内部使用，将函数的类名、参数等信息写入syslog,可以％log([(),…..])的格式追加其他打印信息。

```Objective-C
%hook SpringBorad
- (void)_menuButtonDown:(id)down
{
    %log((NSString *)@"iosre",(NSString *)@"Debug");
    %orig; // 调用原始的_menuButtonDown方法
}
%end
```

---
### %orig

>该指令在%hook内部使用，执行被hook的函数的原始代码；也可以用％orig更改原始函数的参数。

```Objective-C
%hook SpringBorad
- (void)setCustomSubtitleText:(id)arg1 withColor:   (id)arg2
{
    %orig(@"change arg2",arg2);// 将arg2的参数修 改为"change arg2"
}
%end
```

---
### %group

>该指令用于将%hook分组，便于代码管理及按条件初始化分组，必须以%end结尾。 
一个％group可以包含多个%hook,所有不属于某个自定义group的％hook会被隐式归类到％group_ungrouped中。

```Objective-C
/*
在%group iOS7Hook中钩住iOS7Class的iOS7Method,在%group iOS8Class中钩住iOS8Method函数,然后在%group _ungroup中钩住SpringBoard类的powerDown函数.
*/
%group iOS7Hook
%hook iOS7Class
- (id)ios7Method
{
    id result = %orig;
    NSLog(@"这个方法只有iOS7适用");
    return result;
}
%end
%end // iOS7Method

%group iOS8Hook
%hook iOS8Class
- (id)ios8Method
{
    id result = %orig;
    NSLog(@"这个方法只有iOS7适用");
    return result;
}
%end
%end // iOS8Method

%hook SpringBoard
- (void)powerDown
{
     %orig;
}
%end
```

---
### %init

>该指令用于初始化某个％group，必须在%hook或％ctor内调用；如果带参数，则初始化指定的group，如果不带参数，则初始化_ungrouped. 
注： 
切记，只有调用了％init,对应的%group才能起作用！

```Objective-C
#ifndef KCFCoreFoundationVersionNumber_iOS_8_0
#define KCFCoreFoundationVersionNumber_iOS_8_0      1140.10
#endif

- (void)applicationDidFinishLaunching:(UIApplication    *)application
{
    %orig;

    %init; // Equals to init(_ungrouped)

    if (KCFCoreFoundationVersionNumber >=   KCFCoreFoundationVersionNumber_iOS_7_0 &&   KCFCoreFoundationVersionNumber >    KCFCoreFoundationVersionNumber_iOS_8_0)
        %init(iOS7Hook);
    if (KCFCoreFoundationVersionNumber >= KCFCoreFoundationVersionNumber_iOS_8_0)
        %init(iOS8Hook);
}
%end
```

---
### %ctor

>tweak的constructor,完成初始化工作；如果不显示定义，Theos会自动生成一个%ctor,并在其中调用%init(_ungrouped)。%ctor一般可以用来初始化%group,以及进行MSHookFunction等操作,如下:

```Objective-C
#ifndef KCFCoreFoundationVersionNumber_iOS_8_0
#define KCFCoreFoundationVersionNumber_iOS_8_0      1140.10
#endif

%ctor
{
    %init;

    if (KCFCoreFoundationVersionNumber >= KCFCoreFoundationVersionNumber_iOS_7_0 && KCFCoreFoundationVersionNumber > KCFCoreFoundationVersionNumber_iOS_8_0)
    %init(iOS7Hook);
    if (KCFCoreFoundationVersionNumber >= KCFCoreFoundationVersionNumber_iOS_8_0)
    %init(iOS8Hook);
    MSHookFunction((void *)&AudioServicesPlaySystemSound,(void *)&replaced_AudioServerPlaySystemSound,(void **)&orginal_AudioServicesPlaySystemSound);
}
```

---
### %new

>在%hook内部使用，给一个现有class添加新函数，功能与class_addMethod相同.
>
>注： 
Objective-C的category与class_addMethod的区别： 
前者是静态的而后者是动态的。使用%new添加,而不需要向.h文件中添加函数声明,如果使用category,可能与遇到这样那样的错误.

```Objective-C 
%hook SpringBoard
%new
- (void)addNewMethod
{
    NSLog(@"动态添加一个方法到SpringBoard");
}
%end
```

---
### %c 

>该指令的作用等同于objc_getClass或NSClassFromString,即动态获取一个类的定义，在%hook或％ctor内使用 。 动态获取一个类,如果用’+’标记,则获取类的对象,如果用’-’标记则获取实例对象,默认是’-’

---
### %property

>Add a property to a %subclass just like you would with @property to a normal Objective-C subclass as well as adding new properties to existing classes within %hook.

```Objective-C 
%property (nonatomic|assign|retain|copy|weak|strong|getter|setter) Type name;
```

---
### %subclass

>Subclass block - the class is created at runtime and populated with methods. ivars are not yet supported (use associated objects). The %new specifier is needed for a method that doesn't exist in the superclass. To instantiate an object of the new class, you can use the %c operator.
>
>Can be inside a %group block.

```Objective-C 
%subclass MyObject : NSObject

- (id)init {
    self = %orig;
    [self setSomeValue:@"value"];
    return self;
}

//the following two new methods act as `@property (nonatomic, retain) id someValue;`
%new
- (id)someValue {
    return objc_getAssociatedObject(self, @selector(someValue));
}

%new
- (void)setSomeValue:(id)value {
    objc_setAssociatedObject(self, @selector(someValue), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%end

%ctor {
    MyObject *myObject = [[%c(MyObject) alloc] init];
    NSLog(@"myObject: %@", [myObject someValue]);
}
```