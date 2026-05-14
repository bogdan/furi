# frozen_string_literal: true

require "test_helper"
require "cgi/escape"

class FuriBaseTest < Minitest::Test
  def assert_parts(uri_string, expected_parts)
    uri = Furi.parse(uri_string)
    expected_parts.each do |part, value|
      actual = uri.send(part)
      assert actual == value,
        "Expected #{part.inspect} to equal #{value.inspect}, but it was #{actual.inspect}"
    end
  end

  def assert_serializes_as(hash, expectation)
    if expectation.is_a?(Array)
      expectation = expectation.map { |item|
        item.split("=").map { |z| CGI.escape(z.to_s) }.join("=")
      }.join("&")
    end
    assert_equal expectation, Furi.serialize(hash)
  end
end

class FuriTest < FuriBaseTest
  def test_inspect
    assert_equal "#<Furi::Uri \"http://google.com\">", Furi.parse('http://google.com').inspect
  end
end

class FuriParseTest < FuriBaseTest
  def test_raises_on_empty_string
    assert_raises(Furi::FormattingError) { Furi.parse("") }
  end

  def test_raises_parse_error_on_non_integer_port
    assert_raises(Furi::ParseError) { Furi.parse("x-test+scheme.complex:redirect") }
  end

  def test_priority_path_treats_string_before_slash_as_path
    uri = Furi.parse("gusiev.com/articles", priority: :path)
    assert_nil uri.host
    assert_equal "/gusiev.com/articles", uri.path
  end

  def test_priority_path_treats_bare_string_as_path
    uri = Furi.parse("gusiev.com", priority: :path)
    assert_nil uri.host
    assert_equal "/gusiev.com", uri.path
  end

  def test_priority_path_preserves_query_and_anchor
    uri = Furi.parse("gusiev.com/articles?a=1#top", priority: :path)
    assert_nil uri.host
    assert_equal "/gusiev.com/articles", uri.path
    assert_equal "a=1", uri.query_string
    assert_equal "top", uri.anchor
  end

  def test_priority_path_still_parses_host_with_protocol
    uri = Furi.parse("http://gusiev.com/articles", priority: :path)
    assert_equal "gusiev.com", uri.host
    assert_equal "/articles", uri.path
  end

  def test_priority_path_abstract_protocol_as_host
    uri = Furi.parse("//gusiev.com/articles", priority: :path)
    assert_equal "gusiev.com", uri.host
    assert_equal "/articles", uri.path
  end

  def test_priority_host_default
    uri = Furi.parse("gusiev.com/articles")
    assert_equal "gusiev.com", uri.host
    assert_equal "/articles", uri.path
  end

  def test_parses_url_with_everything
    assert_parts("http://user:pass@www.gusiev.com:8080/articles/index.html?a=1&b=2#header", {
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
      filename: 'index',
      extension: 'html',
      query_string: "a=1&b=2",
      query_tokens: [['a', '1'], ['b', '2']],
      query: {'a' => '1', 'b' => '2'},
      request: '/articles/index.html?a=1&b=2',
      endpoint: 'http://user:pass@www.gusiev.com:8080/articles/index.html',
      anchor: 'header',
      fragment: 'header',
      home_page?: false,
    })
  end

  def test_parses_url_without_path
    assert_parts("http://gusiev.com", {
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
      endpoint: 'http://gusiev.com',
      home_page?: true,
    })
  end

  def test_parses_url_with_root_path
    assert_parts("http://gusiev.com/?a=b", {
      hostname: 'gusiev.com',
      path: '/',
      path!: '/',
      request: '/?a=b',
      home_page?: true,
    })
  end

  def test_extracts_anchor
    assert_parts("http://gusiev.com/posts/index.html?a=b#zz", {
      anchor: 'zz',
      query_string: 'a=b',
      path: '/posts/index.html',
      port: nil,
      protocol: 'http',
      resource: '/posts/index.html?a=b#zz',
      request: '/posts/index.html?a=b',
      location: 'http://gusiev.com',
      file: 'index.html',
      filename: 'index',
      extension: 'html',
    })
  end

  def test_works_with_path_without_url
    assert_parts("/posts/index.html", {
      path: '/posts/index.html',
      hostname: nil,
      port: nil,
      protocol: nil,
      location: nil,
      extension: 'html',
      home_page?: false,
    })
  end

  def test_works_with_path_ending_at_slash
    assert_parts("/posts/", {
      path: '/posts/',
      directory: '/posts',
      file: nil,
      filename: nil,
      'file!' => '',
      extension: nil,
      home_page?: false,
    })
  end

  def test_parses_uri_with_user_and_password
    assert_parts("http://user:pass@gusiev.com", {
      username: 'user',
      password: 'pass',
      hostname: 'gusiev.com',
      query_string: nil,
      anchor: nil,
      location: 'http://user:pass@gusiev.com',
    })
  end

  def test_parses_uri_with_user_without_password
    assert_parts("http://user@gusiev.com", {
      username: 'user',
      password: nil,
      hostname: 'gusiev.com',
      query_string: nil,
      anchor: nil,
      location: 'http://user@gusiev.com',
    })
  end

  def test_supports_aliases
    assert_parts("http://gusiev.com#zz", {
      location: 'http://gusiev.com',
    })
  end

  def test_parses_uri_with_explicit_port_and_auth
    assert_parts("http://user:pass@gusiev.com:80", {
      username: 'user',
      password: 'pass',
      userinfo: 'user:pass',
      protocol: 'http',
      port: 80,
      query_string: nil,
    })
  end

  def test_parses_custom_port
    assert_parts("http://gusiev.com:8080", {
      hostname: 'gusiev.com',
      hostinfo: 'gusiev.com:8080',
      protocol: 'http',
      port: 8080,
    })
  end

  def test_parses_url_with_query
    assert_parts("/index.html?a=b&c=d", {
      host: nil,
      host!: '',
      query_string: 'a=b&c=d',
      query: {'a' => 'b', 'c' => 'd'},
      request: '/index.html?a=b&c=d',
      home_page?: true,
    })
  end

  def test_finds_out_port_if_not_explicitly_defined
    assert_parts("http://gusiev.com", {
      protocol: 'http',
      port: nil,
      'port!' => 80,
    })
  end

  def test_parses_nested_query
    assert_parts("gusiev.com?a[]=1&a[]=2&b[c]=1&b[d]=2", {
      host: 'gusiev.com',
      query: {"a" => ["1", "2"], "b" => {"c" => "1", "d" => "2"}},
    })
  end

  def test_finds_protocol_security
    assert_parts("gusiev.com:443", {
      host: 'gusiev.com',
      ssl: false,
    })
    assert_parts("https://gusiev.com:443", {
      host: 'gusiev.com',
      ssl: true,
    })
  end

  def test_parses_host_into_parts
    assert_parts("http://www.gusiev.com.ua", {
      domain: 'gusiev.com.ua',
      subdomain: 'www',
      domainname: 'gusiev',
      domainzone: 'com.ua',
    })
    assert_parts("http://www.com.ua", {
      domain: 'www.com.ua',
      subdomain: nil,
      domainname: 'www',
      domainzone: 'com.ua',
    })
    assert_parts("http://com.ua", {
      domain: 'com.ua',
      subdomain: nil,
      domainname: 'com',
      domainzone: 'ua',
    })
    assert_parts("http://www.blog.gusiev.com.ua", {
      domain: 'gusiev.com.ua',
      subdomain: 'www.blog',
      domainname: 'gusiev',
      domainzone: 'com.ua',
    })
  end

  def test_parses_double_hash_in_anchor
    assert_parts("/index?a=1#c#d", {
      anchor: 'c#d',
      query_string: "a=1",
      path: '/index',
    })
  end

  def test_parses_anchor_with_special_characters
    assert_parts("/index#c%20d", {
      anchor: 'c d',
      path: '/index',
    })
  end

  def test_parses_blank_port_with_protocol
    assert_parts("http://gusiev.com:/hello", {
      path: '/hello',
      port: nil,
      host: 'gusiev.com',
      protocol: 'http',
    })
  end

  def test_parses_blank_port_without_protocol
    assert_parts("gusiev.com:/hello", {
      path: '/hello',
      port: nil,
      host: 'gusiev.com',
      protocol: nil,
    })
  end

  def test_parses_0_port
    assert_parts("http://gusiev.com:0/hello", {
      path: '/hello',
      port: 0,
      host: 'gusiev.com',
      protocol: 'http',
    })
  end

  def test_downcases_only_protocol_and_host
    assert_parts("HTTP://GUSIEV.cOM/About", {
      protocol: 'http',
      host: 'gusiev.com',
      path: "/About",
    })
  end

  def test_ipv6_parses_host_and_port
    assert_parts("http://[2406:da00:ff00::6b14:8d43]:8080/", {
      path: '/',
      port: 8080,
      host: '[2406:da00:ff00::6b14:8d43]',
      protocol: 'http',
    })
  end

  def test_ipv6_parses_host_and_nil_port
    assert_parts("http://[2406:da00:ff00::6b14:8d43]:/hello", {
      path: '/hello',
      port: nil,
      host: '[2406:da00:ff00::6b14:8d43]',
      protocol: 'http',
    })
  end

  def test_ipv6_parses_host_without_protocol_and_port
    assert_parts("[2406:da00:ff00::6b14:8d43]/hello", {
      path: '/hello',
      port: nil,
      host: '[2406:da00:ff00::6b14:8d43]',
      protocol: nil,
    })
  end

  def test_mailto_without_email
    assert_parts("mailto:?subject=Talkable%20is%20Hiring&body=https%3A%2F%2Fwww.talkable.com%2Fjobs", {
      protocol: 'mailto',
      email: nil,
      query: {
        "subject" => "Talkable is Hiring",
        "body" => "https://www.talkable.com/jobs",
      },
    })
  end

  def test_parse_preserves_raw_query_string_on_emit
    # Characters valid in query values per RFC 3986 (like ?) must not be
    # re-encoded when a URL is parsed and re-emitted without modifying the query.
    uri = Furi.parse("/baz?id=1+1&foo=?&bar=1", priority: :path)
    assert_equal "/baz?id=1+1&foo=?&bar=1", uri.to_s
  end

  def test_parse_raw_query_cleared_when_query_is_updated
    uri = Furi.parse("/baz?foo=?", priority: :path)
    uri.query_tokens = {foo: "bar"}
    assert_equal "/baz?foo=bar", uri.to_s
  end
