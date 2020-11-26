defmodule Artem.Document do
  @moduledoc false
  defstruct document: nil,
            remaining_pipeline_marker: nil,
            schema: nil,
            variables: %{},
            context: %{},
            name: nil
end
