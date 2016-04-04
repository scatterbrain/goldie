defmodule Goldie.Component do
  use Behaviour
  alias Goldie.Event

  @doc """
  Sets up the component
  """
  defcallback setup(struct) :: {:ok, struct}

  @doc """
  Terminates the component
  """
  defcallback teardown(struct) :: {:ok, struct}

  @doc """
  Handles an incoming event
  """
  defcallback handle_event(Event.t, pid, struct) :: {:ok|:stop, Event.t, struct}

  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Goldie.Component
      require Logger

      @doc """
      Default setup
      """
      def setup(state), do: {:ok, state}

      @doc """
      Default teardown
      """
      def teardown(state), do: {:ok, state}

      @doc """
      Catches all unhandled events.
      """
      def handle_event(event, _from, state) do
        Logger.debug(" #{__MODULE__} HANDLE")
        {:ok, event, state}
      end

      defoverridable [setup: 1, teardown: 1, handle_event: 3]
    end
  end
end
