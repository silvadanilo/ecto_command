defmodule CommandEx.OpenApi do
  @moduledoc false

  @doc false
  defmacro __using__(_) do
    quote do
      @before_compile unquote(__MODULE__)
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote unquote: false do
      def schema() do
        {properties, required} =
          Enum.reduce(@command_fields, {%{}, []}, fn field, {fields, required} ->
            {name, type, opts} = field

            if opts[:internal] != true do
              required = if Enum.member?([true, []], opts[:required]), do: [name | required], else: required
              options = Enum.reduce(opts, %{type: type}, &CommandEx.OpenApi.schema_for/2)
              fields = Map.put(fields, name, struct!(OpenApiSpex.Schema, options))
              {fields, required}
            else
              {fields, required}
            end
          end)

        %OpenApiSpex.Schema{
          title: "CreatePost",
          type: :object,
          properties: properties,
          required: required
        }
      end
    end
  end

  def schema_for({:change, _options}, acc), do: acc
  def schema_for({:inclusion, values}, acc), do: Map.put(acc, :enum, values)
  def schema_for({:format, format}, acc), do: Map.put(acc, :pattern, format)

  def schema_for({:length, options}, acc) do
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

  def schema_for({:number, options}, acc) do
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
        acc
        |> Map.put(:minimum, value)
        |> Map.put(:maximum, value)
        |> Map.put(:exclusiveMinimum, true)
        |> Map.put(:exclusiveMaximum, true)
    end)
  end

  def schema_for({:doc, options}, acc) do
    Map.merge(acc, Enum.into(options, %{}))
  end

  def schema_for({:required, _}, acc), do: acc

  def schema_for(validator, acc) do
    IO.inspect(validator)
    acc
  end
end
