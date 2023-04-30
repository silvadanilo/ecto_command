defmodule Unit.EctoCommand.MiddlewareTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use EctoCommand.Test.CommandCase

  alias EctoCommand.Middleware.Pipeline

  defmodule SampleMiddleware do
    @moduledoc false

    alias EctoCommand.Middleware.Pipeline

    @behaviour EctoCommand.Middleware

    @doc false
    defmacro __using__(opts \\ []) do
      quote bind_quoted: [opts: opts, module: __MODULE__] do
        @middlewares {module, opts}
      end
    end

    def register_callback(kind, middleware_name, function) do
      Process.put({kind, middleware_name}, function)
    end

    def get_callback(kind, middleware_name, default_function) do
      Process.get({kind, middleware_name}, default_function)
    end

    @impl true
    def before_execution(pipeline, opts) do
      middleware_name = opts[:middleware_name]
      store_call(:before_execution, middleware_name)

      get_callback(:before_execution, middleware_name, fn pipeline -> pipeline end).(pipeline)
    end

    @impl true
    def after_execution(pipeline, opts) do
      middleware_name = opts[:middleware_name]
      store_call(:after_execution, middleware_name)

      get_callback(:after_execution, middleware_name, fn pipeline, _opts -> pipeline end).(pipeline, opts)
    end

    @impl true
    def after_failure(pipeline, opts) do
      middleware_name = opts[:middleware_name]
      store_call(:after_failure, middleware_name)

      get_callback(:after_failure, middleware_name, fn pipeline, _opts -> pipeline end).(pipeline, opts)
    end

    @impl true
    def invalid(pipeline, opts) do
      middleware_name = opts[:middleware_name]
      store_call(:invalid, middleware_name)

      get_callback(:invalid, middleware_name, fn pipeline, _opts -> pipeline end).(pipeline, opts)
    end

    defp store_call(kind, middleware_name) do
      kind
      |> Process.get([])
      |> then(&Process.put(kind, &1 ++ [middleware_name]))
    end
  end

  defmodule SampleCommand do
    use EctoCommand

    command do
      param :name, :string, required: true
    end

    def execute(%__MODULE__{} = command) do
      case Process.get(:ecto_commandecution_should_fails, false) do
        true -> {:error, :an_error}
        false -> {:executed, command}
      end
    end
  end

  setup do
    Application.put_env(:ecto_command, :middlewares, [
      {Unit.EctoCommand.MiddlewareTest.SampleMiddleware, middleware_name: :first_middleware},
      {Unit.EctoCommand.MiddlewareTest.SampleMiddleware, middleware_name: :second_middleware}
    ])

    on_exit(fn ->
      Application.put_env(:ecto_command, :middlewares, [])
    end)
  end

  describe "a middleware before_execution function" do
    test "is called for every registered middleware" do
      assert {:executed, _command} = SampleCommand.execute(%{name: "foo"})
      assert [:first_middleware, :second_middleware] = Process.get(:before_execution, [])
    end

    test "is not called when the command is invalid" do
      SampleMiddleware.register_callback(:before_execution, :first_middleware, fn _error ->
        raise "Should not be called"
      end)

      assert {:error, _error} = SampleCommand.execute(%{})
      assert [] = Process.get(:before_execution, [])
    end

    test "is not called when a previous middleware returns an error" do
      SampleMiddleware.register_callback(:before_execution, :first_middleware, fn pipeline ->
        Pipeline.halt(pipeline, {:error, :an_error})
      end)

      assert {:error, :an_error} = SampleCommand.execute(%{name: "foo"})
      assert [:first_middleware] == Process.get(:before_execution, [])
    end

    test "a middleware could update the command" do
      SampleMiddleware.register_callback(:before_execution, :first_middleware, fn pipeline ->
        Pipeline.update!(pipeline, :command, fn command -> %{command | name: "updated"} end)
      end)

      assert {:executed, %SampleCommand{name: "updated"}} == SampleCommand.execute(%{name: "foo"})
    end
  end

  describe "a middleware after_execution function" do
    test "is called (in reverse order) for every registered middleware" do
      assert {:executed, _command} = SampleCommand.execute(%{name: "foo"})
      assert [:second_middleware, :first_middleware] = Process.get(:after_execution, [])
    end

    test "a middleware could change the result" do
      SampleMiddleware.register_callback(:after_execution, :first_middleware, fn pipeline, _opts ->
        assert {:executed, _} = Pipeline.response(pipeline)
        Pipeline.respond(pipeline, {:error, :an_error})
      end)

      assert {:error, :an_error} = SampleCommand.execute(%{name: "foo"})
      assert [:first_middleware, :second_middleware] = Process.get(:before_execution, [])
    end
  end

  describe "a middleware invalid function" do
    test "is called for every registered middleware when the command is invalid" do
      assert {:error, _changeset} = SampleCommand.execute(%{})
      assert [:first_middleware, :second_middleware] = Process.get(:invalid, [])
    end
  end

  describe "a middleware after_failure function" do
    test "is called (in reverse order) for every registered middleware when the execution fails" do
      Process.put(:ecto_commandecution_should_fails, true)

      assert {:error, :an_error} = SampleCommand.execute(%{name: "foo"})
      assert [:second_middleware, :first_middleware] = Process.get(:after_failure, [])
    end

    test "a middleware could change the failed result" do
      SampleMiddleware.register_callback(:after_failure, :first_middleware, fn pipeline, _opts ->
        assert {:error, :an_error} = Pipeline.response(pipeline)
        Pipeline.respond(pipeline, {:ok, :updated_result})
      end)

      Process.put(:ecto_commandecution_should_fails, true)

      assert {:ok, :updated_result} = SampleCommand.execute(%{name: "foo"})
    end
  end

  describe "use command defined middlewares when are set" do
    defmodule SampleCommandWithMiddlewares do
      use EctoCommand
      use SampleMiddleware, middleware_name: :third_middleware
      use SampleMiddleware, middleware_name: :fourth_middleware

      command do
        param :name, :string, required: true
      end

      def execute(%__MODULE__{} = command) do
        {:executed, command}
      end
    end

    test "middlewares are executed in the right order" do
      assert {:executed, _command} = SampleCommandWithMiddlewares.execute(%{name: "foo"})

      assert [:first_middleware, :second_middleware, :third_middleware, :fourth_middleware] =
               Process.get(:before_execution, [])
    end
  end
end
