defmodule Goldie.Component.SocketHandler do
  use Goldie.Component
  alias Goldie.Event
  require Logger
  use Bitwise

  ## pings sent every KEEPALIVE_INTERVAL to prevent stale sockets
  @keepalive_interval 30000 

  @socket_keepalive_length 90000 ##If we don't get socket messages for 90 seconds, disconnect
  @socket_keepalive_interval 5000 ##Check if we have received messages every 5 seconds

  @msg_id_length 4 ##bytes- uint 32 bit value
  @nonce_bytes_length 33 ##bytes
  @hmac_bytes_length 11 ##bytes
  @compress_threshold_bytes 512

  @ckey <<48,168,223,40,213,245,25,36,115,66,70,149,127,121,245,188,77,50,54,111>> #Client key
  @skey <<170,59,187,127,112,41,118,62,24,236,86,74,226,21,193,181,157,150,112,47>> #Server key

  @doc """
  Send a message to caller's own socket
  """
  @spec send_socket(map) :: :ok
  def send_socket(msg) do
    Event.send_event(self(), {:socket_send, msg})
  end

  @spec setup(Goldie.Player) :: {:ok, Goldie.Player}  
  def setup(state) do
    state = %Goldie.Player { state |  
      msg_sent_uncompressed: 0, 
      msg_sent_compressed: 0,
      socket_keepalive_timestamp: Goldie.Utils.timestamp_epoch(),
      last_msg_id: {0, 0, nil}
    }

    state = state 
            |> setup_protocol_integrity 
            |> setup_connection
    {:ok, state}
  end

  @doc """
  Event Handler: Receive a TCP message
  """
  @spec handle_event(Event.t, pid, Goldie.Player) :: {:ok|:stop, Event.t, Goldie.Player}
  def handle_event({:socket_receive, packet} = _event, _from, %{ :entity => entity } = state) do
    <<msg_id :: little-unsigned-integer-size(32), hmac :: binary-size(@hmac_bytes_length), xorred_msg_data :: binary>> = packet
    {:ok, msg} = xorred_msg_data 
                  |> xor_cipher(hmac)
                  |> :erlang.list_to_binary
                  |> Goldie.Message.decode
   
    Logger.debug("[SOCKET RECEIVE #{entity.id}]: #{inspect msg}")
    Event.send_event(self(), {String.to_atom(msg._cmd), msg})
    
    ##TODO We need to send ping ack at the latest 2 seconds after receiving this message if no natural
    ## message traffic is happening (player is idling)
    msg_arrival_timestamp = Goldie.Utils.timestamp_ms()
    {_, _, backup_timer_ref} = state.last_msg_id
    new_backup_timer_ref = case backup_timer_ref do
      nil ->
        :erlang.send_after(2000, self(), {:ping_backup_timer_timeout})
      _ ->
        backup_timer_ref
    end

    {:ok, {:socket_receive, msg}, %Goldie.Player { state | 
        last_client_hmac: hmac, 
        socket_keepalive_timestamp: Goldie.Utils.timestamp_epoch(), 
        last_msg_id: {msg_id, msg_arrival_timestamp, new_backup_timer_ref}

      }}
  end

  @doc """
  Event Handler: Send a TCP message
  """
  def handle_event({:socket_send, msg} = _event, _from, %{ :socket => socket, :transport => transport } = state) do
    state = send(transport, socket, msg, state.entity.id, state) 
    {:ok, {:socket_send, msg}, state}
  end

  @doc """
  Event Handler sink
  """
  def handle_event(event, _from, state) do
    {:ok, event, state}
  end

  # setups the required state data for protocol integrity
  @spec setup_protocol_integrity(Goldie.Player) :: Goldie.Player
  defp setup_protocol_integrity(state) do
    nonce = :crypto.rand_bytes(@nonce_bytes_length)
    %Goldie.Player{ state | nonce: nonce, last_client_hmac: <<>>, last_server_hmac: <<>> }
  end

  ## sends the initial connection message to the client. 
  ## The connection between the server and the client is ready after the 
  ## client receives this message.
  @spec setup_connection(Goldie.Player) :: Goldie.Player
  defp setup_connection(%Goldie.Player { :transport => transport, :socket => socket } = state) do
    send(transport, socket, Goldie.Message.handshake(), "Unknown", state)
  end

  ## Send a message to the client's socket.
  @spec send(term, port, map, binary, Goldie.Player) :: Goldie.Player
  defp send(transport, socket, message, player_name, state) do
    Logger.debug("[SOCKET SEND #{player_name}]: #{inspect message}")
    case Goldie.Message.encode(message) do
      {:ok, packet} ->
        compressed = packet 
                  |> :erlang.iolist_to_binary
                  |> compress
        key = [@skey, state.nonce]
        data = [state.last_server_hmac, compressed]
        hmac = :crypto.sha_mac(key, data, @hmac_bytes_length)
        xorred = xor_cipher(compressed, hmac)

        ## If this is the first message, send Nonce
        packet_without_ping = case state.last_server_hmac do
          <<>> ->
            [state.nonce, hmac, xorred]
          _ ->
            [hmac, xorred]
        end

        {last_msg_id, last_msg_arrival_timestamp, ping_ack_backup_timer} = state.last_msg_id

        ## Mark if this message has ping information or not
        has_ping_info = last_msg_id != 0
        packet_with_ping = case has_ping_info do
          true ->
            now_ms = Goldie.Utils.timestamp_ms()
            server_delay = now_ms - last_msg_arrival_timestamp
            ping_header = << <<1>> :: binary, last_msg_id :: little-unsigned-size(32), server_delay :: little-unsigned-integer-size(16)>>
            [ping_header | packet_without_ping]
          false ->
            ping_header = <<0>>
            [ping_header | packet_without_ping]
        end

        :ok = do_send(transport, socket, packet_with_ping)
        case ping_ack_backup_timer do
          nil ->
            :ok
          _ ->
            ## We can cancel the backup timer because we send normal traffic
            :erlang.cancel_timer(ping_ack_backup_timer)
        end

        uncompressed_size = byte_size(packet)
        compressed_size = byte_size(compressed)
        uncompressed_sum = state.msg_sent_uncompressed + uncompressed_size
        compressed_sum = state.msg_sent_compressed + compressed_size

        %Goldie.Player { state | 
          :last_server_hmac => hmac,
          :msg_sent_uncompressed => uncompressed_sum,  
          :msg_sent_compressed => compressed_sum, 
          :last_msg_id =>  {0, 0, nil}
        }
      _ ->
        exit({:error, {:failed_encode, message}})
    end
  end

  defp do_send(transport, socket, _) when is_nil(transport) or is_nil(socket) do
    #For testing purposes
    :ok
  end
  defp do_send(transport, socket, packet) do
    transport.send(socket, packet)
  end

  ## compresses using deflate
  @spec compress(binary) :: binary
  defp compress(data) do
    case byte_size(data) > @compress_threshold_bytes do
      true ->
        compressed = :zlib.zip(data)
        << <<1>> :: binary, compressed :: binary>>
      _ ->
        << <<0>> :: binary, data :: binary>>
    end
  end

  ## xor cipher the data with the key
  @spec xor_cipher(binary, binary) :: binary()
  def xor_cipher(xdata, key) do
    key_size = byte_size(key)
    sequence = 0..byte_size(xdata) - 1
    Enum.map(sequence, fn(index) -> 
    item = :binary.at(xdata, index)
    key_index = rem(index, key_size)
    key_item = :binary.at(key, key_index)
    item ^^^ key_item
    end) 
  end
end
