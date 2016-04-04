defmodule Goldie.ComponentServer.GenServer do
  @moduledoc """
  GenServer that defines event handler for running components
  Example:
  defmodule MyServer do
  use Goldie.ComponentServer.GenServer
  ...
  end
  """
  alias Goldie.Event

  defmacro __using__(_opts) do
    quote do
      use GenServer

      @doc """
      Event received
      """
      def handle_info({:event, event, from}, state) do
        {:ok, state} = run_components(state.components, event, from, state)
        {:noreply, state}
      end

      @doc """
      Runs setup for all components
      """
      @spec setup_components(struct) :: {:ok, struct}
      def setup_components(state) do
        setup_components(state.components, state)
      end

      @spec setup_components(list, struct) :: {:ok, struct} | {:ok, Event.t, struct}
      defp setup_components([], state), do: {:ok, state}

      defp setup_components([component|components], state) do
        {:ok, state} = component.setup(state)
        setup_components(components, state)
      end

      @doc """
      Runs teardown for all components
      """
      @spec teardown_components(struct) :: {:ok, struct}
      def teardown_components(state) do
        teardown_components(state.components, state)
      end

      @spec teardown_components(list, struct) :: {:ok, struct} | {:ok, Event.t, struct}
      defp teardown_components([], state), do: {:ok, state}

      defp teardown_components([component|components], state) do
        {:ok, state} = component.teardown(state)
        teardown_components(components, state)
      end

      @spec run_components(list, Event.t, pid, struct) :: {:ok, struct} | {:ok|:stop, Event.t, struct}
      defp run_components([], _event, _from, state), do: {:ok, state}

      defp run_components([component|components], event, from, state) do
        case component.handle_event(event, from, state) do
          {:ok, event, state} ->
            run_components(components, event, from, state)
            ## Any component can stop the event from propagating
          {:stop, event, state} ->
            run_components([], event, from, state)
        end
      end

    end
  end
end
