# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule EctoCommand.OpenApi do
  @moduledoc false

  alias EctoCommand.OpenApi.Type

  @doc false
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts, module: __MODULE__] do
      alias EctoCommand.OpenApi.Type

      @ecto_command_openapi_options opts
      @before_compile module
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote unquote: false do
      def schema do
        {properties, required} =
          Enum.reduce(@command_fields, {%{}, []}, fn field, {fields, required} ->
            {name, type, opts} = field

            if opts[:internal] != true do
              required = if Enum.member?([true, []], opts[:required]), do: [name | required], else: required
              fields = Map.put(fields, name, EctoCommand.OpenApi.schema_for(type, opts))
              {fields, required}
            else
              {fields, required}
            end
          end)

        %OpenApiSpex.Schema{
          title: @ecto_command_openapi_options[:title] || __MODULE__,
          type: @ecto_command_openapi_options[:type] || :object,
          properties: properties,
          required: required
        }
      end
    end
  end

  def schema_for(type, opts) do
    opts
    |> Enum.reduce(base_schema(type), &schema_for(&1, &2, opts))
    |> then(&struct!(OpenApiSpex.Schema, &1))
    |> add_example()
  end

  defp schema_for(_opt, %{type: {:array, type}} = acc, opts) do
    acc
    |> Map.put(:type, :array)
    |> Map.put(:items, [schema_for(type, Keyword.delete(opts, :doc))])
    |> Map.merge(Map.new(opts[:doc] || []))
  end

  defp schema_for({:change, _options}, acc, _opts), do: acc
  defp schema_for({:inclusion, values}, acc, _opts), do: Map.put(acc, :enum, values)
  defp schema_for({:subset, values}, acc, _opts), do: Map.put(acc, :enum, values)
  defp schema_for({:format, format}, acc, _opts), do: Map.put(acc, :pattern, format)

  defp schema_for({:length, options}, acc, _opts) do
    Enum.reduce(options, acc, fn
      {:min, min}, acc ->
        Map.put(acc, :minLength, min)

      {:max, max}, acc ->
        Map.put(acc, :maxLength, max)

      {:is, is}, acc ->
        Map.put(acc, :minLength, is)
        Map.put(acc, :maxLength, is)
    end)
  end

  defp schema_for({:number, options}, acc, _opts) do
    Enum.reduce(options, acc, fn
      {:less_than, value}, acc ->
        acc
        |> Map.put(:maximum, value)
        |> Map.put(:exclusiveMaximum, true)

      {:greater_than, value}, acc ->
        acc
        |> Map.put(:minimum, value)
        |> Map.put(:exclusiveMinimum, true)

      {:less_than_or_equal_to, value}, acc ->
        acc
        |> Map.put(:maximum, value)
        |> Map.put(:exclusiveMaximum, false)

      {:greater_than_or_equal_to, value}, acc ->
        acc
        |> Map.put(:minimum, value)
        |> Map.put(:exclusiveMinimum, false)

      {:equal_to, value}, acc ->
        acc
        |> Map.put(:minimum, value)
        |> Map.put(:maximum, value)
        |> Map.put(:exclusiveMinimum, false)
        |> Map.put(:exclusiveMaximum, false)

      {:not_equal_to, value}, acc ->
        Map.put(acc, :not, %{enum: [value]})
    end)
  end

  defp schema_for({:values, values}, acc, _opts) do
    parsed_values =
      Enum.map(values, fn
        value when is_atom(value) -> Atom.to_string(value)
        value -> value
      end)

    Map.put(acc, :enum, parsed_values)
  end

  defp schema_for({:default, value}, acc, _opts) do
    Map.put(acc, :default, value)
  end

  defp schema_for({:doc, options}, acc, _opts) do
    Map.merge(acc, Enum.into(options, %{}))
  end

  defp schema_for({:required, _}, acc, _opts), do: acc

  defp base_schema(:binary_id), do: %{type: :string}
  defp base_schema(:date), do: %{type: :string, format: :date}
  defp base_schema(:utc_datetime), do: %{type: :string, format: :"date-time"}
  defp base_schema(:utc_datetime_usec), do: %{type: :string, format: :"date-time"}
  defp base_schema(:naive_datetime), do: %{type: :string, format: :"date-time"}
  defp base_schema(:naive_datetime_usec), do: %{type: :string, format: :"date-time"}
  defp base_schema(:time), do: %{type: :string}
  defp base_schema(Ecto.Enum), do: %{type: :string}
  defp base_schema(:float), do: %{type: :number}
  defp base_schema(:decimal), do: %{type: :number}
  defp base_schema(value), do: %{type: value}

  defp add_example(%{example: example} = schema) when not is_nil(example), do: schema
  defp add_example(schema), do: Map.put(schema, :example, Type.example_for(schema))
end
