import sys

from . import armbian_utils as armbian_utils

ASSET_LOG_BASE = armbian_utils.get_from_env("ASSET_LOG_BASE")


def write_md_asset_log(file: str, contents: str):
	"""Log a message to the asset log file."""
	if ASSET_LOG_BASE is None:
		print(f"ASSET_LOG_BASE not defined; here's the contents:\n{contents}", file=sys.stderr)
		return
	target_file = ASSET_LOG_BASE + file
	with open(target_file, "w") as asset_log:
		asset_log.write(contents)
	print(f"- Wrote to {target_file}.\n", file=sys.stderr)


class SummarizedMarkdownWriter:
	def __init__(self, file_name, title):
		self.file_name = file_name
		self.title = title
		self.summary: list[str] = []
		self.contents = ""

	def __enter__(self):
		return self

	def __exit__(self, *args):
		write_md_asset_log(self.file_name, self.get_summarized_markdown())

	def add_summary(self, summary):
		self.summary.append(summary)

	def write(self, text):
		self.contents += text

	# see https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/organizing-information-with-collapsed-sections
	def get_summarized_markdown(self):
		if len(self.title) == 0:
			raise Exception("Markdown Summary Title not set")
		if len(self.summary) == 0:
			raise Exception("Markdown Summary not set")
		if self.contents == "":
			raise Exception("Markdown Contents not set")
		return f"<details><summary>{self.title}: {'; '.join(self.summary)}</summary>\n<p>\n\n{self.contents}\n\n</p></details>\n"
