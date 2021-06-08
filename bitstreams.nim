import streams, endians, bitops, algorithm, macros

type
  BitStream* = ref object
    stream: Stream
    buffer: uint64
    bitsLeft: int

proc newFileBitStream*(f: string; mode = fmRead; size = -1): BitStream =
  if mode in {fmWrite, fmAppend}:
    raise newException(Defect, "This mode is not supported for bitstreams")
  result = BitStream(stream: newFileStream(f, mode, size), buffer: 0, bitsLeft: 0)

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
proc resetBuffer*(bs: BitStream) =
  bs.buffer = 0
  bs.bitsLeft = 0

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

proc readS8*(bs: BitStream): int8 =
  readInt8(bs.stream)

proc readS16Be*(bs: BitStream): int16 =
  var x = readInt16(bs.stream)
  bigEndian16(addr result, addr x)

proc readS32Be*(bs: BitStream): int32 =
  var x = readInt32(bs.stream)
  bigEndian32(addr result, addr x)

proc readS64Be*(bs: BitStream): int64 =
  var x = readInt64(bs.stream)
  bigEndian64(addr result, addr x)

proc readS16Le*(bs: BitStream): int16 =
  var x = readInt16(bs.stream)
  littleEndian16(addr result, addr x)

proc readS32Le*(bs: BitStream): int32 =
  var x = readInt32(bs.stream)
  littleEndian32(addr result, addr x)

proc readS64Le*(bs: BitStream): int64 =
  var x = readInt64(bs.stream)
  littleEndian64(addr result, addr x)

proc readU8*(bs: BitStream): uint8 =
  readUint8(bs.stream)

proc readU16Be*(bs: BitStream): uint16 =
  var x = readUint16(bs.stream)
  bigEndian16(addr result, addr x)

proc readU32Be*(bs: BitStream): uint32 =
  var x = readUint32(bs.stream)
  bigEndian32(addr result, addr x)

proc readU64Be*(bs: BitStream): uint64 =
  var x = readUint64(bs.stream)
  bigEndian64(addr result, addr x)

proc readU16Le*(bs: BitStream): uint16 =
  var x = readUint16(bs.stream)
  littleEndian16(addr result, addr x)

proc readU32Le*(bs: BitStream): uint32 =
  var x = readUint32(bs.stream)
  littleEndian32(addr result, addr x)

proc readU64Le*(bs: BitStream): uint64 =
  var x = readUint64(bs.stream)
  littleEndian64(addr result, addr x)

proc readF32Be*(bs: BitStream): float32 =
  var x = readFloat32(bs.stream)
  bigEndian32(addr result, addr x)

proc readF64Be*(bs: BitStream): float64 =
  var x = readFloat64(bs.stream)
  bigEndian64(addr result, addr x)

proc readF32Le*(bs: BitStream): float32 =
  var x = readFloat32(bs.stream)
  littleEndian32(addr result, addr x)

proc readF64Le*(bs: BitStream): float64 =
  var x = readFloat64(bs.stream)
  littleEndian64(addr result, addr x)

proc readBitsBe*(bs: BitStream, n: int, endian = bigEndian): uint64 =
  let bitsNeeded = n - bs.bitsLeft
  if bitsNeeded > 0:
    var bytesNeeded = ((bitsNeeded - 1) div 8) + 1;
    var buf: array[8, byte]
    doAssert bs.stream.readData(addr buf, bytesNeeded) == bytesNeeded
    if endian != cpuEndian and n mod 8 == 0:
      for i in countdown(bytesNeeded - 1, 0):
        bs.buffer = bs.buffer shl 8
        bs.buffer = bs.buffer or buf[i]
        bs.bitsLeft += 8
    else:
      for i in 0 ..< bytesNeeded:
        bs.buffer = bs.buffer shl 8
        bs.buffer = bs.buffer or buf[i]
        bs.bitsLeft += 8
  result = bs.buffer shr (bs.bitsLeft - n)
  result.mask(0 ..< n)
  bs.bitsLeft -= n
  bs.buffer.mask(0 ..< bs.bitsLeft)

proc readBitsLe*(bs: BitStream, n: int, endian = bigEndian): uint64 =
  let bitsNeeded = n - bs.bitsLeft
  if bitsNeeded > 0:
    var bytesNeeded = ((bitsNeeded - 1) div 8) + 1;
    var buf: array[8, byte]
    doAssert bs.stream.readData(addr buf, bytesNeeded) == bytesNeeded
    if endian != cpuEndian and n mod 8 == 0:
      for i in countdown(bytesNeeded - 1, 0):
        bs.buffer = bs.buffer or (uint64(buf[i]) shl bs.bitsLeft)
        bs.bitsLeft += 8
    else:
      for i in 0 ..< bytesNeeded:
        bs.buffer = bs.buffer or (uint64(buf[i]) shl bs.bitsLeft)
        bs.bitsLeft += 8
  result = bs.buffer.masked(0 ..< n)
  bs.buffer = bs.buffer shr n
  bs.bitsLeft -= n

proc readStr*(bs: BitStream): string =
  while true:
    let c = readChar(bs.stream)
    if c == '\0': break
    result.add(c)

proc readStr*(bs: BitStream, n: int): string =
  if n mod 8 != 0:
    raise newException(Defect, "String reads must be byte-aligned")
  readStr(bs.stream, n div 8)

