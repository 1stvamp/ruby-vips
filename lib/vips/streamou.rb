# This module provides an interface to the top level bits of libvips
# via ruby-ffi.
#
# Author::    John Cupitt  (mailto:jcupitt@gmail.com)
# License::   MIT

require 'ffi'

module Vips
  if Vips::at_least_libvips?(8, 9)
    attach_function :vips_streamou_new, [], :pointer
  end

  # A user output stream you can attach action signal handlers to to implememt 
  # custom output types.
  #
  # ```ruby
  # stream = Vips::Streamou.new
  # stream.signal_connect "write" do |buf, len|
  #   # write up to len bytes from buf, return the nuber of bytes 
  #   # actually written
  # end
  # ```
  class Streamou < Vips::Streamo
    module StreamouLayout
      def self.included(base)
        base.class_eval do
          layout :parent, Vips::Streamo::Struct
          # rest opaque
        end
      end
    end

    class Struct < Vips::Streamo::Struct
      include StreamouLayout
    end

    class ManagedStruct < Vips::Streamo::ManagedStruct
      include StreamouLayout
    end

    def initialize
      puts "streamou init"
      pointer = Vips::vips_streamou_new
      raise Vips::Error if pointer.null?
      @refs = []

      super pointer
    end

    # The block is executed to write data to the source. The interface is
    # exactly as IO::write, ie. it should write the string and return the 
    # number of bytes written.
    def on_write 
      p = Proc.new 
      @refs << p
      signal_connect "write" do |p, len|
        puts "on_write: #{len} bytes to be written"
        chunk = p.get_bytes(0, len)
        puts "calling block"
        bytes_written = p.call chunk
        puts "wrote #{bytes_written}"
        bytes_written
      end
    end

    # The block is executed at the end of write. It should do any necessary
    # finishing action.
    def on_finish &block
      signal_connect "finish" do 
        block.call()
      end
    end

  end
end
