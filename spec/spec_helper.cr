require "spec"
require "../src/byte_buffer"

def byte_slice(*args : Number)
  Slice.new(args.size) { |i| args[i].to_u8 }
end

def byte_slice(bytes : Enumerable(Int) | Iterator(Int))
  ary = bytes.map(&.to_u8).to_a
  ary.to_unsafe.to_slice ary.size
end
