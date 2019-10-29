#!/usr/local/bin/elixir


# Usage:
#   Set the slack url in the config below
#   Check if counts below are correct
#   Set reboot to true if you want it to auto reboot
#   run ./monitor.exs

defmodule Config do
  def lighthouse_count, do: 1
  def partner_count, do: 1
  def interpreter_count, do: 1
  def reboot, do: true
  def frequency, do: 15
  def slack_url, do: "https://hooks.slack.com/services/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"
end

defmodule Speech do
  def say(message) do
    speak(message)
    slack(message)
  end

  def slack(message) do
    body = 
      ~s(payload={"text": "#{message}" })

    case Config.slack_url do
      "" -> :noop
      url when is_binary(url) ->
        System.cmd("curl", ["-s", "-X", "POST", "--data-urlencode", body, url])
      _ -> :noop
    end
  end

  defp speak(message) do
    System.cmd("say", ["-v", "fiona", "-r", "220", message])
    IO.puts(message)
  end
end

defmodule Describe do
  @name_match ~r/^Name:\s+(?<name>.*)/
  @section_match ~r/^(?<key>.*):\s+(?<value>.*)/
  @continuation_match ~r/^\s+(?<value>.*)/

  def parse(string) when is_binary(string) do
    string
    |> String.split("\n")
    |> parse()
  end

  def parse(list) when is_list(list) do
    parse(list, %{})
  end

  defp parse_value(string) do
    String.split(string, ",")
  end

  defp parse([], acc), do: acc

  defp parse([h|t], acc) do
    case h do
      "" -> parse(t, acc)
      _ ->
        case Regex.named_captures(@name_match, h) do
          %{"name" => name} -> parse_section(t, name, Map.put(acc, name, %{}))
          _ -> parse(t, acc)
        end
    end
  end

  defp parse_section([], _name, acc), do: acc

  defp parse_section([h|t], name, acc) do
    case h do
      "" -> parse(t, acc)
      _ ->
        case Regex.named_captures(@section_match, h) do
          %{"key" => key, "value" => value} ->
            previous_val =
              acc
              |> Map.get(name)
              |> Map.get(key, [])

            updated =
              acc
              |> Map.get(name)
              |> Map.put(key, previous_val ++ parse_value(value))
            
            parse_continuation(t, name, key, Map.put(acc, name, updated))
          _ ->
            parse_section(t, name, acc)
        end
    end
  end

  defp parse_continuation([], _name, _key, acc), do: acc

  defp parse_continuation([h|t], name, key, acc) do
    case h do
      "" -> parse(t, acc)
      _ ->
        case Regex.named_captures(@continuation_match, h) do
          %{"value" => value} ->
            updated_value =
              acc
              |> Map.get(name)
              |> Map.get(key)
              |> Kernel.++(parse_value(value))

            updated =
              acc
              |> Map.get(name)
              |> Map.put(key, updated_value)

            parse_continuation(t, name, key, Map.put(acc, name, updated))
          _ ->
            parse_section([h|t], name, acc)
        end
    end
  end
end

defmodule Alert do
  @none ~r/none/
  @stack_name "master"
  @stack_suffix ""

  def check({app = @stack_name <> "-partner-server" <> @stack_suffix, endpoints}) do
    {check(endpoints, Config.partner_count), app}
  end

  def check({app = @stack_name <> "-lighthouse-server" <> @stack_suffix, endpoints}) do
    {check(endpoints, Config.lighthouse_count), app}
  end

  def check({app = @stack_name <> "-interpreter-server", endpoints}) do
    {check(endpoints, Config.interpreter_count), app}
  end

  def check(endpoints, desired_count) do
    if Enum.any?(endpoints, fn endpoint -> Regex.match?(@none, endpoint) end) do
      :critical
    else
      if length(endpoints) < desired_count do
        :danger
      else
        :ok
      end
    end
  end

  def notify(alert = {:ok, _}) do
    alert
  end

  def notify(alert = {:danger, app}) do
    beep()
    Speech.say(app <> " is in danger")

    alert
  end

  def notify(alert = {:critical, app}) do
    beep()
    beep()
    Speech.say(app <> " is critical")
    beep()
    beep()

    alert
  end

  defp beep() do
    System.cmd("afplay", ["/System/Library/Sounds/Ping.aiff"])
  end
end 

