import streams, endians, macros

type
  BitStream* = ref object
    stream: Stream
    buffer: uint64
    bitsLeft: int

template getMaskOnes(n: int): uint64 =
  if n == 64: 0xFFFFFFFFFFFFFFFF'u64
  else: (1'u64 shl n) - 1

proc newFileBitStream*(f: File): BitStream =
  BitStream(stream: newFileStream(f), buffer: 0, bitsLeft: 0)

proc newFileBitStream*(f: string; mode = fmRead; size = -1): BitStream =
  BitStream(stream: newFileStream(f, mode, size), buffer: 0, bitsLeft: 0)

proc newStringBitStream*(s = ""): BitStream =
  BitStream(stream: newStringStream(s), buffer: 0, bitsLeft: 0)

proc close*(bs: BitStream) = close(bs.stream)
proc atEnd*(bs: BitStream): bool = atEnd(bs.stream) and bs.bitsLeft == 0
proc getPosition*(bs: BitStream): int = getPosition(bs.stream)
template pos*(bs: BitStream): int = getPosition(bs)
proc setPosition*(bs: BitStream, n: int) = setPosition(bs.stream, n)
template seek*(bs: BitStream, n: int) = setPosition(bs, n)
proc skip*(bs: BitStream, n: int) = bs.seek(pos(bs) + n)
proc readAll*(bs: BitStream): string = readAll(bs.stream)
proc isAligned*(bs: BitStream): bool = bs.bitsLeft == 0
proc align*(bs: BitStream) =
  bs.buffer = 0
  bs.bitsLeft = 0

proc readBitsBe*(bs: BitStream, n: int): uint64 =
  let bitsNeeded = n - bs.bitsLeft
  if bitsNeeded > 0:
    var bytesNeeded = ((bitsNeeded - 1) div 8) + 1;
    var buf: array[8, byte]
    doAssert bs.stream.readData(addr(buf), bytesNeeded) == bytesNeeded
    for i in 0 ..< bytesNeeded:
      bs.buffer = bs.buffer shl 8
      bs.buffer = bs.buffer or buf[i]
      inc(bs.bitsLeft, 8)
  let
    mask = getMaskOnes(n)
    shiftBits = bs.bitsLeft - n
  result = (bs.buffer shr shiftBits) and mask
  dec(bs.bitsLeft, n)
  bs.buffer = bs.buffer and getMaskOnes(bs.bitsLeft)

proc readBitsLe*(bs: BitStream, n: int): uint64 =
  let bitsNeeded = n - bs.bitsLeft
  if bitsNeeded > 0:
    var bytesNeeded = ((bitsNeeded - 1) div 8) + 1;
    var buf: array[8, byte]
    doAssert bs.stream.readData(addr(buf), bytesNeeded) == bytesNeeded
    for i in 0 ..< bytesNeeded:
      bs.buffer = bs.buffer or (uint64(buf[i]) shl bs.bitsLeft)
      inc(bs.bitsLeft, 8)
  let mask = getMaskOnes(n)
  result = bs.buffer and mask
  bs.buffer = bs.buffer shr n
  dec(bs.bitsLeft, n)

proc readS8*(bs: BitStream): int8 = readInt8(bs.stream)

when system.cpuEndian == bigEndian:
  proc readS16Be*(bs: BitStream): int16 = readInt16(bs.stream)
  proc readS32Be*(bs: BitStream): int32 = readInt32(bs.stream)
  proc readS64Be*(bs: BitStream): int64 = readInt64(bs.stream)

  proc readS16Le*(bs: BitStream): int16 =
    var
      bufferIn: array[2, byte]
      bufferOut: array[2, byte]
    doAssert bs.stream.readData(addr(bufferIn), 2) == 2
    swapEndian16(addr(bufferOut), addr(bufferIn))
    result = cast[int16](bufferOut)

  proc readS32Le*(bs: BitStream): int32 =
    var
      bufferIn: array[4, byte]
      bufferOut: array[4, byte]
    doAssert bs.stream.readData(addr(bufferIn), 4) == 4
    swapEndian32(addr(bufferOut), addr(bufferIn))
    result = cast[int32](bufferOut)

  proc readS64Le*(bs: BitStream): int64 =
    var
      bufferIn: array[8, byte]
      bufferOut: array[8, byte]
    doAssert bs.stream.readData(addr(bufferIn), 8) == 8
    swapEndian64(addr(bufferOut), addr(bufferIn))
    result = cast[int64](bufferOut)
else:
  proc readS16Be*(bs: BitStream): int16 =
    var
      bufferIn: array[2, byte]
      bufferOut: array[2, byte]
    doAssert bs.stream.readData(addr(bufferIn), 2) == 2
    swapEndian16(addr(bufferOut), addr(bufferIn))
    result = cast[int16](bufferOut)

  proc readS32Be*(bs: BitStream): int32 =
    var
      bufferIn: array[4, byte]
      bufferOut: array[4, byte]
    doAssert bs.stream.readData(addr(bufferIn), 4) == 4
    swapEndian32(addr(bufferOut), addr(bufferIn))
    result = cast[int32](bufferOut)

  proc readS64Be*(bs: BitStream): int64 =
    var
      bufferIn: array[8, byte]
      bufferOut: array[8, byte]
    doAssert bs.stream.readData(addr(bufferIn), 8) == 8
    swapEndian64(addr(bufferOut), addr(bufferIn))
    result = cast[int64](bufferOut)

  proc readS16Le*(bs: BitStream): int16 = readInt16(bs.stream)
  proc readS32Le*(bs: BitStream): int32 = readInt32(bs.stream)
  proc readS64Le*(bs: BitStream): int64 = readInt64(bs.stream)

proc readU8*(bs: BitStream): uint8 = readUint8(bs.stream)

when system.cpuEndian == bigEndian:
  proc readU16Be*(bs: BitStream): uint16 = readUint16(bs.stream)
  proc readU32Be*(bs: BitStream): uint32 = readUint32(bs.stream)
  proc readU64Be*(bs: BitStream): uint64 = readUint64(bs.stream)

  proc readU16Le*(bs: BitStream): uint16 =
    var
      bufferIn: array[2, byte]
      bufferOut: array[2, byte]
    doAssert bs.stream.readData(addr(bufferIn), 2) == 2
    swapEndian16(addr(bufferOut), addr(bufferIn))
    result = cast[uint16](bufferOut)

  proc readU32Le*(bs: BitStream): uint32 =
    var
      bufferIn: array[4, byte]
      bufferOut: array[4, byte]
    doAssert bs.stream.readData(addr(bufferIn), 4) == 4
    swapEndian32(addr(bufferOut), addr(bufferIn))
    result = cast[uint32](bufferOut)

  proc readU64Le*(bs: BitStream): uint64 =
    var
      bufferIn: array[8, byte]
      bufferOut: array[8, byte]
    doAssert bs.stream.readData(addr(bufferIn), 8) == 8
    swapEndian64(addr(bufferOut), addr(bufferIn))
    result = cast[uint64](bufferOut)
else:
  proc readU16Be*(bs: BitStream): uint16 =
    var
      bufferIn: array[2, byte]
      bufferOut: array[2, byte]
    doAssert bs.stream.readData(addr(bufferIn), 2) == 2
    swapEndian16(addr(bufferOut), addr(bufferIn))
    result = cast[uint16](bufferOut)

  proc readU32Be*(bs: BitStream): uint32 =
    var
      bufferIn: array[4, byte]
      bufferOut: array[4, byte]
    doAssert bs.stream.readData(addr(bufferIn), 4) == 4
    swapEndian32(addr(bufferOut), addr(bufferIn))
    result = cast[uint32](bufferOut)

  proc readU64Be*(bs: BitStream): uint64 =
    var
      bufferIn: array[8, byte]
      bufferOut: array[8, byte]
    doAssert bs.stream.readData(addr(bufferIn), 8) == 8
    swapEndian64(addr(bufferOut), addr(bufferIn))
    result = cast[uint64](bufferOut)

  proc readU16Le*(bs: BitStream): uint16 = readUint16(bs.stream)
  proc readU32Le*(bs: BitStream): uint32 = readUint32(bs.stream)
  proc readU64Le*(bs: BitStream): uint64 = readUint64(bs.stream)

# Floating point numbers
when system.cpuEndian == bigEndian:
  proc readF32Be*(bs: BitStream): float32 = readFloat32(bs.stream)
  proc readF64Be*(bs: BitStream): float64 = readFloat64(bs.stream)

  proc readF32Le*(bs: BitStream): float32 =
    var
      bufferIn: array[4, byte]
      bufferOut: array[4, byte]
    doAssert bs.stream.readData(addr(bufferIn), 4) == 4
    swapEndian32(addr(bufferOut), addr(bufferIn))
    result = cast[float32](bufferOut)

  proc readF64Le*(bs: BitStream): float64 =
    var
      bufferIn: array[8, byte]
      bufferOut: array[8, byte]
    doAssert bs.stream.readData(addr(bufferIn), 8) == 8
    swapEndian64(addr(bufferOut), addr(bufferIn))
    result = cast[float64](bufferOut)
else:
  proc readF32Be*(bs: BitStream): float32 =
    var
      bufferIn: array[4, byte]
      bufferOut: array[4, byte]
    doAssert bs.stream.readData(addr(bufferIn), 4) == 4
    swapEndian32(addr(bufferOut), addr(bufferIn))
    result = cast[float32](bufferOut)

  proc readF64Be*(bs: BitStream): float64 =
    var
      bufferIn: array[8, byte]
      bufferOut: array[8, byte]
    doAssert bs.stream.readData(addr(bufferIn), 8) == 8
    swapEndian64(addr(bufferOut), addr(bufferIn))
    result = cast[float64](bufferOut)

  proc readF32Le*(bs: BitStream): float32 = readFloat32(bs.stream)
  proc readF64Le*(bs: BitStream): float64 = readFloat64(bs.stream)

template readAligned*(bs: BitStream; typ, endian: char; size: int) =
  if typ notin {'u', 's', 'f'}:
    raise newException(Defect, "Valid types are: 'u', 's', 'f'")
  if endian notin {'l', 'b'}:
    raise newException(Defect, "Valid endians are: 'l', 'b'")
  if size notin {8, 16, 32, 64}:
    raise newException(Defect, "Valid sizes are: 8, 16, 32, 64")
  if typ == 'f' and size notin {32, 64}:
    raise newException(Defect, "Valid sizes for floats are: 32, 64")
  let p = ident("read" & typ & $size & (if size != 8: endian & "e" else: ""))
  result = quote do: `p`(bs)

proc readStr*(bs: BitStream): string =
  while true:
    let c = readChar(bs.stream)
    if c == '\0': break
    result.add(c)

proc readStr*(bs: BitStream, n: int): string =
  if n mod 8 != 0:
    raise newException(Defect, "String reads must be byte-aligned")
  readStr(bs.stream, n div 8)