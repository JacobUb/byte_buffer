require "./spec_helper"

describe ByteBuffer do
  describe "initialize" do
    it "creates a new ByteBuffer with the given capacity" do
      bb = ByteBuffer.new(7)
      bb.capacity.should eq(7)

      bb = ByteBuffer.new(1)
      bb.capacity.should eq(1)
    end

    it "raises if capacity is less than zero" do
      expect_raises(ArgumentError, "negative capacity") { ByteBuffer.new(-1) }
    end

    it "its starting position is zero" do
      bb = ByteBuffer.new(3)
      bb.position.should eq(0)
    end

    it "its limit starts equal to its capacity" do
      bb = ByteBuffer.new(3)
      bb.limit.should eq(3)
    end

    it "its mark starts as undefined" do
      bb = ByteBuffer.new(5)
      bb.mark.should eq(-1)
    end

    it "a new instance has a limit equal to its capacity" do
      bb = ByteBuffer.new(3)
      bb.limit.should eq(bb.capacity)
    end

    it "wraps an existing Slice(UInt8)" do
      slice = byte_slice(1, 2, 3)
      bb = ByteBuffer.new(slice)
      bb.to_slice.should eq(slice)
    end
  end

  describe "zero" do
    it "sets the contents of the buffer to zero" do
      bb = ByteBuffer.new(byte_slice 1..4)
      bb.zero.to_slice.should eq(byte_slice 0, 0, 0, 0)
    end

    it "works with offset and size (1)" do
      bb = ByteBuffer.new(byte_slice 1..4)
      bb.zero(1, 2).to_slice.should eq(byte_slice 1, 0, 0, 4)
    end

    it "works with offset and size (2)" do
      bb = ByteBuffer.new(byte_slice 1..4)
      bb.zero(0, 4).to_slice.should eq(byte_slice 0, 0, 0, 0)
    end

    it "works with a range (1)" do
      bb = ByteBuffer.new(byte_slice 1..4)
      bb.zero(1..2).to_slice.should eq(byte_slice 1, 0, 0, 4)
    end

    it "works with a range (2)" do
      bb = ByteBuffer.new(byte_slice 1..4)
      bb.zero(0..2).to_slice.should eq(byte_slice 0, 0, 0, 4)
    end

    it "works with a range (3)" do
      bb = ByteBuffer.new(byte_slice 1..4)
      bb.zero(0...4).to_slice.should eq(byte_slice 0, 0, 0, 0)
    end

    it "raises if out of bounds" do
      bb = ByteBuffer.new(byte_slice 1..4)
      expect_raises(IndexError) { bb.zero(0..4) }
      expect_raises(IndexError) { bb.zero(1..4) }
      expect_raises(IndexError) { bb.zero(0, 5) }
      expect_raises(IndexError) { bb.zero(1, 4) }
      expect_raises(IndexError) { bb.zero(5, 1) }
    end
  end

  describe "write(Slice(UInt8))" do
    it "copies the contents of the slice into the buffer" do
      bb = ByteBuffer.new(10)
      slice = byte_slice(0..9)
      bb.write slice
      bb.@buffer.to_slice(10).should eq(slice)
    end

    it "the position is advanced accordingly (1)" do
      bb = ByteBuffer.new(10)
      slice = byte_slice(0..5)
      bb.write slice
      bb.position.should eq(6)
    end

    it "the position is advanced accordingly (2)" do
      bb = ByteBuffer.new(8)
      slice = byte_slice(0..1)
      bb.write slice
      slice = byte_slice(2..3)
      bb.write slice
      slice = byte_slice(4..7)
      bb.write slice
      slice = byte_slice(0..7)
      bb.@buffer.to_slice(8).should eq(slice)
    end

    it "raises if the buffer can't accomodate all the bytes in the slice" do
      bb = ByteBuffer.new(5)
      slice = byte_slice(0..5)
      expect_raises(IO::Error, "buffer is full") { bb.write slice }
    end
  end

  describe "read(Slice(UInt8))" do
    it "fills the slice with the buffer's data" do
      slice = byte_slice(0..9)
      bb = ByteBuffer.new(slice)
      slice = byte_slice([0] * 6)
      bb.read slice
      slice.should eq(byte_slice(0..5))
    end
  end

  describe "relative write" do
    it "writes a number in big endian order" do
      bb = ByteBuffer.new(4)
      bb.order = IO::ByteFormat::BigEndian
      bb.write 1234567890
      bb.to_slice.to_a.should eq([73, 150, 2, 210])
    end

    it "writes a number in little endian order" do
      bb = ByteBuffer.new(4)
      bb.order = IO::ByteFormat::LittleEndian
      bb.write 1234567890
      bb.to_slice.to_a.should eq([210, 2, 150, 73])
    end

    it "writes an enumerable (1)" do
      bb = ByteBuffer.new(8).zero
      bb.position = 4
      bb.write 1_u8..4_u8
      bb.to_slice.should eq(byte_slice(0, 0, 0, 0, 1, 2, 3, 4))
    end

    it "writes an enumerable (2)" do
      bb = ByteBuffer.new(16)
      bb.order = IO::ByteFormat::LittleEndian
      bb.write ({1, 2, 3, 4})
      slice = byte_slice(1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0, 4, 0, 0, 0)
      bb.to_slice.should eq(slice)
    end

    it "raises when writing multiple numbers without enough space" do
      bb = ByteBuffer.new(15)
      expect_raises(IO::Error, "buffer is full") { bb.write [1, 2, 3, 4] }
    end

    it "raises when writing an enumerable without enough space (1)" do
      bb = ByteBuffer.new(8)
      bb.position = 5
      expect_raises(IO::Error, "buffer is full") { bb.write 1_u8..4_u8 }
    end

    it "raises when writing an enumerable without enough space (2)" do
      bb = ByteBuffer.new(3)
      expect_raises(IO::Error, "buffer is full") { bb.write 1_u8..4_u8 }
    end
  end

  describe "absolute write" do
    it "writes at the given index (1)" do
      bb = ByteBuffer.new(10)
      bb.order = IO::ByteFormat::LittleEndian
      bb.write 2, 1234567890
      bb[2, 4].should eq(byte_slice 210, 2, 150, 73)
    end

    it "writes at the given index (2)" do
      bb = ByteBuffer.new(16)
      16_u8.times { |i| bb.write i, i }
      bb.to_slice.should eq(byte_slice 0..15)
    end

    it "writes at the given index (3)" do
      bb = ByteBuffer.new(16).zero
      bb.order = IO::ByteFormat::LittleEndian
      4.times { |i| bb.write (i * 4), 1234567890 }
      slice = byte_slice 210, 2, 150, 73, 210, 2, 150, 73, 210, 2, 150, 73, 210, 2, 150, 73
      bb.to_slice.should eq(slice)
    end

    it "writes at the given index (4)" do
      bb = ByteBuffer.new(10)
      bb.order = IO::ByteFormat::BigEndian
      bb.write 2, 1234567890
      bb[2, 4].should eq(byte_slice 73, 150, 2, 210)
    end

    it "raises if writing would go past capacity (1)" do
      bb = ByteBuffer.new(16)
      expect_raises(IndexError) { bb.write 16, 0_u8 }
    end

    it "raises if writing would go past capacity (2)" do
      bb = ByteBuffer.new(16)
      expect_raises(IndexError) { bb.write 15, 0_u16 }
    end

    it "raises if writing would go past capacity (3)" do
      bb = ByteBuffer.new(16)
      expect_raises(IndexError) { bb.write 13, 0 }
    end

    it "raises if writing would go past capacity (4)" do
      bb = ByteBuffer.new(16)
      expect_raises(IndexError) { bb.write 9, 0_i64 }
    end

    it "raises if writing would go past capacity (5)" do
      bb = ByteBuffer.new(16)
      expect_raises(IndexError) { bb.write 13, 0_f32 }
    end

    it "raises if writing would go past capacity (6)" do
      bb = ByteBuffer.new(16)
      expect_raises(IndexError) { bb.write 9, 0_i64 }
    end
  end

  describe "relative read" do
    it "reads a value and advances the position (1)" do
      bb = ByteBuffer.new(byte_slice 1..4)
      bb.read.should eq(1)
      bb.read.should eq(2)
      bb.read.should eq(3)
      bb.read.should eq(4)
    end

    it "reads a value and advances the position (2)" do
      bb = ByteBuffer.new(byte_slice 1..4)
      bb.order = IO::ByteFormat::LittleEndian
      bb.read(Int16).should eq(513)
      bb.read(Int16).should eq(1027)
    end

    it "reads a value and advances the position (2)" do
      bb = ByteBuffer.new(byte_slice 1..8)
      bb.order = IO::ByteFormat::LittleEndian
      bb.read(Int32).should eq(67305985)
      bb.read(Int32).should eq(134678021)
    end

    it "can't read past the limit" do
      bb = ByteBuffer.new(byte_slice 1..8)
      bb.limit = 4
      4.times { bb.read }
      expect_raises(IO::EOFError) { bb.read }
    end
  end

  describe "absolute read" do
    it "reads at the given index (1)" do
      slice = byte_slice 210, 4, 0, 0, 225, 16, 0, 0, 1, 252, 198, 8, 197, 57, 115, 57
      bb = ByteBuffer.new(slice)
      bb.order = IO::ByteFormat::LittleEndian
      bb.read(0, Int32).should eq(1234)
      bb.read(4, Int32).should eq(4321)
      bb.read(8, Int32).should eq(147258369)
      bb.read(12, Int32).should eq(963852741)
    end

    it "reads at the given index (2)" do
      slice = byte_slice 12, 210, 4, 210, 2, 150, 73, 121, 223, 13, 134, 72, 112, 0, 0, 182, 243, 157, 63, 93, 29, 91, 42, 202, 192, 243, 63
      bb = ByteBuffer.new(slice)
      bb.order = IO::ByteFormat::LittleEndian
      bb.read(0).should eq(12)
      bb.read(1, Int16).should eq(1234)
      bb.read(3, Int32).should eq(1234567890)
      bb.read(7, Int64).should eq(123456789012345)
      bb.read(15, Float32).should eq(1.234_f32)
      bb.read(19, Float64).should eq(1.2345678)
    end

    it "reads at the given index (3)" do
      bb = ByteBuffer.new(byte_slice 256.times)
      255.downto(0) { |i| bb.read(i).should eq(i) }
    end

    it "raises if reading beyond capacity" do
      expect_raises(IndexError) { ByteBuffer.new(1).read 1 }
      expect_raises(IndexError) { ByteBuffer.new(5).read 5 }
      {% for type, i in %w(Int8 UInt8 Int16 UInt16 Int32 UInt32 Int64 UInt64) %}
        i = {{i = 2 ** (i / 2)}}
        expect_raises(IndexError) { ByteBuffer.new(i).read i, {{type.id}} }
      {% end %}
      {% for type, i in %w(Float32 Float64) %}
        i = {{(i + 1) * 4}}
        expect_raises(IndexError) { ByteBuffer.new(i).read i, {{type.id}} }
      {% end %}
    end
  end

  describe "[]" do
    it "returns a byte in the given index (1)" do
      bb = ByteBuffer.new(4)
      bb.order = IO::ByteFormat::LittleEndian
      bb.write 1234567890
      bb[0].should eq(210)
      bb[1].should eq(2)
      bb[2].should eq(150)
      bb[3].should eq(73)
    end

    it "returns a byte in the given index (2)" do
      bb = ByteBuffer.new(4)
      bb.order = IO::ByteFormat::BigEndian
      bb.write 1234567890
      bb[3].should eq(210)
      bb[2].should eq(2)
      bb[1].should eq(150)
      bb[0].should eq(73)
    end

    it "raises if out of bounds" do
      bb = ByteBuffer.new(4)
      bb.order = IO::ByteFormat::LittleEndian
      expect_raises(IndexError) { bb[4] }
    end

    it "returns a slice when given an offset and a size" do
      bb = ByteBuffer.new(16)
      bb.order = IO::ByteFormat::LittleEndian
      bb.position = 8
      bb.write 1234567890
      bb[8, 4].should eq(byte_slice 210, 2, 150, 73)
    end

    it "raises if given an offset and a size out of bounds" do
      bb = ByteBuffer.new(16)
      bb.order = IO::ByteFormat::LittleEndian
      bb.position = 8
      bb.write 1234567890
      expect_raises(IndexError) { bb[13, 4] }
    end

    it "returns a slice when given a range (1)" do
      bb = ByteBuffer.new(16)
      bb.order = IO::ByteFormat::LittleEndian
      bb.position = 8
      bb.write 1234567890
      bb[8..11].should eq(byte_slice 210, 2, 150, 73)
    end

    it "returns a slice when given a range (2)" do
      bb = ByteBuffer.new(16)
      bb.order = IO::ByteFormat::LittleEndian
      bb.position = 8
      bb.write 1234567890
      bb[8...12].should eq(byte_slice 210, 2, 150, 73)
    end

    it "raises if given a range out of bounds" do
      bb = ByteBuffer.new(16)
      bb.order = IO::ByteFormat::LittleEndian
      bb.position = 8
      bb.write 1234567890
      expect_raises(IndexError) { bb[12..16] }
    end
  end

  describe "[]=" do
    it "sets the given byte at the given index" do
      bb = ByteBuffer.new(3).zero
      bb[1] = 134_u8
      bb.to_slice.should eq(byte_slice 0, 134, 0)
    end

    it "raises if out of bounds" do
      bb = ByteBuffer.new(3).zero
      expect_raises(IndexError) { bb[3] = 134_u8 }
    end
  end

  describe "limit=" do
    it "raises if trying to write beyond the limit" do
      bb = ByteBuffer.new(8)
      bb.limit = 4
      bb.write 123
      expect_raises(IO::Error, "buffer is full") { bb.write 456 }
    end

    it "raises if trying to read beyond the limit" do
      slice = byte_slice 1..4
      bb = ByteBuffer.new(slice)
      bb.limit = 3
      bb.read(Int16)
      expect_raises(IO::EOFError, "End of file reached") { bb.read(Int16) }
    end
  end

  describe "position=" do
    it "sets the position to the given index" do
      bb = ByteBuffer.new(byte_slice 0, 0, 0, 0, 0, 0)
      bb.position = 1
      bb.write 1234567890
      slice = byte_slice(0, 210, 2, 150, 73, 0)
      bb.to_slice.should eq(slice)
    end

    it "raises if the given index is greater than capacity" do
      bb = ByteBuffer.new(3)
      expect_raises(ArgumentError) { bb.position = 4 }
    end

    it "raises if the given index is greater than limit" do
      bb = ByteBuffer.new(3)
      bb.limit = 2
      expect_raises(ArgumentError) { bb.position = 3 }
    end
  end

  describe "mark" do
    it "sets the mark to the current position" do
      bb = ByteBuffer.new(10)
      bb.position = 5
      bb.mark!
      bb.mark.should eq(5)
    end
  end

  describe "clear" do
    it "resets position, limit and mark" do
      bb = ByteBuffer.new(5)
      bb.write 1234567890
      bb.flip
      bb.position = 2
      bb.mark!
      bb.clear
      bb.position.should eq(0)
      bb.limit.should eq(bb.capacity)
      bb.mark.should eq(-1)
    end
  end

  describe "flip" do
    it "sets the limit to the current position" do
      bb = ByteBuffer.new(10)
      bb.write 1234567890
      pos = bb.position
      bb.flip
      bb.limit.should eq(pos)
    end

    it "sets the position to zero" do
      bb = ByteBuffer.new(10)
      bb.write 1234567890_f64
      bb.flip
      bb.position.should eq(0)
    end

    it "removes the mark" do
      bb = ByteBuffer.new(10)
      bb.position = 5
      bb.mark!
      bb.flip
      bb.mark.should eq(-1)
    end

    it "allows reading from a previous write" do
      bb = ByteBuffer.new(16)
      bb.write [1, 2, 3, 4]
      bb.flip
      bb.read(Int32).should eq(1)
      bb.read(Int32).should eq(2)
      bb.read(Int32).should eq(3)
      bb.read(Int32).should eq(4)
    end
  end

  describe "remaining" do
    it "returns the number of bytes between position and limit (1)" do
      ByteBuffer.new(13).remaining.should eq(13)
    end

    it "returns the number of bytes between position and limit (2)" do
      bb = ByteBuffer.new(10)
      bb.write 1
      bb.remaining.should eq(6)
    end

    it "returns the number of bytes between position and limit (3)" do
      bb = ByteBuffer.new(10)
      bb.write 1
      bb.write 2
      bb.flip
      bb.remaining.should eq(8)
    end

    it "returns the number of bytes between position and limit (4)" do
      bb = ByteBuffer.new(10)
      bb.write 1
      bb.write 2
      bb.flip
      bb.read(Int32)
      bb.remaining.should eq(4)
    end
  end

  describe "remaining?" do
    it "returns true if #remaining is greater than zero (1)" do
      bb = ByteBuffer.new(10)
      bb.write 123
      bb.remaining?.should be_true
    end

    it "returns true if #remaining is greater than zero (2)" do
      bb = ByteBuffer.new(4)
      bb.write 123
      bb.remaining?.should be_false
    end

    it "returns true if #remaining is greater than zero (3)" do
      bb = ByteBuffer.new(8)
      bb.write 123
      bb.write 123
      bb.flip
      bb.remaining?.should be_true
    end

    it "returns true if #remaining is greater than zero (4)" do
      bb = ByteBuffer.new(8)
      bb.write 123
      bb.write 123
      bb.flip
      bb.read(Int64)
      bb.remaining?.should be_false
    end
  end

  describe "rewind" do
    it "sets the position to zero" do
      bb = ByteBuffer.new(5)
      bb.write 123
      bb.rewind
      bb.position.should eq(0)
    end

    it "removes the mark" do
      bb = ByteBuffer.new(5)
      bb.position = 3
      bb.mark!
      bb.rewind
      bb.mark.should eq(-1)
    end
  end

  describe "reset" do
    it "sets the position to the mark" do
      bb = ByteBuffer.new(5)
      bb.position = 3
      bb.mark!
      bb.position = 5
      bb.reset
      bb.position.should eq(3)
    end

    it "raises if the mark was undefined" do
      bb = ByteBuffer.new(5)
      expect_raises(Exception, "invalid mark") { bb.reset }
    end
  end

  describe "compact" do
    it "moves bytes from current position up to the limit to the beginning (1)" do
      bb = ByteBuffer.new(16)
      bb.write 1_u8..16_u8
      bb.flip
      4.times { bb.read }
      bb.compact
      slice = byte_slice(5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 13, 14, 15, 16)
      bb.to_slice.should eq(slice)
    end

    it "moves bytes from current position up to the limit to the beginning (2)" do
      bb = ByteBuffer.new(10)
      bb.write Int32::MAX
      bb.write 1234567890
      bb.flip
      bb.read(Int32)
      bb.compact
      bb[0, 4].should eq(byte_slice 210, 2, 150, 73)
    end

    it "moves bytes from current position up to the limit to the beginning (3)" do
      bb = ByteBuffer.new(16)
      (1..4).each { |n| bb.write n }
      bb.flip
      bb.position += 8
      bb.compact
      bb.write [5, 6]
      bb.flip
      bb.position += 16
      slice = byte_slice(3, 0, 0, 0, 4, 0, 0, 0, 5, 0, 0, 0, 6, 0, 0, 0)
      bb.to_slice.should eq(slice)
    end
  end

  describe "dup" do
    it "duplicates the buffer with shared memory" do
      bb = ByteBuffer.new(byte_slice 1, 2, 3, 4)
      bb2 = bb.dup
      bb.write 1, 5_u8
      bb2.read(1).should eq(5)
      bb.to_unsafe.should eq(bb2.dup.to_unsafe)
    end
  end

  describe "clone" do
    it "duplicates the buffer with copied memory" do
      bb = ByteBuffer.new(byte_slice 1, 2, 3, 4)
      bb2 = bb.clone
      bb.write 1, 5_u8
      bb2.read(1).should eq(2)
      bb.to_unsafe.should_not eq(bb2.to_unsafe)
    end
  end

  describe "to_io & from_io" do
    it "allows the buffer to read from or write into another IO" do
      bb1, bb2 = ByteBuffer.new(10), ByteBuffer.new(10)
      bb1.print "ByteBuffer"
      bb1.flip

      IO.pipe do |r, w|
        bb1.to_io w
        bb2.from_io r
      end

      bb2.flip.gets.should eq("ByteBuffer")
    end

    it "allows the buffer to read from or write into another ByteBuffer (1)" do
      bb1, bb2 = ByteBuffer.new(10), ByteBuffer.new(10)
      bb1.print "ByteBuffer"
      bb1.flip

      bb2.write_bytes bb1

      bb2.flip.gets.should eq("ByteBuffer")
    end

    it "allows the buffer to read from or write into another ByteBuffer (2)" do
      bb1, bb2 = ByteBuffer.new(12), ByteBuffer.new(12)
      {bb1, bb2}.each &.order=(IO::ByteFormat::LittleEndian)
      bb1.position += 4
      bb1.write 1234567890

      bb2.write_bytes bb1.flip

      bb2.flip
      bb2.read(Int32)
      bb2.read(Int32).should eq(1234567890)
    end

    it "implicit call to to_io raises if the destination is full" do
      bb1, bb2 = ByteBuffer.new(10), ByteBuffer.new(9)
      bb1.print "ByteBuffer"
      bb1.flip

      expect_raises(IO::Error, "buffer is full") { bb2.write_bytes bb1 }
    end
  end

  describe "each" do
    it "elements are yielded from @position up to @limit (block)" do
      bb = ByteBuffer.new(byte_slice 1, 2, 3, 4, 5, 6)
      bb.position += 1
      bb.limit -= 1
      ary = [] of UInt8
      bb.each { |e| ary << e }
      ary.should eq([2, 3, 4, 5])
    end

    it "elements are yielded from @position up to @limit (no block)" do
      bb = ByteBuffer.new(byte_slice 1, 2, 3, 4, 5, 6)
      bb.position += 1
      bb.limit -= 1
      bb.each.to_a.should eq([2, 3, 4, 5])
    end

    it "can use Enumerable methods" do
      bb = ByteBuffer.new(byte_slice 0, 1, 2, 3, 4)
      bb.position += 1
      bb.limit -= 1
      bb.join(", ").should eq("1, 2, 3")
    end

    it "accepts a type as an argument (block)" do
      bb = ByteBuffer.new(16)
      bb.write ary = [1, 2, 3]
      ary.clear
      bb.flip.each(Int32) { |e| ary << e }
      ary.should eq([1, 2, 3])
    end

    it "accepts a type as an argument (no block)" do
      bb = ByteBuffer.new(16)
      bb.write [1, 2, 3]
      bb.flip.each(Int32).to_a.should eq([1, 2, 3])
    end
  end

  describe "BufferIterator" do
    it "can be created from a ByteBuffer" do
      bb = ByteBuffer.new(10)
      bb.each.should be_a(ByteBuffer::BufferIterator(UInt8))
      {% for type in %w(Int8 UInt8 Int16 UInt16 Int32 UInt32 Int64 UInt64 Float32 Float64) %}
        bb.each({{type.id}}).should be_a(ByteBuffer::BufferIterator({{type.id}}))
      {% end %}
    end

    it "advances the position of its parent on iteration" do
      bb = ByteBuffer.new(byte_slice 1, 2, 3, 4)
      bb.each(Int32).next
      bb.position.should eq(4)
    end

    it "its next method returns Iterator::STOP when there's no data left to read" do
      bb = ByteBuffer.new(3)
      iter = bb.each
      3.times { iter.next.should be_a(UInt8) }
      iter.next.should be_a(Iterator::Stop)
    end

    it "its next? method returns nil when there's no data left to read" do
      bb = ByteBuffer.new(3)
      iter = bb.each
      3.times { iter.next?.should be_a(UInt8) }
      iter.next?.should eq(nil)
    end

    it "its next! method raises when there's no data left to read (1)" do
      bb = ByteBuffer.new(3)
      iter = bb.each
      3.times { iter.next!.should be_a(UInt8) }
      expect_raises(IO::EOFError, "End of file reached") { iter.next! }
    end

    it "its next! method raises when there's no data left to read(2)" do
      bb = ByteBuffer.new(8 * 3)
      iter = bb.each(Int64)
      3.times { iter.next!.should be_a(Int64) }
      expect_raises(IO::EOFError, "End of file reached") { iter.next! }
    end

    it "its rewind method returns its parent's position to its former value" do
      bb = ByteBuffer.new(byte_slice 1, 2, 3, 4)
      bb.read
      iter = bb.each(UInt16)
      iter.next
      iter.rewind
      bb.read.should eq(2)
    end
  end

  describe "mixed" do
    it "test 1" do
      bb = ByteBuffer.new(16).zero
      slice = byte_slice 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
      bb.to_slice.should eq(slice)
      bb.order = IO::ByteFormat::LittleEndian
      bb.capacity.should eq(16)
      bb.limit.should eq(16)
      bb.position.should eq(0)

      bb.write 123_i8
      slice = byte_slice(123, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
      bb.to_slice.should eq(slice)
      bb.position.should eq(1)

      bb.write 12345_i16
      slice = byte_slice(123, 57, 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
      bb.to_slice.should eq(slice)
      bb.position.should eq(3)

      bb.write 1234567890_u32
      slice = byte_slice(123, 57, 48, 210, 2, 150, 73, 0, 0, 0, 0, 0, 0, 0, 0, 0)
      bb.to_slice.should eq(slice)
      bb.position.should eq(7)

      bb.write 1.2345_f64
      slice = byte_slice(123, 57, 48, 210, 2, 150, 73, 141, 151, 110, 18, 131, 192, 243, 63, 0)
      bb.to_slice.should eq(slice)
      bb.position.should eq(15)

      bb.write 5_u8
      slice = byte_slice(123, 57, 48, 210, 2, 150, 73, 141, 151, 110, 18, 131, 192, 243, 63, 5)
      bb.to_slice.should eq(slice)
      bb.position.should eq(16)

      {% for type in %w(i8 u8 i16 u16 i32 u32 i64 u64 f32 f64) %}
        expect_raises(IO::Error, "buffer is full") { bb.write 1{{type.id}} }
      {% end %}



      bb.flip.should eq(bb)
      bb.position.should eq(0) # => 0
      bb.limit.should eq(16) # => 16

      n = bb.read # => 123_u8
      n.should eq(123)
      n.should be_a(UInt8)
      bb.position.should eq(1) # => 1

      n = bb.read UInt16 # => 12345_i16
      n.should eq(12345)
      n.should be_a(UInt16)
      bb.position.should eq(3) # => 3

      n = bb.read Int32 # => 1234567890_i32
      n.should eq(1234567890)
      n.should be_a(Int32)
      bb.position.should eq(7) # => 7

      n = bb.read Float64 # => 1.2345_f64
      n.should eq(1.2345)
      n.should be_a(Float64)
      bb.position.should eq(15) # => 15

      n = bb.read(Int8) # => 5_i8
      n.should eq(5)
      n.should be_a(Int8)
      bb.position.should eq(16) # => 16

      expect_raises(IO::EOFError, "End of file reached") { bb.read }
      {% for type in %w(Int8 UInt8 Int16 UInt16 Int32 UInt32 Int64 UInt64 Float32 Float64) %}
        expect_raises(IO::EOFError, "End of file reached") { bb.read {{type.id}} }
      {% end %}
    end

    it "test 2" do
      bb = ByteBuffer.new(10).zero
      bb.write 10_i16
      bb.write 20_i16
      bb.write 30_i16
      bb.flip
      bb.read(Int16).should eq(10)
      bb.compact
      slice = byte_slice(20, 0, 30, 0, 30, 0, 0, 0, 0, 0)
      bb.to_slice.should eq(slice)
      bb.position.should eq(4)
      bb.write 1234567890
      slice = byte_slice(20, 0, 30, 0, 210, 2, 150, 73, 0, 0)
      bb.to_slice.should eq(slice)
      bb.remaining.should eq(2)
      bb.position.should eq(8)
      bb.limit.should eq(10)
      bb.flip
      bb.read(Int64).should eq(5302428712243691540)
      bb.remaining.should eq(0)
      bb.position.should eq(8)
      bb.limit.should eq(8)
    end

    it "test 3" do
      bb = ByteBuffer.new(16).zero
      bb.order = IO::ByteFormat::LittleEndian
      bb.to_slice.should eq(byte_slice 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
      bb.limit.should eq(16)
      bb.position = 3
      bb.limit.should eq(16)
      bb.write 134
      bb.limit.should eq(16)
      bb.to_slice.should eq(byte_slice 0, 0, 0, 134, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
      bb.position.should eq(7)
      bb.limit.should eq(16)
      bb.position = 10
      bb.write 123_u16
      bb.position.should eq(12)
      bb.to_slice.should eq(byte_slice 0, 0, 0, 134, 0, 0, 0, 0, 0, 0, 123, 0, 0, 0, 0, 0)
      bb.flip
      bb.position.should eq(0)
      bb.limit.should eq(12)
      bb.capacity.should eq(16)
      bb.position = 3
      bb.limit.should eq(12)
      bb.read(Int16).should eq(134)
      bb.position.should eq(5)
      ib = bb.as_int32_buffer
      ib.capacity.should eq(4)
      ib.rewind
      ib.position.should eq(0)
      bb.position.should eq(5)
    end

    it "test 4" do
      bb = ByteBuffer.new(8)
      bb.write 77_i8
      expect_raises(IO::Error, "buffer is full") { bb.write 1_i64 }
      expect_raises(IndexError) { bb.write 1, 1_i64 }
      expect_raises(IndexError) { bb.write -1, 1_i64 }
      expect_raises(Exception) { bb.reset }
      bb.flip
      expect_raises(IO::EOFError, "End of file reached") { bb.read Int16 }
      expect_raises(IO::EOFError, "End of file reached") { bb.read Int32 }
      expect_raises(IO::EOFError, "End of file reached") { bb.read Int64 }
      bb.read(Int8).should eq(77)
    end
  end

  describe "ByteBuffer::*Buffer" do
    it "can be created from an existing ByteBuffer" do
      bb = ByteBuffer.new(16)
      ib = bb.as_int32_buffer
      ib.should be_a(ByteBuffer::Int32Buffer)
      ib.capacity.should eq(4)
    end

    it "can be created from capacity" do
      ib = ByteBuffer::Int64Buffer.new(4)
      ib.capacity.should eq(4)
      ib.bytesize.should eq(4 * 8)
    end

    it "can be created from a slice" do
      slice = Slice.new(10, &.to_u16)
      ib = ByteBuffer::UInt16Buffer.new(slice)
      ib.capacity.should eq(10)
      ib.bytesize.should eq(20)
    end

    it "inherits its byte order from the ByteBuffer it was created from" do
      bb = ByteBuffer.new(1)
      bb.order = IO::ByteFormat::LittleEndian
      bb.as_float32_buffer.order.should eq(IO::ByteFormat::LittleEndian)

      bb = ByteBuffer.new(1)
      bb.order = IO::ByteFormat::BigEndian
      bb.as_int16_buffer.order.should eq(IO::ByteFormat::BigEndian)
    end

    it "can write (1)" do
      bb = ByteBuffer.new(4)
      bb.order = IO::ByteFormat::LittleEndian
      sb = bb.as_int16_buffer
      sb.write 1_i16
      sb.write 2_i16
      bb.to_slice.should eq(byte_slice 1, 0, 2, 0)
    end

    it "can write (2)" do
      bb = ByteBuffer.new(16)
      bb.order = IO::ByteFormat::LittleEndian
      ib = bb.as_int32_buffer
      ib.write [1, 2, 3, 4]
      slice = byte_slice 1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0, 4, 0, 0, 0
      bb.to_slice.should eq(slice)
    end

    it "can write (3)" do
      bb = ByteBuffer.new(16)
      bb.order = IO::ByteFormat::LittleEndian
      ib = bb.as_int32_buffer
      ib.write Slice[1, 2, 3, 4]
      slice = byte_slice 1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0, 4, 0, 0, 0
      bb.to_slice.should eq(slice)
    end

    it "raises if writing beyond capacity" do
      bb = ByteBuffer.new(4).as_int32_buffer
      bb.write 1
      expect_raises(IO::Error, "buffer is full") { bb.write 1 }
    end

    it "can read (1)" do
      bb = ByteBuffer.new(16)
      sb = bb.as_uint16_buffer
      sb.write [1_u16, 2_u16, 3_u16, 4_u16]
      sb.flip
      slice = Slice[0_u16, 0_u16, 0_u16, 0_u16]
      sb.read slice
      slice.should eq(Slice[1_u16, 2_u16, 3_u16, 4_u16])
    end

    it "can read" do
      bb = ByteBuffer.new(4)
      sb = bb.as_int16_buffer
      sb.write 1_i16
      sb.write 2_i16
      sb.flip
      sb.read.should eq(1_i16)
      sb.read.should eq(2_i16)
    end

    it "raises if reading beyond the limit" do
      bb = ByteBuffer.new(4)
      sb = bb.as_int16_buffer
      sb.write 1_i16
      sb.write 2_i16
      sb.flip
      sb.read
      sb.read
      expect_raises(IO::EOFError, "End of file reached") { sb.read }
    end

    it "can absolute write" do
      bb = ByteBuffer.new(16).as_int32_buffer.zero
      bb.write 2, 1234567890
      bb.to_slice.to_a.should eq([0, 0, 1234567890, 0])
    end

    it "raises on absolute write beyond capacity" do
      bb = ByteBuffer.new(16).as_int32_buffer.zero
      expect_raises(IndexError) { bb.write 4, 1234567890 }
    end

    it "can absolute read" do
      bb = ByteBuffer.new(byte_slice 1, 2, 3, 4).as_uint16_buffer
      bb.read(1).should eq(1027)
    end

    it "raises on absolute read beyond capacity" do
      bb = ByteBuffer.new(byte_slice 1, 2, 3, 4).as_float32_buffer
      expect_raises(IndexError) { p bb.read 1 }
    end

    it "absolute reads are indexed in terms of the ViewBuffer's type" do
      bb = ByteBuffer.new(16)
      (1..4).each { |n| bb.write n * 10 }
      ib = bb.as_int32_buffer
      ib.read(3).should eq(40)
      ib.read(1).should eq(20)
      ib.read(0).should eq(10)
      ib.read(2).should eq(30)
    end

    it "absolute writes are indexed in terms of the ViewBuffer's type" do
      bb = ByteBuffer.new(16)
      ib = bb.as_int32_buffer
      ib.write 3, 40
      ib.write 1, 20
      ib.write 0, 10
      ib.write 2, 30
      ib.to_slice.to_a.should eq([10, 20, 30, 40])
    end

    it "changes made to a ViewBuffer are reflected on its parent ByteBuffer" do
      bb = ByteBuffer.new(16)
      bb.order = IO::ByteFormat::LittleEndian
      bb.write 1_i64
      bb.write 2_i64
      ib = bb.as_uint64_buffer
      slice = byte_slice(1, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0)
      bb.to_slice.should eq(slice)
    end
  end
end
