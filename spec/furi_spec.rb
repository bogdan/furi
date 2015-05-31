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
    end

    def matches?(hash)
      @hash = hash
      Furi.serialize(hash) == @expectation
    end

    def failure_message
      "Expected #{@hash.inspect} to serialize as #{@expectation.inspect}, but was serialized as #{Furi.serialize(@hash)}"
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
 
      expect({:a => {:b => 'c'}, :q => [1,2]}).to serialize_as("a%5Bb%5D=c&q%5B%5D=1&q%5B%5D=2")
      expect({:hello => {world: nil}, a: {b: [{c: nil}]}}).to serialize_as("")
      expect(nil).to serialize_as("")
    end
  end

end
