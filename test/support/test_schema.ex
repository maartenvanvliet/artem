defmodule Artem.Fixtures.TestSchema do
  @moduledoc false
  use Absinthe.Schema

  query do
    field(:version, :string)
    field(:name_from_context,
      type: :string,
      resolve: fn _, _, res ->
        {:ok, res.context.name}
      end
    )

    field :name_from_var, :string do
      arg(:name, :string)
      arg(:num2, :string)

      resolve(fn
        _, args, _ ->
          {:ok, Map.get(args, :name)}
      end)
    end
  end
end
