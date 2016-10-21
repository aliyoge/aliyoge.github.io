---
title: Objective-C源码学习
notebook: IOSReverse
tags: [IOSReverse,Objective-C,IOS]
categories: IOSReverse
---

## 1.理解NSObject和元类

#### 1.1 在OC中的对象和类是什么

1. 对象是在objc.h中定义的

```objectivec
/// An opaque type that represents an C class.
typedef struct objc_class *Class;

/// Represents an instance of a class.
struct objc_object {
    Class isa  OBJC_ISA_AVAILABILITY;
};
```

2. 类是在runtime.h中定义的

```objectivec
struct objc_class {
    Class isa  OBJC_ISA_AVAILABILITY;

#if !__OBJC2__
    Class super_class                                        OBJC2_UNAVAILABLE;
    const char *name                                         OBJC2_UNAVAILABLE;
    long version                                             OBJC2_UNAVAILABLE;
    long info                                                OBJC2_UNAVAILABLE;
    long instance_size                                       OBJC2_UNAVAILABLE;
    struct objc_ivar_list *ivars                             OBJC2_UNAVAILABLE;
    struct objc_method_list **methodLists                    OBJC2_UNAVAILABLE;
    struct objc_cache *cache                                 OBJC2_UNAVAILABLE;
    struct objc_protocol_list *protocols                     OBJC2_UNAVAILABLE;
#endif

} OBJC2_UNAVAILABLE;
/* Use `Class` instead of `struct objc_class *` */
```

>OC中的类和对象在源码中都是用结构体表示的。
>本质上类并不是C语言中的类，它也是对象，也是某个类的实例，这个类称之为元类(metaclass)。
>元类也是对象，也是某个类的实例，这个类叫根元类(root metaclass)。
>所有元类所属类是同一个根元类。
>根元类也是元类，所以它所属的类也是根元类，也就是它本身。
>根元类指的就是根类(rootclass)的元类。
>在C中有两个根类(rootclass)，一个是NSObject，一个是NSProxy。

#### 1.2 isa指针和super_Class指针

```bash
                            nil
                             ^
                             |
                             |
                  isa   (NSObject)      isa                      isa
rootclass实例   ++++++> rootclass类   ++++++> rootclass元类  <<+++++++
                             ^   ^             |   ^              +  +
                             |   |             |   |              +  +
                             |   ---------------   |              +  +
                  isa   (FatherClass)   isa                       +  +
fatherclass实例 ++++++> fatherclass类 ++++++> fatherclass元类 ++++++   +
                             ^                     ^                 +
                             |                     |                 +
                             |                     |                 +
                  isa   (SubClass)      isa                          +
subclass实例    ++++++> subclass类    ++++++> subclass元类    ++++++++
```

**我的理解**

rootclass元类实际上是objc_class结构体对象。当创建其subclass元类时，objc内部是将父类结构体中保存的方法，
拷贝一份到新创建的objc_class结构提对象，此结构体对象的super_Class指针指向父类，所有子元类的isa指针都
指向rootclass的元类(根元类)。根元类的isa指针指向自己。比较特殊的是：**根元类的super_Class指针指向根类。**

而元类创建类的时候，类的类方法保存在元类中，实例方法保存在自己的类中。也都是用结构体记录。子类方法的
isa指针指向元类，super_class指针父类。根类的super_Class指针为nil。

实例类型是objc_object结构体，只有isa指针，没有super_Class指针。

## 2.Runtime中常用名词

#### 2.1 SEL
 
```objectivec
typedef struct objc_selector *SEL;
```

>源码中没能直接找到objc_selector的定义，但是从书籍是了解到可以将SEL理解为char*指针。
>如果我们包含函数`-(int)test{return 1;}`，然后打印`NSLog(@"SEL = %s",@selector(test));`
>我们将会得到输出是:`SEL = test`
>所以猜测`struct objc_selector`的定义为：

```objectivec
struct objc_selector {
    char name[64 or ...]
    ...
}
```

>它是objc_msgSend函数的第二个参数。在OC中用`selector`表示(Swift中是`Selector`类)
>获取SEL方法选择器：

```objectivec
//使用Objc编译器命令@selector
SEL sel = @selector(whatMethod)

//使用Runtime系统的sel_registerName函数
SEL sel = sel_registerName("whatMethod")

//使用OC方法
SEL sel = NSSelectorFromString(@"whatMethod")
```

#### 2.2 id

