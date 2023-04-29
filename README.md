# EctoCommand

EctoCommand is a toolkit for mapping, validating, and executing commands received from any source.
It provides a simple and flexible way to define and execute commands in Elixir. With support for validation, middleware, and automatic OpenAPI documentation generation, it's a valuable tool for building scalable and maintainable Elixir applications. We hope you find it useful!

## Installation

To install EctoCommand, add it as a dependency to your project by adding `ecto_command` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_command, "~> 0.1.0"}
  ]
end
```

## Why Ecto?

"Ecto is also commonly used to map data from any source into Elixir structs, whether they are backed by a database or not."  
Based on this definition of the [Ecto](https://github.com/elixir-ecto/ecto) library, **EctoCommand** utilizes the "embedded_schema" functionality to map input data into an Elixir data structure to be used as a "command".  
This means that **EctoCommand is not tied to your persistence layer**.

As a result, you can easily convert data received from any source into a valid command struct, which can be executed easily. Additionally, you can also add functionality through middlewares to the execution pipeline.

Here is an example of a command definition:

```elixir
defmodule SampleCommand do
  use EctoCommand.Command

  command do
    param :id, :string
    param :name, :string, required: true, length: [min: 2, max: 255]
    param :email, :string, required: true, format: ~r/@/, length: [min: 6]
    param :count, :integer, required: true, number: [greater_than_or_equal_to: 18, less_than: 100]
    param :password, :string, required: true, length: [greater_than_or_equal_to: 8, less_than: 100], trim: true

    internal :hashed_password, :string
  end

  def execute(%SampleCommand{} = command) do
    # ....
    :ok
  end

  def fill(:hashed_password, _changeset, %{"password" => password}, _metadata) do
    :crypto.hash(:sha256, password) |> Base.encode64()
  end
end

:ok = SampleCommand.execute(%{id: "aa-bb-cc", name: "foobar", email: "foo@bar.com", count: 22, password: "mysecret"})

