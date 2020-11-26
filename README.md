# Artem

## [![Hex pm](http://img.shields.io/hexpm/v/artem.svg?style=flat)](https://hex.pm/packages/artem) [![Hex Docs](https://img.shields.io/badge/hex-docs-9768d1.svg)](https://hexdocs.pm/artem) [![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)![.github/workflows/elixir.yml](https://github.com/maartenvanvliet/artem/workflows/.github/workflows/elixir.yml/badge.svg)

---

Library to help testing Absinthe graphql queries.

It has several features to aid in testing:

- precompile queries during compile time
- use sigils for less verbose syntax
- generates functions for named graphql operations

## Installation

The package can be installed
by adding `artem` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:artem, "~> 1.0.0"}
  ]
end
```

## Usage

Add the `Artem` module with the `use` clause. You'll need to
supply the `schema:` option with the Absinthe schema under test.

```elixir
defmodule ArtemTest do
  use ExUnit.Case

  use Artem, schema: Your.Absinthe.Schema
end
```

Now you get access to the macros supplied by Artem. There are a couple of ways
to use them

### Sigils

The first approach is using sigils

```elixir
defmodule ArtemTest do
  #...
  @version_query ~q"
    query {
      version
    }
  "
  test "run query" do
    assert {:ok, %{data: %{"version" => "201008"}}} == Artem.run(@version_query)
  end

```

This precompiles the document into the `@version_query` module attribute. If you run
this document multiple times in your tests you'll only have to run the static parts
(parsing/some validation) of the document once. This can also be used outside of testing,
if your app relies on internal graphql queries for example.

### Generated functions

The second approach builds on this but when your graphql operations are named
they are compiled into functions you can call.

```elixir
defmodule ArtemTest do
  #...
  ~q"
    query MyTest($format: String{
      datetime(format: $format)
    }
  "

  test "run query" do
    assert {:ok, %{data: %{"datetime" => "201008"}}} ==
            my_test(variables: %{format: "YYMMDD"}, context: %{current_user_id: 1})
  end

```

You can pass in the variables/context into the function.

Note that the name of the function is snake_cased from the camelized name of
the operation.

### precompile/2

The third way is using the precompile/2 macro

```elixir
defmodule ArtemTest do
  #...
  @query precompile("
    query {
      version
    }
  ")

  test "run query" do
    assert {:ok, %{data: %{"version" => "201008"}}} == Artem.run(@query)
  end

```

The sigil is syntactic sugar for calling the precompile macro. You can
use this for more direct control over this process, allowing easier
composability.

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/artem](https://hexdocs.pm/artem).
