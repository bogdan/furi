# Furi

Furi is a Friendly URI parsing library.
Furi's philosophy is to make any operation possible in ONE LINE OF CODE.

If there is an operation that takes more than one line of code to do with Furi, this is considered a terrible bug and you should create an issue.

## Installation

Add this line to your application's Gemfile:

```ruby
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


``` ruby
Furi.host("http://gusiev.com") # => "gusiev.com"
Furi.port("http://gusiev.com") # => nil
Furi.port!("http://gusiev.com") # => 80

Furi.update("http://gusiev.com", protocol: '') # => "//gusiev.com"
Furi.update("http://gusiev.com?source=google", query: {email: "a@b.com"}) 
    # => "http://gusiev.com?email=a@b.com"
Furi.merge("http://gusiev.com?source=google", query: {email: "a@b.com"}) 
    # => "http://gusiev.com?source=google&email=a@b.com"

Furi.build(protocol: '//', host: 'gusiev.com', path: '/assets/application.js') 
    # => "//gusiev.com/assets/application.js"

Furi.default("http://gusiev.com", subdomain: 'www') # => "http://www.gusiev.com"
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
    \_/                     \_/  \___/  \_/    \__________/ \       \_/
     |                       |     |     |           |       \       |
  protocol             subdomain   | domainzone  directory    \  extension
                                   |     |                     \_____/  
                             domainname  /                        |     
                                    \___/                     filename 
                                      |                                 
                                    domain                   
```


Copied from [URI.js](http://medialize.github.io/URI.js/about-uris.html) parsing library 


## TODO

* rfc3986

## Contributing

Contribute in the way you want. Branch names and other bla-bla-bla doesn't matter.

