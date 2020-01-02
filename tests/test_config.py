"""Tests of scriv/config.py"""

from scriv.config import read_config

CONFIG1 = """\
[scriv]
output_file = README.md
categories = New, Different, Gone, Bad
"""

CONFIG2 = """\
[someotherthing]
no_idea = what this is

[tool.scriv]
output_file = README.md
categories =
    New
    Different
    Gone
    Bad

[more stuff]
value = 17
"""


def test_defaults(temp_dir):  # pylint: disable=unused-argument
    config = read_config()
    assert config.entry_directory == "changelog.d"
    assert config.format == "rst"
    assert config.output_file == "CHANGELOG.rst"
    assert config.insert_marker == "scriv:insert-here"


def test_reading_config(temp_dir):
    (temp_dir / ".scrivrc").write_text(CONFIG1)
    config = read_config()
    assert config.entry_directory == "changelog.d"
    assert config.output_file == "README.md"
    assert config.categories == ["New", "Different", "Gone", "Bad"]


def test_reading_config_list(temp_dir):
    (temp_dir / "tox.ini").write_text(CONFIG2)
    config = read_config()
    assert config.categories == ["New", "Different", "Gone", "Bad"]
