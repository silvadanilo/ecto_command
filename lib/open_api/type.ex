defmodule EctoCommand.OpenApi.Type do
  @moduledoc false

  alias OpenApiSpex.Schema

  def uuid(options \\ []) do
    [format: :uuid, description: "UUID", example: "defa2814-3686-4a73-9f64-a17cdfd7f1a1"] ++ options
  end

  def enum(values, options \\ []) do
    [example: List.first(values)] ++ options
  end

  def datetime(options \\ []) do
    [format: :"date-time", example: "2023-04-03T10:21:00Z"] ++ options
  end

  def date(options \\ []) do
    [format: :date, example: "2023-04-03"] ++ options
  end

  def boolean(options \\ []) do
    [example: true] ++ options
  end

  def email(options \\ []) do
    [format: :email, description: "Email", example: "user@domain.com"] ++ options
  end

  def phone(options \\ []) do
    [format: :telephone, description: "Telephone", example: "(425) 123-4567"] ++ options
  end

  def example_for(%Schema{type: :array, items: [%{enum: values}]} = _schema) when is_list(values),
    do: Enum.take(values, 2)

  def example_for(%Schema{default: default}) when not is_nil(default), do: default
  def example_for(%Schema{enum: values}) when is_list(values), do: List.first(values)
  def example_for(%Schema{type: :string, format: :date}), do: "2023-04-03"
  def example_for(%Schema{type: :string, format: :"date-time"}), do: "2023-04-03T10:21:00Z"
  def example_for(%Schema{type: :string}), do: "string"
  def example_for(%Schema{type: :boolean}), do: true
  def example_for(%Schema{type: :integer} = schema), do: trunc(number_example(schema))
  def example_for(%Schema{type: :number} = schema), do: number_example(schema)
  def example_for(%Schema{type: :array, items: [%{example: nil}]}), do: []
  def example_for(%Schema{type: :array, items: [%{example: example}]}), do: [example]

  def example_for(%Schema{type: :object, properties: properties}) do
    Map.new(properties, fn {name, %Schema{example: example} = schema} ->
      {name, example || example_for(schema)}
    end)
  end

  def example_for(_schema), do: nil

  defp number_example(%Schema{not: %{enum: [n]}}), do: (n + 1) / 1

  defp number_example(%Schema{} = schema) do
    min = if schema.minimum, do: schema.minimum + ((schema.exclusiveMinimum && 1) || 0)
    max = if schema.maximum, do: schema.maximum - ((schema.exclusiveMaximum && 1) || 0)
    number_between(min, max)
  end

  defp number_between(nil, nil), do: 10.0
  defp number_between(min, nil), do: min
  defp number_between(nil, max), do: max
  defp number_between(min, max), do: min + (max - min) / 2
end
