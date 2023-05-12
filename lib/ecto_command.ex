defmodule EctoCommand do
  @moduledoc """
  The `EctoCommand` module provides a DSL for defining command schemas.
  It is used by `use EctoCommand` in your command modules.

  ### Example
      defmodule MyApp.Commands.CreatePost do
        use EctoCommand
        alias MyApp.PostRepository

        command do
          param :title, :string, required: true, length: [min: 3, max: 255]
          param :body, :string, required: true, length: [min: 3]

          internal :slug, :string
          internal :author, :string
        end

        def execute(%__MODULE__{} = command) do
          ...
          :ok
        end

        def fill(:slug, _changeset, %{"title" => title}, _metadata) do
          Slug.slufigy(title)
        end

        def fill(:author, _changeset, _params, %{"triggered_by" => triggered_by}) do
          triggered_by
        end

        def fill(:author, changeset, _params, _metadata) do
          Ecto.Changeset.add_error(changeset, :triggered_by, "triggered_by metadata info is missing")
        end
      end
  """

  alias EctoCommand
  alias EctoCommand.Middleware.Pipeline

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
      import EctoCommand,
        only: [
          command: 1,
          param: 2,
          param: 3,
          validate_with: 1,
          validate_with: 2,
          internal: 2,
          internal: 3,
          embeds_one: 3,
          cast_embedded_fields: 2
        ]

      import Ecto.Changeset

      @before_compile unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :cast_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :internal_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :validators, accumulate: true)
      Module.register_attribute(__MODULE__, :trim_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :command_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :middlewares, accumulate: true)

      @doc """
      The `fill/4` function takes four arguments: the name of the field, the current temporary changeset, the parameters received from external sources, and additional metadata. You can choose to return the value that will populate the field or the updated changeset. Both options are acceptable, but returning the changeset is particularly useful if you want to add errors to it.
      """
      def fill(_, changeset, _params, _metadata), do: changeset

      defoverridable fill: 4
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote unquote: false do
      # The new/2 function creates a new command struct with the given params and metadata
      # in case of invalid data it returns an error changeset.
      # ## Examples
      #   new(%{name: "John", age: 28})
      #   new(%{name: "John", age: 28}, %{user_id: 1})
      @spec new(params :: map, metadata :: map) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
      def new(%{} = params, metadata \\ %{}) do
        params
        |> changeset(metadata)
        |> apply_action(:insert)
      end

      # The changeset/2 function creates a new changeset with the given params and validates it against the given schema.
      # It also fills the internal fields with the given metadata.
      # ## Examples
      #    changeset(%{name: "John", age: 28})
      #    changeset(%{name: "John", age: 28}, %{user_id: 1})
      @spec changeset(params :: map, metadata :: map) :: Ecto.Changeset.t()
      def changeset(params, metadata \\ %{})

      def changeset(struct, params) when is_struct(struct) do
        changeset(params, %{})
      end

      def changeset(%{} = params, metadata) do
        params = EctoCommand.trim_fields(params, @trim_fields)

        __MODULE__
        |> struct!(%{})
        |> cast(params, @cast_fields)
        |> cast_embedded_fields(Keyword.keys(@ecto_embeds))
        |> __validate()
        |> __fill_internal_fields(metadata)
      end

      @spec execute(params :: map, metadata :: map) :: any() | {:error, Ecto.Changeset.t()}
      def execute(%{} = params, metadata \\ %{}) when is_map(params) do
        EctoCommand.execute(%Pipeline{
          params: params,
          metadata: metadata,
          handler: __MODULE__,
          middlewares: Application.get_env(:ecto_command, :middlewares, []) ++ Enum.reverse(@middlewares)
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

  @doc false
  def parse_block({:__block__, context, block}), do: {:__block__, context, Enum.map(block, &parse_block/1)}
  def parse_block(block), do: block

  @doc """
  The command/1 macro defines a command schema with the given block.
  ## Examples
       command do
         param :name, :string
         param :age, :integer
       end
  """
  defmacro command(do: block) do
    prelude =
      quote do
        use Ecto.Schema
        @primary_key false

        embedded_schema do
          import Ecto.Schema, except: [embeds_one: 3, embeds_one: 4]
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

            {field, validator, data, options}, acc ->
              quote do:
                      unquote(acc)
                      |> unquote(String.to_atom("validate_#{Atom.to_string(validator)}"))(
                        unquote(field),
                        unquote(data),
                        unquote(options)
                      )

            {field, validator, {data, options}}, acc ->
              quote do:
                      unquote(acc)
                      |> unquote(String.to_atom("validate_#{Atom.to_string(validator)}"))(
                        unquote(field),
                        unquote(data),
                        unquote(options)
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

  defmacro validate_with(function, opts \\ []) do
    quote do
      Module.put_attribute(__MODULE__, :validators, {:extra, unquote(function), unquote(opts)})
    end
  end

  @doc """
  Defines a command internal field.  \n
  These fields will be ignored during the "cast process".
  Instead, you need to define a public `fill/4` function to populate them. The `fill/4` function takes four arguments: the name of the field, the current temporary changeset, the parameters received from external sources, and additional metadata. You can choose to return the value that will populate the field or the updated changeset. Both options are acceptable, but returning the changeset is particularly useful if you want to add errors to it.
  ## Examples
       internal :slug, :string
       internal :author, :string
  """
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

  @doc """
  Defines a command parameter field.  \n
  The `param` macro is based on the `field` macro of [Ecto.Schema](https://hexdocs.pm/ecto/Ecto.Schema.html) and defines a field in the schema with a given name and type. You can pass all the options supported by the `field` macro. Afterwards, each defined `param` is cast with the "external" data received.
  In addition to those options, the `param` macro accepts a set of other options that indicate how external data for that field should be validated.
  These options are applied to the intermediate Changeset created in order to validate data.
  These options are mapped into `validate_*` methods of the [Ecto.Changeset](https://hexdocs.pm/ecto/Ecto.Changeset.html).
  ## Examples

      param :title, :string, required: true, length: [min: 3, max: 255]
      param :body, :string, required: true, length: [min: 3]
  """
  defmacro param(name, type, opts \\ [])

  defmacro param(name, type, opts) do
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

  defmacro embeds_one(name, schema, do: block) do
    quote do
      defmodule unquote(schema) do
        use EctoCommand

        command do
          unquote(block)
        end
      end

      Ecto.Schema.embeds_one(unquote(name), unquote(schema))
    end
  end

  @doc false
  @spec trim_fields(map(), [atom()]) :: map()
  def trim_fields(params, trim_fields) do
    Enum.reduce(trim_fields, params, fn field, params ->
      Map.update(params, field, nil, &String.trim/1)
    end)
  end

  @doc false
  @spec execute(Pipeline.t()) :: any() | {:error, Ecto.Changeset.t()}
  def execute(%Pipeline{} = pipeline) do
    pipeline
    |> instantiate_command()
    |> Pipeline.chain(:before_execution, pipeline.middlewares)
    |> Pipeline.execute()
    |> Pipeline.chain(:after_execution, Enum.reverse(pipeline.middlewares))
    |> Pipeline.chain(:after_failure, Enum.reverse(pipeline.middlewares))
    |> Pipeline.response()
  end

  def cast_embedded_fields(changeset, embedded_fields) do
    Enum.reduce(embedded_fields, changeset, fn embedded_field, changeset ->
      Ecto.Changeset.cast_embed(changeset, embedded_field)
    end)
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
