defmodule Unit.CommandEx.Command.MiddlewareTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use CommandEx.Test.CommandCase

  defmodule SampleMiddleware do
    @moduledoc false

    @behaviour CommandEx.Middleware

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
    def before_execution(command, opts) do
      middleware_name = opts[:middleware_name]
      store_call(:before_execution, middleware_name)

      get_callback(:before_execution, middleware_name, fn c -> {:ok, c} end).(command)
    end

    @impl true
    def after_execution(result, command, opts) do
      middleware_name = opts[:middleware_name]
      store_call(:after_execution, middleware_name)

      get_callback(:after_execution, middleware_name, fn r, _c, _o -> r end).(result, command, opts)
    end

    @impl true
    def after_failure(_kind, result, command, opts) do
      middleware_name = opts[:middleware_name]
      store_call(:after_failure, middleware_name)

      get_callback(:after_failure, middleware_name, fn r, _c, _o -> r end).(result, command, opts)
    end

    defp store_call(kind, middleware_name) do
      kind
      |> Process.get([])
      |> then(& Process.put(kind, &1 ++ [middleware_name]))
    end
  end

  defmodule SampleCommand do
    use CommandEx.Command
    use SampleMiddleware, middleware_name: :first_middleware
    use SampleMiddleware, middleware_name: :second_middleware

    command do
      field :name, :string, required: true
    end

    def execute(%__MODULE__{} = command) do
      case Process.get(:command_execution_should_fails, false) do
        true -> {:error, :an_error}
        false -> {:executed, command}
      end
    end
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
      SampleMiddleware.register_callback(:before_execution, :first_middleware, fn _command ->
        {:error, :an_error}
      end)

      assert {:error, :an_error} = SampleCommand.execute(%{name: "foo"})
      assert [:first_middleware] == Process.get(:before_execution, [])
    end

    test "a middleware could update the command" do
      SampleMiddleware.register_callback(:before_execution, :first_middleware, fn command ->
        {:ok, %{command | name: "updated"}}
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
      SampleMiddleware.register_callback(:after_execution, :first_middleware, fn result, _command, _opts ->
        assert {:executed, _} = result
        {:error, :an_error}
      end)

      assert {:error, :an_error} = SampleCommand.execute(%{name: "foo"})
      assert [:first_middleware, :second_middleware] = Process.get(:before_execution, [])
    end
  end

  describe "a middleware after_failure function" do
    test "is called (in reverse order) for every registered middleware when the command is invalid" do
      assert {:error, _changeset} = SampleCommand.execute(%{})
      assert [:second_middleware, :first_middleware] = Process.get(:after_failure, [])
    end

    test "is called (in reverse order) for every registered middleware when the execution fails" do
      Process.put(:command_execution_should_fails, true)

      assert {:error, _changeset} = SampleCommand.execute(%{name: "foo"})
      assert [:second_middleware, :first_middleware] = Process.get(:after_failure, [])
    end

    test "a middleware could change the failed result" do
      SampleMiddleware.register_callback(:after_failure, :first_middleware, fn result, _command, _opts ->
        assert {:error, :an_error} = result
        {:ok, :updated_result}
      end)

      Process.put(:command_execution_should_fails, true)

      assert {:ok, :updated_result} = SampleCommand.execute(%{name: "foo"})
    end
  end
end
