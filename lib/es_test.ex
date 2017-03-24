defmodule ESTest.CLI do

  @switches [host: :string, dry_run: :boolean, repeat: :integer]
  def main(args) do
    {options, _, _} = OptionParser.parse(args, switches: @switches)
    Application.ensure_all_started(:hackney)
    :ok = :hackney_pool.start_pool(__MODULE__, max_connections: 1000)
    Enum.map(1..(options[:repeat] || 1), fn _ ->
      options[:host]
      |> run(options[:dry_run])
    end)
    |> List.flatten()
    |> Enum.map(&Task.await(&1, :infinity))
    |> analyze()
    |> report()
  end

  @project Mix.Project.get!().project[:escript][:name]
  def run(nil), do: raise """
  Please provide a host to hit. Usage:
      #{@project} --host dev.weddingwire.com
  """

  @categories ~w(band beauty catering venue ceremonymusic dj dress entertainer rental favor florist invitation jewelry eventproduction officiant partysupplies photography rehearsaldinner transportation travel other videography cake planner)
  @letters ?a..?z
  @partner_key "163r5mm3"
  def run(host, dry_run) do
    for category <- @categories, letter <- @letters, letter2 <- @letters do
      Task.async(__MODULE__, :search, [host, dry_run, category, <<letter, letter2>>])
    end
  end

  def search(host, dry_run, category, letter) do
    url = "https://#{host}/apis/v5/public/#{@partner_key}/vendors/search?category_name=#{category}&vendor_name=#{letter}"
    IO.puts ["Running against ", IO.ANSI.cyan, url, IO.ANSI.default_color]
    :timer.tc fn ->
      if dry_run do
        Process.sleep(1_000)
        %HTTPoison.Response{status_code: 200, headers: [{"X-Runtime", "1.0"}]}
      else
        HTTPoison.get!(url, [], hackney: [:insecure, {:pool, __MODULE__}], connect_timeout: :infinity, recv_timeout: :infinity, timeout: :infinity, ssl: [{:versions, [:'tlsv1.2']}])
      end
    end
  end

  def analyze(list) when is_list(list) do
    IO.puts ["Analyzing results..."]
    Enum.reduce(list, {0.0, 0.0, 0, 0}, &analyze/2)
  end

  def analyze({actual_time_micro, %HTTPoison.Response{status_code: 200, body: body, headers: headers}}, state) do
    IO.inspect body
    headers
    |> Enum.find(&match?({"X-Runtime", _}, &1))
    |> analyze(actual_time_micro / 1_000_000, state)
  end
  def analyze({"X-Runtime", runtime_string}, actual_time, {average, actual_average, count, failed}) do
    runtime = String.to_float(runtime_string)
    count = count + 1
    avg_diff = (runtime - average) / count
    actual_avg_diff = (actual_time - actual_average) / count
    {avg_diff + average, actual_avg_diff + actual_average, count, failed}
  end
  def analyze(_, _, {average, actual_average, count, failed}) do
    {average, actual_average, count, failed + 1}
  end

  def report(list) when is_list(list) do
    list
    |> Enum.reduce(fn {avg, act_avg, req, failed}, {avg_acc, act_avg_acc, req_acc, failed_acc} ->
      count = req + req_acc
      avg = (avg - avg_acc) / count
      act_avg = (act_avg - act_avg_acc) / count
      {avg, act_avg, count, failed + failed_acc}
    end)
    |> report()
  end
  def report({average, actual_average, requests, failed}) do
    IO.puts ["Total of ",
              IO.ANSI.cyan, inspect(requests), IO.ANSI.default_color,
              " requests (with ",
              IO.ANSI.cyan, inspect(failed), IO.ANSI.default_color,
              " failed) averaging ",
              IO.ANSI.cyan, inspect(average), IO.ANSI.default_color,
              " seconds (actual elapsed average ",
              IO.ANSI.cyan, inspect(actual_average), IO.ANSI.default_color,
              " seconds)"]
  end
end