```objectivec
typedef struct objc_object *id;
```

#### 2.3 IMP

smalltalk是动态语言的鼻祖，更是OC发展的最大推动力。在smalltalk中，所有的东西都是对象（或者都应该被当做对象），例如表达式2 + 3被理解成向对象2发送了消息+，其中接收的参数是 3

```objectivec
typedef id (*IMP)(id, SEL, ...);
```

>它就是一个函数指针，是有编译器生成的。指向了方法的实现。
>`IMP`跟`block`是非常相似的东西，`IMP`可以看做是一个特殊的`block`，同样的系统提供了两者相互转换的方法：`imp_implementationWithBlock`和`imp_getBlock`。

```objectivec
+ (void)initialize
    void (^requestBlock)(id object, SEL aSelector, id URL, id parameters) = 
        ^(id object, SEL aSelector, id URL, id parameters) {
        // do some networking request
    };
    IMP requestIMP = imp_implementationWithBlock(requestBlock);
    class_addMethod([self class], @selector(networkReuqest:parameters:), requestIMP, "v@:@@");
}

// View controller
[self performSelector: @selector(networkReuqest:parameters:) withObject: URL withObject: parameters];
```

上面这段代码会crash的非常无厘头，提示EXC_BAD_ACCESS错误。因为block参数不能存在SEL!!去掉`SEL aSelector`这个参数就OK了。

#### 2.4 Method

```objectivec
typedef struct objc_method *Method;
```

>在`objc_method`中存储了方法名，方法类型和方法实现。

```objectivec
/**
method_name: 方法的名字，通常我们使用@selector()的方式获取一个方法的SEL地址，这个被用来进行散列计算存储方法的IMP实现。由于SEL类型采用了散列的算法，因此如果同一个类中存在同样名字的方法，那么就会导致方法的IMP地址无法唯一化。这也是苹果不允许同名不同参数类型的方法存在的原因。
method_type: 每一种数据类型有着自己对应的字符编码，method_type表示方法返回值、参数的字符编码，比如-(void)playWith:(id)的字符编码为v@:@。
*/
struct objc_method {
    SEL method_name                                          OBJC2_UNAVAILABLE;
    char *method_types                                       OBJC2_UNAVAILABLE;
    IMP method_imp                                           OBJC2_UNAVAILABLE;
}                                                            OBJC2_UNAVAILABLE;
```

#### 2.5 Ivar 

```objectivec
typedef struct objc_ivar *Ivar;
```

>`Ivar`代表类中的实例变量。

```objectivec
struct objc_ivar {
    char *ivar_name                                          OBJC2_UNAVAILABLE;
    char *ivar_type                                          OBJC2_UNAVAILABLE;
    int ivar_offset                                          OBJC2_UNAVAILABLE;
#ifdef __LP64__
    int space                                                OBJC2_UNAVAILABLE;
#endif
}                                                            OBJC2_UNAVAILABLE;
```

#### 2.6 Property

```objectivec
typedef struct objc_property *Property;
typedef struct objc_property *objc_property_t;//这个更常用
```

>`@property`标记了类中的属性，是指向`objc_property`结构体的指针。

```objectivec
struct objc_property {
    const char *name;
    const char *attributes;
};
```

#### 2.7 Cache

```objectivec
typedef struct objc_cache *Cache
```

>Cache为方法调用的性能进行优化。

```objectivec
struct objc_cache {
    unsigned int mask /* total = mask + 1 */                 OBJC2_UNAVAILABLE;
    unsigned int occupied                                    OBJC2_UNAVAILABLE;
    Method buckets[1]                                        OBJC2_UNAVAILABLE;
};
```

## 3.Runtime中方法使用

#### 3.1 交换两个方法实现

```objectivec
//获取某个类的类方法
Method class_getClassMethod(Class cls , SEL name)

//获取某个类的实例方法
Method class_getInstanceMethod(Class cls , SEL name)

//交换两个方法的实现
void method_exchangeImplementations(Method m1 , Method m2)
```

**实例**

**交换类方法**

```objectivec
Method m1 = class_getClassMethod([SomeClass class], @selector(method1))
Method m2 = class_getClassMethod([SomeClass class], @selector(method2))

method_exchangeImplementations(m1, m2)
```

**拦截系统方法**

1、为UIImage创建分类，自定义xd_imageNamed:用于拦截系统方法。