end

class FuriReplaceTest < FuriBaseTest
  def test_replace_query
    assert_equal '/index.html?c=d', Furi.replace("/index.html?a=b", query: {c: 'd'})
  end

  def test_replace_hostname
    assert_equal 'gusiev.com/index.html', Furi.replace("www.gusiev.com/index.html", hostname: 'gusiev.com')
    assert_equal 'gusiev.com/index.html', Furi.replace("/index.html", hostname: 'gusiev.com')
    assert_equal 'http://gusiev.com/index.html', Furi.replace("http://www.gusiev.com/index.html", hostname: 'gusiev.com')
    assert_equal 'gusiev.com/index.html', Furi.replace("/index.html", hostname: 'gusiev.com')
    assert_equal '/index.html?a=b', Furi.replace("gusiev.com/index.html?a=b", hostname: nil)
    assert_equal '/?a=b', Furi.replace("gusiev.com?a=b", hostname: nil)
  end

  def test_replace_port
    assert_equal 'gusiev.com:33', Furi.replace("gusiev.com", port: 33)
    assert_equal 'gusiev.com:33/index.html', Furi.replace("gusiev.com/index.html", port: 33)
    assert_equal 'gusiev.com:80/index.html', Furi.replace("gusiev.com:33/index.html", port: 80)
    assert_equal 'http://gusiev.com/index.html', Furi.replace("http://gusiev.com:33/index.html", port: 80)
    assert_equal 'http://gusiev.com/index.html', Furi.replace("http://gusiev.com:33/index.html", port: nil)
    assert_equal 'http://gusiev.com:0/index.html', Furi.replace("http://gusiev.com:33/index.html", port: 0)
    assert_equal 'http://gusiev.com/index.html', Furi.replace("http://gusiev.com:33/index.html", port: '')
  end

  def test_replace_directory
    assert_equal 'gusiev.com/articles', Furi.replace("gusiev.com", directory: 'articles')
    assert_equal 'gusiev.com/articles', Furi.replace("gusiev.com/", directory: 'articles')
    assert_equal 'gusiev.com/posts/index#header', Furi.replace("gusiev.com/index#header", directory: '/posts')
    assert_equal 'gusiev.com/#header', Furi.replace("gusiev.com/articles/#header", directory: nil)
    assert_equal 'gusiev.com/posts/index?a=b', Furi.replace("gusiev.com/articles/index?a=b", directory: 'posts')
    assert_equal '/posts/index?a=b', Furi.replace("/articles/index?a=b", directory: '/posts')
    assert_equal '/posts/index.html?a=b', Furi.replace("/articles/index.html?a=b", directory: '/posts/')
  end

  def test_replace_file
    assert_equal 'gusiev.com/article', Furi.replace("gusiev.com", file: 'article')
    assert_equal 'gusiev.com/article', Furi.replace("gusiev.com/", file: 'article')
    assert_equal 'gusiev.com/article2#header', Furi.replace("gusiev.com/article1#header", file: '/article2')
    assert_equal 'gusiev.com/#header', Furi.replace("gusiev.com/article#header", file: nil)
    assert_equal 'gusiev.com/articles/article2?a=b', Furi.replace("gusiev.com/articles/article1?a=b", file: 'article2')
    assert_equal '/articles/article2?a=b', Furi.replace("/articles/article1?a=b", file: '/article2')
    assert_equal '/articles/article2.html?a=b', Furi.replace("/articles/article1.xml?a=b", file: 'article2.html')
  end

  def test_replace_filename
    assert_equal 'gusiev.com/article', Furi.replace("gusiev.com", filename: 'article')
    assert_equal 'gusiev.com/article', Furi.replace("gusiev.com/", filename: 'article')
    assert_equal 'gusiev.com/article2#header', Furi.replace("gusiev.com/article1#header", filename: '/article2')
    assert_equal 'gusiev.com/#header', Furi.replace("gusiev.com/article#header", filename: nil)
    assert_equal 'gusiev.com/articles/article2?a=b', Furi.replace("gusiev.com/articles/article1?a=b", filename: 'article2')
    assert_equal '/articles/article2?a=b', Furi.replace("/articles/article1?a=b", filename: '/article2')
    assert_equal '/articles/article2.xml?a=b', Furi.replace("/articles/article1.xml?a=b", filename: 'article2')
  end

  def test_replace_extension
    assert_raises(Furi::FormattingError) { Furi.replace("gusiev.com/", extension: 'xml') }
    assert_equal 'gusiev.com/article.html#header', Furi.replace("gusiev.com/article#header", extension: 'html')
    assert_equal 'gusiev.com/article?header', Furi.replace("gusiev.com/article.html?header", extension: nil)
    assert_equal 'gusiev.com/article.html?a=b', Furi.replace("gusiev.com/article.xml?a=b", extension: 'html')
    assert_equal 'gusiev.com/article.html?a=b', Furi.replace("gusiev.com/article.html.erb?a=b", extension: 'html')
    assert_equal 'gusiev.com/article.html.erb?a=b', Furi.replace("gusiev.com/article.html?a=b", extension: 'html.erb')
  end

  def test_replace_resource
    assert_equal 'gusiev.com/article?a=1#hello', Furi.replace("gusiev.com", resource: '/article?a=1#hello')
    assert_equal 'gusiev.com/article2', Furi.replace("gusiev.com/article1#header", resource: '/article2')
    assert_equal 'gusiev.com', Furi.replace("gusiev.com/article#header", resource: nil)
    assert_equal 'gusiev.com/article2', Furi.replace("gusiev.com/article1?a=b", resource: 'article2')
  end

  def test_replace_path
    assert_equal 'gusiev.com/article', Furi.replace("gusiev.com", path: '/article')
    assert_equal 'gusiev.com/article2#header', Furi.replace("gusiev.com/article1#header", path: '/article2')
    assert_equal 'gusiev.com#header', Furi.replace("gusiev.com/article#header", path: nil)
    assert_equal 'gusiev.com/article2?a=b', Furi.replace("gusiev.com/article1?a=b", path: 'article2')
  end

  def test_replace_ssl
    assert_equal 'https://gusiev.com', Furi.replace("http://gusiev.com", ssl: true)
    assert_equal 'https://gusiev.com', Furi.replace("https://gusiev.com", ssl: true)
    assert_equal 'http://gusiev.com', Furi.replace("https://gusiev.com", ssl: false)
    assert_equal 'http://gusiev.com', Furi.replace("http://gusiev.com", ssl: false)
  end

  def test_replace_protocol
    assert_equal '//gusiev.com', Furi.replace("http://gusiev.com", protocol: '')
    assert_equal 'gusiev.com', Furi.replace("http://gusiev.com", protocol: nil)
    assert_equal 'https://gusiev.com', Furi.replace("http://gusiev.com", protocol: 'https')
    assert_equal 'http://gusiev.com', Furi.replace("gusiev.com", protocol: 'http')
    assert_equal 'http://gusiev.com', Furi.replace("gusiev.com", protocol: 'http:')
    assert_equal 'http://gusiev.com', Furi.replace("gusiev.com", protocol: 'http:/')
    assert_equal 'http://gusiev.com', Furi.replace("gusiev.com", protocol: 'http://')
  end

  def test_replace_userinfo
    assert_equal 'http://hello:world@gusiev.com', Furi.replace("http://gusiev.com", userinfo: 'hello:world')
    assert_equal 'http://hello:world@gusiev.com', Furi.replace("http://aa:bb@gusiev.com", userinfo: 'hello:world')
    assert_equal 'http://gusiev.com', Furi.replace("http://aa:bb@gusiev.com", userinfo: nil)
    assert_equal 'http://hello:world@gusiev.com', Furi.replace("http://aa@gusiev.com", userinfo: 'hello:world')
  end

  def test_replace_authority
    assert_equal 'http://gusiev.com/index.html', Furi.replace("http://user:pass@gusiev.com:8080/index.html", authority: 'gusiev.com')
  end

  def test_replace_request
    assert_equal 'http://gusiev.com:8080/blog.html?a=b', Furi.replace("http://gusiev.com:8080/index.html?c=d", request: '/blog.html?a=b')
  end

  def test_replace_domainzone
    assert_equal 'http://gusiev.com.ua:8080', Furi.replace("http://gusiev.com:8080", domainzone: 'com.ua')
    assert_equal 'http://gusiev.com:8080', Furi.replace("http://gusiev.com.ua:8080", domainzone: 'com')
    assert_equal 'http://gusiev:8080', Furi.replace("http://gusiev.com.ua:8080", domainzone: nil)
  end

  def test_replace_domainname
    assert_equal 'http://google.com', Furi.replace("http://gusiev.com", domainname: 'google')
    assert_equal 'http://com', Furi.replace("http://gusiev.com", domainname: nil)
  end

  def test_replace_subdomain
    assert_equal 'http://blog.gusiev.com', Furi.replace("http://gusiev.com", subdomain: 'blog')
    assert_equal 'http://gusiev.com', Furi.replace("http://blog.gusiev.com", subdomain: nil)
  end

  def test_replace_location
    assert_equal 'http://gusiev.com/index.html', Furi.replace("/index.html", location: 'http://gusiev.com')
    assert_equal 'http://gusiev.com/index.html', Furi.replace("/index.html", location: 'http://gusiev.com/')
    assert_equal 'gusiev.com:80/index.html', Furi.replace("gusiev.com:433/index.html", location: 'gusiev.com:80')
    assert_equal '/index.html', Furi.replace("gusiev.com:433/index.html", location: nil)
    assert_equal '/index.html', Furi.replace("http://gusiev.com:433/index.html", location: nil)
  end

  def test_replace_endpoint
    assert_equal 'http://gusiev.com/blog.html?a=1#top', Furi.replace("http://gusiev.com/index.html?a=1#top", endpoint: 'http://gusiev.com/blog.html')
  end

  def test_replace_query_hash
    assert_equal '/?a=1', Furi.replace("/", query: {a: 1})
    assert_equal '/?a%5B%5D=1&a%5B%5D=2', Furi.replace("/", query: {a: [1, 2]})
    assert_equal '/?a=1&b=2', Furi.replace("/", query: {a: 1, b: 2})
    assert_equal '/?a=2', Furi.replace("/?a=1", query: {a: 2})
    assert_equal '/?a=1', Furi.replace("/?a=1&a=1", query: true)
  end
