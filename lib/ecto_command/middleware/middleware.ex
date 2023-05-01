defmodule EctoCommand.Middleware do
  @moduledoc """
  Middleware provides an extension point to add functions that you want to be
  called for every command execution

  Implement the `EctoCommand.Middleware` behaviour in your module and define the
  `c:before_execution/2`, `c:after_execution/2`, `c:after_failure/2` and `c:invalid/2` callback functions.

  ## Example middleware

      defmodule SampleMiddleware do
        @behaviour EctoCommand.Middleware

        @impl true
        def before_execution(pipeline, _opts) do
          pipeline
          |> Pipeline.assign(:some_data, :some_value)
          |> Pipeline.update!(:command, fn command -> %{command | name: "updated-name"} end)
        end

        @impl true
        def after_execution(pipeline, _opts) do
          Logger.debug("Command executed successfully", command: pipeline.command, result: Pipeline.response(pipeline))

          pipeline
        end

        @impl true
        def after_failure(pipeline, _opts) do
          Logger.error("Command execution fails", command: pipeline.command, error: Pipeline.response(pipeline))

          pipeline
        end

        @impl true
        def invalid(pipeline, _opts) do
          Logger.error("invalid params received", params: pipeline.params, error: Pipeline.response(pipeline))

          pipeline
        end
      end
  """

  alias EctoCommand.Middleware.Pipeline

  @type pipeline :: %Pipeline{}

  @doc """
  Is executed before command execution, and only if the command is valid. In this function, if you'd like, you might update the command that will be executed.
  ## Example
      @impl true
      def before_execution(pipeline, _opts) do
        pipeline
        |> Pipeline.assign(:some_data, :some_value)
        |> Pipeline.update!(:command, fn command -> %{command | name: "updated-name"} end)
      end
  """
  @callback before_execution(pipeline :: pipeline(), opts :: Keyword.t()) :: pipeline()

  @doc """
  Is executed following a sucessful command execution. In this function, if you'd like, you could alter the returned value.
  ## Example
      @impl true
      def after_execution(pipeline, _opts) do
        Logger.debug("Command executed successfully", command: pipeline.command, result: Pipeline.response(pipeline))

        pipeline
      end
  """
  @callback after_execution(pipeline :: pipeline(), opts :: Keyword.t()) :: pipeline()

  @doc """
  Is executed after a failed command execution. In this function you could, if you wish, also update the returned value.
  ## Example
      @impl true
      def after_failure(pipeline, _opts) do
        Logger.error("Command execution fails", command: pipeline.command, error: Pipeline.response(pipeline))

        pipeline
      end
  """
  @callback after_failure(pipeline :: pipeline(), opts :: Keyword.t()) :: pipeline()

  @doc """
  Is executed when the command's inputs are invalid.
  ## Example
      @impl true
      def invalid(pipeline, _opts) do
        Logger.error("invalid params received", params: pipeline.params, error: Pipeline.response(pipeline))

        pipeline
      end
  """
  @callback invalid(pipeline :: pipeline(), opts :: Keyword.t()) :: pipeline()
end