```objectivec
+ (UIImage *)xd_imageNamed:(NSString *)name {
    double version = [[UIDevice currentDevice].systemVersion doubleValue];
    if (version >= 7.0) {
        // 如果系统版本是7.0以上，使用另外一套文件名结尾是‘_os7’的扁平化图片
        name = [name stringByAppendingString:@"_os7"];
    }
    //这里因为系统方法名已经变成我们自定义的方法，所以这里要将实际要调用的
    //imageNamed:换成我们自定义的方法才能调到系统的imageNamed:
    return [UIImage xd_imageNamed:name];
}
```

2、在分类中重写UIImage的load方法，实现方法交换。

```objectivec
+ (void)load {
    // 获取两个类的类方法
    Method m1 = class_getClassMethod([UIImage class], @selector(imageNamed:));
    Method m2 = class_getClassMethod([UIImage class], @selector(xd_imageNamed:));
    // 开始交换方法实现
    method_exchangeImplementations(m1, m2);
}
```

#### 3.2 给分类添加属性

>在分类中是无法设置属性的，因为在分类声明中写`@property`只能生成get和set方法的声明，但是
>无法生成成员变量。如果使用成员变量，比如:

```objectivec
int _num

- (int)num {
    return _num;
}

- (void)setnum:(int)num {
    _num = num;
}

//但是全局变量程序整个执行过程中内存里只有一份，当我创建多个对象
//修改的都是同一个值。
```

**属性关联**

```objectivec
/**
将值value和对象object关联起来(将值存储到对象中)
object : 给哪个对象设置属性
key    : 用于取出存储值的key，一个属性对应一个key，key可以是char，double，int等。
value  : 给属性设置的值
policy : 储存策略(assign，copy，retain)
*/
void objc_setAssociatedObject(id object , const void *key , id value , objc_AssociationPloicy policy)

/**
用key取值
*/
id objc_getAssociatedObject(id object , const void *key)
```

**举个栗子:**

```objectivec
//.h文件
@property (nonatomic, copy)NSString *content;

//.m文件

char contentKey;

- (void)setContent:(NSString *)content {
    objc_setAssociatedObject(self, &contentKey, content, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)content {
    return objc_getAssociatedObject(self, &contentKey);
}
```

#### 3.3 获取类的所以成员变量

```objectivec
/**
获取类的所有成员变量
*/
Ivar *class_copyIvarList(Class cls, unsigned int *outCount)

/**
获取成员变量的名字
*/
const char *ivar_getName(Ivar v)

/**
获取成员变量的类型
*/
const char *ivar_getTypeEndcoding(Ivar v)
```

**举个栗子:重写归档和解档方法**

```objectivec
//.h
#import <Foundation/Foundation.h>

@interface NSObject (Extension)

- (NSArray *)ignoredNames;
- (void)encode:(NSCoder *)aCoder;
- (void)decode:(NSCoder *)aDecoder;

@end

//.m
#import "NSObject+Extension.h"
#import <objc/runtime.h>

@implementation NSObject (Extension)

- (void)decode:(NSCoder *)aDecoder {
    // 一层层父类往上查找，对父类的属性执行归解档方法
    Class c = self.class;
    while (c &&c != [NSObject class]) {

        unsigned int outCount = 0;
        Ivar *ivars = class_copyIvarList(c, &outCount);
        for (int i = 0; i < outCount; i++) {
            Ivar ivar = ivars[i];
            NSString *key = [NSString stringWithUTF8String:ivar_getName(ivar)];

            // 如果有实现该方法再去调用
            if ([self respondsToSelector:@selector(ignoredNames)]) {
                if ([[self ignoredNames] containsObject:key]) continue;
            }

            id value = [aDecoder decodeObjectForKey:key];
            [self setValue:value forKey:key];
        }
        free(ivars);
        c = [c superclass];
    }

}

- (void)encode:(NSCoder *)aCoder {
    // 一层层父类往上查找，对父类的属性执行归解档方法
    Class c = self.class;
    while (c &&c != [NSObject class]) {

        unsigned int outCount = 0;
        Ivar *ivars = class_copyIvarList([self class], &outCount);
        for (int i = 0; i < outCount; i++) {
            Ivar ivar = ivars[i];
            NSString *key = [NSString stringWithUTF8String:ivar_getName(ivar)];

            // 如果有实现该方法再去调用
            if ([self respondsToSelector:@selector(ignoredNames)]) {
                if ([[self ignoredNames] containsObject:key]) continue;
            }

            id value = [self valueForKeyPath:key];
            [aCoder encodeObject:value forKey:key];
        }
        free(ivars);
        c = [c superclass];
    }
}
@end
```

