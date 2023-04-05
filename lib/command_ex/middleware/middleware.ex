defmodule CommandEx.Middleware do
  @moduledoc """
  Middleware provides an extension point to add functions that you want to be
  called for every command execution

  Implement the `Commanded.Middleware` behaviour in your module and define the
  `c:before_execution/2`, `c:after_execution/3`, and `c:after_failure/4` callback functions.

  ## Example middleware

      defmodule NoOpMiddleware do
        @behaviour CommandEx.Middleware

        def before_execution(command, opts) do
          {:ok, command}

          # or

          # this way the subsequent middlewares will not be executed,
          # the command will not be executed,
          # and the return value will be: {:error, :some_error}
          {:error, :some_error}
        end

        def after_execution(result, _command, _opts) do
          result
        end

        def after_failure(_kind, result, _command, _opts) do
          result
        end
      end
  """

  @callback before_execution(command :: struct(), opts :: Keyword.t()) :: {:ok, struct()} | {:error, any()} | {:halt, any()}
  @callback after_execution(result :: any(), command :: struct(), opts :: Keyword.t()) :: {:ok, any()} | {:error, any()} | {:halt, any()}
  @callback after_failure(kind :: atom(), result :: any(), command :: struct() | map(), opts :: Keyword.t()) :: {:error, any()}
end
