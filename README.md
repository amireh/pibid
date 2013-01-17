# Pibi

[![Build Status](https://travis-ci.org/amireh/pibi.png)](https://travis-ci.org/amireh/pibi)

A money management and tracking service. The app is written in Ruby, and uses the following primary dependencies:

* Sinatra
* DataMapper (against a MySQL back-end)
* Pony for sending emails
* Gravatarify for gravatar integration
* OmniAuth (FB, Twitter, and Github) for authentication

For unit testing, RSpec is used primary. Integration testing is done using Capybara and Capybara-webkit for headless browser testing.

The front-end uses valid HTML5 semantics, CSS3, and some JavaScript using jQuery. No CoffeeScript or SASS at the moment of writing.

## Installation

Get the required gems (using bundler), set up the database, and populate the currency table:

```bash
rake db:setup
rake pibi:currencies
```

Afterwards, you need to set up the `config/credentials.yml` file. See the credentials template file for its structure and what should be in it.

## Testing

Run `rspec` using bundler:

`bundler exec rspec spec/`

## Internal notes and monkey patches

Under sad, sad and extreme circumstances, I've had to do some rather shameful things to the honorable gems the app uses. Here's a breakdown:

**Sinatra::Contrib::ContentFor**

A `yield_with_default()` method was added to the module that allows one to provide some default content for a content block in case the current view didn't provide any. Quite useful to make sure the site has a default title when a view hasn't modified, or does it need to, the title.

**Sinatra::Templates**

The `erb` method was explicitly overridden to internally convert the view path argument to symbol, because if it accepted a string, it would simply render it instead of rendering the view pointed to by that string.

**Sinatra::Base**

`delete` and `put` route builders were overridden to implicitly build a `GET` and `POST` RESTful equivalent routes. I found myself duplicating each `put` and `delete` route because browsers simply don't support those operations without JS, which is not required for Pibi.

The **private** methods `invoke` and `dispatch!` were also replaced by versions that fixed an issue that was occuring in the app, which wasn't merged into Sinatra's current master yet. See [this issue](https://github.com/sinatra/sinatra/issues/600#issuecomment-11789680) for more info.


## License

```text
Copyright (c) 2012-2013 Algol Labs LLC.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```