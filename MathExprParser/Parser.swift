/*-------------------------------------------------------------------------
    Simple math expression parser for Swift,
    
    (MIT License)

    Copyright (c) 2021 Philipp AnnÃ©

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
-------------------------------------------------------------------------*/

import Foundation



public class Parser {
    public let _EOF = 0
    public let _number = 1
    public let _identifier = 2
    public let _pi = 11
    public let _abs = 12
    public let _sin = 13
    public let _cos = 14
    public let _tan = 15
    public let _asin = 16
    public let _acos = 17
    public let _atan = 18
    public let _sinh = 19
    public let _cosh = 20
    public let _tanh = 21
    public let _asinh = 22
    public let _acosh = 23
    public let _atanh = 24
    public let _log = 25
    public let _exp = 26
    public let _sqrt = 27
    public let _sign = 28
    public let maxT = 29

    static let _T = true
    static let _x = false
    static let minErrDist = 2
    let minErrDist : Int = Parser.minErrDist

    public var scanner: Scanner
    public var errors: Errors

    public var t: Token             // last recognized token
    public var la: Token            // lookahead token
    var errDist = Parser.minErrDist

    private var _val: Double = 0.0
    
    private var _parameters: [String: Double] = [:]
    
    public var result: Double {
        get { return _val }
    }
    
    public func addParameter(_ name: String, withValue value: Double) {
        _parameters[name] = value
    }
    
    convenience init(scanner: Scanner, withParameters parameters: [String : Double]) {
        
        self.init(scanner: scanner)
        _parameters = parameters
    }
    
    


    public init(scanner: Scanner) {
        self.scanner = scanner
        errors = Errors()
        t = Token()
        la = t
    }
    
    func SynErr (_ n: Int) {
        if errDist >= minErrDist { errors.SynErr(la.line, col: la.col, n: n) }
        errDist = 0
    }
    
    public func SemErr (_ msg: String) {
        if errDist >= minErrDist { errors.SemErr(t.line, col: t.col, s: msg) }
        errDist = 0
    }

    func Get () {
        while true {
            t = la
            la = scanner.Scan()
            if la.kind <= maxT { errDist += 1; break }

            la = t
        }
    }
    
    func Expect (_ n: Int) {
        if la.kind == n { Get() } else { SynErr(n) }
    }
    
    func StartOf (_ s: Int) -> Bool {
        return set(s, la.kind)
    }
    
    func ExpectWeak (_ n: Int, _ follow: Int) {
        if la.kind == n {
            Get()
        } else {
            SynErr(n)
            while !StartOf(follow) { Get() }
        }
    }
    
    func WeakSeparator(_ n: Int, _ syFol: Int, _ repFol: Int) -> Bool {
        var kind = la.kind
        if kind == n { Get(); return true }
        else if StartOf(repFol) { return false }
        else {
            SynErr(n)
            while !(set(syFol, kind) || set(repFol, kind) || set(0, kind)) {
                Get()
                kind = la.kind
            }
            return StartOf(syFol)
        }
    }

    func MathExpr() {
        Expression(&_val)
    }

    func Expression(_ value:inout Double) {
        var lhs: Double = 0.0
        var rhs: Double = 0.0
        
        if StartOf(1) {
            Term(&lhs)
        } else if la.kind == 3 /* "-" */ {
            Get()
            Term(&lhs)
            lhs.negate()
        } else { SynErr(30) }
        while la.kind == 3 /* "-" */ || la.kind == 4 /* "+" */ {
            if la.kind == 4 /* "+" */ {
                Get()
                Term(&rhs)
                lhs += rhs
            } else {
                Get()
                Term(&rhs)
                lhs -= rhs
            }
        }
        value = lhs
    }

    func Term(_ value:inout Double) {
        var lhs: Double = 0.0
        var rhs: Double = 0.0
        
        Factor(&lhs)
        while StartOf(2) {
            if la.kind == 5 /* "^" */ {
                Get()
                Factor(&rhs)
                lhs = pow(lhs, rhs)
            } else if la.kind == 6 /* "%" */ {
                Get()
                Factor(&rhs)
                lhs = lhs.truncatingRemainder(dividingBy: rhs)
            } else if la.kind == 7 /* "*" */ {
                Get()
                Factor(&rhs)
                lhs *= rhs
            } else {
                Get()
                Factor(&rhs)
                lhs /= rhs
            }
        }
        value = lhs
    }

    func Factor(_ value:inout Double) {
        if la.kind == 9 /* "(" */ {
            Get()
            Expression(&value)
            Expect(10 /* ")" */)
        } else if StartOf(3) {
            Function(&value)
        } else if la.kind == _pi {
            Get()
            value = Double.pi
        } else if la.kind == _number {
            Get()
            value = Double(t.val)!
        } else if la.kind == _identifier {
            Get()
            if let p = _parameters[t.val] {
               value = p
            } else {
               SemErr("parameter '\(t.val)' is not defined")
            }
            
        } else { SynErr(31) }
    }

