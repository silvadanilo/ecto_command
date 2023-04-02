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
        only: [command: 1, command_field: 1, command_field: 2, command_field: 3, extra_validator: 1, extra_validator: 2]

      import Ecto.Changeset

      @before_compile unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :cast_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :internal_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :validators, accumulate: true)
      Module.register_attribute(__MODULE__, :trim_fields, accumulate: true)

      @doc false
      def set(_, changeset, _params), do: changeset

      defoverridable set: 3
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote unquote: false do
      def new(attributes) do
        attributes
        |> changeset()
        |> apply_action(:insert)
      end

      def changeset(%{} = params) do
        __MODULE__
        |> struct!(%{})
        |> cast(params, @cast_fields)
        |> __set_internal_fields()
        |> __trim_fields()
        |> __validate()
      end

      def execute(%{} = attributes) when is_map(attributes) do
        with {:ok, command} <- new(attributes) do
          command
          |> execute()
        end
      end

      def __set_internal_fields(changeset) do
        Enum.reduce(Enum.reverse(@internal_fields), changeset, fn field, changeset ->
          case apply(__MODULE__, :set, [field, changeset, changeset.params]) do
            %Ecto.Changeset{} = changeset -> changeset
            value -> put_change(changeset, field, value)
          end
        end)
      end
    end
  end

  def parse_block({:__block__, context, block}), do: {:__block__, context, Enum.map(block, &parse_block/1)}
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
        validator_ast =
          Enum.reduce(@validators, quote(do: changeset), fn
            {:extra, function, opts}, acc ->
              quote do: unquote(function).(unquote(acc), unquote(opts))

            {field, :change, {metadata, validator_fn}}, acc ->
              quote do:
                      unquote(acc)
                      |> unquote(String.to_atom("validate_change"))(
                        unquote(field),
                        unquote(metadata),
                        unquote(validator_fn)
                      )

            {field, validator, options}, acc ->
              quote do:
                      unquote(acc)
                      |> unquote(String.to_atom("validate_#{Atom.to_string(validator)}"))(
                        unquote(field),
                        unquote(options)
                      )
          end)

        def __validate(changeset) do
          unquote(validator_ast)
        end

        trim_fields_ast =
          Enum.reduce(@trim_fields, quote(do: changeset), fn
            field, acc -> quote do: update_change(unquote(acc), unquote(field), &CommandEx.Command.trim/1)
          end)

        def __trim_fields(changeset) do
          unquote(trim_fields_ast)
        end
      end

    quote do
      unquote(prelude)
      unquote(postlude)
    end
  end

  defmacro extra_validator(function, opts \\ []) do
    quote do
      Module.put_attribute(__MODULE__, :validators, {:extra, unquote(function), unquote(opts)})
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
        if unquote(type) == :string do
          Module.put_attribute(__MODULE__, :trim_fields, unquote(name))
        else
          raise ArgumentError, "trim option can only be used with string fields, got: #{inspect(unquote(type))}"
        end
      end

      unquote(@valid_validators)
      |> Enum.each(fn validator ->
        if opts[validator] !== nil && opts[validator] !== false do
          parsed_opts = if opts[validator] == true, do: [], else: opts[validator]

          Module.put_attribute(
            __MODULE__,
            :validators,
            {unquote(name), validator, Macro.escape(parsed_opts)}
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

  def trim(string) when is_binary(string), do: String.trim(string)
  def trim(any), do: any
end
