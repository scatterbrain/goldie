defmodule SocketHandlerTest do
  use ExUnit.Case, async: false
  import Mock
  require Logger
  alias Goldie.Component.SocketHandler
  doctest Goldie.Component.SocketHandler

  setup do
    assert {:ok, state} = SocketHandler.setup(%Goldie.Player{ entity: %{ id: "my_id" } })
    on_exit fn ->
      assert {:ok, _state} = SocketHandler.teardown(state)    
    end

    {:ok, state: state}
  end

  test "socket send", _context do
    msg = %{}
    assert :ok = SocketHandler.send_socket(msg)
    assert_receive {:event, {:socket_send, msg}, _}
  end

  test "event socket receive", context do
    state = context.state 
    {:ok, data} = Goldie.Message.encode(%{_cmd: :move, data: %{coord: [1, 2], jou: true, faa: %{}}})
    hmac = :erlang.iolist_to_binary(:crypto.rand_bytes(11))
    xorred_msg = :erlang.list_to_binary(SocketHandler.xor_cipher(data, hmac))
    packet = << 1 :: little-unsigned-integer-size(32), hmac :: binary, xorred_msg :: binary>>
    assert {:ok, {:socket_receive, _}, _} = SocketHandler.handle_event({:socket_receive, packet}, self(), state)
  end

  test "event socket send", context do
    state = context.state
    transport = :ranch_tcp
    state = %Goldie.Player{state | transport: transport}
    with_mock transport, [send: fn(_, _) -> :ok end] do    
      assert {:ok, {:socket_send, _}, _} = SocketHandler.handle_event({:socket_send, %{msg: "test", hoi: true, foo: %{}}}, self(), state)
    end
  end
end


