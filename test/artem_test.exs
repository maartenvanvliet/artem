defmodule ArtemTest do
  use ExUnit.Case

  use Artem, schema: Artem.Fixtures.TestSchema

  @query ~q"
    query {
      version
    }
  "

  test "executes a document" do
    assert Artem.run(@query) == {:ok, %{data: %{"version" => nil}}}
  end

  @context_query Artem.precompile("
    query {
      name_from_context
    }
  ")

  test "name from context" do
    {:ok, result} =
      @context_query
      |> Artem.assign_context(%{name: "some name"})
      |> Artem.run()

    assert result == %{data: %{"name_from_context" => "some name"}}
  end

  ~q|
    query TestA{
      name_from_context
    }
  |

  test "generated function works with context" do
    assert test_a(context: %{name: "some name"}) ==
             {:ok, %{data: %{"name_from_context" => "some name"}}}
  end

  ~q|
    query TestB($name: String!){
      nameFromVar(name: $name)
    }
  |

  test "generated function works with variables" do
    assert function_exported?(__MODULE__, :test_b, 1)

    assert test_b(variables: %{"name" => "some name"}) ==
             {:ok, %{data: %{"nameFromVar" => "some name"}}}
  end

  Artem.precompile(
    """
      query TestC($name: String!){
        nameFromVar(name: $name)
      }
    """,
    generate_function: false
  )

  test "disable function generation" do
    refute function_exported?(__MODULE__, :test_c, 1)
  end

  test "invalid doc" do
    document = """
    defmodule Test do
      use Artem, schema: Artem.Fixtures.TestSchema

      @invalid_doc ~q|
        query
          version

      |
    end
    """

    assert_raise(Artem.Error, fn ->
      Code.eval_string(document)
    end)
  end
end
