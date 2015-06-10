require 'spec_helper'

describe Furi do

  class PartsMatcher

    def initialize(expectation)
      @expectation = expectation
    end

    def matches?(text)
      @uri = Furi.parse(text)
      @expectation.each do |part, value|
        if @uri.send(part) != value
          @unmatched_part = part
          return false
        end
      end
      return true
    end

    def failure_message
      "Expected #{@unmatched_part.inspect} to equal #{@expectation[@unmatched_part].inspect}, but it was #{@uri.send(@unmatched_part).inspect}"
    end

  end

  class SerializeAs
    def initialize(expectation)
      @expectation = expectation
      if @expectation.is_a?(Array)
        @expectation = @expectation.map do |item|
          item.map {|z| CGI.escape(z.to_s)}.join("=")
        end.join("&")
      end
    end

    def matches?(hash)
      @hash = hash
      Furi.serialize(hash) == @expectation
    end

    def failure_message
      "Expected #{@hash.inspect} to serialize as #{@expectation.inspect}, but was serialized as #{Furi.serialize(@hash)}.\n" +
        "Debug: #{unserialize(@expectation)}, but was serialized as #{unserialize(Furi.serialize(@hash))}"
    end

    def unserialize(string)
      string.split("&").map do |z|
        z.split("=").map do |q|
          CGI.unescape(q)
        end
      end.inspect
    end
  end

  def have_parts(parts)
    PartsMatcher.new(parts)
  end

  def serialize_as(value)
    SerializeAs.new(value)
  end


  it "parses URL without path" do
    expect("http://gusiev.com").to have_parts(
                                              protocol: 'http',
                                              host: 'gusiev.com',
                                              query_string: nil,
                                              query: {},
                                              path: nil,
                                              port: nil,
                                             )
  end

  it "extracts anchor" do
    expect("http://gusiev.com/posts/index.html?a=b#zz").to have_parts(
      anchor: 'zz',
      query_string: 'a=b',
      path: '/posts/index.html',
      port: nil,
      protocol: 'http',
    )
  end

  it "works with path without URL" do
    expect("/posts/index.html").to have_parts(
      path: '/posts/index.html',
      host: nil,
      port: nil,
      protocol: nil,
    )
  end

  it "parses uri with user and password" do
    expect("http://user:pass@gusiev.com").to have_parts(
      username: 'user',
      password: 'pass',
      host: 'gusiev.com',
      query_string: nil,
      anchor: nil,
    )
  end

  it "parses uri with user and without password" do
    expect("http://user@gusiev.com").to have_parts(
      username: 'user',
      password: nil,
      host: 'gusiev.com',
      query_string: nil,
      anchor: nil,
    )
  end


  it "supports aliases" do
    expect("http://gusiev.com#zz").to have_parts(
      schema: 'http',
      fragment: 'zz',
    )
  end

  it "parses uri with explicit port and auth data" do
    expect("http://user:pass@gusiev.com:80").to have_parts(
      username: 'user',
      password: 'pass',
      protocol: 'http',
      port: 80,
      query_string: nil,
    )
  end
  it "parses url with query" do
    expect("/index.html?a=b&c=d").to have_parts(
      query_string: 'a=b&c=d',
      query: {'a' => 'b', 'c' => 'd'}
    )
  end

  it "finds out port if not explicitly defined`" do
    expect("http://gusiev.com").to have_parts(
      protocol: 'http',
      port: nil,
      "port!" => 80
    )
  end

  it "support update for query" do
    expect(Furi.update("/index.html?a=b", query: {c: 'd'})).to eq('/index.html?c=d')
  end

  describe "serialize" do
    it "should work" do
      expect({a: 'b'}).to serialize_as("a=b")
      expect(a: nil).to serialize_as("a=")
      expect(nil).to serialize_as("")
      expect(b: 2, a: 1).to serialize_as("b=2&a=1")
      expect(a: {b: {c: []}}).to serialize_as("")
      expect({:a => {:b => 'c'}}).to serialize_as("a%5Bb%5D=c")
      expect(q: [1,2]).to serialize_as("q%5B%5D=1&q%5B%5D=2")
      expect(a: {b: [1,2]}).to serialize_as("a%5Bb%5D%5B%5D=1&a%5Bb%5D%5B%5D=2")
      expect(q: "cowboy hat?").to serialize_as("q=cowboy+hat%3F")
      expect(a: true).to serialize_as("a=true")
      expect(a: false).to serialize_as("a=false")
      expect(a: [nil, 0]).to serialize_as("a%5B%5D=&a%5B%5D=0")
      expect(a: [0, [1,2]]).to serialize_as("a%5B%5D=0&a%5B%5D%5B%5D=1&a%5B%5D%5B%5D=2")
      expect(a: [0, [1,2]]).to serialize_as([["a[]", 0],["a[][]", 1],["a[][]", 2]])
      expect({"f": ["b", 42, "your base"] }).to serialize_as("f%5B%5D=b&f%5B%5D=42&f%5B%5D=your+base")
      expect({"a[]": 1 }).to serialize_as("a%5B%5D=1")
      expect("a" => [1, 2], "b" => "blah" ).to serialize_as("a%5B%5D=1&a%5B%5D=2&b=blah")
      expect(->{
        Furi.serialize([1,2])
      }).to raise_error(ArgumentError)


      params = { b:{ c:3, d:[4,5], e:{ x:[6], y:7, z:[8,9] }}};
      expect(CGI.unescape(Furi.serialize(params))).to eq("b[c]=3&b[d][]=4&b[d][]=5&b[e][x][]=6&b[e][y]=7&b[e][z][]=8&b[e][z][]=9")

      params = { "a": [ 0, [ 1, 2 ], [ 3, [ 4, 5 ], [ 6 ] ], { "b": [ 7, [ 8, 9 ], [ { "c": 10, "d": 11 } ], [ [ 12 ] ], [ [ [ 13 ] ] ], { "e": { "f": { "g": [ 14, [ 15 ] ] } } }, 16 ] }, 17 ] };
      expect( CGI.unescape( Furi.serialize(params) ), "a[]=0&a[1][]=1&a[1][]=2&a[2][]=3&a[2][1][]=4&a[2][1][]=5&a[2][2][]=6&a[3][b][]=7&a[3][b][1][]=8&a[3][b][1][]=9&a[3][b][2][0][c]=10&a[3][b][2][0][d]=11&a[3][b][3][0][]=12&a[3][b][4][0][0][]=13&a[3][b][5][e][f][g][]=14&a[3][b][5][e][f][g][1][]=15&a[3][b][]=16&a[]=17", "nested arrays" );


      expect( decodeURIComponent( uery.param({ "a": [1,2,3], "b[]": [4,5,6], "c[d]": [7,8,9], "e": { "f": [10], "g": [11,12], "h": 13 } }) ), "a[]=1&a[]=2&a[]=3&b[]=4&b[]=5&b[]=6&c[d][]=7&c[d][]=8&c[d][]=9&e[f][]=10&e[g][]=11&e[g][]=12&e[h]=13", "Make sure params are not double-encoded." );

      expect( "jquery": "1.4.2").to serialize_as("jquery=1.4.2")

    end
  end


