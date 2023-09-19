// RUN: %empty-directory(%t)
// RUN: %target-swift-frontend -target arm64-apple-none-macho -Xcc -D__MACH__ -Xcc -D__arm64__ -Xcc -D__APPLE__ \
// RUN:   -enable-experimental-feature Embedded -enforce-exclusivity=none %s -c -o %t/a.o
// RUN: %target-clang %t/a.o -o %t/a.out
// RUN: %target-run %t/a.out | %FileCheck %s

// REQUIRES: executable_test
// REQUIRES: VENDOR=apple
// REQUIRES: CPU=arm64

@_silgen_name("putchar")
func putchar(_: UInt8)

public func print(_ s: StaticString, terminator: StaticString = "\n") {
  var p = s.utf8Start
  while p.pointee != 0 {
    putchar(p.pointee)
    p += 1
  }
  p = terminator.utf8Start
  while p.pointee != 0 {
    putchar(p.pointee)
    p += 1
  }
}

@_silgen_name("vprintf")
func vprintf(_: UnsafePointer<UInt8>, _: UnsafeRawPointer)

var global: Int = 0
public func print(_ n: Int) {
    let f: StaticString = "%d\n"
    global = n
    vprintf(f.utf8Start, &global)
}

@_silgen_name("malloc")
func malloc(_: Int) -> UnsafeMutableRawPointer

struct Bytes<T>: Collection {
    var storage: UnsafeMutableBufferPointer<T>
    var size: Int
    init(size: Int, initialValue: T) {
        self.storage = .init(start: malloc(MemoryLayout<T>.stride * size).assumingMemoryBound(to: T.self), count: size)
        self.storage.initialize(repeating: initialValue)
        self.size = size
    }
    
    func index(after i: Int) -> Int {
        return i + 1
    }
    
    subscript(position: Int) -> T {
        get {
            return storage[position]
        }
        set(newValue) {
            storage[position] = newValue
        }
    }
    
    public subscript(bounds: Range<Index>) -> SubSequence {
        get { fatalError() }
        set { fatalError() }
    }
    
    var startIndex: Int { return 0 }
    
    var endIndex: Int { return size }
    
    typealias Element = T
    
    typealias Index = Int
    
    typealias SubSequence = Bytes
}

func foo() {
    var bytes = Bytes<Int>(size: 10, initialValue: 0)
    bytes[4] = 42
    bytes[2] = 22
    bytes[6] = 13
    bytes[6] = 15
    bytes[8] = 9
    bytes[9] = -1
    print(bytes[0]) // CHECK: 0
    print(bytes.max()!)// CHECK: 42
    print(bytes.min()!) // CHECK: -1
}

foo()