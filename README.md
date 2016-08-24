# ByteBuffer

An IO object superficially similar to Crystal's [MemoryIO](https://crystal-lang.org/api/MemoryIO.html) but meant to behave more like Java's nio.ByteBuffer.

## Installation


Add this to your application's `shard.yml`:

```yaml
dependencies:
  byte_buffer:
    github: Exilor/byte_buffer
```


## Usage


```crystal
require "byte_buffer"
```


**Constructors**
```crystal
# A ByteBuffer with a capacity of 64 bytes.
ByteBuffer.new(64)

# A ByteBuffer that wraps an existing Slice(UInt8). Operations on the ByteBuffer
# will be reflected on the slice.
slice = Slice.new(32, 0_u8)
ByteBuffer.new(slice)
```

**Properties**
- *capacity*: The number of bytes it can store. This value is set at creation and cannot be changed.
- *position*: The index at which new data will be written to or read from.
- *limit*: The index that marks the point from which data can't be further written or read.
- *mark*: An optional stored position that the ByteBuffer can later return to.
- *order*: The byte order (endianness). An [IO::ByteFormat](https://crystal-lang.org/api/IO/ByteFormat.html) object that by default is [IO::ByteFormat::SystemEndian](https://crystal-lang.org/api/IO/ByteFormat/SystemEndian.html).

**Writing**
```crystal
# Assuming little endian byte order.
bb = ByteBuffer.new(16) #   0,  0,  0,   0, 0,   0,  0,   0,   0,   0,  0,   0,   0,   0,  0, 0
bb.capacity # => 16
bb.limit # => 16
bb.position # => 0

bb.write 123_i8         # 123,  0,  0,   0, 0,   0,  0,   0,   0,   0,  0,   0,   0,   0,  0, 0
bb.position # => 1

bb.write 12345_i16      # 123, 57, 48,   0, 0,   0,  0,   0,   0,   0,  0,   0,   0,   0,  0, 0
bb.position # => 3

bb.write 1234567890_u32 # 123, 57, 48, 210, 2, 150, 73,   0,   0,   0,  0,   0,   0,   0,  0, 0
bb.position # => 7

bb.write 1.2345_f64     # 123, 57, 48, 210, 2, 150, 73, 141, 151, 110, 18, 131, 192, 243, 63, 0
bb.position # => 15

bb.write 5_u8           # 123, 57, 48, 210, 2, 150, 73, 141, 151, 110, 18, 131, 192, 243, 63, 5
bb.position # => 16

bb.write 6_u8 # => buffer is full (IO::Error)
```

**Reading**
```crystal
# Continuing from the example on writing.

# The limit is set to the position and the position is set to 0.
bb.flip
bb.position # => 0
bb.limit # => 16

bb.read # => 123_u8
bb.position # => 1

bb.read Int16 # => 12345_i16
bb.position # => 3

bb.read Int32 # => 1234567890_i32
bb.position # => 7

bb.read Float64 # => 1.2345_f64
bb.position # => 15

bb.read(Int8) # => 5_i8
bb.position # => 16

bb.read # => end of file reached (IO::EOFError)
```

**Changing the byte order**
```crystal
bb = ByteBuffer.new(1)
bb.order # => IO::ByteOrder::LittleEndian
bb.order = IO::ByteOrder::BigEndian
```

More information on the [wiki]

## Contributing

1. Fork it ( https://github.com/Exilor/byte_buffer/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request
