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
          item.split("=").map {|z| CGI.escape(z.to_s)}.join("=")
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



  describe "#parse" do
    it "parses URL without path" do
      expect("http://gusiev.com").to have_parts(
        protocol: 'http',
        hostname: 'gusiev.com',
        query_string: "",
        query: {},
        path: nil,
        path!: '/',
        port: nil,
        request: '/',
        resource: '/',
      )
    end

    it "extracts anchor" do
      expect("http://gusiev.com/posts/index.html?a=b#zz").to have_parts(
        anchor: 'zz',
        query_string: 'a=b',
        path: '/posts/index.html',
        port: nil,
        protocol: 'http',
        resource: '/posts/index.html?a=b#zz',
        request: '/posts/index.html?a=b',
      )
    end

    it "works with path without URL" do
      expect("/posts/index.html").to have_parts(
        path: '/posts/index.html',
        hostname: nil,
        port: nil,
        protocol: nil,
      )
    end

    it "parses uri with user and password" do
      expect("http://user:pass@gusiev.com").to have_parts(
        username: 'user',
        password: 'pass',
        hostname: 'gusiev.com',
        query_string: "",
        anchor: nil,
      )
    end

    it "parses uri with user and without password" do
      expect("http://user@gusiev.com").to have_parts(
        username: 'user',
        password: nil,
        hostname: 'gusiev.com',
        query_string: "",
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
        userinfo: 'user:pass',
        protocol: 'http',
        port: 80,
        query_string: "",
      )
    end
    it "parses url with query" do
      expect("/index.html?a=b&c=d").to have_parts(
        host: nil,
        host!: '',
        query_string: 'a=b&c=d',
        query: {'a' => 'b', 'c' => 'd'},
        request: '/index.html?a=b&c=d',
      )
    end

    it "finds out port if not explicitly defined`" do
      expect("http://gusiev.com").to have_parts(
        protocol: 'http',
        port: nil,
        "port!" => 80
      )
    end
    it "parses nested query" do
      expect("gusiev.com?a[]=1&a[]=2&b[c]=1&b[d]=2").to have_parts(
        host: 'gusiev.com',
        query: {"a" => ["1","2"], "b" => {"c" => "1", "d" => "2"}},
      )
    end

    it "find out protocol security" do
      expect("gusiev.com:443").to have_parts(
        host: 'gusiev.com',
        :"ssl" => false
      )
      expect("https://gusiev.com:443").to have_parts(
        host: 'gusiev.com',
        :"ssl" => true
      )
    end
  end
  describe ".update" do
    
    it "support update for query" do
      expect(Furi.update("/index.html?a=b", query: {c: 'd'})).to eq('/index.html?c=d')
    end

    it "updates hostname" do
      expect(Furi.update("www.gusiev.com/index.html", hostname: 'gusiev.com')).to eq('gusiev.com/index.html')
      expect(Furi.update("/index.html", hostname: 'gusiev.com')).to eq('gusiev.com/index.html')
      expect(Furi.update("http://www.gusiev.com/index.html", hostname: 'gusiev.com')).to eq('http://gusiev.com/index.html')
      expect(Furi.update("/index.html", hostname: 'gusiev.com')).to eq('gusiev.com/index.html')
      expect(Furi.update("gusiev.com/index.html?a=b", hostname: nil)).to eq('/index.html?a=b')
      expect(Furi.update("gusiev.com?a=b", hostname: nil)).to eq('/?a=b')
    end

    it "updates port" do
      expect(Furi.update("gusiev.com", port: 33)).to eq('gusiev.com:33')
      expect(Furi.update("gusiev.com/index.html", port: 33)).to eq('gusiev.com:33/index.html')
      expect(Furi.update("gusiev.com:33/index.html", port: 80)).to eq('gusiev.com:80/index.html')
      expect(Furi.update("http://gusiev.com:33/index.html", port: 80)).to eq('http://gusiev.com/index.html')
    end

    it "updates ssl" do
      expect(Furi.update("http://gusiev.com", ssl: true)).to eq('https://gusiev.com')
      expect(Furi.update("https://gusiev.com", ssl: true)).to eq('https://gusiev.com')
      expect(Furi.update("https://gusiev.com", ssl: false)).to eq('http://gusiev.com')
      expect(Furi.update("http://gusiev.com", ssl: false)).to eq('http://gusiev.com')
    end
    it "updates protocol" do
      expect(Furi.update("http://gusiev.com", protocol: '')).to eq('//gusiev.com')
      expect(Furi.update("http://gusiev.com", protocol: nil)).to eq('gusiev.com')
      expect(Furi.update("http://gusiev.com", protocol: 'https')).to eq('https://gusiev.com')
      expect(Furi.update("gusiev.com", protocol: 'http')).to eq('http://gusiev.com')
      expect(Furi.update("gusiev.com", protocol: 'http:')).to eq('http://gusiev.com')
      expect(Furi.update("gusiev.com", protocol: 'http:/')).to eq('http://gusiev.com')
      expect(Furi.update("gusiev.com", protocol: 'http://')).to eq('http://gusiev.com')
    end

  end

  describe ".build" do
    it "should work correctly" do
      expect(Furi.build(hostname: 'hello.com')).to eq('hello.com')
      expect(Furi.build(hostname: 'hello.com', port: 88)).to eq('hello.com:88')
      expect(Furi.build(hostname: 'hello.com', port: 88)).to eq('hello.com:88')
      expect(Furi.build(schema: 'https', hostname: 'hello.com', port: 88)).to eq('https://hello.com:88')
      expect(Furi.build(schema: 'http', hostname: 'hello.com', port: 80)).to eq('http://hello.com')
      expect(Furi.build(path: '/index.html', query: {a: 1, b: 2})).to eq('/index.html?a=1&b=2')
    end
  end

  describe ".merge" do
    it "should work" do
      expect(Furi.merge("//gusiev.com", query: {a: 1})).to eq('//gusiev.com?a=1')
      expect(Furi.merge("//gusiev.com?a=1", query: {b: 2})).to eq('//gusiev.com?a=1&b=2')
      expect(Furi.merge("//gusiev.com?a=1", query: {a: 2})).to eq('//gusiev.com?a=2')
      expect(Furi.merge("//gusiev.com?a=1", query: [['a', 2], ['b', 3]])).to eq('//gusiev.com?a=1&a=2&b=3')
      expect(Furi.merge("//gusiev.com?a=1&b=2", query: '?a=3')).to eq('//gusiev.com?a=1&b=2&a=3')
    end
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
      expect({f: ["b", 42, "your base"] }).to serialize_as("f%5B%5D=b&f%5B%5D=42&f%5B%5D=your+base")
      expect({"a[]" => 1 }).to serialize_as("a%5B%5D=1")
      expect({"a[b]" => [1] }).to serialize_as(["a[b][]=1"])
      expect("a" => [1, 2], "b" => "blah" ).to serialize_as("a%5B%5D=1&a%5B%5D=2&b=blah")

      expect(a: [1,{c: 2, b: 3}, 4]).to serialize_as(["a[]=1", "a[][c]=2", "a[][b]=3", "a[]=4"])
      expect(->{
        Furi.serialize([1,2])
      }).to raise_error(ArgumentError)
      expect(->{
        Furi.serialize(a: [1,[2]])
      }).to raise_error(ArgumentError)


      params = { b:{ c:3, d:[4,5], e:{ x:[6], y:7, z:[8,9] }}};
      expect(CGI.unescape(Furi.serialize(params))).to eq("b[c]=3&b[d][]=4&b[d][]=5&b[e][x][]=6&b[e][y]=7&b[e][z][]=8&b[e][z][]=9")

    end
  end

  describe "parse_nested_query" do
    it "should work" do
    Furi.parse_nested_query("foo").
      should eq "foo" => nil
    Furi.parse_nested_query("foo=").
      should eq "foo" => ""
    Furi.parse_nested_query("foo=bar").
      should eq "foo" => "bar"
    Furi.parse_nested_query("foo=\"bar\"").
      should eq "foo" => "\"bar\""

    Furi.parse_nested_query("foo=bar&foo=quux").
      should eq "foo" => "quux"
    Furi.parse_nested_query("foo&foo=").
      should eq "foo" => ""
    Furi.parse_nested_query("foo=1&bar=2").
      should eq "foo" => "1", "bar" => "2"
    Furi.parse_nested_query("&foo=1&&bar=2").
      should eq "foo" => "1", "bar" => "2"
    Furi.parse_nested_query("foo&bar=").
      should eq "foo" => nil, "bar" => ""
    Furi.parse_nested_query("foo=bar&baz=").
      should eq "foo" => "bar", "baz" => ""
    Furi.parse_nested_query("my+weird+field=q1%212%22%27w%245%267%2Fz8%29%3F").
      should eq "my weird field" => "q1!2\"'w$5&7/z8)?"

    Furi.parse_nested_query("a=b&pid%3D1234=1023").
      should eq "pid=1234" => "1023", "a" => "b"

    Furi.parse_nested_query("foo[]").
      should eq "foo" => [nil]
    Furi.parse_nested_query("foo[]=").
      should eq "foo" => [""]
    Furi.parse_nested_query("foo[]=bar").
      should eq "foo" => ["bar"]

    Furi.parse_nested_query("foo[]=1&foo[]=2").
      should eq "foo" => ["1", "2"]
    Furi.parse_nested_query("foo=bar&baz[]=1&baz[]=2&baz[]=3").
      should eq "foo" => "bar", "baz" => ["1", "2", "3"]
    Furi.parse_nested_query("foo[]=bar&baz[]=1&baz[]=2&baz[]=3").
      should eq "foo" => ["bar"], "baz" => ["1", "2", "3"]

    Furi.parse_nested_query("x[y][z]=1").
      should eq "x" => {"y" => {"z" => "1"}}
    Furi.parse_nested_query("x[y][z][]=1").
      should eq "x" => {"y" => {"z" => ["1"]}}
    Furi.parse_nested_query("x[y][z]=1&x[y][z]=2").
      should eq "x" => {"y" => {"z" => "2"}}
    Furi.parse_nested_query("x[y][z][]=1&x[y][z][]=2").
      should eq "x" => {"y" => {"z" => ["1", "2"]}}

    Furi.parse_nested_query("x[y][][z]=1").
      should eq "x" => {"y" => [{"z" => "1"}]}
    Furi.parse_nested_query("x[y][][z][]=1").
      should eq "x" => {"y" => [{"z" => ["1"]}]}
    Furi.parse_nested_query("x[y][][z]=1&x[y][][w]=2").
      should eq "x" => {"y" => [{"z" => "1", "w" => "2"}]}

    Furi.parse_nested_query("x[y][][v][w]=1").
      should eq "x" => {"y" => [{"v" => {"w" => "1"}}]}
    Furi.parse_nested_query("x[y][][z]=1&x[y][][v][w]=2").
      should eq "x" => {"y" => [{"z" => "1", "v" => {"w" => "2"}}]}

    Furi.parse_nested_query("x[y][][z]=1&x[y][][z]=2").
      should eq "x" => {"y" => [{"z" => "1"}, {"z" => "2"}]}
    Furi.parse_nested_query("x[y][][z]=1&x[y][][w]=a&x[y][][z]=2&x[y][][w]=3").
      should eq "x" => {"y" => [{"z" => "1", "w" => "a"}, {"z" => "2", "w" => "3"}]}

    lambda { Furi.parse_nested_query("x[y]=1&x[y]z=2") }.
      should raise_error(TypeError,  "expected Hash (got String) for param `y'")

    lambda { Furi.parse_nested_query("x[y]=1&x[]=1") }.
      should raise_error(TypeError, /expected Array \(got [^)]*\) for param `x'/)

    lambda { Furi.parse_nested_query("x[y]=1&x[y][][w]=2") }.
      should raise_error(TypeError, "expected Array (got String) for param `y'")
    end

  end

end
