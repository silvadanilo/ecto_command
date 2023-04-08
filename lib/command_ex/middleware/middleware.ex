defmodule CommandEx.Middleware do
  @moduledoc """
  Middleware provides an extension point to add functions that you want to be
  called for every command execution

  Implement the `Commanded.Middleware` behaviour in your module and define the
  `c:before_execution/3`, `c:after_execution/4`, `c:after_failure/4` and `c:invalid/3` callback functions.

  ## Example middleware

      defmodule SampleMiddleware do
        @behaviour CommandEx.Middleware

        def before_execution(command, _attributes, _opts) do
          {:ok, command}

          # or

          # this way the subsequent middlewares will not be executed,
          # the command will not be executed,
          # and the return value will be: {:error, :some_error}
          {:error, :some_error}
        end

        def after_execution(result, _command, _attributes, _opts) do
          result
        end

        def after_failure(error, _command, _attributes, _opts) do
          error
        end

        def invalid(error, _attributes, _module, _opts) do
          error
        end
      end
  """

  @callback before_execution(command :: struct(), attributes :: map(), opts :: Keyword.t()) ::
              {:ok, struct()} | {:error, any()} | {:halt, any()}

  @callback after_execution(command :: struct(), result :: any(), attributes :: map(), opts :: Keyword.t()) ::
              {:ok, any()} | {:error, any()} | {:halt, any()}

  @callback after_failure(command :: struct(), result :: any(), attributes :: map(), opts :: Keyword.t()) ::
              {:ok, any()} | {:error, any()}

  @callback invalid(error :: any(), attributes :: map(), module :: atom(), opts :: Keyword.t()) :: any()
end