end

class FuriBuildTest < FuriBaseTest
  def test_build
    assert_equal 'hello.com', Furi.build(hostname: 'hello.com')
    assert_equal 'hello.com:88', Furi.build(hostname: 'hello.com', port: 88)
    assert_equal 'https://hello.com:88', Furi.build(schema: 'https', hostname: 'hello.com', port: 88)
    assert_equal 'http://hello.com', Furi.build(schema: 'http', hostname: 'hello.com', port: 80)
    assert_equal '/index.html?a=1&b=2', Furi.build(path: '/index.html', query: {a: 1, b: 2})
    assert_equal 'gusiev.com/?a=1', Furi.build(path: '/', host: 'gusiev.com', query: {a: 1})
    assert_equal 'gusiev.com/articles/?a=1', Furi.build(path: '/articles/', host: 'gusiev.com', query: {a: 1})
    assert_equal 'user@hello.com', Furi.build(user: 'user', hostname: 'hello.com')
    assert_equal 'http://hello.com', Furi.build(protocol: 'http', host: 'hello.com', port: 80)
    assert_equal '/?a=b', Furi.build(query: 'a=b')
    assert_raises(Furi::FormattingError) { Furi.build(host: nil, port: 80) }
    assert_raises(Furi::FormattingError) { Furi.build(host: 'localhost', password: 'pass') }
  end

  def test_build_protocol
    assert_equal 'http://hello.com', Furi.build(protocol: 'http', host: 'hello.com', port: 80)
    assert_equal 'mailto:bogdan@gusiev.com', Furi.build(protocol: 'mailto', username: "bogdan", host: 'gusiev.com')
    assert_equal 'mailto:bogdan@gusiev.com', Furi.build(email: "bogdan@gusiev.com")
    assert_equal 'mailto:?subject=Hello&body=Welcome', Furi.build(protocol: 'mailto', query: {subject: 'Hello', body: "Welcome"})
  end

  def test_build_escapes_anchor_special_characters
    assert_equal '/index#a%20b', Furi.build(path: "/index", anchor: 'a b')
    assert_equal '/index#caf%C3%A9', Furi.build(path: "/index", anchor: 'café')
    assert_equal '/index#a%23b', Furi.build(path: "/index", anchor: 'a#b')
  end

  def test_build_escapes_square_brackets_in_anchor
    assert_equal '/index#a%5Bb%5D', Furi.build(path: "/index", anchor: 'a[b]')
    assert_equal '/index#section%5B1%5D', Furi.build(path: "/index", anchor: 'section[1]')
  end

  def test_build_does_not_escape_valid_fragment_characters
    assert_equal '/index#a?b', Furi.build(path: "/index", anchor: 'a?b')
    assert_equal '/index#a/b', Furi.build(path: "/index", anchor: 'a/b')
    assert_equal '/index#a@b', Furi.build(path: "/index", anchor: 'a@b')
    assert_equal '/index#a:b', Furi.build(path: "/index", anchor: 'a:b')
    assert_equal '/index#a!b', Furi.build(path: "/index", anchor: 'a!b')
  end

  def test_build_encodes_username_special_characters
    assert_equal 'http://openid.aol.com%2Fnextangler:one+two%3F@host.com/',
      Furi.build(protocol: 'http', username: 'openid.aol.com/nextangler', password: 'one two?', host: 'host.com', path: '/')
    assert_equal 'http://user%40name:p%40ss@host.com/',
      Furi.build(protocol: 'http', username: 'user@name', password: 'p@ss', host: 'host.com', path: '/')
  end

  def test_build_does_not_encode_plain_username_password
    assert_equal 'http://user:pass@host.com/', Furi.build(protocol: 'http', username: 'user', password: 'pass', host: 'host.com', path: '/')
  end

  def test_username_accessor_returns_raw_value
    uri = Furi::Uri.new({protocol: 'http', username: 'openid.aol.com/nextangler', password: 'one two?', host: 'host.com', path: '/'})
    assert_equal 'openid.aol.com/nextangler', uri.username
    assert_equal 'one two?', uri.password
  end
