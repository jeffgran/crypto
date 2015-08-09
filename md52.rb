require 'pp'

module JG
  class MD5
    PAD_BYTE = "\x80" # 0b10000000
    A = "\x67\x45\x23\x01"
    B = "\xef\xcd\xab\x89"
    C = "\x98\xba\xdc\xfe"
    D = "\x10\x32\x54\x76"

    def initialize(input_string)
      @input = input_string.force_encoding("BINARY")
    end

    def hexdigest
      #digested_words.map(&:to_s).map(&:reverse).join.unpack("H*").first
      digested_words.map(&:to_hex).join
    end

    def digested_words
      # initialize with constants
      a = MD5Word.new(A)
      b = MD5Word.new(B)
      c = MD5Word.new(C)
      d = MD5Word.new(D)
      words.each_slice(16) do |x|
        aa = a
        bb = b
        cc = c
        dd = d

        a, b, c, d = rounds(a, b, c, d, x)

        # add the original values from this iteration of loop to the
        # permutated ones to "promote a faster 'avalanche effect'"
        a += aa
        b += bb
        c += cc
        d += dd
      end

      [a, b, c, d]
    end

    def words
      bytes.each_byte.each_slice(4).map{ |n| MD5Word.new(n.pack("CCCC")) }
    end

    def padding
      puts (PAD_BYTE + zero_bytes).force_encoding("BINARY").length
      # puts (PAD_BYTE + zero_bytes + terminator).force_encoding("BINARY").length
      # puts (PAD_BYTE + zero_bytes + terminator).force_encoding("BINARY").inspect
      (PAD_BYTE + zero_bytes).each_char.each_slice(4).map do |four|
        four.reverse.join
      end.join
      #(PAD_BYTE + zero_bytes).reverse
    end

    def bytes
      @input + padding + terminator
    end

    def zero_bytes
      tail_length = @input.length % 64

      pad_length = if tail_length < 56
                     56 - tail_length
                   elsif tail_length >= 56
                     56 + (64 - tail_length)
                   end

      Array.new(pad_length - 1) { 0b00000000 }.pack("C*")
    end

    def terminator
      [@input.size].pack("Q<")
    end


    def rounds(a, b, c, d, x)
      ROUNDS.each do |data|
        round = data[:round]

        16.times do |i|
          s = data[:s][i % 4]
          k = data[:k][i]
          t = T[data[:t][i]]

          # puts "ROUND#{round}:#{i}"
          # puts "ROUND#{round}: k=#{k} s=#{s} ti=#{t}"
          # puts "  a=#{a.inspect} b=#{b.inspect} c=#{c.inspect} d=#{d.inspect}"
          # puts "  x[k]=#{x[k].inspect}"
          # puts "  Ti=#{t.inspect}"
          # puts "  #{data[:method]}(b,c,d)=#{MD5Word.send(data[:method], b,c,d).inspect}"
          # puts "  a+f(bcd)+ti = #{(a + MD5Word.send(data[:method], b,c,d) + t).inspect}"
          # puts "  a+f(bcd)+xk+ti = #{(a + MD5Word.send(data[:method], b,c,d) + x[k] + t).inspect}"
          # puts "        a=#{a.to_s} b=#{b.to_s} c=#{c.to_s} d=#{d.to_s}"

          a = (b + (a + MD5Word.send(data[:method], b,c,d) + x[k] + t).rotate_left(s))
          a, b, c, d = [a, b, c, d].rotate(-1)
        end
        puts "ROUND#{round} COMPLETE:"
        puts "a = #{a.inspect}"
        puts "b = #{b.inspect}"
        puts "c = #{c.inspect}"
        puts "d = #{d.inspect}"
      end
      [a, b, c, d]
    end


  end


  # class MD5Byte
  #   def initialize(char)
  #     @char = char
  #   end

  #   def to_i
  #     @char.ord
  #   end
  # end

  class MD5Word
    def initialize(bytes)
      @bytes = bytes.force_encoding("BINARY")
      raise ArgumentError, "A word is 4 bytes (got #{@bytes.inspect})" if @bytes.length != 4
    end

    def to_hex
      @bytes.reverse.unpack("H*")
    end

    def to_i
      MD5Word.bytes_to_integer(@bytes)
    end

    def inspect
      @bytes.unpack("H*").first
    end

    def to_s
      @bytes
    end

    def +(another)
      MD5Word.new(MD5Word.integer_to_bytes((self.to_i + another.to_i)))
    end

    def rotate_left(n)
      new_int = (((self.to_i) << (n)) | ((self.to_i) >> (32 - (n))))
      MD5Word.new(MD5Word.integer_to_bytes(new_int))
      # pp "N is #{n}"
      # MD5Word.new(MD5Word.integer_to_bytes(n))
    end

    class << self
      def f(x, y, z)
        result = (x.to_i & y.to_i) | ((~(x.to_i)) & z.to_i)
        new_from_integer(result)
      end

      def g(x, y, z)
        result = (x.to_i & z.to_i) | (y.to_i & (~z.to_i))
        new_from_integer(result)
      end

      def h(x, y, z)
        result = x.to_i ^ y.to_i ^ z.to_i
        new_from_integer(result)
      end

      def i(x, y, z)
        result = y.to_i ^ (x.to_i | (~z.to_i))
        new_from_integer(result)
      end

      def bytes_to_integer(bytes)
        bytes.reverse.unpack("L<").first
      end

      def integer_to_bytes(int)
        [int].pack("L<").reverse
      end

      def new_from_integer(int)
        new(integer_to_bytes(int))
      end
    end
  end
