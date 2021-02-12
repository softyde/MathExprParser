//
//  MathExprParserTests.swift
//  MathExprParserTests
//
//  Created by Philipp Anné on 05.02.21.
//

import XCTest
@testable import MathExprParser

struct TestCase {
    var description: String
    var expression: String
    var result: Double
    var shouldFail = false
}

class MathExprParserTests: XCTestCase {

    let testCases: [TestCase] = [
        
        TestCase(description: "Invalid 1", expression: "abc", result: 0.0, shouldFail: true),
        TestCase(description: "Invalid 2", expression: "a+++b", result: 0.0, shouldFail: true),        
        TestCase(description: "Numeric value", expression: "1.234", result: 1.234),
        TestCase(description: "Left to right 1", expression: "1/2*3", result: 1.0/2.0*3.0),
        TestCase(description: "Left to right 2", expression: "1/2/3", result: 1.0/2.0/3.0),        
        TestCase(description: "Whitespace ignore", expression: "    1.234\t +9.876 \r\n", result: 1.234 + 9.876),
        TestCase(description: "Constant", expression: "pi", result: Double.pi),
        TestCase(description: "Real World 1", expression: "sin(((22.5/2)/180)*pi)", result: sin(22.5/2/180*Double.pi)),
        TestCase(description: "Simple addition", expression: "1.1 + 2.3", result: 1.1 + 2.3),
        TestCase(description: "Simple multiplication", expression: "1.1 * 2.3", result: 1.1 * 2.3),
        TestCase(description: "Simple point before line", expression: "1.1 + 2.2 * 3.3", result: 1.1 + 2.2 * 3.3),
        TestCase(description: "Simple parenthesis", expression: "(1.1 + 2.2) * 3.3", result: (1.1 + 2.2) * 3.3),
        TestCase(description: "Trigonometric function", expression: "sin(cos(pi))", result: sin(cos(Double.pi))),
        TestCase(description: "Complex expression", expression: "sqrt(3.0/4.0) + 2.0 * abs(sin(pi * 180.0)^2.0)", result: sqrt(3.0/4.0) + 2.0 * abs(pow(sin(Double.pi * 180.0), 2.0))),
    ]
    
/*    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }*/

    func testExample() throws {
        
        testCases.forEach() { testCase in
            
            print(testCase.description)
            
            let inputStream = InputStream(data: testCase.expression.data(using: .utf8)!)
            let scanner = MathExprParser.Scanner(s: inputStream)
            
            let parser = MathExprParser.Parser(scanner: scanner)
            parser.Parse()
            
            if(parser.errors.count > 0) {
                
                XCTAssert(testCase.shouldFail)
                print("Test failed intentionally")
                
            } else {
            
                let result = parser.result
            
                print("\(result) <-> \(testCase.result)")
                XCTAssert(result == testCase.result)
            }
        }
                
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    /*func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }*/

}
