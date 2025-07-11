# v0.2.4

* Improved `Furi.update` behavior for `path:` overrides:

  * Supports **relative path resolution** (`..` and subpaths)
  * Leading slashes in `path` now **replace** the original path
  * `nil` path removes the path portion entirely, leaving only the host

  **Examples:**

  ```ruby
  Furi.update("https://www.google.com/maps", path: "place/1.23,3.28")
  # => "https://www.google.com/maps/place/1.23,3.28"

  Furi.update("https://www.google.com/maps", path: "/account")
  # => "https://www.google.com/account"

  Furi.update("https://www.google.com/maps", path: "..")
  # => "https://www.google.com/"

  Furi.update("https://www.google.com/maps", path: nil)
  # => "https://www.google.com"
  ```

# v0.2.3

* Ruby 3.0 support #2
* Escaping special characters in anchor

