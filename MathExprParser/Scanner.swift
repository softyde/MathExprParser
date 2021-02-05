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



public class Token {
	public var kind = 0		 // token kind
	public var pos = 0		 // token position in bytes in the source text (starting at 0)
	public var charPos = 0	 // token position in characters in the source text (starting at 0)
	public var col = 0		 // token column (starting at 1)
	public var line = 0		 // token line (starting at 1)
	public var val = ""		 // token value
	public var next: Token?  // ML 2005-03-11 Tokens are kept in linked list
}

extension InputStream {
	var CanSeek: Bool { return false }
}

//-----------------------------------------------------------------------------------
// Buffer
//-----------------------------------------------------------------------------------
public class Buffer {
	// This Buffer supports the following cases:
	// 1) seekable stream (file)
	//    a) whole stream in buffer
	//    b) part of stream in buffer
	// 2) non seekable stream (network, console)
	
	public static let EOF = 3   // EOT mark
	static let MIN_BUFFER_LENGTH = 1024 // 1KB
	let MIN_BUFFER_LENGTH : Int = Buffer.MIN_BUFFER_LENGTH
	let MAX_BUFFER_LENGTH = Buffer.MIN_BUFFER_LENGTH * 64 // 64KB
	var buf : [UInt8]			// input buffer
	var bufStart: Int			// position of first byte in buffer relative to input stream
	var bufLen: Int				// length of buffer
	var fileLen: Int			// length of input stream (may change if the stream is no file)
	var bufPos: Int	= 0			// current position in buffer
	var stream: InputStream     // input stream (seekable)
	var isUserStream: Bool		// was the stream opened by the user?
	
	public init (s: InputStream, isUserStream: Bool) {
		stream = s; self.isUserStream = isUserStream
		
		if stream.CanSeek {
			fileLen = 0
			bufLen = min(fileLen, MAX_BUFFER_LENGTH)
			bufStart = Int.max // nothing in the buffer so far
		} else {
			fileLen = 0; bufLen = 0; bufStart = 0
		}
		
		buf = [UInt8](repeating: 0, count: bufLen>0 ? bufLen : MIN_BUFFER_LENGTH)
		if fileLen > 0 { Pos = 0 } // setup buffer to position 0 (start)
		else { bufPos = 0 } // index 0 is already after the file, thus Pos = 0 is invalid
	}
	
	fileprivate init (b: Buffer) { // called in UTF8Buffer constructor
		buf = b.buf
		bufStart = b.bufStart
		bufLen = b.bufLen
		fileLen = b.fileLen
		bufPos = b.bufPos
		stream = b.stream
		isUserStream = b.isUserStream
	}
	
	public func Read () -> Int {
        let returnVal : Int
		if bufPos < bufLen {
            returnVal = Int(buf[bufPos]); bufPos += 1
		} else if Pos < fileLen {
			returnVal = Int(buf[bufPos]); bufPos += 1
		} else if !stream.CanSeek && ReadNextStreamChunk() > 0 {
			returnVal = Int(buf[bufPos]); bufPos += 1
		} else {
			returnVal = Buffer.EOF
		}
        return returnVal
	}
	
	public func Peek () -> Int {
		let curPos = Pos
		let ch = Read()
		Pos = curPos
		return ch
	}
	
	// beg .. begin, zero-based, inclusive, in byte
	// end .. end, zero-based, exclusive, in byte
	public func GetString (_ beg: Int, end: Int) -> String {
		var len = 0
		var buf = [CChar](repeating: 0, count: end-beg+1)
		let oldPos = Pos
		Pos = beg
        while Pos < end { buf[len] = CChar(Read()); len += 1 }
		Pos = oldPos
		return String(cString: buf)
	}
	
	public var Pos: Int {
		get { return bufPos + bufStart }
		set {
			if newValue >= fileLen && !stream.CanSeek {
				// Wanted position is after buffer and the stream
				// is not seek-able e.g. network or console,
				// thus we have to read the stream manually till
				// the wanted position is in sight.
				while newValue >= fileLen && ReadNextStreamChunk() > 0 {}
			}
			
			if newValue < 0 || newValue > fileLen {
				assert(true, "buffer out of bounds access, position: \(newValue)")
			}
			
			if (newValue >= bufStart && newValue < bufStart + bufLen) { // already in buffer
				bufPos = newValue - bufStart
				//			} else if (stream != null) { // must be swapped in
				//				stream.Seek(value, SeekOrigin.Begin);
				//				bufLen = stream.Read(buf, 0, buf.Length);
				//				bufStart = newValue; bufPos = 0;
			} else {
				// set the position to the end of the file, Pos will return fileLen.
				bufPos = fileLen - bufStart
			}
		}
	}
	
