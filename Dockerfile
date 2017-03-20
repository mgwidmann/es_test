FROM ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive
# Set locale correctly so elixir doesn't complain
ENV LANG C.UTF-8

# Run update to make wget available
RUN apt-get update
RUN apt-get install -y wget

# Add Erlang Solutions deb packages & update
RUN wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && dpkg -i erlang-solutions_1.0_all.deb
RUN apt-get update

# Install necessary Erlang packages
RUN apt-get install -y erlang-dev
RUN apt-get install -y esl-erlang
RUN apt-get install -y erlang-inets erlang-ssl erlang-asn1 erlang-public-key erlang-parsetools

# Install elixir
RUN apt-get install -y elixir
RUN mix local.hex --force
RUN mix local.rebar --force

ENV MIX_ENV=prod

RUN mkdir -p /app

COPY . /app/
WORKDIR /app

# Produce executable
RUN mix escript.build