```

## Usage

### Defining a Command

To define a new command, create a module that includes the `EctoCommand.Command` behaviour and implements the `execute/1` function.  
The `execute/1` function takes the command structure as an argument.  
The `command` macro is used to define the parameters included in the command.   
The `param` macro is used to [define which parameters are accepted by the command](#params-definition), and the `internal` macro is used to [define which parameters are internally set](#internal-fields).


```elixir
defmodule MyApp.Commands.CreatePost do
  use EctoCommand.Command

  alias MyApp.PostRepository

  command do
    param :title, :string, required: true, length: [min: 3, max: 255]
    param :body, :string, required: true, length: [min: 3]

    internal :slug, :string
    internal :author, :string
  end

  def execute(%__MODULE__{} = command) do
    PostRepository.insert(%{
      title: command.title,
      body: command.body,
      slug: command.slug
    })
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
```

### Executing a Command

In order to execute the command, you need to call the `execute/2` function providing a raw parameter data map and, optionally, some metadata.  
```elixir
params = %{title: "New amazing post", body: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut eget ante odio."}
metadata = %{triggered_by: "writer"}

:ok = MyApp.Commands.CreatePost.execute(params, metadata)
```
This data is validated, and if it passes all validation rules, a new command structure is created and passed as an argument to the `execute/1` function defined inside your command module.

### Handling Errors

If a required parameter is missing or has an invalid value, the `EctoCommand.execute/2` function will return an error tuple with an invalid `Ecto.Changeset` structure. You can then use the changeset to return errors to the client or perform other actions.

```elixir
{:error, %Ecto.Changeset{valid?: false}} = MyApp.Commands.CreatePost.execute.execute(%{})
```

Returning an invalid `Ecto.Changeset` is particularly useful when working with Phoenix forms.

## Main goals and functionality of EctoCommand

EctoCommand aims to provide the following functionality:

- [An easy way to define the fields in a command (`param` macro).](#params-definition)
- [A simple and compact way of specifying how these fields should be validated (`param` macro options)](#validations-and-constraints-definition)
- [Defining the fields that need to be part of the command but can't be set from the outside (`internal` macro)](#internal-fields)
- [Validation of the params received from the outside](#validations)
- [Easy hooking of middleware to add functionality (like audit)](#using-middlewares-in-ectocommand)
- [Automatic generation of OpenApi documentation](#automated-generation-of-openapi-documentation)

## Params definition

To define the params that a command should accept, use the `param` macro. 
The `param` macro is based on the `field` macro of [Ecto.Schema](https://hexdocs.pm/ecto/Ecto.Schema.html) and defines a field in the schema with a given name and type. You can pass all the options supported by the `field` macro. Afterwards, each defined `param` is cast with the "external" data received.

## Validations and constraints definition

In addition to those options, the `param` macro accepts a set of other options that indicate how external data for that field should be validated. 
These options are applied to the intermediate Changeset created in order to validate data. 
These options are mapped into `validate_*` methods of the [Ecto.Changeset](https://hexdocs.pm/ecto/Ecto.Changeset.html). 
For example, if you want a command to have a "name" field that is required and has a length between 2 and 255 chars, you can write:

```Elixir
param :name, :string, required: true, length: [min: 2, max: 255]
```

This means that the command will have a `name` field, which will be cast to a `string` type. These functions will be called during the changeset validation:
```Elixir
changeset
|> validate_required([:name])
|> validate_length(:name, min: 2, max: 255)
```

for validators that accept both data and options, you could pass just data like:
```elixir
param :email, :string, format: ~r/@/
```
or data and options in this way:
```elixir
param :email, :string, format: {~r/@/, message: "my custom error message"}
```

## Internal fields

Sometimes, you might need to define internal fields, like `hashed_password` or `triggered_by`, which are not supposed to be set externally. To define such fields, you can use the `internal` macro.

```elixir
  command do
    param :password, :string, required: true, length: [greater_than_or_equal_to: 8, less_than: 100], trim: true
    internal :hased_password, :string
    internal :triggered_by, :string
  end

  def fill(:hased_password, _changeset, %{"password" => password}, _metadata) do
    :crypto.hash(:sha256, password) |> Base.encode64()
  end

  def fill(:triggered_by, _changeset, _params, %{"triggered_by": triggered_by}) do
    triggered_by
  end

  def fill(:triggered_by, changeset, _params, _metadata) do
    Ecto.Changeset.add_error(changeset, :triggered_by, "triggered_by metadata info is missing")
  end
```

These fields will be ignored during the "cast process". Instead, you need to define a public `fill/4` function to populate them. The `fill/4` function takes four arguments: the name of the field, the current temporary changeset, the parameters received from external sources, and additional metadata. You can choose to return the value that will populate the field or the updated changeset. Both options are acceptable, but returning the changeset is particularly useful if you want to add errors to it.

## Validations 

All parameters are validated in order to instantiate the command structure. 
When you use `EctoCommand.Command` inside your module, three methods are added:

- `changeset/2`
- `new/2`
- `execute/2`

All three methods take parameter data and metadata as arguments. 
The `changeset/2` function performs validation and other operations, and returns a valid or invalid `Ecto.Changeset`.  
The `new/2` function internally calls the `changeset/2` function and returns either the valid command structure or the invalid `Ecto.Changeset`.  
The `execute/2` function internally calls the `new/2` function and then calls the `execute/1` function (which should be defined inside the command module), or returns the invalid `Ecto.Changeset`.

## Using Middlewares in EctoCommand

EctoCommand supports middlewares, which allow you to modify the behavior of a command before and/or after its execution. 

A middleware is a module that implements the `EctoCommand.Middleware` behavior. Here's how you can use middlewares in your EctoCommand project:

```elixir
defmodule MyApp.MyMiddleware do
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
```

Each method takes two arguments: an [EctoCommand.Pipeline](https://github.com/silvadanilo/ecto_command/blob/master/lib/ecto_command/middleware/pipeline.ex) structure and the options you set for that middleware.  
The method should return an EctoCommand.Pipeline structure.

- `before_execution/2` is executed before command execution, it is executed only if the command is valid. In this function you could, if you wish, also update the command that will be executed.
- `after_execution/2` is executed after command successfully execution. In this function you could, if you wish, also update the returned value.
- `after_failure/2` is executed after command successfully execution. In this function you could, if you wish, also update the returned value.
- `invalid/2` is executed when data to build the command is invalid. 

### Configuring Middlewares
There are two ways to specify which middleware should be executed:

1. **Global configuration:** 

You can set up a list of middleware to be executed for every command by adding the following to your application's configuration:

```elixir
config :ecto_command, :middlewares,
  {MyApp.MyFirstMiddleware, a_middleware_option: :foo},
  {MyApp.MySecondMiddleware, a_middleware_option: :bar}
```

2. **Command-level configuration:** 

You can also specify middleware to be executed for a specific command by adding the `use` directive in the command module:

```elixir
defmodule MyApp.MyCommand do
  use EctoCommand.Command
  use MyApp.MyFirstMiddleware, a_middleware_option: :foo
  use MyApp.MySecondMiddleware, a_middleware_option: :bar

  ....
end
```

In this case, the specified middleware is executed only for that particular command.


## Automated generation of OpenAPI documentation

EctoCommand has a built-in feature that automatically generates OpenAPI documentation based on the parameters and validation rules defined in your command modules.  
This can save you a significant amount of time and effort in writing and maintaining documentation, particularly if you have a large number of commands.  

To generate the OpenAPI schema, you can use the `EctoCommand.OpenApi` module:

```elixir
use EctoCommand.OpenApi
```

By default, the schema's title is the fully qualified domain name (FQDN) of the module, and the default type is `:object`. 
However, you can override the defaults by passing options to the `use` module:

```elixir
use EctoCommand.OpenApi, title: "CustomTitle", type: :object
```


Then in your controller you can simply pass your command module to the request body specs:
```elixir

defmodule MyAppWeb.PostController do
  use MyAppWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias MyApp.Commands.CreatePost

  operation :create_post,
    summary: "Create a Post",
    request_body: {"Post params", "application/json", CreatePost},
    responses: [
      ok: {"Post response", "application/json", []},
      bad_request: {"Post response", "application/json", []}
    ]
  def create_post(conn, params) do
    ...
  end
```

For more information on serving the Swagger UI, please refer to the readme of the [open-api-spex](https://github.com/open-api-spex/open_api_spex) library.

## Contributing
Contributions are always welcome! Please feel free to submit a pull request or create an issue if you find a bug or have a feature request.

## License
This library is licensed under the MIT license. See [LICENSE](https://github.com/silvadanilo/ecto_command/blob/master/LICENSE) for more details.


> Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
> and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
> be found at <https://hexdocs.pm/ecto_command>.