	// Read the next chunk of bytes from the stream, increases the buffer
	// if needed and updates the fields fileLen and bufLen.
	// Returns the number of bytes read.
	private func ReadNextStreamChunk() -> Int {
		let free = buf.count - bufLen
		var read = 0
		if free == 0 {
			// in the case of a growing input stream
			// we can neither seek in the stream, nor can we
			// foresee the maximum length, thus we must adapt
			// the buffer size on demand.
			var newBuf = [UInt8](repeating: 0, count:bufLen * 2)  // [bufLen * 2];
			newBuf[0..<bufLen] = buf[0..<bufLen]
			read = stream.read(&buf, maxLength:bufLen)
			newBuf[bufLen..<bufLen*2] = buf[0..<bufLen]
			buf = newBuf
		} else {
			read = stream.read(&buf, maxLength:free)
		}
		if read > 0 {
			bufLen = (bufLen + read); fileLen = bufLen
			return read
		}
		// end of stream reached
		return 0
	}
}

//-----------------------------------------------------------------------------------
// UTF8Buffer
//-----------------------------------------------------------------------------------
public class UTF8Buffer: Buffer {
	
	public override func Read() -> Int {
		var ch: Int
		repeat {
			ch = super.Read()
			// until we find a utf8 start (0xxxxxxx or 11xxxxxx)
		} while ch >= 128 && (ch & 0xC0) != 0xC0 && ch != Character(Buffer.EOF)
		if ch < 128 || ch == Character(Buffer.EOF) {
			// nothing to do, first 127 chars are the same in ascii and utf8
			// 0xxxxxxx or end of file character
		} else if (ch & 0xF0) == 0xF0 {
			// 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
			let c1 = ch & 0x07; ch = super.Read()
			let c2 = ch & 0x3F; ch = super.Read()
			let c3 = ch & 0x3F; ch = super.Read()
			let c4 = ch & 0x3F
			ch = (((((c1 << 6) | c2) << 6) | c3) << 6) | c4
		} else if (ch & 0xE0) == 0xE0 {
			// 1110xxxx 10xxxxxx 10xxxxxx
			let c1 = ch & 0x0F; ch = super.Read()
			let c2 = ch & 0x3F; ch = super.Read()
			let c3 = ch & 0x3F
			ch = (((c1 << 6) | c2) << 6) | c3;
		} else if (ch & 0xC0) == 0xC0 {
			// 110xxxxx 10xxxxxx
			let c1 = ch & 0x1F; ch = super.Read()
			let c2 = ch & 0x3F
			ch = (c1 << 6) | c2
		}
		return ch
	}
}


//-----------------------------------------------------------------------------------
// Scanner
//-----------------------------------------------------------------------------------
public class Scanner {
	let EOL : Character = "\n"
	let eofSym = 0 /* pdt */
	let maxT = 28
	let noSym = 28


	var buffer: Buffer?			// scanner buffer
	
	var t = Token()				// current token
	var ch: Character = "\0"    // current input character
	var pos = 0					// byte position of current character
	var charPos = 0				// position by unicode characters starting with 0
	var col = 0					// column number of current character
	var line = 0				// line number of current character
	var oldEols = 0				// EOLs that appeared in a comment;
	static var start: [Int: Int] { // maps first token character to start state
		var result = [Int: Int]()
		for i in 48...57 { result[i] = 1 }
		result[45] = 4
		result[43] = 5
		result[94] = 6
		result[37] = 7
		result[42] = 8
		result[47] = 9
		result[97] = 33
		result[40] = 12
		result[41] = 13
		result[115] = 34
		result[99] = 35
		result[116] = 36
		result[108] = 20
		result[101] = 23
		result[112] = 31
		result[Buffer.EOF] = -1

		return result
	}

	var tokens = Token()  // list of tokens already peeked (first token is a dummy)
	var pt = Token()      // current peek token
	