defmodule Pod do
  require Logger
  @stack_name "master"
  @stack_suffix ""

  def reboot(alert = {:ok, _}) do
    alert
  end

  def reboot(alert = {:danger, _}) do
    alert
  end

  def reboot(alert = {:critical, app}) do
    if Config.reboot do
      reboot(app)
    end

    alert
  end

  def reboot(app = @stack_name <> "-lighthouse-server" <> @stack_suffix) do
    beep()
    Speech.say("Rebooting " <> app)
    {response, _} = System.cmd("kubectl", ["delete", "po", "-l", "app=lighthouse-server-web,release=vineya-green"])
    response
    |> String.split()
    |> debug()
  end

  def reboot(app = @stack_name <> "-partner-server" <> @stack_suffix) do
    beep()
    Speech.say("Rebooting " <> app)
    {response, _} = System.cmd("kubectl", ["delete", "po", "-l", "app=partner-server-web,release=vineya-green"])
    response
    |> String.split()
    |> debug()
  end

  def reboot(app = @stack_name <> "-interpreter-server") do
    beep()
    Speech.say("Rebooting " <> app)
    {response, _} = System.cmd("kubectl", ["delete", "po", "-l", "app=interpreter-server,release=vineya-green"])
    response
    |> String.split()
    |> debug()
  end

  defp beep() do
    System.cmd("afplay", ["/System/Library/Sounds/Ping.aiff"])
  end

  def debug(any) do
    Logger.debug(fn ->
      inspect(any, pretty: true)
    end)

    any
  end
end

defmodule Monitor do
  require Logger

  @sample_output ~S"""
    Name:                     vineya-green-lighthouse-server-web
    Namespace:                default
    Labels:                   app=lighthouse-server-web
                              chart=lighthouse-server-0.1.0
                              heritage=Tiller
                              release=vineya-green
    Annotations:              <none>
    Selector:                 app=lighthouse-server-web,release=vineya-green
    Type:                     NodePort
    IP:                       100.71.150.167
    Port:                     http  8080/TCP
    TargetPort:               http/TCP
    NodePort:                 http  32171/TCP
    Endpoints:                100.104.0.5:8080
    Session Affinity:         None
    External Traffic Policy:  Cluster
    Events:                   <none>


    Name:                     vineya-green-partner-server-web
    Namespace:                default
    Labels:                   app=partner-server-web
                              chart=partner-server-0.1.0
                              heritage=Tiller
                              release=vineya-green
    Annotations:              <none>
    Selector:                 app=partner-server-web,release=vineya-green
    Type:                     NodePort
    IP:                       100.68.208.45
    Port:                     http  8080/TCP
    TargetPort:               http/TCP
    NodePort:                 http  31611/TCP
    Endpoints:                100.112.0.6:8080
    Session Affinity:         None
    External Traffic Policy:  Cluster
    Events:                   <none>


    Name:                     vineya-green-interpreter-server
    Namespace:                default
    Labels:                   app=interpreter-server
                              chart=interpreter-server-0.1.0
                              heritage=Tiller
                              release=vineya-green
    Annotations:              <none>
    Selector:                 app=interpreter-server,release=vineya-green
    Type:                     NodePort
    IP:                       100.69.3.180
    Port:                     http  8080/TCP
    TargetPort:               http/TCP
    NodePort:                 http  32030/TCP
    Endpoints:                100.114.0.8:8080
    Port:                     http-job-web  9000/TCP
    TargetPort:               http-job-web/TCP
    NodePort:                 http-job-web  32124/TCP
    Endpoints:                100.114.0.8:9000
    Session Affinity:         None
    External Traffic Policy:  Cluster
    Events:                   <none>

    """

  @stack_name "master"
  @stack_suffix ""

  def monitor do
    {output, 0} = System.cmd("kubectl", ["describe", "svc", @stack_name <> "-lighthouse-server" <> @stack_suffix, @stack_name <> "-partner-server" <> @stack_suffix, @stack_name <> "-interpreter-server"])

    output
      |> Describe.parse()
      |> Enum.map(fn {k, v} -> {k, Map.get(v, "Endpoints")} end)
      |> debug()
      |> Enum.map(&Alert.check/1)
      |> Enum.map(&Alert.notify/1)
      |> Enum.map(&Pod.reboot/1)

    :timer.sleep(1000 * Config.frequency)

    monitor()
  end

  def debug(any) do
    Logger.debug(fn ->
      inspect(any, pretty: true)
    end)

    any
  end
end

Speech.slack("Oopsie Bot Starting")

Monitor.monitor