使用方法

```objectivec
// 设置需要忽略的属性
- (NSArray *)ignoredNames {
    return @[@"bone"];
}

// 在系统方法内来调用我们的方法
- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        [self decode:aDecoder];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [self encode:aCoder];
}
```

#### 3.4 替换方法实现

假设现在需要一个圆角按钮，并且保证点击触发事件的范围必须要这个圆之内，那么通过一个UIButton+Runtime的扩展来替换旧有-pointInside:withEvent:方法

```objectivec
@interface UIButton(Runtime)

@property (nonatomic, assign) BOOL roundTouchEnable;

@end


const void * RoundTouchEnableKey = &RoundTouchEnableKey;
@implementation UIButton(Runtime)

- (BOOL)roundTouchEnable
{
    return [objc_getAssociatedObject(self, RoundTouchEnableKey) boolValue];
}

- (void)setRoundTouchEnable: (BOOL)roundTouchEnable
{
    objc_setAssociatedObject(self, RoundTouchEnableKey, @(roundTouchEnable), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)replacePointInside: (CGPoint)point withEvent: (UIEvent *)event
{
    if (CGRectGetWidth(self.frame) != CGRectGetHeight(self.frame) 
        || !self.roundTouchEnable)
    {
        return [super pointInside: point withEvent: event];
    }
    CGFloat radius = CGRectGetWidth(self.frame) / 2;
    CGPoint offset = CGPointMake(point.x - radius, point.y - radius);
    return sqrt(offset.x * offset.x + offset.y * offset.y) <= radius;
}

// 替换方法实现
+ (void)initialize
{
    [super initialize];
    Method replaceMethod = class_getInstanceMethod([self class], @selector(replacePointInside:withEvent:));
    Method originMethod = class_getInstanceMethod([self class], @selector(pointInside:withEvent:));
    method_setImplementation(originMethod, method_getImplementation(replaceMethod));
}
@end
```

## 4 Runtime消息机制 

#### 4.1 C是一门动态语言

* 静态语言：在运行前会进行类型判断，类的所有成员、方法都会在编译阶段确定好内存地址。类成员只能访问属于自己的方法和变量，如果方法调用错误，代码无法通过编译，会直接引起编译器报错。因此，静态语言结构规范、便于调试、且可以进行多样的性能优化。常见的静态语言包括java/C++/C等。
* 动态语言：大部分的判断工作被推迟到运行时进行，类的成员变量、方法地址都在运行时确认。可以在运行时动态的添加类成员、方法等。具有较高的灵活性和可定制性、便于阅读，但方法通常无法进行内联等优化。
 
>`smalltalk`是动态语言的鼻祖，更是OC发展的最大推动力。在`smalltalk`中，所有的东西都是对象（或者都应该被当做对象），例如表达式`5 + 3`被理解成向对象5发送了消息+，其中接收的参数是 3。

#### 4.2 消息发送过程

```objectivec
//无参数
objc_msgSend(receiver, selector)
//有参数时
objc_msgSend(receiver, selector, arg1, arg2, ...)
```

##### 4.2.1 消息发送总览

1. 检测这个`selector` 是不是要忽略的。比如 Mac OS X 开发，有了垃圾回收就不理会`retain`,`release`这些函数了。
2. 检测这个`target`是不是`nil`对象。ObjC的特性是允许对一个`nil`对象执行任何一个方法不会Crash，因为会被忽略掉。
3. 如果上面两个通过，就从先`cache`里面找这个类的`IMP`，找到就直接跳到对应函数里面。
4. 如果`cache`里面没有，就到类的方法列表中查找，然后超类的方法列表，一直到`NSObject`。
5. 如果还说没有就要进入`动态方法`解析了。

>为了高度优化性能，苹果直接使用汇编实现了这个函数（源码处于Source/objc-msg-arm.s文件下）：

