class ByteBuffer
  # This module contains the methods shared by ByteBuffer and the other buffers.
  # Indices here are always in terms of the size of T.
  #
  # @buffer: the pointer that backs this buffer.
  #
  # @capacity: the number of values that this buffer can store.
  #
  # @position: the index of the next value that will be written or read.
  #
  # @limit: the index from which data cannot be further written or read.
  #
  # @mark: an optional bookmark of a position of interest.
  #
  # @order: the endianness of the buffer.
  module Buffer(T)
    getter position : Int32
    getter capacity : Int32
    getter limit : Int32
    getter order : IO::ByteFormat
    protected setter mark

    @buffer : T*
    @position : Int32
    @limit : Int32
    @mark : Int32
    @capacity : Int32
    @order : IO::ByteFormat

    # Reads a T value and advances the position. Raises EOFError if there's not
    # enough data remaining to read.
    def read : T
      raise IO::EOFError.new unless remaining?
      value = absolute_read @position, T
      @position += 1
      value
    end

    # Reads a T value at the given index. Raises IndexError if the index is out
    # of bounds.
    def read(index : Int) : T
      if index >= @capacity
        raise IndexError.new("#read(#{index}) (capacity: #{@capacity})")
      end
      absolute_read index, T
    end

    # Fills the slice from T values from the buffer, limited by the values that
    # can currently be read. Returns the number of values that were read.
    def read(slice : Slice(T))
      size = {slice.size, remaining}.min
      if size > 0
        size.times do |i|
          slice.to_unsafe[i] = absolute_read @position + i, T
        end
        @position += size
      end
      size
    end

    # Writes a T value and advances the position. Raises IO::Error if there's
    # not enough room for the value.
    def write(value : T)
      raise IO::Error.new "buffer is full" unless remaining?
      absolute_write @position, value
      @position += 1
    end

    # Writes the contents of the enumerable into the buffer. Raises IO::Error if
    # the buffer can't store all the values.
    def write(values : Enumerable(T))
      raise IO::Error.new "buffer is full" if remaining < values.size
      pos, stop = @position, @position + remaining
      values.each do |val|
        absolute_write pos, val
        pos += 1
      end
      @position = pos
    end

    # Writes the contents of the slice into the buffer. Raises IO::Error if
    # the buffer can't store all the values.
    def write(slice : Slice(T))
      size = slice.size
      raise IO::Error.new "buffer is full" if remaining < size
      size.times do |i|
        absolute_write @position + i, slice.unsafe_at i
      end
      @position += size
    end

    # Writes the contents of the array into the buffer. Raises IO::Error if
    # the buffer can't store all the values.
    def write(array : Array(T))
      size = array.size
      raise IO::Error.new "buffer is full" if remaining < size
      size.times do |i|
        absolute_write @position + i, array.unsafe_at i
      end
      @position += size
    end

    # Writes a T value at the given index. Raises IndexError if the index is out
    # of bounds.
    def write(index : Int, value : T)
      raise IndexError.new if index >= @capacity
      absolute_write index, value
      self
    end

    # Returns a slice with T values from `offset` to `offset + size`. Raises
    # IndexError if out of bounds.
    def [](offset : Int, size : Int) : Slice(T)
      if size < 0 || offset < 0 || offset + size > @capacity
        raise IndexError.new("#[#{offset}, #{size}] (capacity: #{@capacity})")
      end
      Slice.new(@buffer + offset, size)
    end

    # Returns a slice with T values within the range. Changes to the slice will
    # also be reflected on the buffer. Raises IndexError if the range is out of
    # bounds.
    def [](range : Range(Int, Int)) : Slice(T)
      size = (range.excludes_end? ? range.end - 1 : range.end) - range.begin + 1
      offset = range.begin
      if size < 0 || offset < 0 || offset + size > @capacity
        raise IndexError.new("#[#{range}] (capacity: #{@capacity})")
      end

      Slice.new(@buffer + offset, size)
    end

    # Returns a T value at the given index. Raises IndexError if the index is
    # out of bounds.
    def [](index : Int) : T
      if index < 0 || index >= @capacity
        raise IndexError.new("#[#{index}] (capacity: #{@capacity}")
      end
      @buffer[index]
    end

    # Sets the given value at the given index. Raises IndexError if the index is
    # out of bounds.
    def []=(index : Int, value : T) : T
      if index < 0 || index + sizeof(T) > @capacity
        raise IndexError.new("#[#{index}] = #{value} (capacity: #{@capacity})")
      end
      @buffer[index] = value
    end

    # Makes the buffer ready for writing again from the beginning. Position,
    # limit and mark are resetted to their original values. Any data that wasn't
    # read is forgotten about in the sense that the buffer forgets its location
    # and will be overwritten in subsequent writes. It doesn't actually set the
    # contents to zero.
    def clear : self
      @limit, @position, @mark = @capacity, 0, -1
      self
    end

    # Makes the buffer ready for re-reading previously read data by leaving the
    # limit unchanged and setting the position to zero. It also removes the mark
    # if there was one.
    def rewind : self
      @position, @mark = 0, -1
      self
    end

    # Sets the limit to the current position and the position to zero. It also
    # removes the mark if there was one.
    def flip : self
      @limit, @position, @mark = @position, 0, -1
      self
    end

    # The position goes back to the position the buffer had when #mark was
    # called. Raises if the mark wasn't set.
    def reset : self
      raise "invalid mark" if @mark < 0
      @position = @mark
      self
    end

    # Any data between the position and the limit is copied to the beginning of
    # the buffer. The position is set after the end of that data and limit and
    # mark are reset.
    def compact : self
      @buffer.move_from(@buffer + @position, remaining)
      @position = remaining
      @limit = @capacity
      @mark = -1
      self
    end

    # Returns the difference between the position and the limit. When reading,
    # returns the number of values left to read. When writing, returns the
    # number of values that can be written.
    def remaining : Int32
      @limit - @position
    end

    # See #remaining. Returns true if remaining > 0.
    def remaining? : Bool
      @position < @limit
    end

    # Returns the capacity, which is the number of T values that the buffer can
    # store.
    def size : Int32
      @capacity
    end

    # Returns the capacity of the buffer in bytes.
    def bytesize : Int32
      @capacity * sizeof(T)
    end

    # Sets the position to the given index. Raises if the index is greater than
    # the capacity or the limit.
    def position=(index : Int)
      if index > @capacity
        raise ArgumentError.new("position cannot be greater than the capacity")
      elsif index > @limit
        raise ArgumentError.new("position cannot be greater than the limit")
      elsif index < 0
        raise ArgumentError.new("position must be greater than zero")
      end
      @position = index.to_i
      @mark = -1 if @mark > index
      index
    end

    # Sets the limit to the given index. Sets the position to the limit if
    # position > limit. Removes the mark if the mark > limit.
    def limit=(index : Int)
      if index > @capacity
        raise ArgumentError.new("limit cannot be greater than the capacity")
      elsif index < 0
        raise ArgumentError.new("limit must be greater than zero")
      end
      @limit = index.to_i
      @position = @limit if @position > @limit
      @mark = -1 if @mark > @limit
      index
    end

    # Sets the mark to the current position. Later, the position can be returned
    # to the former position with `reset`.
    def mark : self
      @mark = @position
      self
    end

    # Returns the index of the mark or nil if it's undefined.
    def mark? : Int32?
      @mark if @mark > -1
    end

    # Removes the mark.
    def discard_mark : self
      @mark = -1
      self
    end

    # Returns a slice of type T with the contents of the buffer. Changes made to
    # the slice will be reflected in the buffer.
    def to_slice : Slice(T)
      Slice.new(@buffer, @capacity)
    end

    # Returns the pointer that backs this buffer.
    def to_unsafe : T*
      @buffer
    end

    # Sets all the elements of the buffer to 0.
    def zero : self
      @buffer.clear(@capacity)
      self
    end

    # Sets `size` elements of the buffer to 0, starting from `offset`.
    def zero(offset : Int, size : Int) : self
      if offset + size > @capacity
        raise IndexError.new "#zero(#{offset}, #{size}) (capacity: #{capacity})"
      end
      (@buffer + offset).clear(size)
      self
    end

    # Sets elements of the buffer in the range to 0.
    def zero(range : Range(Int, Int)) : self
      size = (range.excludes_end? ? range.end - 1 : range.end) - range.begin + 1
      if range.begin + size > @capacity
        raise IndexError.new "#zero(#{range}) (capacity: #{capacity})"
      end
      (@buffer + range.begin).clear(size)
      self
    end

    # Creates a copy with the same `position`, `limit`, `mark` and `order`.
    # The copy contains the same data as the original and any changes to it will
    # be reflected on the original.
    def dup : self
      bb = self.class.new(to_slice)
      bb.position, bb.limit, bb.mark, bb.order = @position, @limit, @mark, @order
      bb
    end

    # Creates a copy with the same `position`, `limit`, `mark` and `order`.
    # The copy contains the same data as the original but changes to it won't
    # be reflected on the original.
    def clone : self
      bb = self.class.new(@capacity)
      bb.write to_slice
      bb.position, bb.limit, bb.mark, bb.order = @position, @limit, @mark, @order
      bb
    end

    # Reads a value of type t at the given index. Does not do any bounds check.
    private def absolute_read(index : Int, t)
      buf = (@buffer + index).as(UInt8*)
      @order.decode t, PointerIO.new(pointerof(buf))
    end

    # Writes a value at the given index. Does not do any bounds check.
    private def absolute_write(index : Int, value)
      buf = (@buffer + index).as(UInt8*)
      @order.encode value, PointerIO.new(pointerof(buf))
    end

    private struct PointerIO
      include IO

      def initialize(@pointer : UInt8**)
      end

      def read(slice : Slice(UInt8))
        count = slice.size
        slice.copy_from(@pointer.value, count)
        @pointer.value += count
        count
      end

      def write(slice : Slice(UInt8))
        count = slice.size
        slice.copy_to(@pointer.value, count)
        @pointer.value += count
        nil
      end
    end
  end
end