end

class FuriUpdateTest < FuriBaseTest
  def test_updates_query
    assert_equal '//gusiev.com?a=1', Furi.update("//gusiev.com", query: {a: 1})
    assert_equal '//gusiev.com?a=1&b=2', Furi.update("//gusiev.com?a=1", query: {b: 2})
    assert_equal '//gusiev.com?a=2', Furi.update("//gusiev.com?a=1", query: {a: 2})
    assert_equal '//gusiev.com?a=1&a=2&b=3', Furi.update("//gusiev.com?a=1", query: [['a', 2], ['b', 3]])
    assert_equal '//gusiev.com?a=1&b=2&a=3', Furi.update("//gusiev.com?a=1&b=2", query: '?a=3')
  end

  def test_updates_query_string
    assert_equal '//gusiev.com?a=1&b=2&a=3', Furi.update("//gusiev.com?a=1&b=2", query_string: '?a=3')
  end

  def test_updates_path
    assert_equal 'https://www.google.com/maps/place/1.23,3.28', Furi.update("https://www.google.com/maps", path: "place/1.23,3.28")
    assert_equal 'https://www.google.com/account', Furi.update("https://www.google.com/maps", path: "/account")
    assert_equal 'https://www.google.com/', Furi.update("https://www.google.com/maps", path: "..")
    assert_equal 'https://www.google.com', Furi.update("https://www.google.com/maps", path: nil)
    assert_equal 'https://www.google.com/maps', Furi.update("https://www.google.com", path: "/maps")
  end
