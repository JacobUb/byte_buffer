class ByteBuffer
  {% for type in %w(Int8 UInt8 Int16 UInt16 Int32 UInt32 Int64 UInt64 Float32 Float64) %}
    class {{type.id}}Buffer
      include Buffer({{type.id}})

      def initialize(capacity : Int)
        raise ArgumentError.new("negative capacity") if capacity < 0
        @buffer = Pointer({{type.id}}).malloc(capacity)
        @limit = @capacity = capacity.to_i
        @order = IO::ByteFormat::SystemEndian
      end

      def initialize(slice : Slice({{type.id}}))
        @buffer = slice.to_unsafe
        @limit = @capacity = slice.size
        @order = IO::ByteFormat::SystemEndian
      end

      def initialize(buf : ByteBuffer)
        @buffer = buf.@buffer.as({{type.id}}*)
        @limit = @capacity = buf.capacity / sizeof({{type.id}})
        @order = buf.order
      end
    end

    # Creates a `{{type.id}}Buffer` backed by the same memory as the ByteBuffer
    # it was created from. Changes to the contents of the `{{type.id}}Buffer`
    # will be reflected on its parent. `position`, `limit` and `mark` are
    # independent.
    def as_{{type.downcase.id}}_buffer : {{type.id}}Buffer
      {{type.id}}Buffer.new(self)
    end
  {% end %}
end