	var tval = ""		  // text of current token
	var tlen = 0          // length of current token
	
	public init(fileName: String) {
		if let stream = InputStream(fileAtPath: fileName) {
			stream.open()
			if stream.hasBytesAvailable {
                buffer = UTF8Buffer(s:stream, isUserStream: false)
			} else {
				assert(false, "Cannot open file " + fileName)
			}
		} else {
			assert(false, "Cannot open file " + fileName)
		}
		Init()
	}
	
	public init (s: InputStream) {
        s.open()
        if s.hasBytesAvailable {
            buffer = UTF8Buffer(s:s, isUserStream: true)
		} else {
			assert(false, "Cannot open user stream")
		}
		Init()
	}
	
	func Init() {
		pos = -1; line = 1; col = 0; charPos = -1
		oldEols = 0
		NextCh()
		if ch == "\u{0EF}" { // check optional byte order mark for UTF-8
			NextCh(); let ch1 = ch
			NextCh(); let ch2 = ch
			if ch1 != "\u{0BB}" || ch2 != "\u{0BF}" {
				assert(false, "illegal byte order mark: EF \(ch1) \(ch2)")
			}
			buffer = UTF8Buffer(b: buffer!); col = 0; charPos = -1
			NextCh()
		}
		tokens = Token(); pt = tokens  // first token is a dummy
	}
	
	func NextCh() {
		if oldEols > 0 {
			ch = EOL; oldEols -= 1
		} else {
			let nl: Character = "\n"
			pos = buffer!.Pos
			// buffer reads unicode chars, if UTF8 has been detected
			ch = Character(buffer!.Read()); col += 1; charPos += 1
			// replace isolated "\r" by "\n" in order to make
			// eol handling uniform across Windows, Unix and Mac
			if ch == "\r" && buffer!.Peek() != nl.unicodeValue { ch = EOL }
			if ch == EOL { line += 1; col = 0 }
		}

	}

	func AddCh() {
		if ch != Character(Buffer.EOF) {
			tval.append(ch)
			NextCh()
		}
	}



	func CheckLiteral() {
		switch t.val {
			default: break
		}
	}

