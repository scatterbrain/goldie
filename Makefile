CLI_SNAME=cli
BRANCH=master

all: compile

depends:
	@mix do deps.get
	@MIX_ENV=local mix deps.compile --all

compile:
	@MIX_ENV=local mix do compile

clean:
	@mix do clean
	@mix deps.clean --all

test:
	@mix test --cover

plt: 
	@MIX_ENV=local mix dialyzer.plt

dialyzer: 
	@MIX_ENV=local mix dialyzer

dogma: 
	@MIX_ENV=local mix dogma

credo: 
	@MIX_ENV=local mix credo list --strict --ignore readability

run:
	@MIX_ENV=local mix run --no-halt

.PHONY: all depends compile clean run test 
