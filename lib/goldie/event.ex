defmodule Goldie.Event do
  @moduledoc """
  Event sender
  """
  @type event_name :: atom
  @type t :: {event_name, any}

  @doc """
  Send an event to self
  """
  @spec send_event(t) :: :ok
  def send_event(msg) do
    send_event(self(), msg) 
  end
  
  @doc """
  Send an event to receivers
  """
  @spec send_event(pid, t) :: :ok
  def send_event(receiver, msg) do
    {:event, ^msg, _} = send receiver, {:event, msg, self()}
    :ok
  end

  @doc """
  Send an event to self after a timeout
  """
  @spec send_after(t, non_neg_integer) :: {:ok, reference}
  def send_after(msg, timeout) do
    tref = Process.send_after(self(), {:event, msg, self()}, timeout)
    {:ok, tref}
  end

  @doc """
  Cancels a timer started with send_after
  """
  @spec cancel_timer(reference) :: :ok
  def cancel_timer(tref) do
    Process.cancel_timer(tref)
  end

end
