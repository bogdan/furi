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
Furi.port("http://gusiev.com") # => nil
Furi.port!("http://gusiev.com") # => 80
Furi.update("http://gusiev.com", protocol: 'https') # => "https://gusiev.com"
Furi.update("http://gusie.com/index.html?source=google", email: "a@b.com")

```

## Contributing

Contribute in the way you want. Branch names and other bla-bla-bla doesn't matter.

