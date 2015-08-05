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

Here are basic 
``` ruby
Furi.host("http://gusiev.com") # => "gusiev.com"
Furi.port("http://gusiev.com") # => nil
Furi.port!("http://gusiev.com") # => 80
Furi.update("http://gusiev.com", protocol: '') # => "//gusiev.com"
Furi.update("http://gusiev.com?source=google", email: "a@b.com") 
    # => "http://gusiev.com?email=a@b.com"
Furi.merge("http://gusiev.com?source=google", email: "a@b.com") 
    # => "http://gusiev.com?source=google&email=a@b.com"

Furi.parse("gusiev.com/index.html?person[first_name]=Bogdan&person[last_name]=Gusiev") 
    # => #<Furi::Uri "http://gusiev.com/index.html?person[first_name]=Bogdan&person[last_name]=Gusiev"> 
```

## Reference


```
                         authority
                   __________|_________
                  /                    \
             userinfo                hostinfo                     resource
               __|___                ___|___                ___________|____________
              /      \              /       \              /                        \
         username  password       host      port         path              query  anchor
           __|___   __|__    ______|______   |  __________|_________     ____|____   |
          /      \ /     \  /             \ / \/                    \   /         \ / \
   http://username:password@www.example.com:80/hello/world/article.html?name=bogdan#info
    \_/                     \_/  \___/  \_/    \__________/ \      \__/
     |                       |     |     |           |       \       |
  protocol             subdomain   | domain_zone directory    \   suffix
                                   |     |                     \___/  
                            domain_name  /                       |     
                                    \___/                    filename 
                                      |                                 
                                    domain                   

```


Copied from [URI.js](http://medialize.github.io/URI.js/about-uris.html) parsing library 



## Contributing

Contribute in the way you want. Branch names and other bla-bla-bla doesn't matter.

