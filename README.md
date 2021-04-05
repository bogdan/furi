# Furi

[![Gem Version](https://badge.fury.io/rb/furi.svg)](https://badge.fury.io/rb/furi)
[![Build Status](https://github.com/bogdan/furi/workflows/CI/badge.svg?branch=master)](https://github.com/bogdan/furi/actions)
[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fbogdan%2Ffuri.svg?type=shield)](https://app.fossa.io/projects/git%2Bgithub.com%2Fbogdan%2Ffuri?ref=badge_shield)

Furi is a Friendly URI parsing library.
Furi's philosophy is to make any operation possible in ONE LINE OF CODE.

If there is an operation that takes more than one line of code to do with Furi, this is considered a terrible bug and you should create an issue.

## Installation

Add this line to your application's Gemfile:

``` ruby
gem 'furi'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install furi

## Usage

I'll say it again: any operation should take exacly one line of code!
Here are basic:

### Utility Methods

Parsing the URI fragments:

``` ruby
Furi.host("http://gusiev.com") # => "gusiev.com"
Furi.port("http://gusiev.com") # => nil
Furi.port!("http://gusiev.com") # => 80
```

Updating the URI parts:

``` ruby
Furi.update("http://gusiev.com", protocol: '') # => "//gusiev.com"
Furi.update("http://gusiev.com?source=google", query: {email: "a@b.com"})
    # => "http://gusiev.com?source=google&email=a@b.com"
Furi.replace("http://gusiev.com?source=google", query: {email: "a@b.com"})
    # => "http://gusiev.com?email=a@b.com"

Furi.defaults("http://gusiev.com", subdomain: 'www') # => "http://www.gusiev.com"
Furi.defaults("http://blog.gusiev.com", subdomain: 'www') # => "http://blog.gusiev.com"
```

Building an URI from initial parts:

``` ruby
Furi.build(protocol: '//', host: 'gusiev.com', path: '/assets/application.js')
    # => "//gusiev.com/assets/application.js"
```

### Working with Object

``` ruby
uri = Furi.parse("gusiev.com")
    # => #<Furi::Uri "gusiev.com">

uri.port     # => nil
uri.port!    # => 80
uri.path     # => nil
uri.path!    # => '/'
uri.subdomain ||= 'www'
uri.protocol = "//" # protocol abstract URL
```

### Processing Query String

``` ruby
uri = Furi.parse("/?person[first_name]=Bogdan&person[last_name]=Gusiev")

uri.query_string # => "person[first_name]=Bogdan&person[last_name]=Gusiev"
uri.query_tokens # => [person[first_name]=Bogdan, person[last_name]=Gusiev]
uri.query # => {person: {first_name: Bogdan, last_name: 'Gusiev'}}

uri.merge_query(person: {email: 'a@b.com'})
    # => {person: {email: 'a@b.com', first_name: Bogdan, last_name: 'Gusiev'}}

uri.merge_query(person: {email: 'a@b.com'})
    # => {person: {email: 'a@b.com', first_name: Bogdan, last_name: 'Gusiev'}}
```

## Reference

```
                location                                            resource
                    |                                                ___|___
             _______|_______                                        /       \
            /               \                                      /         \
           /             authority                             request        \
          /        __________|_________                           |            \
         /        /                    \                    ______|______       \
        /    userinfo                hostinfo              /             \       \
       /       __|___                ___|___              /               \       \
      /       /      \              /       \            /                 \       \
     /   username  password       host      port       path               query   anchor
    /      __|___   __|__    ______|______   |  _________|__________     ____|____   |
   /      /      \ /     \  /             \ / \/                    \   /         \ / \
   http://username:zhongguo@www.example.com:80/hello/world/article.html?name=bogdan#info
    \_/                     \_/  \___/  \_/    \__________/\     /  \_/
     |                       |     |     |           |      \___/    |
  protocol             subdomain   | domainzone  directory    |   extension
                                   |     |                 filename  |
                             domainname  /                     \_____/
                                    \___/                         |
                                      |                          file
                                    domain
```

Originated from [URI.js](http://medialize.github.io/URI.js/about-uris.html) parsing library.
Giving credit...

## TODO

* Improve URI.join algorithm to match the one used in Addressable library
* Implement filename
* Encoding/Decoding special characters:
  * path
  * query
  * fragment

## Contributing

Contribute in the way you want. Branch names and other bla-bla-bla do not matter.

## License

[![FOSSA Status](https://app.fossa.io/api/projects/git%2Bgithub.com%2Fbogdan%2Ffuri.svg?type=large)](https://app.fossa.io/projects/git%2Bgithub.com%2Fbogdan%2Ffuri?ref=badge_large)
