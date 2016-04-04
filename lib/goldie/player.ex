defmodule Goldie.Player do
  @moduledoc """
  Player process handling player's socket connection and state.
  """
  use Goldie.ComponentServer.GenServer
  require Logger
  alias Goldie.Event
  @behaviour :ranch_protocol

  @components [
    Goldie.Component.SocketHandler,
    Goldie.Component.Authentication, 
    Goldie.Component.Mover, 
    Goldie.Component.MoverComm,
    Goldie.Component.Spawner
  ]

  defstruct socket: nil,
  transport: nil,
  nonce: nil, #%20 bytes of random
  last_client_hmac: nil, #Last client issued hmac. Server uses this to check client sent messages.
  last_server_hmac: nil, #Last server issued hmac. Client can use this to check server sent messages.
  socket_keepalive_timestamp: nil,  #Timestamp when we last received a message
  msg_sent_uncompressed: nil,
  msg_sent_compressed: nil,
  last_msg_id: nil, 
  authenticated: false,
  timers: %{},
  components: [],
  entity: %{}

  def start_link(ref, socket, transport, opts) do
    ## https://github.com/ninenines/ranch/blob/master/doc/src/guide/protocols.asciidoc
    :proc_lib.start_link(__MODULE__, :init, [ref, socket, transport, opts])
  end

  def init(ref, socket, transport, _opts = []) do
    :ok = :proc_lib.init_ack({:ok, self()})
    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, [
      active: :once,
      packet: 4

    ])
    state = %Goldie.Player{
      socket: socket,
      transport: transport,
      components: @components
    }
    
    send self(), :setup
    :gen_server.enter_loop(__MODULE__, [], state)
  end

  def handle_info(:setup, state) do
    {:ok, state} = setup_components(state)
    {:noreply, state}    
  end

  def handle_info({:tcp, socket, data}, state = %Goldie.Player{socket: socket, transport: transport}) do
    transport.setopts(socket, [active: :once])
    Event.send_event(self(), {:socket_receive, data})
    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, _socket, reason}, state) do
    {:stop, reason, state}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    Logger.debug("Player terminate")
    {:ok, state} = teardown_components(state)
    {:noreply, state}
  end
end