```objectivec
/*****************************************************************
 *
 * id objc_msgSend(id self, SEL    _cmd,...);
 *
 *****************************************************************/
    ENTRY objc_msgSend
    MESSENGER_START

    cbz    r0, LNilReceiver_f    // 判断消息接收者是否为nil

    ldr    r9, [r0]              // r9 = self->isa
    CacheLookup NORMAL           // 到缓存中查找方法

LCacheMiss:                      // 方法未缓存
    MESSENGER_END_SLOW
    ldr    r9, [r0, #ISA]        
    b    __objc_msgSend_uncached

LNilReceiver:                    // 消息接收者为nil处理
    mov    r1, #0
    mov    r2, #0
    mov    r3, #0
    FP_RETURN_ZERO
    MESSENGER_END_NIL
    bx    lr    

LMsgSendExit:
    END_ENTRY objc_msgSend
```

##### 4.2.2 查找方法

>查找方法实现是通过_class_lookupMethodAndLoadCache3这个函数完成的：

```objectivec
IMP _class_lookupMethodAndLoadCache3(id obj, SEL sel, Class cls)
{
    return lookUpImpOrForward(cls, sel, obj, 
                          YES/*initialize*/, NO/*cache*/, YES/*resolver*/);
}

IMP lookUpImpOrForward(Class cls, SEL sel, id inst, 
                   bool initialize, bool cache, bool resolver)
{
    Class curClass;
    IMP methodPC = nil;
    Method meth;
    bool triedResolver = NO;

    methodListLock.assertUnlocked();

    // 如果传入的cache为YES，到类缓存中查找方法缓存
    if (cache) {
        methodPC = _cache_getImp(cls, sel);
        if (methodPC) return methodPC;    
    }

    // 判断类是否已经被释放
    if (cls == _class_getFreedObjectClass())
        return (IMP) _freedHandler;

    // 如果类未初始化，对其进行初始化。如果这个消息是initialize，那么直接进行类的初始化
    if (initialize  &&  !cls->isInitialized()) {
        _class_initialize (_class_getNonMetaClass(cls, inst));
    }

 retry:
    methodListLock.lock();

    // 忽略在GC环境下的部分消息，比如retain、release等
    if (ignoreSelector(sel)) {
        methodPC = _cache_addIgnoredEntry(cls, sel);
        goto done;
    }

    // 遍历缓存方法，如果找到，直接返回
    methodPC = _cache_getImp(cls, sel);
    if (methodPC) goto done;

    // 遍历类自身的方法列表查找方法实现
    meth = _class_getMethodNoSuper_nolock(cls, sel);
    if (meth) {
        log_and_fill_cache(cls, cls, meth, sel);
        methodPC = method_getImplementation(meth);
        goto done;
    }

    // 尝试向上遍历父类的方法列表查找实现
    curClass = cls;
    while ((curClass = curClass->superclass)) {
        // Superclass cache.
        meth = _cache_getMethod(curClass, sel, _objc_msgForward_impcache);
        if (meth) {
            if (meth != (Method)1) { 
                log_and_fill_cache(cls, curClass, meth, sel);
                methodPC = method_getImplementation(meth);
                goto done;
            }
            else {
                // Found a forward:: entry in a superclass.
                // Stop searching, but don't cache yet; call method 
                // resolver for this class first.
                break;
            }
        }

        // 查找父类的方法列表
        meth = _class_getMethodNoSuper_nolock(curClass, sel);
        if (meth) {
            log_and_fill_cache(cls, curClass, meth, sel);
            methodPC = method_getImplementation(meth);
            goto done;
        }
    }

    // 没有找到任何的方法实现，进入消息转发第一阶段“动态方法解析”
    // 调用+ (BOOL)resolveInstanceMethod: (SEL)selector
    // 征询接收者所属的类是否能够动态的添加这个未实现的方法来解决问题
    if (resolver  &&  !triedResolver) {
        methodListLock.unlock();
        _class_resolveMethod(cls, sel, inst);
        triedResolver = YES;
        goto retry;
    }

    // 仍然没有找到方法实现进入消息转发第二阶段“备援接收者”
    // 先后会调用 -(id)forwardingTargetForSelector: (SEL)selector 
    // 以及 - (void)forwardInvocation: (NSInvocation*)invocation 进行最后的补救
    // 如果补救未成功抛出消息发送错误异常
    _cache_addForwardEntry(cls, sel);
    methodPC = _objc_msgForward_impcache;

 done:
    methodListLock.unlock();

    assert(!(ignoreSelector(sel)  &&  methodPC != (IMP)&_objc_ignored_method));
    return methodPC;
}
```

**以上为方法调用全部过程，主要分为三部分：**

1、查找是否存在对应方法缓存，如果存在直接返回调用，为了优化性能，方法的缓存使用了散列表的方式。

