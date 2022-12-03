import os
import sys


def parse_env_for_tokens(env_name):
	result = []
	# Read the environment; if None, return an empty list.
	val = os.environ.get(env_name, None)
	if val is None:
		return result
	# tokenize val; split by whitespace, line breaks, commas, and semicolons.
	# trim whitespace from tokens.
	return [token for token in [token.strip() for token in (val.split())] if token != ""]


def get_from_env(env_name):
	value = os.environ.get(env_name, None)
	if value is not None:
		value = value.strip()
	return value


def get_from_env_or_bomb(env_name):
	value = get_from_env(env_name)
	if value is None:
		raise Exception(f"{env_name} environment var not set")
	if value == "":
		raise Exception(f"{env_name} environment var is empty")
	return value


def yes_or_no_or_bomb(value):
	if value == "yes":
		return True
	if value == "no":
		return False
	raise Exception(f"Expected yes or no, got {value}")


def show_incoming_environment():
	print("--ENV-- Environment:", file=sys.stderr)
	for key in os.environ:
		print(f"--ENV-- {key}={os.environ[key]}", file=sys.stderr)
