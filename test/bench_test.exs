defmodule Artem.BenchTest do
  use ExUnit.Case

  use Artem, schema: Artem.Fixtures.TestSchema
  @raw_query ~q|
    query {
      version
    }
  |r

  @prepared_query ~q|
    query {
      version
    }
  |

  @tag :benchmark
  test "benchmark" do
    Benchee.run(
      %{
        "prepare" => fn -> Artem.run(@prepared_query) end,
        "raw" => fn -> Artem.run(@raw_query) end
      },
      time: 10,
      formatters: [{Benchee.Formatters.Console, extended_statistics: true}]
    )
  end
end