end















ROUNDS = [
  {
    round: 1,
    method: :f,
    s: [7, 12, 17, 22],
    k: (0..15).to_a,
    t: (0..15).to_a
  },
  {
    round: 2,
    method: :g,
    s: [5, 9, 14, 20],
    k: [1, 6, 11, 0, 5, 10, 15, 4, 9, 14, 3, 8, 13, 2, 7, 12],
    t: (16..31).to_a
  },
  {
    round: 3,
    method: :h,
    s: [4, 11, 16, 23],
    k: [5, 8, 11, 14, 1, 4, 7, 10, 13, 0, 3, 6, 9, 12, 15, 2],
    t: (32..47).to_a
  },
  {
    round: 4,
    method: :i,
    s: [6, 10, 15, 21],
    k: [0, 7, 14, 5, 12, 3, 10, 1, 8, 15, 6, 13, 4, 11, 2, 9],
    t: (48..63).to_a
  }

]

T = [
  "\xd7\x6a\xa4\x78", "\xe8\xc7\xb7\x56", "\x24\x20\x70\xdb", "\xc1\xbd\xce\xee",
  "\xf5\x7c\x0f\xaf", "\x47\x87\xc6\x2a", "\xa8\x30\x46\x13", "\xfd\x46\x95\x01",
  "\x69\x80\x98\xd8", "\x8b\x44\xf7\xaf", "\xff\xff\x5b\xb1", "\x89\x5c\xd7\xbe",
  "\x6b\x90\x11\x22", "\xfd\x98\x71\x93", "\xa6\x79\x43\x8e", "\x49\xb4\x08\x21",

  "\xf6\x1e\x25\x62", "\xc0\x40\xb3\x40", "\x26\x5e\x5a\x51", "\xe9\xb6\xc7\xaa",
  "\xd6\x2f\x10\x5d", "\x02\x44\x14\x53", "\xd8\xa1\xe6\x81", "\xe7\xd3\xfb\xc8",
  "\x21\xe1\xcd\xe6", "\xc3\x37\x07\xd6", "\xf4\xd5\x0d\x87", "\x45\x5a\x14\xed",
  "\xa9\xe3\xe9\x05", "\xfc\xef\xa3\xf8", "\x67\x6f\x02\xd9", "\x8d\x2a\x4c\x8a",

  "\xff\xfa\x39\x42", "\x87\x71\xf6\x81", "\x6d\x9d\x61\x22", "\xfd\xe5\x38\x0c",
  "\xa4\xbe\xea\x44", "\x4b\xde\xcf\xa9", "\xf6\xbb\x4b\x60", "\xbe\xbf\xbc\x70",
  "\x28\x9b\x7e\xc6", "\xea\xa1\x27\xfa", "\xd4\xef\x30\x85", "\x04\x88\x1d\x05",
  "\xd9\xd4\xd0\x39", "\xe6\xdb\x99\xe5", "\x1f\xa2\x7c\xf8", "\xc4\xac\x56\x65",

  "\xf4\x29\x22\x44", "\x43\x2a\xff\x97", "\xab\x94\x23\xa7", "\xfc\x93\xa0\x39",
  "\x65\x5b\x59\xc3", "\x8f\x0c\xcc\x92", "\xff\xef\xf4\x7d", "\x85\x84\x5d\xd1",
  "\x6f\xa8\x7e\x4f", "\xfe\x2c\xe6\xe0", "\xa3\x01\x43\x14", "\x4e\x08\x11\xa1",
  "\xf7\x53\x7e\x82", "\xbd\x3a\xf2\x35", "\x2a\xd7\xd2\xbb", "\xeb\x86\xd3\x91"
].map do |bytes|
  JG::MD5Word.new(bytes.force_encoding("BINARY"))
end



m = JG::MD5.new("")
# pp m.words
# pp m.words.map(&:to_i)
# pp m.digested_words
pp m.hexdigest