2、未找到缓存， 到类本身或顺着类结构向上查找方法实现，返回`method_t *`类型也就是`Method`。

```objectivec
//非加锁状态下查找方法实现
static method_t * getMethodNoSuper_nolock(Class cls, SEL sel)
{
    runtimeLock.assertLocked();

    assert(cls->isRealized());
    // fixme nil cls? 
    // fixme nil sel?
    for (auto mlists = cls->data()->methods.beginLists(), 
            end = cls->data()->methods.endLists(); 
             mlists != end;
               ++mlists)
    {
        method_t *m = search_method_list(*mlists, sel);
        if (m) return m;
    }

    return nil;
}

// 搜索方法列表
static method_t * search_method_list(const method_list_t *mlist, SEL sel)
{
    int methodListIsFixedUp = mlist->isFixedUp();
    int methodListHasExpectedSize = mlist->entsize() == sizeof(method_t);

    if (__builtin_expect(methodListIsFixedUp && methodListHasExpectedSize, 1)) {
          // 对有序数组进行线性探测
          return findMethodInSortedMethodList(sel, mlist);
    } else {
        // Linear search of unsorted method list
        for (auto& meth : *mlist) {
            if (meth.name == sel) return &meth;
        }
    }

#if DEBUG
    // sanity-check negative results
    if (mlist->isFixedUp()) {
        for (auto& meth : *mlist) {
            if (meth.name == sel) {
                _objc_fatal("linear search worked when binary search did not");
            }
        }
    }
#endif

    return nil;
}
```

如果在这步骤中找到方法实现，则将它加入方法缓存中。

```objectivec
// 记录并且缓存方法
static void log_and_fill_cache(Class cls, IMP imp, SEL sel, id receiver, Class implementer)
{
#if SUPPORT_MESSAGE_LOGGING
    if (objcMsgLogEnabled) {
        bool cacheIt = logMessageSend(implementer->isMetaClass(), 
                                cls->nameForLogging(),
                                implementer->nameForLogging(), 
                                sel);
        if (!cacheIt) return;
    }
#endif
    cache_fill (cls, sel, imp, receiver);
}

//在无加锁状态下缓存方法
static void cache_fill_nolock(Class cls, SEL sel, IMP imp, id receiver)
{
    cacheUpdateLock.assertLocked();

    if (!cls->isInitialized()) return;
    if (cache_getImp(cls, sel)) return;

    cache_t *cache = getCache(cls);
    cache_key_t key = getKey(sel);

    // 如果缓存占用不到3/4，进行缓存。
    mask_t newOccupied = cache->occupied() + 1;
    mask_t capacity = cache->capacity();
    if (cache->isConstantEmptyCache()) {
        cache->reallocate(capacity, capacity ?: INIT_CACHE_SIZE);
    }
    else if (newOccupied <= capacity / 4 * 3) {
    }
    else {
        // 扩充缓存。为了性能，扩充后原有缓存方法全部移除
        cache->expand();
    }
    bucket_t *bucket = cache->find(key, receiver);
    if (bucket->key() == 0) cache->incrementOccupied();
    bucket->set(key, imp);
}
```

如果在类自身方法中没找到，那么循环父类方法，重复上面动作。

3、如果未找到任何方法实现，则会出发消息转发机制。

>消息转发分为两个阶段，第一个阶段我们可以通过动态添加方法之后让编译器再次执行查找方法实现的过程；第二个阶段称作备援的接收者，就是找到一个接盘侠来处理这个事件。

```objectivec
void _class_resolveMethod(Class cls, SEL sel, id inst)
{
    // 非beta类的情况下直接调用 resolveInstanceMethod 方法
    if (! cls->isMetaClass()) {
        _class_resolveInstanceMethod(cls, sel, inst);
    } 
    else {
        // 先调用 resolveClassMethod 请求动态添加方法
        // 然后进行一次查找判断是否处理完成
        // 如果没有添加，再调用 resolveInstanceMethod 方法
        _class_resolveClassMethod(cls, sel, inst);
        if (!lookUpImpOrNil(cls, sel, inst, 
                      NO/*initialize*/, YES/*cache*/, NO/*resolver*/)) 
        {
            _class_resolveInstanceMethod(cls, sel, inst);
        }
    }
}
```

##### 4.2.3 方法缓存

>`cache`存储着我们在方法调用中需要查找的方法缓存。作为缓存方法的cache采用了散列表，以此来大幅度提高检索的速度：

