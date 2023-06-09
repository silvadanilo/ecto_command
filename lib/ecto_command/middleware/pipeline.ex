defmodule EctoCommand.Middleware.Pipeline do
  @moduledoc """
  Pipeline is a struct used as an argument in the callback functions of modules
  implementing the `EctoCommand.Middleware` behaviour.

  This struct must be returned by each function to be used in the next
  middleware based on the configured middleware chain.

  ## Pipeline fields

    - `assigns` - shared user data as a map.

    - `command_uuid` - UUID assigned to the command being executed.

    - `command` - command struct being executed.

    - `params` - raw params received to instantiate the command

    - `metadata` - additional metadata, they could be used to fill internal command fields

    - `halted` - flag indicating whether the pipeline was halted.

    - `handler` - handler module where the "execute/1" function resides

    - `middlewares` - the list of middlewares to be executed

    - `response` - sets the response to send back to the caller.

    - `error` - sets the error to send back to the caller.

  """
  defstruct [
    :handler,
    :command,
    :params,
    :metadata,
    :middlewares,
    :response,
    :error,
    assigns: %{},
    halted: false
  ]

  alias EctoCommand.Middleware.Pipeline

  @type t :: %__MODULE__{
          handler: atom(),
          command: struct() | nil,
          params: map(),
          metadata: map(),
          middlewares: [tuple()],
          response: any() | nil,
          error: any() | nil,
          assigns: map(),
          halted: boolean()
        }

  @doc """
  Set the `key` with value

  ## Examples
      iex> pipeline = set(%Pipeline{}, :command, :my_command)
      iex> pipeline.command
      :my_command
  """
  def set(%Pipeline{} = pipeline, key, value) when is_atom(key) do
    Map.put(pipeline, key, value)
  end

  @doc """
  Puts the `key` with value equal to `value` into `assigns` map.

  ## Examples
      iex> pipeline = assign(%Pipeline{}, :foo, :bar)
      iex> pipeline.assigns
      %{foo: :bar}
  """
  def assign(%Pipeline{} = pipeline, key, value) when is_atom(key) do
    %Pipeline{assigns: assigns} = pipeline

    %Pipeline{pipeline | assigns: Map.put(assigns, key, value)}
  end

  @doc """
  Update the `key` with function `function` that receive the `key` value.

  ## Examples
      iex> pipeline = %Pipeline{command: %{name: "original"}}
      iex> pipeline = update!(pipeline, :command, fn command -> %{command | name: "updated"} end)
      iex> pipeline.command
      %{name: "updated"}
  """
  def update!(%Pipeline{} = pipeline, key, function) do
    Map.update!(pipeline, key, function)
  end

  @doc """
  Has the pipeline been halted?
  ## Examples
      iex> true = halted?(%Pipeline{halted: true})
      iex> false = halted?(%Pipeline{halted: false})
  """
  def halted?(%Pipeline{halted: halted}), do: halted

  @doc """
  Halts the pipeline by preventing further middleware downstream from being invoked.

  Prevents execution of the command if `halt` occurs in a `before_execution` callback.

  ## Examples
      iex> pipeline = %Pipeline{}
      iex> pipeline = halt(pipeline)
      iex> halted?(pipeline)
      true
  """
  def halt(%Pipeline{} = pipeline), do: %Pipeline{pipeline | halted: true}

  @doc """
  Halts the pipeline by preventing further middleware downstream from being invoked.

  Prevents execution of the command if `halt` occurs in a `before_execution` callback.

  Similar to `halt/1` but allows a response to be returned to the caller.

  ## Examples
      iex> pipeline = %Pipeline{}
      iex> pipeline = halt(pipeline, {:error, "halted"})
      iex> response(pipeline)
      {:error, "halted"}
      iex> halted?(pipeline)
      true
  """
  def halt(%Pipeline{} = pipeline, response), do: %Pipeline{pipeline | halted: true} |> respond(response)

  @doc """
  Extract the response from the pipeline, return the error if it is set
  return the stored response otherwise
  return nil if no response is set

  ## Examples
      iex> pipeline = %Pipeline{}
      iex> pipeline = Pipeline.error(pipeline, "halted")
      iex> Pipeline.response(pipeline)
      {:error, "halted"}
  """
  def response(%Pipeline{error: nil, response: response}), do: response
  def response(%Pipeline{error: error}), do: {:error, error}

  @doc """
  Sets the response to be returned to the dispatch caller

  ## Examples
      iex> pipeline = %Pipeline{}
      iex> pipeline = Pipeline.respond(pipeline, {:error, "halted"})
      iex> Pipeline.response(pipeline)
      {:error, "halted"}
  """
  def respond(%Pipeline{} = pipeline, response) do
    %Pipeline{pipeline | error: nil, response: response}
  end

  @doc """
  Sets the error

  ## Examples
      iex> pipeline = %Pipeline{}
      iex> pipeline = Pipeline.error(pipeline, "an_error")
      iex> Pipeline.response(pipeline)
      {:error, "an_error"}
  """
  def error(%Pipeline{} = pipeline, error) do
    %Pipeline{pipeline | error: error}
  end

  @doc """
  Executes the middleware chain.
  """
  def chain(pipeline, stage, middleware)
  def chain(%Pipeline{} = pipeline, _stage, []), do: pipeline
  def chain(%Pipeline{halted: true} = pipeline, _stage, _middleware), do: pipeline
  def chain(%Pipeline{error: nil} = pipeline, :after_failure, _middleware), do: pipeline

  def chain(%Pipeline{} = pipeline, stage, [{module, opts} | modules]) do
    chain(apply(module, stage, [pipeline, opts]), stage, modules)
  end

  @doc """
  Executes the function 'execute/1' in the handler module, pass the command to it.
  Halt the pipeline if command or handler are not set

  ## Examples
      iex> %Pipeline{halted: true} = Pipeline.execute(%Pipeline{halted: true})
      iex> %Pipeline{response: {:error, "command was not initialized"}} = Pipeline.execute(%Pipeline{handler: Pipeline})
      iex> %Pipeline{response: {:error, "handler was not set"}} = Pipeline.execute(%Pipeline{command: %{}})
      iex> %Pipeline{response: {:ok, :result}} = Pipeline.execute(%Pipeline{handler: SampleCommand, command: %SampleCommand{}})
  """
  def execute(%Pipeline{halted: true} = pipeline), do: pipeline
  def execute(%Pipeline{handler: nil} = pipeline), do: halt(pipeline, {:error, "handler was not set"})
  def execute(%Pipeline{command: nil} = pipeline), do: halt(pipeline, {:error, "command was not initialized"})

  def execute(%Pipeline{command: command} = pipeline) do
    case pipeline.handler.execute(command) do
      {:error, error} ->
        error(pipeline, error)

      result ->
        respond(pipeline, result)
    end
  end
end
