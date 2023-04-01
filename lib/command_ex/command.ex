defmodule CommandEx.Command do
  @command_options [:internal, :trim]
  @valid_validators [
    :acceptance,
    :change,
    :confirmation,
    :exclusion,
    :format,
    :inclusion,
    :length,
    :number,
    :required,
    :subset
  ]

  @doc false
  defmacro __using__(_) do
    quote do
      import CommandEx.Command,
        only: [command: 1, command_field: 1, command_field: 2, command_field: 3]

      import Ecto.Changeset

      @before_compile unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :cast_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :internal_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :validators, accumulate: true)
      Module.register_attribute(__MODULE__, :trim_fields, accumulate: true)

      def new(attributes) do
        attributes
        |> changeset()
        |> apply_action(:insert)
      end

      def changeset(%{} = params) do
        __MODULE__
        |> struct!(%{})
        |> cast(params, __schema__(:cast_fields))
        |> trim_fields()
        |> validate()
      end

    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote unquote: false do
      def execute(%{} = attributes) do
        with {:ok, command} <- new(attributes) do
          command
          |> execute()
        end
      end
    end
  end

  def parse_block({:__block__, context, block}),
    do: {:__block__, context, Enum.map(block, &parse_block/1)}

  def parse_block({:field, context, data}), do: {:command_field, context, data}
  def parse_block(block), do: block

  defmacro command(do: block) do
    prelude =
      quote do
        use Ecto.Schema
        @primary_key false

        embedded_schema do
          unquote(parse_block(block))
        end
      end

    postlude =
      quote unquote: false do
        internal_fields = @internal_fields |> Enum.reverse()
        cast_fields = @cast_fields |> Enum.reverse()
        validators = @validators |> Enum.reverse()

        validator_ast =
          Enum.reduce(@validators, quote(do: changeset), fn
            {:{}, [], [:change, field, {metadata, validator_fn}]}, acc ->
              quote do:
                      unquote(acc)
                      |> unquote(String.to_atom("validate_change"))(
                        unquote(field),
                        unquote(metadata),
                        unquote(validator_fn)
                      )

            {:{}, [], [validator, field, options]}, acc ->
              quote do:
                      unquote(acc)
                      |> unquote(String.to_atom("validate_#{Atom.to_string(validator)}"))(
                        unquote(field),
                        unquote(options)
                      )
          end)

        def validate(changeset) do
          unquote(validator_ast)
        end

        trim_fields_ast =
          Enum.reduce(@trim_fields, quote(do: changeset), fn
            field, acc ->
            quote do: update_change(unquote(acc), unquote(field), &CommandEx.Command.trim/1)
          end)

        def trim_fields(changeset) do
          unquote(trim_fields_ast)
        end

        def __schema__(:internal_fields), do: unquote(internal_fields)
        def __schema__(:cast_fields), do: unquote(cast_fields)
        def __schema__(:validators), do: unquote(validators)
      end

    quote do
      unquote(prelude)
      unquote(postlude)
    end
  end

  defmacro command_field(name, type \\ :string, opts \\ []) do
    quote do
      opts = unquote(opts)

      if opts[:internal] == true do
        Module.put_attribute(__MODULE__, :internal_fields, unquote(name))
      else
        Module.put_attribute(__MODULE__, :cast_fields, unquote(name))
      end

      if opts[:trim] == true do
        Module.put_attribute(__MODULE__, :trim_fields, unquote(name))
      end

      unquote(@valid_validators)
      |> Enum.each(fn validator ->
        if opts[validator] !== nil && opts[validator] !== false do
          parsed_opts = if opts[validator] == true, do: [], else: opts[validator]

          Module.put_attribute(
            __MODULE__,
            :validators,
            Macro.escape({validator, unquote(name), parsed_opts})
          )
        end
      end)

      Ecto.Schema.__field__(
        __MODULE__,
        unquote(name),
        unquote(type),
        opts |> Keyword.drop(unquote(@command_options ++ @valid_validators))
      )
    end
  end

  def trim(nil), do: nil
  def trim(string) when is_binary(string), do: String.trim(string)
end