end

class FuriDefaultsTest < FuriBaseTest
  def test_defaults_protocol
    assert_equal 'http://gusiev.com', Furi.defaults("gusiev.com", protocol: 'http')
    assert_equal '//gusiev.com', Furi.defaults("gusiev.com", protocol: '//')
    assert_equal '//gusiev.com', Furi.defaults("//gusiev.com", protocol: 'http')
    assert_equal 'https://gusiev.com', Furi.defaults("https://gusiev.com", protocol: 'http')
  end

  def test_defaults_host
    assert_equal 'https://www.gusiev.com', Furi.defaults("https://gusiev.com", subdomain: 'www')
    assert_equal 'https://blog.gusiev.com', Furi.defaults("https://blog.gusiev.com", subdomain: 'www')
    assert_equal 'http://gusiev.com/index.html', Furi.defaults("/index.html", host: 'gusiev.com', protocol: 'http')
  end

  def test_defaults_query
    assert_equal 'gusiev.com?a=1', Furi.defaults("gusiev.com?a=1", query: {a: 2})
    assert_equal 'gusiev.com?a=1&b=2', Furi.defaults("gusiev.com?a=1", query: {b: 2})
    assert_equal '//gusiev.com?a=1', Furi.defaults("//gusiev.com?a=1", query_string: 'b=2')
    assert_equal '//gusiev.com?b=2', Furi.defaults("//gusiev.com", query_string: 'b=2')
    assert_equal '//gusiev.com?a=1&b=2', Furi.defaults("//gusiev.com?a=1&b=2", query: '?a=3')
  end

  def test_defaults_file
    assert_equal 'gusiev.com/index.html?a=1', Furi.defaults("gusiev.com?a=1", file: 'index.html')
    assert_equal 'gusiev.com/posts?a=1', Furi.defaults("gusiev.com/posts?a=1", file: 'index.html')
    assert_equal 'gusiev.com/posts/index.html?a=1', Furi.defaults("gusiev.com/posts/?a=1", file: 'index.html')
    assert_equal 'gusiev.com/posts/index.html?a=1', Furi.defaults("gusiev.com/posts/?a=1", file: 'index.html')
  end

  def test_defaults_filename
    assert_equal 'gusiev.com/index?a=1', Furi.defaults("gusiev.com?a=1", filename: 'index')
    assert_equal 'gusiev.com/posts?a=1', Furi.defaults("gusiev.com/posts?a=1", filename: 'index')
    assert_equal 'gusiev.com/posts/index?a=1', Furi.defaults("gusiev.com/posts/?a=1", filename: 'index')
    assert_equal 'gusiev.com/posts/index?a=1', Furi.defaults("gusiev.com/posts/?a=1", filename: 'index')
  end

  def test_defaults_extension
    assert_raises(Furi::FormattingError) { Furi.defaults("gusiev.com?a=1", extension: 'html') }
    assert_equal 'gusiev.com/index.html?a=1', Furi.defaults("gusiev.com?a=1", filename: 'index', extension: 'html')
    assert_equal 'gusiev.com/posts.html?a=1', Furi.defaults("gusiev.com/posts?a=1", extension: 'html')
  end
