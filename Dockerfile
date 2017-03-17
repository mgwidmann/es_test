FROM ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -y wget
RUN wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb && dpkg -i erlang-solutions_1.0_all.deb
RUN apt-get update
RUN apt-get install -y erlang-dev
RUN apt-get install -y esl-erlang
RUN apt-get install -y erlang-inets
RUN apt-get install -y erlang-ssl
RUN apt-get install -y erlang-asn1
RUN apt-get install -y erlang-public-key
RUN apt-get install -y erlang-parsetools

RUN mkdir -p /app

COPY blowup /app/
WORKDIR /app
