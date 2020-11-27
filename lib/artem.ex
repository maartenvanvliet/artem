defmodule Artem do
  @external_resource "./README.md"
  @moduledoc """
  #{File.read!(@external_resource) |> String.split("---", parts: 2) |> List.last()}
  """

  alias Absinthe.Phase
  alias Absinthe.Pipeline

  defmacro __using__(opts) do
    schema = Keyword.get(opts, :schema)
    pipeline = Keyword.get(opts, :pipeline, {__MODULE__, :default_pipeline})

    final_validation_phase =
      Keyword.get(opts, :final_validation_phase, Phase.Document.Validation.UniqueVariableNames)

    Module.put_attribute(__CALLER__.module, :schema, schema)
    Module.put_attribute(__CALLER__.module, :pipeline, pipeline)
    Module.put_attribute(__CALLER__.module, :final_validation_phase, final_validation_phase)

    quote do
      import unquote(__MODULE__), only: [sigil_q: 2, precompile: 2, precompile: 3]
    end
  end

  @doc """
  `precompile/2` works the same as the sigil syntax, only slightly more verbose.

   * Pass `precompile: false` to not precompile the query during compilation.
   * Pass `generate_function: false` to not create a function named after the operation name.

  ## Examples

      defmodule SomeTest do
        use Artem, schema: Your.Schema

        @query Artem.precompile("
          query {
            version
          }
        ")
      end

  """

  defmacro precompile(doc, options \\ []) do
    final_validation_phase = Module.get_attribute(__CALLER__.module, :final_validation_phase)

    options =
      Keyword.merge(
        [
          precompile: true,
          last_phase: final_validation_phase,
          pipeline: {__MODULE__, :default_pipeline},
          generate_function: true
        ],
        options
      )

    quote bind_quoted: [
            doc: doc,
            schema: Module.get_attribute(__CALLER__.module, :schema),
            options: options
          ] do
      document = precompile(doc, schema, options)

      if options[:generate_function] && document.name != nil do
        name = document.name |> Macro.underscore() |> String.to_atom()

        def unquote(Macro.escape(name))(opts) when is_list(opts) do
          Artem.run(
            unquote(Macro.escape(document)),
            Keyword.merge(opts, operation_name: unquote(Macro.escape(document)).name)
          )
        end

        def unquote(Macro.escape(name))(variables \\ %{}, context \\ %{}, opts \\ []) do
          unquote(Macro.escape(name))(
            Keyword.merge([variables: variables, context: context], opts)
          )
        end
      end

      document
    end
  end

  @doc """
  The `q` sigil can be used to precompile queries used in tests. It is a dynamic
  sigil in the sense that the resulting graphql query is run against the declared schema.

  Pass in the `r` modifier at the end of the sigil block to not precompile the query and use
  its 'raw' form. This will only parse the query when it is run in the tests.

  ## Examples
      defmodule SomeTest do
        use Artem, schema: Your.Schema

        @query ~q|
          query {
            version
          }
        |

        test "runs precompiled query" do
          Artem.run(@query)
        end

        @raw_query ~q|
          query {
            version
          }
        |r

        test "runs raw query" do
          Artem.run(@raw_query)
        end
      end

  """
  defmacro sigil_q(doc, []) do
    quote bind_quoted: [doc: doc] do
      precompile(doc, precompile: true)
    end
  end

  defmacro sigil_q(doc, [?r]) do
    quote bind_quoted: [doc: doc] do
      precompile(doc, precompile: false)
    end
  end

  @doc """
  Macroless version of precompile/2

  Pass in the schema as the second argument

  ## Examples

  ```elixir
      defmodule SomeTest do
        @query Artem.precompile("
          query {
            version
          }
        ", Your.Schema)
      end
  ```
  """
  @spec precompile(any, any, maybe_improper_list | %{precompile: boolean}) :: Artem.Document.t()
  def precompile(doc, schema, opts) when is_list(opts) do
    precompile(doc, schema, Map.new(opts))
  end

  def precompile(doc, schema, %{precompile: true} = opts) do
    {module, fun} = opts.pipeline
    pipeline = Kernel.apply(module, fun, [schema, []])

    pipeline =
      pipeline
      |> Pipeline.upto(opts.last_phase)
      |> Pipeline.insert_after(opts.last_phase, Phase.Document.Result)

    case Pipeline.run(doc, pipeline) do
      {:ok, result, _} -> check_result(result, schema, opts.last_phase)
    end
  end

  def precompile(doc, schema, %{precompile: false}) do
    %Artem.Document{
      schema: schema,
      document: doc,
      remaining_pipeline_marker: nil
    }
  end

  @doc """
  Assign a context to the current query, e.g. set a `current_user_id`

  ## Examples
      defmodule SomeTest do
        use Artem, schema: Your.Schema

        @query ~q|
          query {
            version
          }
        |

        test "runs precompiled query" do
          @query
          |> Artem.assign_context(%{current_user_id: 1})
          |> Artem.run()
        end
      end

  """
  @spec assign_context(Artem.Document.t(), map) :: Artem.Document.t()
  def assign_context(%Artem.Document{} = doc, context) do
    %{doc | context: context}
  end

  @doc """
  Assign variables to the current query, to pass them to the graphql query

  ## Examples
      defmodule SomeTest do
        use Artem, schema: Your.Schema

        @query ~q|
          query($format: String{
            datetime(format: $format)
          }
        |

        test "runs precompiled query" do
          @query
          |> Artem.assign_variables(%{format: "YYMMDD})
          |> Artem.run()
        end
      end

  """
  @spec assign_vars(Artem.Document.t(), map) :: Artem.Document.t()
  def assign_vars(%Artem.Document{} = doc, variables) do
    %{doc | variables: variables}
  end

  @doc """
  Run a document against the schema.

  The


  ## Examples
      defmodule SomeTest do
        use Artem, schema: Your.Schema

        @query ~q|
          query($format: String{
            datetime(format: $format)
          }
        |

        test "runs precompiled query" do
          @query
          |> Artem.assign_variables(%{format: "YYMMDD})
          |> Artem.run()
        end

        test "with " do
          Artem.run(@query, variables: %{format: "YYMMDD}, context: %{current_user_id: 1})
        end
      end

  """
  @spec run(Artem.Document.t(), keyword) :: {:error, binary} | {:ok, any}
  def run(%Artem.Document{} = doc, options \\ []) do
    options = build_opts(doc, options)

    remaining_pipeline = build_pipeline(doc, options)

    case Pipeline.run(doc.document, remaining_pipeline) do
      {:ok, %{result: result}, _phases} ->
        {:ok, result}

      {:error, msg, _phases} ->
        {:error, msg}
    end
  end

  @doc """
  Default pipeline called for the schema

  Can be overridden by supplying a `{module, function}` tuple

  ```
    ## Examples
      defmodule SomeTest do
        use Artem, schema: Your.Schema, pipeline: {Your.Schema, :your_pipeline}
  ```
  """
  @spec default_pipeline(Absinthe.Schema.t(), Keyword.t()) :: Absinthe.Pipeline.t()
  def default_pipeline(schema, pipeline_opts) do
    Pipeline.for_document(schema, pipeline_opts)
  end

  defp check_result(result, schema, phase) do
    case result.execution do
      %{validation_errors: [], result: _execution_result} ->
        %Artem.Document{
          schema: schema,
          document: result,
          remaining_pipeline_marker: phase,
          name: build_name(result)
        }

      %{validation_errors: [error | _]} ->
        raise Artem.Error, error.message
    end
  end

  defp build_name(%{input: %{definitions: [node]}}), do: node.name

  defp build_name(%{input: %{definitions: _nodes}}),
    do: raise(Artem.Error, "Multiple operations are not supported")

  # For raw string documents, entire pipeline needs to run
  defp build_pipeline(%Artem.Document{document: document} = doc, options)
       when is_binary(document) do
    Pipeline.for_document(doc.schema, options)
  end

  # For precompiled documents, only remainder of pipeline runs
  defp build_pipeline(%Artem.Document{document: %Absinthe.Blueprint{}} = doc, options) do
    Pipeline.for_document(doc.schema, options) |> Pipeline.from(doc.remaining_pipeline_marker)
  end

  defp build_opts(doc, options) do
    options
    |> Keyword.put(:variables, Map.merge(doc.variables, options[:variables] || %{}))
    |> Keyword.put(:context, Map.merge(doc.context, options[:context] || %{}))
    |> Keyword.put(:operation_name, options[:operation_name])
  end
end