    func Function(_ value:inout Double) {
        var inner: Double = 0.0
        switch la.kind {
        case _abs:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = abs(inner)
        case _sin:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = sin(inner)
        case _cos:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = cos(inner)
        case _tan:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = tan(inner)
        case _asin:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = asin(inner)
        case _acos:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = acos(inner)
        case _atan:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = atan(inner)
        case _sinh:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = sinh(inner)
        case _cosh:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = cosh(inner)
        case _tanh:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = tanh(inner)
        case _asinh:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = asinh(inner)
        case _acosh:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = acosh(inner)
        case _atanh:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = atanh(inner)
        case _log:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = log(inner)
        case _exp:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = exp(inner)
        case _sqrt:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = sqrt(inner)
        case _sign:
            Get()
            Expect(9 /* "(" */)
            Expression(&inner)
            Expect(10 /* ")" */)
            value = inner < 0 ? -1 : 1
        default: SynErr(32)
        }
    }



    public func Parse() {
        la = Token()
        la.val = ""
        Get()
        MathExpr()
        Expect(_EOF)

    }

    func set (_ x: Int, _ y: Int) -> Bool { return Parser._set[x][y] }
    static let _set: [[Bool]] = [
        [_T,_x,_x,_x, _x,_x,_x,_x, _x,_x,_x,_x, _x,_x,_x,_x, _x,_x,_x,_x, _x,_x,_x,_x, _x,_x,_x,_x, _x,_x,_x],
        [_x,_T,_T,_x, _x,_x,_x,_x, _x,_T,_x,_T, _T,_T,_T,_T, _T,_T,_T,_T, _T,_T,_T,_T, _T,_T,_T,_T, _T,_x,_x],
        [_x,_x,_x,_x, _x,_T,_T,_T, _T,_x,_x,_x, _x,_x,_x,_x, _x,_x,_x,_x, _x,_x,_x,_x, _x,_x,_x,_x, _x,_x,_x],
        [_x,_x,_x,_x, _x,_x,_x,_x, _x,_x,_x,_x, _T,_T,_T,_T, _T,_T,_T,_T, _T,_T,_T,_T, _T,_T,_T,_T, _T,_x,_x]

    ]
} // end Parser


public class Errors {
    public var count = 0                                 // number of errors detected
    private let errorStream = Darwin.stderr              // error messages go to this stream
    public var errMsgFormat = "-- line %i col %i: %@"    // 0=line, 1=column, 2=text
    
    func Write(_ s: String) { fputs(s, errorStream) }
    func WriteLine(_ format: String, line: Int, col: Int, s: String) {
        let str = String(format: format, line, col, s)
        WriteLine(str)
    }
    func WriteLine(_ s: String) { Write(s + "\n") }
    
    public func SynErr (_ line: Int, col: Int, n: Int) {
        var s: String
        switch n {
        case 0: s = "EOF expected"
        case 1: s = "number expected"
        case 2: s = "identifier expected"
        case 3: s = "\"-\" expected"
        case 4: s = "\"+\" expected"
        case 5: s = "\"^\" expected"
        case 6: s = "\"%\" expected"
        case 7: s = "\"*\" expected"
        case 8: s = "\"/\" expected"
        case 9: s = "\"(\" expected"
        case 10: s = "\")\" expected"
        case 11: s = "\"pi\" expected"
        case 12: s = "\"abs\" expected"
        case 13: s = "\"sin\" expected"
        case 14: s = "\"cos\" expected"
        case 15: s = "\"tan\" expected"
        case 16: s = "\"asin\" expected"
        case 17: s = "\"acos\" expected"
        case 18: s = "\"atan\" expected"
        case 19: s = "\"sinh\" expected"
        case 20: s = "\"cosh\" expected"
        case 21: s = "\"tanh\" expected"
        case 22: s = "\"asinh\" expected"
        case 23: s = "\"acosh\" expected"
        case 24: s = "\"atanh\" expected"
        case 25: s = "\"log\" expected"
        case 26: s = "\"exp\" expected"
        case 27: s = "\"sqrt\" expected"
        case 28: s = "\"sign\" expected"
        case 29: s = "??? expected"
        case 30: s = "invalid Expression"
        case 31: s = "invalid Factor"
        case 32: s = "invalid Function"

        default: s = "error \(n)"
        }
        WriteLine(errMsgFormat, line: line, col: col, s: s)
        count += 1
    }

    public func SemErr (_ line: Int, col: Int, s: String) {
        WriteLine(errMsgFormat, line: line, col: col, s: s);
        count += 1
    }
    
    public func SemErr (_ s: String) {
        WriteLine(s)
        count += 1
    }
    
    public func Warning (_ line: Int, col: Int, s: String) {
        WriteLine(errMsgFormat, line: line, col: col, s: s)
    }
    
    public func Warning(_ s: String) {
        WriteLine(s)
    }
} // Errors