proc createSubstream*(bs: BitStream, n: int): BitStream =
  if not bs.isAligned:
    raise newException(Defect, "Cannot create substream out of unaligned stream")
  newStringBitStream(readStr(bs.stream, n))

when cpuEndian == bigEndian:
  proc writeBe*(bs: BitStream, x: SomeNumber) = write(bs.stream, x)
  proc writeLe*(bs: BitStream, x: SomeNumber) =
    var x = x
    when sizeof(x) == 1:
      write(bs.stream, x)
    elif sizeof(x) == 2:
      var swapped: array[2, byte]
      swapEndian16(addr swapped, addr x)
      writeData(bs.stream, addr swapped, 2)
    elif sizeof(x) == 4:
      var swapped: array[4, byte]
      swapEndian32(addr swapped, addr x)
      writeData(bs.stream, addr swapped, 4)
    elif sizeof(x) == 8:
      var swapped: array[8, byte]
      swapEndian64(addr swapped, addr x)
      writeData(bs.stream, addr swapped, 8)
else:
  proc writeBe*(bs: BitStream, x: SomeNumber) =
    var x = x
    when sizeof(x) == 1:
      write(bs.stream, x)
    elif sizeof(x) == 2:
      var swapped: array[2, byte]
      swapEndian16(addr swapped, addr x)
      writeData(bs.stream, addr swapped, 2)
    elif sizeof(x) == 4:
      var swapped: array[4, byte]
      swapEndian32(addr swapped, addr x)
      writeData(bs.stream, addr swapped, 4)
    elif sizeof(x) == 8:
      var swapped: array[8, byte]
      swapEndian64(addr swapped, addr x)
      writeData(bs.stream, addr swapped, 8)
  proc writeLe*(bs: BitStream, x: SomeNumber) = write(bs.stream, x)

proc writeBitsBe*(bs: BitStream, n: int, x: SomeNumber, endian = bigEndian) =
  var x = uint64(x)
  if endian != cpuEndian and n mod 8 == 0:
    var tmp: uint64
    swapEndian64(addr tmp, addr x)
    x = tmp shl (64 - n)
  var
    shift = n - bs.bitsLeft
    bytes = if shift > 0: (shift div 8 + (if shift mod 8 != 0: 1 else: 0))
            else: 0
    pos = bs.pos
  if bs.bitsLeft > 0:
    dec pos
    inc bytes
    shift += 8
  else:
    bs.bitsLeft = 8
  var buf = newSeq[byte](bytes)
  if bytes > 0:
    bs.seek(pos)
    buf[0] = if bs.stream.atEnd: 0'u8 else: bs.readU8()
  if bytes > 1:
    bs.seek(pos + (bytes - 1))
    buf[bytes - 1] = if bs.stream.atEnd: 0'u8 else: bs.readU8()
  bs.seek(pos)
  for i in 0 ..< bytes:
    shift -= 8
    let
      mask = if shift > 0: toMask[uint64](0 ..< bs.bitsLeft)
             else: toMask[uint64](0 ..< bs.bitsLeft + shift) shl (-shift)
      shifted = if shift > 0: x shr shift else: x shl (-shift)
    buf[i] = byte((buf[i] and (mask.flipMasked(0 ..< 8))) or (shifted and mask))
    if i == 0:
      bs.bitsLeft = 8
  bs.stream.writeData(addr buf[0], bytes)
  bs.bitsLeft = -shift

proc writeBitsLe*(bs: BitStream, n: int, x: SomeNumber, endian = bigEndian) =
  # for now it's assumed that data are written sequentially, which means this
  # proc will have to be modified to not override already written data at the
  # last byte
  var x = uint64(x)
  if endian != cpuEndian and n mod 8 == 0:
    var tmp: uint64
    swapEndian64(addr tmp, addr x)
    x = tmp shl (64 - n)
  let
    shift = if bs.bitsLeft mod 8 != 0: (8 - bs.bitsLeft) else: 0
    bits = shift + n
    bytes = bits div 8 + (if bits mod 8 != 0: 1 else: 0)
  x = x shl shift
  var buf = newSeq[byte](bytes)
  bs.bitsLeft = 8 - (bits mod 8)
  if shift > 0:
    # the last written byte is partial, so we need to fetch it, modify it, and
    # write it back
    bs.skip(-1)
    buf[0] = if bs.stream.atEnd: 0'u8 else: bs.readU8()
    bs.skip(-1)
  for i in 0 ..< bytes:
    buf[i] = buf[i] or byte(x)
    x = x shr 8
    if bs.bitsLeft >= 8:
      bs.bitsLeft -= 8
  bs.stream.writeData(addr buf[0], bytes)

proc writeStr*(bs: BitStream, s: string) =
  write(bs.stream, s)

proc writeTermStr*(bs: BitStream, s: string, term = '\0') =
  write(bs.stream, s)
  write(bs.stream, term)

proc writeZeroBytes*(bs: BitStream, n: int) =
  for i in 0 ..< n:
    bs.stream.write(0'u8)

proc writeFromSubstream*(s, ss: BitStream; n: int) =
  if not s.isAligned:
    raise newException(Defect,
      "Cannot write from a substream to an unaligned stream")
  if not ss.isAligned:
    raise newException(Defect,
      "Cannot write an unaligned substream")
  s.writeStr(ss.readStr(8*n))

proc newPaddedBitStream*(padding: int): BitStream =
  result = BitStream(stream: newStringStream(), buffer: 0, bitsLeft: 0)
  result.writeZeroBytes(padding)
  result.seek(0)