```objectivec
#define CACHE_HASH(sel, mask) (((uintptr_t)(sel)>>2) & (mask))

struct cache_t {
    struct bucket_t *_buckets;
    mask_t _mask;
    mask_t _occupied;
    // functions
}

// cache method
buckets = (cache_entry **)cache->buckets;
for (index = CACHE_HASH(sel, cache->mask); 
     buckets[index] != NULL; 
     index = (index+1) & cache->mask)
{ }
buckets[index] = entry;

//利用sel的指针地址和mask做一个简单的位运算，然后找到一个空槽存储起来。
```

>以此推出从缓存中查找sel实现代码CacheLookup, 苹果使用汇编完成查找步骤，用以优化性能。

```objectivec
.macro CacheLookup

    ldrh    r12, [r9, #CACHE_MASK]    // r12 = mask
    ldr    r9, [r9, #CACHE]    // r9 = buckets
.if $0 == STRET  ||  $0 == SUPER_STRET
    and    r12, r12, r2        // r12 = index = SEL & mask
.else
    and    r12, r12, r1        // r12 = index = SEL & mask
.endif
    add    r9, r9, r12, LSL #3    // r9 = bucket = buckets+index*8
    ldr    r12, [r9]        // r12 = bucket->sel
2:
.if $0 == STRET  ||  $0 == SUPER_STRET
    teq    r12, r2
.else
    teq    r12, r1
.endif
    bne    1f
    CacheHit $0
1:    
    cmp    r12, #1
    blo    LCacheMiss_f        // if (bucket->sel == 0) cache miss
    it    eq            // if (bucket->sel == 1) cache wrap
    ldreq    r9, [r9, #4]        // bucket->imp is before first bucket
    ldr    r12, [r9, #8]!        // r12 = (++bucket)->sel
    b    2b

.endmacro
```

#### 4.3 消息转发

>通常情况下，调用不属于某个对象的方法的时候，应用就会崩溃crash。
>通过方法调用源码可以看到，并不是没有找到方法实现就直接crash。
>在crash之前编译器会进行消息转发机制，有依次有三次机会。

```objectivec
第一阶段         resolveInstanceMethod  
(动态添加方法：添加对应方法，跳到方法实现)             
						   
第二阶段		 forwardingTargetForSelector
(最后的接盘侠：直接接管对应方法，实现方法)

			     forwardInvocation
```

1、第一阶段(resolveInstanceMethod)

避免程序因为类型错误导致crash，可以通过`class_addMethod`动态添加处理方法。
类可以在`objc_registerClassPair`完成类注册后动态添加方法，但不能动态添加属性，
类似于`category`。

```objectivec
id wrongTypeGetter(id object, SEL sel) {
    return nil;
}

void wrongTypeSetter(id object, SEL sel, id value) {
    // do nothing
}

+ (BOOL)resolveInstanceMethod: (SEL)selector
{
    NSString * selName = NSStringFromSelector(selector);
    if ([sel hasPrefix: @"set"]) {
        class_addMethod(self, selector, (IMP)wrongTypeSetter, "v@:@");
    } else {
        class_addMethod(self, selector, (IMP)wrongTypeGetter, "@@:")
    }
}
```

2、第二阶段(forwardingTargetForSelector)

>在iOS中不支持多继承，尽管我们可以通过协议和组合模式实现`伪多继承`。`伪多继承`和`多继承`的区别在于：`多继承`是将多个类的功能组合到一个对象当中，而`伪多继承`多个类的功能依旧分布在不同对象当中，但是对象彼此对消息发送者透明。那么，如果我们消息转发给另一个对象可以用来实现这种伪多继承。

```objectivec
@interface Person: NSObject

@property (nonatomic, strong) NSNumber * age;

@end

@implementation Person

- (id)forwardingTargetForSelector: (SEL)aSelector
{
    // 甚至可以通过runtime遍历自己属性找到可以响应方法的接盘侠
    NSString * selName = NSStringFromSelector(aSelector);
    if ([selName hasSuffix: @"Value"]) {
        return self.age;
    }
    return nil;
}

@end

// View controller
id p = [[Person alloc] init];
[p setAge: @(18)];
NSLog(@"%lu, %.2f", [p integerValue], [p doubleValue]);    //18, 18.00
```

3、第二阶段最后(forwardInvocation)

