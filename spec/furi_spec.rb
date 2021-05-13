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

  describe ".parse" do

    it "raises on empty string" do
      expect {
        Furi.parse("")
      }.to raise_error(Furi::FormattingError)
    end

    it "parses URL with everything" do
      expect("http://user:pass@www.gusiev.com:8080/articles/index.html?a=1&b=2#header").to have_parts(
        location: 'http://user:pass@www.gusiev.com:8080',
        protocol: 'http',
        schema: 'http',
        authority: 'user:pass@www.gusiev.com:8080',
        hostinfo: 'www.gusiev.com:8080',
        host: 'www.gusiev.com',
        subdomain: 'www',
        domain: 'gusiev.com',
        domainzone: 'com',
        port: 8080,
        userinfo: 'user:pass',
        username: 'user',
        password: 'pass',

        resource: '/articles/index.html?a=1&b=2#header',
        path: "/articles/index.html",
        file: 'index.html',
        extension: 'html',
        query_string: "a=1&b=2",
        query_tokens: [['a', '1'], ['b', '2']],
        query: {'a' => '1', 'b' => '2'},
        request: '/articles/index.html?a=1&b=2',
        anchor: 'header',
        fragment: 'header',
        home_page?: false,
      )

    end
    it "parses URL without path" do
      expect("http://gusiev.com").to have_parts(
        protocol: 'http',
        hostname: 'gusiev.com',
        query_string: nil,
        query: {},
        path: nil,
        path!: '/',
        port: nil,
        request: nil,
        request!: '/',
        resource: nil,
        resource!: '/',
        location: 'http://gusiev.com',
        home_page?: true,
      )
    end

    it "parses URL with root path" do
      expect("http://gusiev.com/?a=b").to have_parts(
        hostname: 'gusiev.com',
        path: '/',
        path!: '/',
        request: '/?a=b',
        home_page?: true,
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
        location: 'http://gusiev.com',
        file: 'index.html',
        extension: 'html',
      )
    end

    it "works with path without URL" do
      expect("/posts/index.html").to have_parts(
        path: '/posts/index.html',
        hostname: nil,
        port: nil,
        protocol: nil,
        location: nil,
        extension: 'html',
        home_page?: false,
      )
    end

    it "works with path ending at slash" do

      expect("/posts/").to have_parts(
        path: '/posts/',
        directory: '/posts',
        file: nil,
        'file!' =>  '',
        extension: nil,
        home_page?: false,
      )
    end

    it "parses uri with user and password" do
      expect("http://user:pass@gusiev.com").to have_parts(
        username: 'user',
        password: 'pass',
        hostname: 'gusiev.com',
        query_string: nil,
        anchor: nil,
        location: 'http://user:pass@gusiev.com',
      )
    end

    it "parses uri with user and without password" do
      expect("http://user@gusiev.com").to have_parts(
        username: 'user',
        password: nil,
        hostname: 'gusiev.com',
        query_string: nil,
        anchor: nil,
        location: 'http://user@gusiev.com',
      )
    end


    it "supports aliases" do
      expect("http://gusiev.com#zz").to have_parts(
        location: 'http://gusiev.com',
      )
    end

    it "parses uri with explicit port and auth data" do
      expect("http://user:pass@gusiev.com:80").to have_parts(
        username: 'user',
        password: 'pass',
        userinfo: 'user:pass',
        protocol: 'http',
        port: 80,
        query_string: nil,
      )
    end

    it "parses custom port" do
      expect("http://gusiev.com:8080").to have_parts(
        hostname: 'gusiev.com',
        hostinfo: 'gusiev.com:8080',
        protocol: 'http',
        port: 8080,
      )

    end
    it "parses url with query" do
      expect("/index.html?a=b&c=d").to have_parts(
        host: nil,
        host!: '',
        query_string: 'a=b&c=d',
        query: {'a' => 'b', 'c' => 'd'},
        request: '/index.html?a=b&c=d',
        home_page?: true,
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

    it "parses host into parts" do
      expect("http://www.gusiev.com.ua").to have_parts(
        domain: 'gusiev.com.ua',
        subdomain: 'www',
        domainname: 'gusiev',
        domainzone: 'com.ua'
      )
      expect("http://www.com.ua").to have_parts(
        domain: 'www.com.ua',
        subdomain: nil,
        domainname: 'www',
        domainzone: 'com.ua'
      )
      expect("http://com.ua").to have_parts(
        domain: 'com.ua',
        subdomain: nil,
        domainname: 'com',
        domainzone: 'ua'
      )
      expect("http://www.blog.gusiev.com.ua").to have_parts(
        domain: 'gusiev.com.ua',
        subdomain: 'www.blog',
        domainname: 'gusiev',
        domainzone: 'com.ua'
      )
    end

    it "parses double # in anchor" do
      expect("/index?a=1#c#d").to have_parts(
        anchor: 'c#d',
        query_string: "a=1",
        path: '/index',
      )
    end

    it "parses anchor with special characters" do
      expect("/index#c%20d").to have_parts(
        anchor: 'c d',
        path: '/index',
      )
    end

    it "parses blank port with protocol" do
      expect("http://gusiev.com:/hello").to have_parts(
        path: '/hello',
        port: nil,
        host: 'gusiev.com',
        protocol: 'http',
      )
    end
    it "parses blank port without protocol" do
      expect("gusiev.com:/hello").to have_parts(
        path: '/hello',
        port: nil,
        host: 'gusiev.com',
        protocol: nil,
      )
    end

    it "parses 0 port as blank port" do
      expect("http://gusiev.com:0/hello").to have_parts(
        path: '/hello',
        port: 0,
        host: 'gusiev.com',
        protocol: 'http',
      )
    end

    it "downcases only protocol and host" do
      expect("HTTP://GUSIEV.cOM/About").to have_parts(
        protocol: 'http',
        host: 'gusiev.com',
        path: "/About",
      )
    end

    describe "ipv6 host" do
      it "parses host and port" do
        expect("http://[2406:da00:ff00::6b14:8d43]:8080/").to have_parts(
          path: '/',
          port: 8080,
          host: '[2406:da00:ff00::6b14:8d43]',
          protocol: 'http',
        )
      end
      it "parses host and nil port" do

        expect("http://[2406:da00:ff00::6b14:8d43]:/hello").to have_parts(
          path: '/hello',
          port: nil,
          host: '[2406:da00:ff00::6b14:8d43]',
          protocol: 'http',
        )
      end

      it "parses host without protocol and port" do
        expect("[2406:da00:ff00::6b14:8d43]/hello").to have_parts(
          path: '/hello',
          port: nil,
          host: '[2406:da00:ff00::6b14:8d43]',
          protocol: nil,
        )
      end
    end

    describe "mailto" do
      it "without email" do
        expect("mailto:?subject=Talkable%20is%20Hiring&body=https%3A%2F%2Fwww.talkable.com%2Fjobs").to have_parts(
          protocol: 'mailto',
          email: nil,
          query: {
            "subject" => "Talkable is Hiring",
            "body" => "https://www.talkable.com/jobs"
          }
        )
      end
    end
  end
  describe ".replace" do

    it "support replace for query" do
      expect(Furi.replace("/index.html?a=b", query: {c: 'd'})).to eq('/index.html?c=d')
    end

    it "replace hostname" do
      expect(Furi.replace("www.gusiev.com/index.html", hostname: 'gusiev.com')).to eq('gusiev.com/index.html')
      expect(Furi.replace("/index.html", hostname: 'gusiev.com')).to eq('gusiev.com/index.html')
      expect(Furi.replace("http://www.gusiev.com/index.html", hostname: 'gusiev.com')).to eq('http://gusiev.com/index.html')
      expect(Furi.replace("/index.html", hostname: 'gusiev.com')).to eq('gusiev.com/index.html')
      expect(Furi.replace("gusiev.com/index.html?a=b", hostname: nil)).to eq('/index.html?a=b')
      expect(Furi.replace("gusiev.com?a=b", hostname: nil)).to eq('/?a=b')
    end

    it "replace port" do
      expect(Furi.replace("gusiev.com", port: 33)).to eq('gusiev.com:33')
      expect(Furi.replace("gusiev.com/index.html", port: 33)).to eq('gusiev.com:33/index.html')
      expect(Furi.replace("gusiev.com:33/index.html", port: 80)).to eq('gusiev.com:80/index.html')
      expect(Furi.replace("http://gusiev.com:33/index.html", port: 80)).to eq('http://gusiev.com/index.html')
      expect(Furi.replace("http://gusiev.com:33/index.html", port: nil)).to eq('http://gusiev.com/index.html')
      expect(Furi.replace("http://gusiev.com:33/index.html", port: 0)).to eq('http://gusiev.com:0/index.html')
      expect(Furi.replace("http://gusiev.com:33/index.html", port: '')).to eq('http://gusiev.com/index.html')
    end
    it "replace directory" do
      expect(Furi.replace("gusiev.com", directory: 'articles')).to eq('gusiev.com/articles')
      expect(Furi.replace("gusiev.com/", directory: 'articles')).to eq('gusiev.com/articles')
      expect(Furi.replace("gusiev.com/index#header", directory: '/posts')).to eq('gusiev.com/posts/index#header')
      expect(Furi.replace("gusiev.com/articles/#header", directory: nil)).to eq('gusiev.com/#header')
      expect(Furi.replace("gusiev.com/articles/index?a=b", directory: 'posts')).to eq('gusiev.com/posts/index?a=b')
      expect(Furi.replace("/articles/index?a=b", directory: '/posts')).to eq('/posts/index?a=b')
      expect(Furi.replace("/articles/index.html?a=b", directory: '/posts/')).to eq('/posts/index.html?a=b')
    end
    it "replace file" do
      expect(Furi.replace("gusiev.com", file: 'article')).to eq('gusiev.com/article')
      expect(Furi.replace("gusiev.com/", file: 'article')).to eq('gusiev.com/article')
      expect(Furi.replace("gusiev.com/article1#header", file: '/article2')).to eq('gusiev.com/article2#header')
      expect(Furi.replace("gusiev.com/article#header", file: nil)).to eq('gusiev.com/#header')
      expect(Furi.replace("gusiev.com/articles/article1?a=b", file: 'article2')).to eq('gusiev.com/articles/article2?a=b')
      expect(Furi.replace("/articles/article1?a=b", file: '/article2')).to eq('/articles/article2?a=b')
      expect(Furi.replace("/articles/article1.xml?a=b", file: 'article2.html')).to eq('/articles/article2.html?a=b')
    end
    it "replace extension" do
      expect(->{
       Furi.replace("gusiev.com/", extension: 'xml')
      }).to raise_error(Furi::FormattingError)
      expect(Furi.replace("gusiev.com/article#header", extension: 'html')).to eq('gusiev.com/article.html#header')
      expect(Furi.replace("gusiev.com/article.html?header", extension: nil)).to eq('gusiev.com/article?header')
      expect(Furi.replace("gusiev.com/article.xml?a=b", extension: 'html')).to eq('gusiev.com/article.html?a=b')
    end
    it "replace resource" do
      expect(Furi.replace("gusiev.com", resource: '/article?a=1#hello')).to eq('gusiev.com/article?a=1#hello')
      expect(Furi.replace("gusiev.com/article1#header", resource: '/article2')).to eq('gusiev.com/article2')
      expect(Furi.replace("gusiev.com/article#header", resource: nil)).to eq('gusiev.com')
      expect(Furi.replace("gusiev.com/article1?a=b", resource: 'article2')).to eq('gusiev.com/article2')
    end
    it "replace path" do
      expect(Furi.replace("gusiev.com", path: '/article')).to eq('gusiev.com/article')
      expect(Furi.replace("gusiev.com/article1#header", path: '/article2')).to eq('gusiev.com/article2#header')
      expect(Furi.replace("gusiev.com/article#header", path: nil)).to eq('gusiev.com#header')
      expect(Furi.replace("gusiev.com/article1?a=b", path: 'article2')).to eq('gusiev.com/article2?a=b')
    end

    it "replace ssl" do
      expect(Furi.replace("http://gusiev.com", ssl: true)).to eq('https://gusiev.com')
      expect(Furi.replace("https://gusiev.com", ssl: true)).to eq('https://gusiev.com')
      expect(Furi.replace("https://gusiev.com", ssl: false)).to eq('http://gusiev.com')
      expect(Furi.replace("http://gusiev.com", ssl: false)).to eq('http://gusiev.com')
    end

    it "replace protocol" do
      expect(Furi.replace("http://gusiev.com", protocol: '')).to eq('//gusiev.com')
      expect(Furi.replace("http://gusiev.com", protocol: nil)).to eq('gusiev.com')
      expect(Furi.replace("http://gusiev.com", protocol: 'https')).to eq('https://gusiev.com')
      expect(Furi.replace("gusiev.com", protocol: 'http')).to eq('http://gusiev.com')
      expect(Furi.replace("gusiev.com", protocol: 'http:')).to eq('http://gusiev.com')
      expect(Furi.replace("gusiev.com", protocol: 'http:/')).to eq('http://gusiev.com')
      expect(Furi.replace("gusiev.com", protocol: 'http://')).to eq('http://gusiev.com')
    end

    it "replace userinfo" do
      expect(Furi.replace("http://gusiev.com", userinfo: 'hello:world')).to eq('http://hello:world@gusiev.com')
      expect(Furi.replace("http://aa:bb@gusiev.com", userinfo: 'hello:world')).to eq('http://hello:world@gusiev.com')
      expect(Furi.replace("http://aa:bb@gusiev.com", userinfo: nil)).to eq('http://gusiev.com')
      expect(Furi.replace("http://aa@gusiev.com", userinfo: 'hello:world')).to eq('http://hello:world@gusiev.com')
    end

    it "replace authority" do
      expect(Furi.replace("http://user:pass@gusiev.com:8080/index.html", authority: 'gusiev.com')).to eq('http://gusiev.com/index.html')
    end

    it "replace request" do
      expect(Furi.replace("http://gusiev.com:8080/index.html?c=d", request: '/blog.html?a=b')).to eq('http://gusiev.com:8080/blog.html?a=b')
    end

    it "replace domainzone" do
      expect(Furi.replace("http://gusiev.com:8080", domainzone: 'com.ua')).to eq('http://gusiev.com.ua:8080')
      expect(Furi.replace("http://gusiev.com.ua:8080", domainzone: 'com')).to eq('http://gusiev.com:8080')
      expect(Furi.replace("http://gusiev.com.ua:8080", domainzone: nil)).to eq('http://gusiev:8080')
    end

    it "replace domainname" do
      expect(Furi.replace("http://gusiev.com", domainname: 'google')).to eq('http://google.com')
      expect(Furi.replace("http://gusiev.com", domainname: nil)).to eq('http://com')
    end
    it "replace subdomain" do
      expect(Furi.replace("http://gusiev.com", subdomain: 'blog')).to eq('http://blog.gusiev.com')
      expect(Furi.replace("http://blog.gusiev.com", subdomain: nil)).to eq('http://gusiev.com')
    end

    it "replace location" do
      expect(Furi.replace("/index.html", location: 'http://gusiev.com')).to eq('http://gusiev.com/index.html')
      expect(Furi.replace("/index.html", location: 'http://gusiev.com/')).to eq('http://gusiev.com/index.html')
      expect(Furi.replace("gusiev.com:433/index.html", location: 'gusiev.com:80')).to eq('gusiev.com:80/index.html')
      expect(Furi.replace("gusiev.com:433/index.html", location: nil)).to eq('/index.html')
      expect(Furi.replace("http://gusiev.com:433/index.html", location: nil)).to eq('/index.html')
    end

    it "replace query" do
      expect(Furi.replace("/", query: {a: 1})).to eq('/?a=1')
      expect(Furi.replace("/", query: {a: [1,2]})).to eq('/?a%5B%5D=1&a%5B%5D=2')
      expect(Furi.replace("/", query: {a: 1, b: 2})).to eq('/?a=1&b=2')
      expect(Furi.replace("/?a=1", query: {a: 2})).to eq('/?a=2')
      expect(Furi.replace("/?a=1&a=1", query: true)).to eq('/?a=1')
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
      expect(Furi.build(path: '/', host: 'gusiev.com', query: {a: 1})).to eq('gusiev.com/?a=1')
      expect(Furi.build(path: '/articles/', host: 'gusiev.com', query: {a: 1})).to eq('gusiev.com/articles/?a=1')
      expect(Furi.build(user: 'user', hostname: 'hello.com')).to eq('user@hello.com')
      expect(Furi.build(protocol: 'http', host: 'hello.com', port: 80)).to eq('http://hello.com')
      expect(Furi.build(query: 'a=b')).to eq('/?a=b')

      expect(->{
        Furi.build(host: nil, port: 80)
      }).to raise_error(Furi::FormattingError)
      expect(->{
        Furi.build(host: 'localhost', password: 'pass')
      }).to raise_error(Furi::FormattingError)
    end

    it "builds protocol" do
      expect(Furi.build(protocol: 'http', host: 'hello.com', port: 80)).to eq('http://hello.com')
      expect(Furi.build(protocol: 'mailto', username: "bogdan", host: 'gusiev.com')).to eq('mailto:bogdan@gusiev.com')
      expect(Furi.build(email: "bogdan@gusiev.com")).to eq('mailto:bogdan@gusiev.com')
      expect(Furi.build(protocol: 'mailto', query: {subject: 'Hello', body: "Welcome"})).to eq('mailto:?subject=Hello&body=Welcome')
    end

    it "escapes anchor special characters" do
      expect(Furi.build(path: "/index", anchor: 'a b')).to eq('/index#a%20b')
    end
  end

  describe ".update" do
    it "updates query" do
      expect(Furi.update("//gusiev.com", query: {a: 1})).to eq('//gusiev.com?a=1')
      expect(Furi.update("//gusiev.com?a=1", query: {b: 2})).to eq('//gusiev.com?a=1&b=2')
      expect(Furi.update("//gusiev.com?a=1", query: {a: 2})).to eq('//gusiev.com?a=2')
      expect(Furi.update("//gusiev.com?a=1", query: [['a', 2], ['b', 3]])).to eq('//gusiev.com?a=1&a=2&b=3')
      expect(Furi.update("//gusiev.com?a=1&b=2", query: '?a=3')).to eq('//gusiev.com?a=1&b=2&a=3')
    end
    it "updates query_string" do
      expect(Furi.update("//gusiev.com?a=1&b=2", query_string: '?a=3')).to eq('//gusiev.com?a=1&b=2&a=3')
    end
  end

  describe ".defaults" do
    it "should set protocol" do
      expect(Furi.defaults("gusiev.com", protocol: 'http')).to eq('http://gusiev.com')
      expect(Furi.defaults("gusiev.com", protocol: '//')).to eq('//gusiev.com')
      expect(Furi.defaults("//gusiev.com", protocol: 'http')).to eq('//gusiev.com')
      expect(Furi.defaults("https://gusiev.com", protocol: 'http')).to eq('https://gusiev.com')
    end
    it "should set host" do
      expect(Furi.defaults("https://gusiev.com", subdomain: 'www')).to eq('https://www.gusiev.com')
      expect(Furi.defaults("https://blog.gusiev.com", subdomain: 'www')).to eq('https://blog.gusiev.com')
      expect(Furi.defaults("/index.html", host: 'gusiev.com', protocol: 'http')).to eq('http://gusiev.com/index.html')
    end
    it "should set query" do
      expect(Furi.defaults("gusiev.com?a=1", query: {a: 2})).to eq('gusiev.com?a=1')
      expect(Furi.defaults("gusiev.com?a=1", query: {b: 2})).to eq('gusiev.com?a=1&b=2')
      expect(Furi.defaults("//gusiev.com?a=1", query_string: 'b=2')).to eq('//gusiev.com?a=1')
      expect(Furi.defaults("//gusiev.com", query_string: 'b=2')).to eq('//gusiev.com?b=2')
      expect(Furi.defaults("//gusiev.com?a=1&b=2", query: '?a=3')).to eq('//gusiev.com?a=1&b=2')
    end
    it "should set file" do
      expect(Furi.defaults("gusiev.com?a=1", file: 'index.html')).to eq('gusiev.com/index.html?a=1')
      expect(Furi.defaults("gusiev.com/posts?a=1", file: 'index.html')).to eq('gusiev.com/posts?a=1')
      expect(Furi.defaults("gusiev.com/posts/?a=1", file: 'index.html')).to eq('gusiev.com/posts/index.html?a=1')
      expect(Furi.defaults("gusiev.com/posts/?a=1", file: 'index.html')).to eq('gusiev.com/posts/index.html?a=1')
    end
    it "should set extension" do
      expect {
        Furi.defaults("gusiev.com?a=1", extension: 'html')
      }.to raise_error(Furi::FormattingError)
      expect(Furi.defaults("gusiev.com?a=1", file: 'index.html', extension: 'html')).to eq('gusiev.com/index.html?a=1')
      expect(Furi.defaults("gusiev.com/posts?a=1", extension: 'html')).to eq('gusiev.com/posts.html?a=1')
      #expect(Furi.defaults("gusiev.com/posts/?a=1", file: 'index.html')).to eq('gusiev.com/posts/index.html?a=1')
      #expect(Furi.defaults("gusiev.com/posts/?a=1", file: 'index.html')).to eq('gusiev.com/posts/index.html?a=1')
    end
  end

  describe "#==" do
    it "should work" do
      expect(Furi.parse('http://gusiev.com:80') == Furi.parse('http://gusiev.com')).to be_truthy
      expect(Furi.parse('http://gusiev.com') == Furi.parse('https://gusiev.com')).to be_falsey
      expect(Furi.parse('http://gusiev.com') == Furi.parse('http://gusiev.com')).to be_truthy
      expect(Furi.parse('http://gusiev.com.ua') == Furi.parse('http://gusiev.com')).to be_falsey
      expect(Furi.parse('http://gusiev.com?a=1&a=1') == Furi.parse('http://gusiev.com?a=1')).to be_falsey
    end

    it "works with query parameters" do
      expect(Furi.parse('/?b=1&a=1') == Furi.parse('/?b=1&a=1')).to be_truthy
      expect(Furi.parse('/?a=1&a=1') == Furi.parse('/?a=1')).to be_falsey
      expect(Furi.parse('/') == Furi.parse('/?a=1')).to be_falsey
      expect(Furi.parse('/') == Furi.parse('http://gusiev.com?a=1')).to be_falsey

    end

    it "ignores case only on protocol and host" do
      expect(Furi.parse('hTTp://gUSiev.cOm') == Furi.parse('http://gusiev.com')).to be_truthy
      expect(Furi.parse('/hello') == Furi.parse('/Hello')).to be_falsey
      expect(Furi.parse('/hello?a=1') == Furi.parse('/hello?A=1')).to be_falsey
      expect(Furi.parse('hTTp://gusiev.cOm') == Furi.parse('http://gusiev.com')).to be_truthy
      expect(Furi.parse('/#h1') == Furi.parse('/#H1')).to be_falsey
      expect(Furi.parse('hello@gusiev.com') == Furi.parse('Hello@gusiev.com')).to be_falsey
      expect(Furi.parse('hello:psswd@gusiev.com') == Furi.parse('hello:Psswd@gusiev.com')).to be_falsey
    end

  end

  describe "#abstract_protocol" do
    it "works" do
      expect(Furi.parse('http://gUSiev.cOm')).to_not be_abstract_protocol
      expect(Furi.parse('//gUSiev.cOm')).to be_abstract_protocol
    end
  end

  describe "#clone" do
    it "should work" do

      uri = Furi.parse('http://gusiev.com')
      expect(uri.clone == uri).to be_truthy
      expect(uri.clone.merge_query([[:a, 1]]) == uri).to be_falsey
    end
  end

  describe "#merge_query" do
    it "works" do
      uri = Furi.parse('http://gusiev.com')
      expect(uri.merge_query({user: {first_name: 'Bogdan'}}))
      expect(uri.query_string).to eq('user%5Bfirst_name%5D=Bogdan')
      expect(uri.merge_query({user: {last_name: 'Gusiev'}}))
      expect(uri.query_string).to eq('user%5Bfirst_name%5D=Bogdan&user%5Blast_name%5D=Gusiev')
    end
  end

  describe "serialize" do
    it "should work" do
      expect({a: 'b'}).to serialize_as("a=b")
      expect(a: nil).to serialize_as("a")
      expect(nil).to serialize_as("")
      expect(b: 2, a: 1).to serialize_as("b=2&a=1")
      expect(a: {b: {c: []}}).to serialize_as("")
      expect({:a => {:b => 'c'}}).to serialize_as("a%5Bb%5D=c")
      expect(q: [1,2]).to serialize_as("q%5B%5D=1&q%5B%5D=2")
      expect(a: {b: [1,2]}).to serialize_as("a%5Bb%5D%5B%5D=1&a%5Bb%5D%5B%5D=2")
      expect(q: "cowboy hat?").to serialize_as("q=cowboy+hat%3F")
      expect(a: true).to serialize_as("a=true")
      expect(a: false).to serialize_as("a=false")
      expect(a: [nil, 0]).to serialize_as("a%5B%5D&a%5B%5D=0")
      expect({f: ["b", 42, "your base"] }).to serialize_as("f%5B%5D=b&f%5B%5D=42&f%5B%5D=your+base")
      expect({"a[]" => 1 }).to serialize_as("a%5B%5D=1")
      expect({"a[b]" => [1] }).to serialize_as(["a[b][]=1"])
      expect("a" => [1, 2], "b" => "blah" ).to serialize_as("a%5B%5D=1&a%5B%5D=2&b=blah")

      expect(a: [1,{c: 2, b: 3}, 4]).to serialize_as(["a[]=1", "a[][c]=2", "a[][b]=3", "a[]=4"])
      expect(->{
        Furi.serialize([1,2])
      }).to raise_error(Furi::FormattingError)
      expect(->{
        Furi.serialize(a: [1,[2]])
      }).to raise_error(Furi::FormattingError)


      params = { b:{ c:3, d:[4,5], e:{ x:[6], y:7, z:[8,9] }}};
      expect(URI.decode_www_form_component(Furi.serialize(params))).to eq("b[c]=3&b[d][]=4&b[d][]=5&b[e][x][]=6&b[e][y]=7&b[e][z][]=8&b[e][z][]=9")

    end
  end

  describe ".query_tokens" do
    it "should work" do
      Furi.query_tokens("a=1").should eq [['a', 1]]
      Furi.query_tokens("a==").should eq [['a', '=']]
      Furi.query_tokens("a==1").should eq [['a', '=1']]
      Furi.query_tokens("a=1&").should eq [['a', 1], ["", nil]]
      Furi.query_tokens("&a=1").should eq [["", nil], ['a', 1]]
      Furi.query_tokens("=").should eq [["", ""], ]
      Furi.query_tokens(" ").should eq [[" ", nil], ]
      Furi.query_tokens(" =").should eq [[" ", ''], ]
      Furi.query_tokens("= ").should eq [["", ' '], ]
      Furi.query_tokens("a=1&b").should eq [['a', 1], ["b", nil]]
      Furi.query_tokens("a=&b").should eq [['a', ''], ['b', nil]]
      Furi.query_tokens("a=1&b=2").should eq [['a', 1], ['b', 2]]
    end
  end

  describe ".parse_query" do
    it "should work" do
    Furi.parse_query("foo").
      should eq "foo" => nil
    Furi.parse_query("foo=").
      should eq "foo" => ""
    Furi.parse_query("foo=bar").
      should eq "foo" => "bar"
    Furi.parse_query("foo=\"bar\"").
      should eq "foo" => "\"bar\""

    Furi.parse_query("foo=bar&foo=quux").
      should eq "foo" => "quux"
    Furi.parse_query("foo&foo=").
      should eq "foo" => ""
    Furi.parse_query("foo=1&bar=2").
      should eq "foo" => "1", "bar" => "2"
    Furi.parse_query("&foo=1&&bar=2").
      should eq "foo" => "1", "bar" => "2"
    Furi.parse_query("foo&bar=").
      should eq "foo" => nil, "bar" => ""
    Furi.parse_query("foo=bar&baz=").
      should eq "foo" => "bar", "baz" => ""
    Furi.parse_query("my+weird+field=q1%212%22%27w%245%267%2Fz8%29%3F").
      should eq "my weird field" => "q1!2\"'w$5&7/z8)?"

    Furi.parse_query("a=b&pid%3D1234=1023").
      should eq "pid=1234" => "1023", "a" => "b"

    Furi.parse_query("foo[]").
      should eq "foo" => [nil]
    Furi.parse_query("foo[]=").
      should eq "foo" => [""]
    Furi.parse_query("foo[]=bar").
      should eq "foo" => ["bar"]

    Furi.parse_query("foo[]=1&foo[]=2").
      should eq "foo" => ["1", "2"]
    Furi.parse_query("foo=bar&baz[]=1&baz[]=2&baz[]=3").
      should eq "foo" => "bar", "baz" => ["1", "2", "3"]
    Furi.parse_query("foo[]=bar&baz[]=1&baz[]=2&baz[]=3").
      should eq "foo" => ["bar"], "baz" => ["1", "2", "3"]

    Furi.parse_query("x[y][z]=1").
      should eq "x" => {"y" => {"z" => "1"}}
    Furi.parse_query("x[y][z][]=1").
      should eq "x" => {"y" => {"z" => ["1"]}}
    Furi.parse_query("x[y][z]=1&x[y][z]=2").
      should eq "x" => {"y" => {"z" => "2"}}
    Furi.parse_query("x[y][z][]=1&x[y][z][]=2").
      should eq "x" => {"y" => {"z" => ["1", "2"]}}

    Furi.parse_query("x[y][][z]=1").
      should eq "x" => {"y" => [{"z" => "1"}]}
    Furi.parse_query("x[y][][z][]=1").
      should eq "x" => {"y" => [{"z" => ["1"]}]}
    Furi.parse_query("x[y][][z]=1&x[y][][w]=2").
      should eq "x" => {"y" => [{"z" => "1", "w" => "2"}]}

    Furi.parse_query("x[y][][v][w]=1").
      should eq "x" => {"y" => [{"v" => {"w" => "1"}}]}
    Furi.parse_query("x[y][][z]=1&x[y][][v][w]=2").
      should eq "x" => {"y" => [{"z" => "1", "v" => {"w" => "2"}}]}

    Furi.parse_query("x[y][][z]=1&x[y][][z]=2").
      should eq "x" => {"y" => [{"z" => "1"}, {"z" => "2"}]}
    Furi.parse_query("x[y][][z]=1&x[y][][w]=a&x[y][][z]=2&x[y][][w]=3").
      should eq "x" => {"y" => [{"z" => "1", "w" => "a"}, {"z" => "2", "w" => "3"}]}

    lambda { Furi.parse_query("x[y]=1&x[y]z=2") }.
      should raise_error(Furi::QueryParseError,  "expected Hash (got String) for param `y'")

    lambda { Furi.parse_query("x[y]=1&x[]=1") }.
      should raise_error(Furi::QueryParseError, /expected Array \(got [^)]*\) for param `x'/)

    lambda { Furi.parse_query("x[y]=1&x[y][][w]=2") }.
      should raise_error(Furi::QueryParseError, "expected Array (got String) for param `y'")
    end

  end

  it "should support inspect" do
    expect(Furi.parse('http://google.com').inspect).to eq("#<Furi::Uri \"http://google.com\">")
  end


  describe ".join" do
    it "works" do
      expect(Furi.join("http://gusiev.com/slides", "../photos")).to eq("http://gusiev.com/photos")
    end
  end
end
