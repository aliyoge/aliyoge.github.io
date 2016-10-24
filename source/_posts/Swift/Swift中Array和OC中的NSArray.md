---
title: Swift中Array和OC中的NSArray
notebook: Swift
tags: [Swift,IOS]
categories: Swift
---
######概念
`Array`是Swift中的结构体类型(`struct`), 属于是`值类型`. 
`NSArray`是OC中的类型, 属于`引用类型`.

        var aarr = ["happy", "every", "day"]
        var barr : NSMutableArray = ["happy", "every", "day"]
        
        //1
        aarr[2] = "minute" //直接改变了aarr第二个元素的值
        barr[2] = "minute" //让barr第二个元素指向"minute"
        print("1---\(aarr)")
        print("1---\(barr)")
        /*输出:
            1---["happy", "every", "minute"]
            1---(
            happy,
            every,
            minute
            )
        */
        
        //2
        func changeA (var a:Array<String>) {
            a[2] = "second" //a是对aarr的拷贝
        }
        func changeB (a : NSMutableArray) {
            a[2] = "second" //a是对barr的引用
        }
        changeA(aarr) //值类型赋值时进行拷贝, 改变是a[2]的值, aarr并没有影响
        changeB(barr) //引用类型赋值时传递的是引用, a[2]和barr[2]都指向同一个地址.
        print("2---\(aarr)")
        print("2---\(barr)")
        /*输出:
            2---["happy", "every", "minute"]
            2---(
            happy,
            every,
            second
            )
        */

######Array和NSArray之间相互转换
Swift在数组方面Array很好的兼容了OC中的NSArray,可以直接进行赋值转换.

*(1) 可以直接声明Array或者NSArray, 并进行遍历*

	    let swiftArray: Array<String> = ["10", "20","30","40","50"]  
	    for element in swiftArray{  
	        print(element)  
	    } 

	    let OCNSArray: NSArray = ["10", "20","30","40","50"]  
	    for element in OCNSArray{  
	       print(element)  
	    } 

*(2)可以声明一个NSArray数组，转化为Array数组，再进行遍历*

        let OCNSArray: NSArray = ["10", "20","30","40","50"]  
	    let swiftArray:[String] = OCNSArray as! [String]  
	       
	    for index in swiftArray{  
	        print(index)  
	    } 

*(3)可以声明一个Array数组，转化为NSArray，再进行遍历*

        let swiftArray: Array<String> = ["10", "20","30","40","50"]  
	    let OCNSArray:NSArray = swiftArray  
	    for index in OCNSArray{  
	        print(index)  
	    }