>`runtime`需要生成一个`methodSignature`变量来组装，这将通过调用消息接收者的`-(NSMethodSignature *)methodSignatureForSelector:`获取，这个变量包含了方法的参数类型、参数个数以及消息接收者等信息。接着把这个变量组装成一个NSInvocation对象进行最后一次的消息转发，调用接收者的`-forwardInvocation:`方法。我们可以对`invocation`做任何事情，包括随意修改参数值、消息接收者等。我最常拿来干的事情就是减少数组的遍历工作：

```objectivec
@implementation NSArray(Runtime)

- (void)forwardInvocation: (NSInvocation *)anInvocation
{
    for (id item in self) {
        if ([item respondsToSelector: anInvocation.selector]) {
            [anInvocation invokeWithTarget: item];
        }
    }
}

@end
```

>NSInvocation对象封装了动态库向接收器转发执行消息所需的所有必要信息，如目标对象、方法选择器、方法参数。因此可以借助NSInvocation实例，使用内部的选择器和其他信息，在任何时候调用接收器。同一个NSInvocation实例可重复调用接收器的同一个方法，或通过不同的目标和方法签名进行复用。
>OC中直接调用对象的消息方法有两种：
>1.`performSelector:withObject`
>2.NSInvocation
>实现NSArray的map方法。可以让数组中每个元素接受消息，并且返回一个新的数组。该方法类似于`makeObjectsPerformSelector:`，不同的是map可以传送带有多个参数的消息，而且可以延伸至数组以外的集合。比如:

```objectivec
int main(int argc, const char * argv[]) {
	NSArray *testArray = @[@1, @2, @3];
	id stringArray = [[testArray map] stringValue];
	NSLog(@%@", stringArray); // "1", "2", "3"
}
```

**实现代码**

```objectivec
//NSArray+Map.h

@interface NSArray (Map)
- (id)map;
@end

//NSArray+Map.m

@implementation NSArray (Map)
- (id)map {
	return [[NSArrayMapProxy alloc] initWithArray:self];
}
@end

//实现NSArrayMapProxy
//NSArrayMapProxy.h

@interface NSArrayMapProxy : NSProxy {
	NSArray *_array;
}
- (instancetype)initWithArray:(NSArray *)array;
@end

//NSArrayMapProxy.m

@implementation NSArrayMapProxy 

- (instancetype)initWithArray:(NSArray *)array {
	_array = array;
	return self;
}

//示例中的数组array包含三个NSNumber类型的对象，于是向proxy发送stringValue消息的时候，proxy就负责将消息转发给数组中的每个元素。于是NSArrayMapProxy就需要重载NSProxy的两个方法，来实现消息转发机制。
//1.在NSArrayMapProxy收到消息后，首先methodSignatureForSelector:会被调用，用于返回一个方法签名。

//这里重载方法时，遍历数组中的元素，如果有元素响应消息，就可以通过该元素找到消息的方法签名。
//这个函数也就是找到方法的实现，自己没有实现方法，就到别的对象中找。
- (nullable NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
	for (id obj in _array) {
		if ([obj respondsToSelector:sel]) {
			return [obj methodSignatureForSelector:sel];
		}
	}

	return [super methodSignatureForSelector:sel];
}

//2.在得到方法签名之后，接着会调`forwardInvocation:`方法，于是可以重载方法后在这里决定消息的转发去向。
- (void)forwardInvocation:(NSInvocation *)invocation {
	SEL sel = invocation.selector;
	NSMutableArray *mappedArray = [NSMutableArray arrayWithCapacity:_array.count];
	for (id obj in _array) {
		if ([obj respondsToSelector:sel]) {
			//[NSInvocation invoke]方法调用
			[invocation invokeWithTarget:obj]; //调用数组中元素obj的stringValue方法
			id mappedValue; //用于存储调用返回value
			[invocation getReturnValue:&mappedValue];
			[mappedArray addObject:mapped];
		}
	}
	//设置调用[NSArrayMapProxy stringValue]的返回值
	[invocation setReturnValue:&mappedArray];
}
@end
```

>具体思路：为NSArray添加map方法，当调用map方式时，返回的是NSArrayMapProxy对象。之后调用NSArrayMapProxy对象的stringValue方法。
>NSArrayMapProxy对象的作用就是在NSArray元素中找到sel方法的签名(就是得到stringValue的实现方法)，然后让每个元素都调用这个方法，并将返回值存储起来，得到新的NSArray。

还有利用类似思路解决服务器返回NSNull问题。







































