# bitstreams
Interface for reading/writing per bits

## How it works
This module is a wrapper around stdlib's streams module.
```nim
type
  BitStream* = ref object
    stream: Stream
    buffer: uint64
    bitsLeft: int
```
`bitsLeft` keeps track of how many bits in `buffer` are not _read_ by the end-user, then:
- if they are more than the user requests, then no _real_ read happens on `steam`
- if they are less than the user requests, data are read from `stream` into `buffer`

## Constructor & Modes
Only the following constructor is provided:
```nim
proc newFileBitStream*(f: string; mode = fmRead; size = -1): BitStream
```
`fmWrite` and `fmAppend` are disallowed because when writing to a bitstream, reads on the underlying `Stream` object are necessary.