end

class FuriEqualityTest < FuriBaseTest
  def test_equality
    assert Furi.parse('http://gusiev.com:80') == Furi.parse('http://gusiev.com')
    refute Furi.parse('http://gusiev.com') == Furi.parse('https://gusiev.com')
    assert Furi.parse('http://gusiev.com') == Furi.parse('http://gusiev.com')
    refute Furi.parse('http://gusiev.com.ua') == Furi.parse('http://gusiev.com')
    refute Furi.parse('http://gusiev.com?a=1&a=1') == Furi.parse('http://gusiev.com?a=1')
  end

  def test_equality_with_query_parameters
    assert Furi.parse('/?b=1&a=1') == Furi.parse('/?b=1&a=1')
    refute Furi.parse('/?a=1&a=1') == Furi.parse('/?a=1')
    refute Furi.parse('/') == Furi.parse('/?a=1')
    refute Furi.parse('/') == Furi.parse('http://gusiev.com?a=1')
  end

  def test_equality_ignores_case_only_on_protocol_and_host
    assert Furi.parse('hTTp://gUSiev.cOm') == Furi.parse('http://gusiev.com')
    refute Furi.parse('/hello') == Furi.parse('/Hello')
    refute Furi.parse('/hello?a=1') == Furi.parse('/hello?A=1')
    assert Furi.parse('hTTp://gusiev.cOm') == Furi.parse('http://gusiev.com')
    refute Furi.parse('/#h1') == Furi.parse('/#H1')
    refute Furi.parse('hello@gusiev.com') == Furi.parse('Hello@gusiev.com')
    refute Furi.parse('hello:psswd@gusiev.com') == Furi.parse('hello:Psswd@gusiev.com')
  end
end

class FuriAbstractProtocolTest < FuriBaseTest
  def test_abstract_protocol
    refute Furi.parse('http://gUSiev.cOm').abstract_protocol?
    assert Furi.parse('//gUSiev.cOm').abstract_protocol?
  end
end

class FuriHttpsTest < FuriBaseTest
  def test_https_predicate
    assert Furi.parse('https://example.com').https?
    refute Furi.parse('http://example.com').https?
    refute Furi.parse('ftp://example.com').https?
    refute Furi.parse('//example.com').https?
  end

  def test_https_via_module
    assert Furi.https?('https://example.com')
    refute Furi.https?('http://example.com')
  end
end

class FuriCloneTest < FuriBaseTest
  def test_clone
    uri = Furi.parse('http://gusiev.com')
    assert uri.clone == uri
    refute uri.clone.merge_query([[:a, 1]]) == uri
  end
end

class FuriMergeQueryTest < FuriBaseTest
  def test_merge_query
    uri = Furi.parse('http://gusiev.com')
    uri.merge_query({user: {first_name: 'Bogdan'}})
    assert_equal 'user%5Bfirst_name%5D=Bogdan', uri.query_string
    uri.merge_query({user: {last_name: 'Gusiev'}})
    assert_equal 'user%5Bfirst_name%5D=Bogdan&user%5Blast_name%5D=Gusiev', uri.query_string
  end
end

