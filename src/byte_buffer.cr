require "./buffer"
require "./other_buffers"

class ByteBuffer
  include IO
  include Buffer(UInt8)
  include Enumerable(UInt8)

  property order : IO::ByteFormat

  @position : Int32 = 0
  @mark : Int32 = -1
  @order : IO::ByteFormat = IO::ByteFormat::SystemEndian

  # Creates a ByteBuffer with the given capacity.
  def initialize(capacity : Int)
    raise ArgumentError.new("negative capacity") if capacity < 0

    @buffer = GC.malloc_atomic(capacity.to_u32).as(UInt8*)
    @limit = @capacity = capacity.to_i
  end

  # Creates a ByteBuffer backed by the given slice. Changes to the contents of
  # the slice will be reflected in the buffer and vice versa.
  def initialize(slice : Slice(UInt8))
    @buffer = slice.to_unsafe
    @limit = @capacity = slice.size
  end

  # Copies as much bytes as there are left into the slice. Returns the number
  # of bytes that were read.
  def read(slice : Slice(UInt8)) : Int32
    size = {slice.size, remaining}.min
    slice.to_unsafe.copy_from @buffer + @position, size
    @position += size
    size
  end

  # Relative read of a byte (UInt8). Raises IO::EOFError if there's no remaining
  # bytes to read.
  def read : UInt8
    read UInt8
  end

  # Writes a Slice(UInt8). Raises IO::Error if there's no space left to write
  # it fully.
  def write(slice : Slice(UInt8))
    size = slice.size
    return if size == 0
    raise IO::Error.new "buffer is full" if size > remaining
    slice.to_unsafe.copy_to @buffer + @position, size
    @position += size
    nil
  end

  # To be called implicitly by IO#write_bytes.
  def to_io(io : IO, format : IO::ByteFormat = @order)
    io.write slice = Slice.new(@buffer + @position, remaining)
    size = slice.size
    @position += size
    size
  end

  # To be called implicitly by IO#read_bytes.
  def from_io(io : IO, format : IO::ByteFormat = @order)
    size = io.read Slice.new(@buffer + @position, remaining)
    @position += size
    size
  end

  # See IO#write_bytes.
  def write_bytes(object, format : IO::ByteFormat = @order)
    object.to_io self, format
  end

  # See IO#read_bytes.
  def read_bytes(type, format : IO::ByteFormat = @order)
    type.from_io self, format
  end

  # Creates a copy with the same `position`, `limit`, `mark` and `order`.
  # The copy contains the same data as the original but doesn't share its
  # memory.
  def dup : self
    bb = ByteBuffer.new(to_slice)
    bb.position, bb.limit, bb.mark, bb.order = @position, @limit, @mark, @order
    bb
  end

  # Creates a copy with the same `position`, `limit`, `mark` and `order`.
  # They share the same underlying memory.
  def clone : self
    bb = ByteBuffer.new(@capacity)
    bb.write to_slice
    bb.position, bb.limit, bb.mark, bb.order = @position, @limit, @mark, @order
    bb
  end

  {% for type, i in %w(Int8 UInt8 Int16 UInt16 Int32 UInt32 Int64 UInt64) %}
    # Relative read of `{{type.id}}`. Raises EOFError if there's not enough
    # remaining bytes to read an entire `{{type.id}}`.
    def read(t : {{type.id}}.class) : {{type.id}}
      raise IO::EOFError.new if remaining < {{2 ** (i / 2)}}
      value = absolute_read @position, {{type.id}}
      @position += {{2 ** (i / 2)}}
      value
    end

    # Absolute read of `{{type.id}}` at `index`. Raises IndexError if `index +
    # {{2 ** (i / 2)}}` is greater or equal than the capacity.
    def read(index : Int, t : {{type.id}}.class) : {{type.id}}
      raise IndexError.new if index + {{2 ** (i / 2)}} > @capacity
      absolute_read index, {{type.id}}
    end

    # Relative write of `{{type.id}}`. Raises IO::Error if there's not enough
    # space for {{2 ** (i / 2)}} bytes.
    def write(value : {{type.id}})
      @order.encode value, self
    end

    # Relative write of `Enumerable({{type.id}})`. Raises IO::Error if there's
    # not enough space for for all its values.
    def write(values : Enumerable({{type.id}}))
      if values.size * {{2 ** (i / 2)}} > remaining
        raise IO::Error.new "buffer is full"
      end
      pos = @position
      values.each do |val|
        absolute_write pos, val
        pos += {{2 ** (i / 2)}}
      end
      @position = pos
    end

    # Absolute write of `{{type.id}}` at `index`. Raises IndexError if `index +
    # sizeof({{type.id}})` is greater or equal than the capacity.
    def write(index : Int, value : {{type.id}})
      if index < 0 || index + {{2 ** (i / 2)}} > @capacity
        raise IndexError.new("#write(#{index}, #{value})")
      end
      absolute_write index, value
    end
  {% end %}

  {% for type, i in %w(Float32 Float64) %}
    # Relative read of `{{type.id}}`. Raises EOFError if there's not enough
    # remaining bytes to read an entire `{{type.id}}`.
    def read(t : {{type.id}}.class) : {{type.id}}
      raise IO::EOFError.new if remaining < {{(i + 1) * 4}}
      value = absolute_read @position, {{type.id}}
      @position += {{(i + 1) * 4}}
      value
    end

    # Absolute read of `{{type.id}}` at `index`. Raises IndexError if `index +
    # {{(i + 1) * 4}}` is greater or equal than the capacity.
    def read(index : Int, t : {{type.id}}.class) : {{type.id}}
      raise IndexError.new if index + {{(i + 1) * 4}} > @capacity
      absolute_read index, {{type.id}}
    end

    # Relative write of `{{type.id}}`. Raises IO::Error if there's not enough
    # space.
    def write(value : {{type.id}})
      @order.encode value, self
    end

    # Relative write of `Enumerable({{type.id}})`. Raises IO::Error if there's
    # not enough space for for all its values.
    def write(values : Enumerable({{type.id}}))
      if values.size * {{(i + 1) * 4}} > remaining
        raise IO::Error.new "buffer is full"
      end
      pos = @position
      values.each do |val|
        absolute_write pos, val
        pos += {{(i + 1) * 4}}
      end
      @position = pos
    end

    # Absolute write of `{{type.id}}` at `index`. Raises IndexError if `index +
    # {{(i + 1) * 32}}` is greater or equal than the capacity.
    def write(index : Int, value : {{type.id}})
      raise IndexError.new if index + {{(i + 1) * 4}} > @capacity
      absolute_write index, value
    end
  {% end %}

  {% for type in %w(Int8 UInt8 Int16 UInt16 Int32 UInt32 Int64 UInt64 Float32 Float64) %}
    # Returns a `BufferIterator({{type.id}})` bound to the ByteBuffer. Iterating
    # it will advance the position of its parent. Its rewind method will reset
    # the ByteBuffer's position to the value it had when the iterator was
    # created.
    def each(t : {{type.id}}.class) : BufferIterator({{type.id}})
      BufferIterator({{type.id}}).new(self)
    end

    # Yields each `{{type.id}}` from the current position to the limit.
    def each(t : {{type.id}}.class, &block : {{type.id}} -> _)
      iter = BufferIterator({{type.id}}).new(self)
      while value = iter.next?
        yield value
      end
      self
    end
  {% end %}

  # Returns a BufferIterator(UInt8) bound to the ByteBuffer. Iterating
  # it will advance the position of its parent. Its rewind method will reset
  # the ByteBuffer's position to the value it had when the iterator was
  # created.
  def each : BufferIterator(UInt8)
    BufferIterator(UInt8).new(self)
  end

  # Yields each byte from the current position to the limit. Position will
  # advance on each successive value yielded to the block.
  def each(&block : UInt8 -> _) : self
    each.each { |byte| yield byte }
    self
  end

  struct BufferIterator(T)
    include Iterator(T)

    @bb : ByteBuffer
    @op : Int32

    def initialize(@bb : ByteBuffer)
      @op = @bb.position
    end

    # Reads a T value. Returns Iterator::Stop::INSTANCE if there's no more T
    # values to read. This method is more useful when called implicitly by
    # other Iterator methods as it returns a Union(T | Iterator::Stop).
    def next : T | Stop
      next? || stop
    end

    # Reads a T value or returns nil if there's no more T values to read.
    def next? : T?
      next! unless @bb.remaining < sizeof(T)
    end

    # Reads a T value. The ByteBuffer will raise IO::EOFError if there's no more
    # T values to read.
    def next! : T
      @bb.read T
    end

    # Sets the position of the ByteBuffer this BufferIterator was created from
    # to the value it had when the BufferIterator was created.
    def rewind : self
      @bb.position = @op
      self
    end
  end
end