end
#"a[]=1&a[]=2&b[c]=3&b[d][]=4&b[d][]=5&b[e][x][]=6&b[e][y]=7&b[e][z][]=8&b[e][z][]=9&b[f]=true&b[g]=false&b[h]=&i[]=10&i[]=11&j=true&k=false&l[]=&l[]=0&m=cowboy+hat?"
#"a[]=1&a[]=2&b[c]=3&b[d][]=4&b[d][]=5&b[e][x][]=6&b[e][y]=7&b[e][z][]=8&b[e][z][]=9&b[f]=true&b[g]=false&b[h]=&i[]=10&i[]=11&j=true&k=false&l[]=&l[]=0&m=cowboy hat?"
#
#
#a%5B%5D%3D1%26a%5B%5D%3D2%26b%5Bc%5D%3D3%26b%5Bd%5D%5B%5D%3D4%26b%5Bd%5D%5B%5D%3D5%26b%5Be%5D%5Bx%5D%5B%5D%3D6%26b%5Be%5D%5By%5D%3D7%26b%5Be%5D%5Bz%5D%5B%5D%3D8%26b%5Be%5D%5Bz%5D%5B%5D%3D9%26b%5Bf%5D%3Dtrue%26b%5Bg%5D%3Dfalse%26b%5Bh%5D%3D%26i%5B%5D%3D10%26i%5B%5D%3D11%26j%3Dtrue%26k%3Dfalse%26l%5B%5D%3D%26l%5B%5D%3D0%26m%3Dcowboy%2Bhat%3F"
#a%5B%5D=1&a%5B%5D=2&b%5Bc%5D=3&b%5Bd%5D%5B%5D=4&b%5Bd%5D%5B%5D=5&b%5Be%5D%5Bx%5D%5B%5D=6&b%5Be%5D%5By%5D=7&b%5Be%5D%5Bz%5D%5B%5D=8&b%5Be%5D%5Bz%5D%5B%5D=9&b%5Bf%5D=true&b%5Bg%5D=false&b%5Bh%5D=&i%5B%5D=10&i%5B%5D=11&j=true&k=false&l%5B%5D=&l%5B%5D=0&m=cowboy+hat%3F