class FuriSerializeTest < FuriBaseTest
  def test_serialize
    assert_serializes_as({a: 'b'}, "a=b")
    assert_serializes_as({a: nil}, "a")
    assert_serializes_as(nil, "")
    assert_serializes_as({b: 2, a: 1}, "b=2&a=1")
    assert_serializes_as({a: {b: {c: []}}}, "")
    assert_serializes_as({a: {b: 'c'}}, "a%5Bb%5D=c")
    assert_serializes_as({q: [1, 2]}, "q%5B%5D=1&q%5B%5D=2")
    assert_serializes_as({a: {b: [1, 2]}}, "a%5Bb%5D%5B%5D=1&a%5Bb%5D%5B%5D=2")
    assert_serializes_as({q: "cowboy hat?"}, "q=cowboy+hat%3F")
    assert_serializes_as({a: true}, "a=true")
    assert_serializes_as({a: false}, "a=false")
    assert_serializes_as({a: [nil, 0]}, "a%5B%5D&a%5B%5D=0")
    assert_serializes_as({f: ["b", 42, "your base"]}, "f%5B%5D=b&f%5B%5D=42&f%5B%5D=your+base")
    assert_serializes_as({"a[]" => 1}, "a%5B%5D=1")
    assert_serializes_as({"a[b]" => [1]}, ["a[b][]=1"])
    assert_serializes_as({"a" => [1, 2], "b" => "blah"}, "a%5B%5D=1&a%5B%5D=2&b=blah")
    assert_serializes_as({a: [1, {c: 2, b: 3}, 4]}, ["a[]=1", "a[][c]=2", "a[][b]=3", "a[]=4"])
    assert_raises(Furi::FormattingError) { Furi.serialize([1, 2]) }
    assert_raises(Furi::FormattingError) { Furi.serialize({a: [1, [2]]}) }

    params = {b: {c: 3, d: [4, 5], e: {x: [6], y: 7, z: [8, 9]}}}
    assert_equal "b[c]=3&b[d][]=4&b[d][]=5&b[e][x][]=6&b[e][y]=7&b[e][z][]=8&b[e][z][]=9",
      URI.decode_www_form_component(Furi.serialize(params))
  end

  def test_serialize_sorted
    assert_equal "a=1&b=2&c=3", URI.decode_www_form_component(Furi.serialize({c: 3, a: 1, b: 2}, sorted: true))
    assert_equal "c=3&a=1&b=2", URI.decode_www_form_component(Furi.serialize({c: 3, a: 1, b: 2}, sorted: false))
    assert_equal "a=1&b=2&c=3", URI.decode_www_form_component(Furi.serialize({c: 3, a: 1, b: 2}, sorted: true))
  end

  def test_build_with_empty_nested_hash_omits_query_string
    assert_equal "/path", Furi.build(path: "/path", query: {a: {}})
    assert_equal "/path", Furi.build(path: "/path", query: {a: [], b: {}})
    assert_equal "/path?a=1", Furi.build(path: "/path", query: {a: 1, b: {}})
  end

  def test_serialize_calls_to_param_on_keys_and_values
    to_param_obj = Class.new(String) { def to_param = "#{self}-1" }
    key1, val1 = to_param_obj.new("custom"),  to_param_obj.new("param")
    key2, val2 = to_param_obj.new("custom2"), to_param_obj.new("param2")
    result = URI.decode_www_form_component(Furi.serialize({ key1 => val1, key2 => val2 }))
    assert_equal "custom-1=param-1&custom2-1=param2-1", result
  end

  def test_serialize_sorted_preserves_array_element_order
    # sorted: true sorts hash keys but must not reorder keys across array element boundaries,
    # otherwise round-tripping through a query parser loses data
    input = {foo: {contents: [{name: "gorby", id: "123"}, {name: "puff", d: "true"}]}}
    result = URI.decode_www_form_component(Furi.serialize(input, sorted: true))
    assert_equal "foo[contents][][name]=gorby&foo[contents][][id]=123&foo[contents][][name]=puff&foo[contents][][d]=true", result
  end

  def test_serialize_as_hash_converts_non_hash_objects
    hash_like = Struct.new(:to_unsafe_h).new({name: "Bogdan", role: "admin"})
    as_hash = ->(v) { v.respond_to?(:to_unsafe_h) ? v.to_unsafe_h : nil }
    result = URI.decode_www_form_component(Furi.serialize({user: hash_like}, as_hash: as_hash))
    assert_equal "user[name]=Bogdan&user[role]=admin", result
  end
end

class FuriQueryTokensTest < FuriBaseTest
  def test_query_tokens
    assert_equal [['a', '1']], Furi.query_tokens("a=1").map(&:to_a)
    assert_equal [['a', '=']], Furi.query_tokens("a==").map(&:to_a)
    assert_equal [['a', '=1']], Furi.query_tokens("a==1").map(&:to_a)
    assert_equal [['a', '1'], ["", nil]], Furi.query_tokens("a=1&").map(&:to_a)
    assert_equal [["", nil], ['a', '1']], Furi.query_tokens("&a=1").map(&:to_a)
    assert_equal [["", ""]], Furi.query_tokens("=").map(&:to_a)
    assert_equal [[" ", nil]], Furi.query_tokens(" ").map(&:to_a)
    assert_equal [[" ", '']], Furi.query_tokens(" =").map(&:to_a)
    assert_equal [["", ' ']], Furi.query_tokens("= ").map(&:to_a)
    assert_equal [['a', '1'], ["b", nil]], Furi.query_tokens("a=1&b").map(&:to_a)
    assert_equal [['a', ''], ['b', nil]], Furi.query_tokens("a=&b").map(&:to_a)
    assert_equal [['a', '1'], ['b', '2']], Furi.query_tokens("a=1&b=2").map(&:to_a)
  end
end

