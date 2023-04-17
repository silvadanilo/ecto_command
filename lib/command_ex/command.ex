defmodule CommandEx.Command do
  @moduledoc false

  alias CommandEx.Command
  alias CommandEx.Middleware.Pipeline

  @command_options [:internal, :trim, :doc]
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
        only: [command: 1, param: 2, param: 3, extra_validator: 1, extra_validator: 2, internal: 2, internal: 3]

      import Ecto.Changeset

      @before_compile unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :cast_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :internal_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :validators, accumulate: true)
      Module.register_attribute(__MODULE__, :trim_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :command_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :middlewares, accumulate: true)

      @doc false
      def fill(_, changeset, _params, _metadata), do: changeset

      defoverridable fill: 4
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote unquote: false do
      def new(attributes, metadata \\ %{}) do
        attributes
        |> changeset(metadata)
        |> apply_action(:insert)
      end

      def changeset(%{} = params, metadata \\ %{}) do
        params = Command.trim_fields(params, @trim_fields)

        __MODULE__
        |> struct!(%{})
        |> cast(params, @cast_fields)
        |> __validate()
        |> __fill_internal_fields(metadata)
      end

      def execute(%{} = params, metadata \\ %{}) when is_map(params) do
        Command.execute(%Pipeline{
          params: params,
          metadata: metadata,
          handler: __MODULE__,
          middlewares: Application.get_env(:command_ex, :middlewares, []) ++ Enum.reverse(@middlewares)
        })
      end

      def __fill_internal_fields(changeset, metadata),
        do: __fill_internal_fields(changeset, metadata, Enum.reverse(@internal_fields))

      def __fill_internal_fields(%{valid?: false} = changeset, _metadata, _internal_fields), do: changeset
      def __fill_internal_fields(changeset, _metadata, []), do: changeset

      def __fill_internal_fields(changeset, metadata, [field | internal_fields]) do
        changeset =
          case apply(__MODULE__, :fill, [field, changeset, changeset.params, metadata]) do
            %Ecto.Changeset{} = changeset -> changeset
            value -> put_change(changeset, field, value)
          end

        __fill_internal_fields(changeset, metadata, internal_fields)
      end
    end
  end

  def parse_block({:__block__, context, block}), do: {:__block__, context, Enum.map(block, &parse_block/1)}
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

  defmacro internal(name, type \\ :string, opts \\ []) do
    quote do
      opts = unquote(opts)

      Module.put_attribute(__MODULE__, :internal_fields, unquote(name))

      Ecto.Schema.__field__(
        __MODULE__,
        unquote(name),
        unquote(type),
        opts |> Keyword.drop(unquote(@command_options ++ @valid_validators))
      )
    end
  end

  defmacro param(name, type, opts \\ []) do
    quote do
      opts = unquote(opts)

      Module.put_attribute(__MODULE__, :command_fields, {unquote(name), unquote(type), opts})
      Module.put_attribute(__MODULE__, :cast_fields, unquote(name))

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

  def trim_fields(params, trim_fields) do
    Enum.reduce(trim_fields, params, fn field, params ->
      Map.update(params, field, nil, &String.trim/1)
    end)
  end

  def execute(%Pipeline{} = pipeline) do
    pipeline
    |> instantiate_command()
    |> Pipeline.chain(:before_execution, pipeline.middlewares)
    |> Pipeline.execute()
    |> Pipeline.chain(:after_execution, Enum.reverse(pipeline.middlewares))
    |> Pipeline.chain(:after_failure, Enum.reverse(pipeline.middlewares))
    |> Pipeline.response()
  end

  defp instantiate_command(%Pipeline{handler: handler, params: params, metadata: metadata} = pipeline) do
    case handler.new(params, metadata) do
      {:ok, command} ->
        Pipeline.set(pipeline, :command, command)

      {:error, error} ->
        pipeline
        |> Pipeline.respond({:error, error})
        |> Pipeline.chain(:invalid, pipeline.middlewares)
        |> Pipeline.halt()
    end
  end
end
