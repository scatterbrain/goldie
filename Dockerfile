FROM phusion/baseimage:0.9.18
ENV MAKE_NEW=24.2.2016
ENV DEBIAN_FRONTEND noninteractive

RUN echo "Host github.com\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config

RUN sed -i.bak 's/main$/main universe/' /etc/apt/sources.list
RUN apt-get update -q

RUN apt-get install wget -y
RUN wget http://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb
RUN dpkg -i erlang-solutions_1.0_all.deb
RUN wget http://packages.erlang-solutions.com/debian/erlang_solutions.asc
RUN apt-key add erlang_solutions.asc
RUN apt-get update
RUN apt-get install erlang -y
RUN apt-get install elixir=1.2.0-1 -y
RUN apt-get install erlang-ssl erlang-inets -y
RUN apt-get install build-essential -y
RUN apt-get install make -y
RUN apt-get install git-core -y

#Locale 
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install local Elixir hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

ADD mix.exs  /tmp/mix.exs 
ADD mix.lock  /tmp/mix.lock 
ADD Makefile /tmp/Makefile
RUN cd /tmp && \
    mix do deps.get && \
    MIX_ENV=local mix deps.compile --all && \
    MIX_ENV=local mix do compile && \
    MIX_ENV=dev mix deps.compile --all && \
    MIX_ENV=dev mix do compile

#Use the cached dependencies
RUN mkdir -p /opt/app && cp -a /tmp/deps /opt/app/ && cp -a /tmp/_build /opt/app

WORKDIR /opt/app
ADD . /opt/app
RUN MIX_ENV=local mix do compile && MIX_ENV=dev mix do compile 
RUN echo /root > /etc/container_environment/HOME

EXPOSE 6874 

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /etc/service/smalltalk-push
ADD bin/goldie.sh /etc/service/smalltalk-push/run
CMD ["/sbin/my_init", "--quiet"]