class FuriParseQueryTest < FuriBaseTest
  def test_parse_query
    assert_equal({"foo" => nil}, Furi.parse_query("foo"))
    assert_equal({"foo" => ""}, Furi.parse_query("foo="))
    assert_equal({"foo" => "bar"}, Furi.parse_query("foo=bar"))
    assert_equal({"foo" => "\"bar\""}, Furi.parse_query("foo=\"bar\""))
    assert_equal({"foo" => "quux"}, Furi.parse_query("foo=bar&foo=quux"))
    assert_equal({"foo" => ""}, Furi.parse_query("foo&foo="))
    assert_equal({"foo" => "1", "bar" => "2"}, Furi.parse_query("foo=1&bar=2"))
    assert_equal({"foo" => "1", "bar" => "2"}, Furi.parse_query("&foo=1&&bar=2"))
    assert_equal({"foo" => nil, "bar" => ""}, Furi.parse_query("foo&bar="))
    assert_equal({"foo" => "bar", "baz" => ""}, Furi.parse_query("foo=bar&baz="))
    assert_equal({"my weird field" => "q1!2\"'w$5&7/z8)?"}, Furi.parse_query("my+weird+field=q1%212%22%27w%245%267%2Fz8%29%3F"))
    assert_equal({"pid=1234" => "1023", "a" => "b"}, Furi.parse_query("a=b&pid%3D1234=1023"))
    assert_equal({"foo" => [nil]}, Furi.parse_query("foo[]"))
    assert_equal({"foo" => [""]}, Furi.parse_query("foo[]="))
    assert_equal({"foo" => ["bar"]}, Furi.parse_query("foo[]=bar"))
    assert_equal({"foo" => ["1", "2"]}, Furi.parse_query("foo[]=1&foo[]=2"))
    assert_equal({"foo" => "bar", "baz" => ["1", "2", "3"]}, Furi.parse_query("foo=bar&baz[]=1&baz[]=2&baz[]=3"))
    assert_equal({"foo" => ["bar"], "baz" => ["1", "2", "3"]}, Furi.parse_query("foo[]=bar&baz[]=1&baz[]=2&baz[]=3"))
    assert_equal({"x" => {"y" => {"z" => "1"}}}, Furi.parse_query("x[y][z]=1"))
    assert_equal({"x" => {"y" => {"z" => ["1"]}}}, Furi.parse_query("x[y][z][]=1"))
    assert_equal({"x" => {"y" => {"z" => "2"}}}, Furi.parse_query("x[y][z]=1&x[y][z]=2"))
    assert_equal({"x" => {"y" => {"z" => ["1", "2"]}}}, Furi.parse_query("x[y][z][]=1&x[y][z][]=2"))
    assert_equal({"x" => {"y" => [{"z" => "1"}]}}, Furi.parse_query("x[y][][z]=1"))
    assert_equal({"x" => {"y" => [{"z" => ["1"]}]}}, Furi.parse_query("x[y][][z][]=1"))
    assert_equal({"x" => {"y" => [{"z" => "1", "w" => "2"}]}}, Furi.parse_query("x[y][][z]=1&x[y][][w]=2"))
    assert_equal({"x" => {"y" => [{"v" => {"w" => "1"}}]}}, Furi.parse_query("x[y][][v][w]=1"))
    assert_equal({"x" => {"y" => [{"z" => "1", "v" => {"w" => "2"}}]}}, Furi.parse_query("x[y][][z]=1&x[y][][v][w]=2"))
    assert_equal({"x" => {"y" => [{"z" => "1"}, {"z" => "2"}]}}, Furi.parse_query("x[y][][z]=1&x[y][][z]=2"))
    assert_equal({"x" => {"y" => [{"z" => "1", "w" => "a"}, {"z" => "2", "w" => "3"}]}}, Furi.parse_query("x[y][][z]=1&x[y][][w]=a&x[y][][z]=2&x[y][][w]=3"))

    ex = assert_raises(Furi::ParameterTypeError) { Furi.parse_query("x[y]=1&x[y]z=2") }
    assert_equal "expected Hash (got String) for param `y'", ex.message

    ex = assert_raises(Furi::ParameterTypeError) { Furi.parse_query("x[y]=1&x[]=1") }
    assert_match(/expected Array \(got [^)]*\) for param `x'/, ex.message)

    ex = assert_raises(Furi::ParameterTypeError) { Furi.parse_query("x[y]=1&x[y][][w]=2") }
    assert_equal "expected Array (got String) for param `y'", ex.message
  end
end

class FuriJoinTest < FuriBaseTest
  def test_join
    assert_equal "http://gusiev.com/photos", Furi.join("http://gusiev.com/slides", "../photos").to_s
  end
end

class FuriEscapeQueryParamTest < FuriBaseTest
  def test_escape_query_param_custom_serialization
    uri = Furi.parse("http://example.com?a=1&b=2")
    result = uri.to_s(escape_query_param: ->(name, value) { "#{name}:#{value}" })
    assert_equal "http://example.com?a:1&b:2", result
  end

  def test_escape_query_param_falls_back_to_default_when_nil_returned
    uri = Furi.parse("http://example.com?a=hello world&b=2")
    result = uri.to_s(escape_query_param: ->(name, value) {
      name == "b" ? nil : "#{name}=#{value}"
    })
    assert_equal "http://example.com?a=hello world&b=2", result
  end

  def test_escape_query_param_with_hash_query
    uri = Furi.parse("http://example.com")
    uri.query = {a: "1", b: "2"}
    result = uri.to_s(escape_query_param: ->(name, value) { "#{name}:#{value}" })
    assert_equal "http://example.com?a:1&b:2", result
  end

  def test_escape_query_param_without_option_uses_default
    uri = Furi.parse("http://example.com?a=1&b=2")
    assert_equal "http://example.com?a=1&b=2", uri.to_s
  end

  def test_escape_query_param_parameter_filter_pattern
    # Simulates Rails-style parameter filtering: replace sensitive values with
    # "[FILTERED]", leave others unchanged (same object identity → nil → default).
    filtered_keys = ["password"]
    filter = ->(name, value) {
      if filtered_keys.include?(name)
        filtered = "[FILTERED]"
      else
        filtered = value
      end
      "#{CGI.escape(name)}=#{filtered}" unless filtered.equal?(value)
    }

    uri = Furi.parse("http://example.com?name=John&password=secret&token")
    result = uri.to_s(escape_query_param: filter)
    assert_equal "http://example.com?name=John&password=[FILTERED]&token", result
  end
end
