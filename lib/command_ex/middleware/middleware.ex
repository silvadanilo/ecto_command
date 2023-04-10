defmodule CommandEx.Middleware do
  @moduledoc """
  Middleware provides an extension point to add functions that you want to be
  called for every command execution

  Implement the `CommandEx.Middleware` behaviour in your module and define the
  `c:before_execution/2`, `c:after_execution/2`, `c:after_failure/2` and `c:invalid/2` callback functions.

  ## Example middleware

      defmodule SampleMiddleware do
        @behaviour CommandEx.Middleware

        @impl true
        def before_execution(pipeline, _opts) do
          pipeline
          |> Pipeline.assign(:some_data, :some_value)
          |> Pipeline.update!(:command, fn command -> %{command | name: "updated-name"} end)
        end

        def after_execution(pipeline, _opts) do
          Logger.debug("Command executed successfully", command: pipeline.command, result: Pipeline.response(pipeline))

          pipeline
        end

        def after_failure(pipeline, _opts) do
          Logger.error("Command execution fails", command: pipeline.command, error: Pipeline.response(pipeline))

          pipeline
        end

        def invalid(pipeline, _opts) do
          Logger.error("invalid params received", params: pipeline.params, error: Pipeline.response(pipeline))

          pipeline
        end
      end
  """

  alias CommandEx.Middleware.Pipeline

  @type pipeline :: %Pipeline{}

  @callback before_execution(pipeline :: pipeline(), opts :: Keyword.t()) :: pipeline()

  @callback after_execution(pipeline :: pipeline(), opts :: Keyword.t()) :: pipeline()

  @callback after_failure(pipeline :: pipeline(), opts :: Keyword.t()) :: pipeline()

  @callback invalid(pipeline :: pipeline(), opts :: Keyword.t()) :: pipeline()
end
