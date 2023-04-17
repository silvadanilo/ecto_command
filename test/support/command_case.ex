defmodule EctoCommand.Test.CommandCase do
  defmacro __using__(_) do
    quote do
      import EctoCommand.Test.CommandCase
    end
  end

  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defmacro define_a_module_with_fields(module_name, do: block) do
    quote do
      defmodule unquote(module_name) do
        use EctoCommand.Command, resource_type: "Sample", resource_id: :id

        command do
          unquote(block)
        end
      end
    end
  end
end