	func NextToken() -> Token {
		while ch == " " ||
			ch >= "\t" && ch <= "\n" || ch == "\r" || ch == " "
		{ NextCh() }

		var recKind = noSym
		var recEnd = pos
		t = Token()
		t.pos = pos; t.col = col; t.line = line; t.charPos = charPos
		var state = Scanner.start[ch.unicodeValue] ?? 0
		tval = ""; AddCh()
		
		loop: repeat {
			switch state {
			case -1: t.kind = eofSym; break loop // NextCh already done
			case 0:
				if recKind != noSym {
					tlen = recEnd - t.pos
					SetScannerBehindT()
				}
				t.kind = recKind; break loop
				// NextCh already done
			case 1:
				recEnd = pos; recKind = 1
				if ch >= "0" && ch <= "9" { AddCh(); state = 1 }
				else if ch == "." { AddCh(); state = 2 }
				else { t.kind = 1; break loop }
			case 2:
				if ch >= "0" && ch <= "9" { AddCh(); state = 3 }
				else { state = 0 }
			case 3:
				recEnd = pos; recKind = 1
				if ch >= "0" && ch <= "9" { AddCh(); state = 3 }
				else { t.kind = 1; break loop }
			case 4:
				 t.kind = 2; break loop 
			case 5:
				 t.kind = 3; break loop 
			case 6:
				 t.kind = 4; break loop 
			case 7:
				 t.kind = 5; break loop 
			case 8:
				 t.kind = 6; break loop 
			case 9:
				 t.kind = 7; break loop 
			case 10:
				if ch == "s" { AddCh(); state = 11 }
				else { state = 0 }
			case 11:
				 t.kind = 8; break loop 
			case 12:
				 t.kind = 9; break loop 
			case 13:
				 t.kind = 10; break loop 
			case 14:
				 t.kind = 17; break loop 
			case 15:
				 t.kind = 18; break loop 
			case 16:
				 t.kind = 19; break loop 
			case 17:
				 t.kind = 20; break loop 
			case 18:
				 t.kind = 21; break loop 
			case 19:
				 t.kind = 22; break loop 
			case 20:
				if ch == "o" { AddCh(); state = 21 }
				else { state = 0 }
			case 21:
				if ch == "g" { AddCh(); state = 22 }
				else { state = 0 }
			case 22:
				 t.kind = 23; break loop 
			case 23:
				if ch == "x" { AddCh(); state = 24 }
				else { state = 0 }
			case 24:
				if ch == "p" { AddCh(); state = 25 }
				else { state = 0 }
			case 25:
				 t.kind = 24; break loop 
			case 26:
				if ch == "r" { AddCh(); state = 27 }
				else { state = 0 }
			case 27:
				if ch == "t" { AddCh(); state = 28 }
				else { state = 0 }
			case 28:
				 t.kind = 25; break loop 
			case 29:
				if ch == "n" { AddCh(); state = 30 }
				else { state = 0 }
			case 30:
				 t.kind = 26; break loop 
			case 31:
				if ch == "i" { AddCh(); state = 32 }
				else { state = 0 }
			case 32:
				 t.kind = 27; break loop 
			case 33:
				if ch == "b" { AddCh(); state = 10 }
				else if ch == "s" { AddCh(); state = 37 }
				else if ch == "c" { AddCh(); state = 38 }
				else if ch == "t" { AddCh(); state = 39 }
				else { state = 0 }
			case 34:
				if ch == "i" { AddCh(); state = 40 }
				else if ch == "q" { AddCh(); state = 26 }
				else { state = 0 }
			case 35:
				if ch == "o" { AddCh(); state = 41 }
				else { state = 0 }
			case 36:
				if ch == "a" { AddCh(); state = 42 }
				else { state = 0 }
			case 37:
				if ch == "i" { AddCh(); state = 43 }
				else { state = 0 }
			case 38:
				if ch == "o" { AddCh(); state = 44 }
				else { state = 0 }
			case 39:
				if ch == "a" { AddCh(); state = 45 }
				else { state = 0 }
			case 40:
				if ch == "n" { AddCh(); state = 46 }
				else if ch == "g" { AddCh(); state = 29 }
				else { state = 0 }
			case 41:
				if ch == "s" { AddCh(); state = 47 }
				else { state = 0 }
			case 42:
				if ch == "n" { AddCh(); state = 48 }
				else { state = 0 }
			case 43:
				if ch == "n" { AddCh(); state = 49 }
				else { state = 0 }
			case 44:
				if ch == "s" { AddCh(); state = 50 }
				else { state = 0 }
			case 45:
				if ch == "n" { AddCh(); state = 51 }
				else { state = 0 }
			case 46:
				recEnd = pos; recKind = 11
				if ch == "h" { AddCh(); state = 14 }
				else { t.kind = 11; break loop }
			case 47:
				recEnd = pos; recKind = 12
				if ch == "h" { AddCh(); state = 15 }
				else { t.kind = 12; break loop }
			case 48:
				recEnd = pos; recKind = 13
				if ch == "h" { AddCh(); state = 16 }
				else { t.kind = 13; break loop }
			case 49:
				recEnd = pos; recKind = 14
				if ch == "h" { AddCh(); state = 17 }
				else { t.kind = 14; break loop }
			case 50:
				recEnd = pos; recKind = 15
				if ch == "h" { AddCh(); state = 18 }
				else { t.kind = 15; break loop }
			case 51:
				recEnd = pos; recKind = 16
				if ch == "h" { AddCh(); state = 19 }
				else { t.kind = 16; break loop }

			default: break loop
			}
		} while true
		t.val = tval
		return t
	}

	private func SetScannerBehindT() {
		buffer!.Pos = t.pos
		NextCh()
		line = t.line; col = t.col; charPos = t.charPos
		for _ in 0..<tlen { NextCh() }
	}
	
	// get the next token (possibly a token already seen during peeking)
	public func Scan () -> Token {
		if tokens.next == nil {
			return NextToken()
		} else {
			tokens = tokens.next!; pt = tokens
			return tokens
		}
	}
	
	// peek for the next token, ignore pragmas
	public func Peek () -> Token {
		repeat {
			if pt.next == nil {
				pt.next = NextToken()
			}
			pt = pt.next!
		} while pt.kind > maxT // skip pragmas		
		return pt
	}
	
	// make sure that peeking starts at the current scan position
	public func ResetPeek () { pt = tokens }

} // end Scanner

