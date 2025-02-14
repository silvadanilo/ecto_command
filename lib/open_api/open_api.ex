# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule EctoCommand.OpenApi do
  @moduledoc false

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
    |> Enum.reduce(%{type: parse_ecto_type(type)}, &schema_for(&1, &2, opts))
    |> add_example()
    |> then(&struct!(OpenApiSpex.Schema, &1))
  end

  defp schema_for(_opt, %{type: {:array, type}} = acc, opts) do
    acc
    |> Map.put(:type, :array)
    |> Map.put(:items, [
      opts
      |> Keyword.update(:doc, [], &Keyword.drop(&1, [:description, :example]))
      |> Enum.reduce(%{type: parse_ecto_type(type)}, &schema_for(&1, &2, opts))
      |> add_example()
      |> then(&struct!(OpenApiSpex.Schema, &1))
    ])
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

  defp parse_ecto_type(:binary_id), do: :string
  defp parse_ecto_type(:date), do: :string
  defp parse_ecto_type(:utc_datetime), do: :string
  defp parse_ecto_type(:naive_datetime), do: :string
  defp parse_ecto_type(:time), do: :string
  defp parse_ecto_type(:utc_datetime_usec), do: :string
  defp parse_ecto_type(:naive_datetime_usec), do: :string
  defp parse_ecto_type(Ecto.Enum), do: :string
  defp parse_ecto_type(:float), do: :number
  defp parse_ecto_type(:decimal), do: :number
  defp parse_ecto_type(value), do: value

  defp add_example(%{example: _} = schema), do: schema

  defp add_example(%{type: :array, items: [%{enum: values}]} = schema),
    do: Map.put(schema, :example, Enum.take(values, 2))

  defp add_example(%{enum: values} = schema),
    do: Map.put(schema, :example, List.first(values))

  defp add_example(%{type: :integer} = schema),
    do: Map.put(schema, :example, trunc(number_example(schema)))

  defp add_example(%{type: :number} = schema),
    do: Map.put(schema, :example, number_example(schema))

  defp add_example(schema), do: schema

  defp number_example(%{not: %{enum: [n]}}), do: (n + 1) / 1

  defp number_example(%{} = schema) do
    min = if schema[:minimum], do: schema[:minimum] + ((schema[:exclusiveMinimum] && 1) || 0)
    max = if schema[:maximum], do: schema[:maximum] - ((schema[:exclusiveMaximum] && 1) || 0)
    pick_number_example(min, max)
  end

  defp pick_number_example(nil, nil), do: 10.0
  defp pick_number_example(min, nil), do: min
  defp pick_number_example(nil, max), do: max
  defp pick_number_example(min, max), do: min + (max - min) / 2
end
