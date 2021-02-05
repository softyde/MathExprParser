# Simple math expression parser for Swift

## Description

This is a simple parser/compiler for evaluating mathematical expressions in Swift.

In the simplest case, Strings can be evaluated and the mathematical result can be determined. However, the scanner processes any form of [InputStream](https://developer.apple.com/documentation/foundation/inputstream)s and can also use the contents of complete files.

The scanner/parser is generated with the [Swift port of Coco/R](https://github.com/mgriebling/Coco) by Michael Griebling. 

## Build-in operators

All operations a performed using Swifts **Double** type.

### Basic arithmetic operators

- Addition **(+)**
- Subtraction **(-)**
- Multipliction **(*)**
- Division **(/)**
- Remainder **(%)** (uses Swifts [truncatingRemainder(dividingBy:)](https://developer.apple.com/documentation/swift/double/2885641-truncatingremainder))
- Exponentiation **(^)**

The grammar follows the rules of dot before line arithmetic, so 1+2*3 will be calculated as 7.
```
1+2*3 == 7
```

Exponentiation will be evaluated before multiplication or division.
```
2*3^4 == 162 
```

### Parenthesis

Round parenthesis can be used to specify calculation order.
```
(1+2)*3 == 9
```

### Functions

The following functions can be used:
- Absolute value: **abs()**
- Exponential functions: **exp()**
- Logarithmic functions: **log()**
- Trigonometric functions: 
    - **cos()**
    - **sin()**
    - **tan()**
- Inverse trigonometric functions: 
    - **acos()**
    - **asin()**
    - **atan()**    
- Hyperbolic functions: 
    - **cosh()**
    - **sinh()**
    - **tanh()**
- Inverse hyperbolic functions: 
    - **acosh()**
    - **asinh()**
    - **atanh()**
- Square root: **sqrt()**
- Signum: **sign()**

### Constants

**pi** is the only constant defined. It is resolved to the value of *Double.pi*.

## Usage examples

See MathExprParserTests.swift for more examples.
```swift
let inputStream = InputStream(data: "sqrt(3.0/4.0) + 2.0 * abs(sin(pi * 180.0)^2.0)".data(using: .utf8)!)
let scanner = MathExprParser.Scanner(s: inputStream)
            
let parser = MathExprParser.Parser(scanner: scanner)
parser.Parse()

// if(parser.errors.count > 0) ...

let result = parser.result

// result == 0.8660254037844386
```

To use the Parser without any framework import, just drag & drop the Parser.swift, Scanner.swift and String+Char.swift files into your project.

## Grammar

See MathExpr.atg for details.

## License

Copyright (c) 2021 Philipp Anné

This project is licensed under the terms of the [MIT license](./LICENSE).