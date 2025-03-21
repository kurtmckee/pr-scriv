# Makefile for scriv
#
# To release:
#   - increment the version in src/scriv/__init__.py
#   - scriv collect
#   - commit changes
#   - make check_release
#   - make release

.PHONY: clean sterile coverage docs help \
	quality requirements test test-all upgrade validate

.DEFAULT_GOAL := help

# For opening files in a browser. Use like: $(BROWSER)relative/path/to/file.html
BROWSER := python -m webbrowser file://$(CURDIR)/

# This runs a Python command for every make invocation, but it's fast enough.
# Is there a way to do it only when needed?
VERSION := $(shell python -c "from setuptools import setup; setup()" --version)
export VERSION

help: ## display this help message
	@echo "Please use \`make <target>' where <target> is one of"
	@awk -F ':.*?## ' '/^[a-zA-Z]/ && NF==2 {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

clean: ## remove generated byte code, coverage reports, and build artifacts
	find . -name '__pycache__' -exec rm -rf {} +
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	-coverage erase
	rm -fr coverage.json
	rm -fr build/
	rm -fr dist/
	rm -fr *.egg-info
	rm -fr htmlcov/
	rm -fr .*_cache/
	cd docs; make clean

sterile: clean ## remove absolutely all built artifacts
	rm -fr .tox

coverage: clean ## generate and view HTML coverage report
	tox -e py39,py313,coverage
	$(BROWSER)htmlcov/index.html

docs: botedits ## generate Sphinx HTML documentation, including API docs
	tox -e docs
	$(BROWSER)docs/_build/html/index.html

PIP_COMPILE = pip-compile --upgrade --resolver=backtracking --no-strip-extras
upgrade: export CUSTOM_COMPILE_COMMAND=make upgrade
upgrade: ## update the requirements/*.txt files with the latest packages satisfying requirements/*.in
	pip install -qr requirements/pip-tools.txt
	# Make sure to compile files after any other files they include!
	$(PIP_COMPILE) -o requirements/pip-tools.txt requirements/pip-tools.in
	$(PIP_COMPILE) -o requirements/base.txt requirements/base.in
	$(PIP_COMPILE) -o requirements/test.txt requirements/test.in
	$(PIP_COMPILE) -o requirements/doc.txt requirements/doc.in
	$(PIP_COMPILE) -o requirements/quality.txt requirements/quality.in
	$(PIP_COMPILE) -o requirements/tox.txt requirements/tox.in
	$(PIP_COMPILE) -o requirements/dev.txt requirements/dev.in

diff_upgrade: ## summarize the last `make upgrade`
	@# The sort flags sort by the package name first, then by the -/+, and
	@# sort by version numbers, so we get a summary with lines like this:
	@#	-bashlex==0.16
	@#	+bashlex==0.17
	@#	-build==0.9.0
	@#	+build==0.10.0
	@git diff -U0 | grep -v '^@' | grep == | sort -k1.2,1.99 -k1.1,1.1r -u -V

botedits: ## make source edits by tools
	python -m black --line-length=80 src/scriv tests docs
	python -m cogapp -crP docs/*.rst

quality: ## check coding style with pycodestyle and pylint
	tox -e quality

requirements: ## install development environment requirements
	pip install -qr requirements/pip-tools.txt
	pip-sync requirements/dev.txt

test: ## run tests in the current virtualenv
	tox -e py39

test-all: ## run tests on every supported Python combination
	tox

validate: clean botedits quality test ## run tests and quality checks

.PHONY: dist pypi testpypi tag gh_release

dist: ## Build the distributions
	python -m build --sdist --wheel

pypi: ## Upload the built distributions to PyPI.
	python -m twine upload --verbose dist/*

testpypi: ## Upload the distrubutions to PyPI's testing server.
	python -m twine upload --verbose --repository testpypi dist/*

tag: ## Make a git tag with the version number
	git tag -s -m "Version $$VERSION" $$VERSION
	git push --all

gh_release: ## Make a GitHub release
	python -m scriv github-release --all --fail-if-warn --check-links

comment_text:
	@echo "Use this to comment on issues and pull requests:"
	@echo "This is now released as part of [scriv $$VERSION](https://pypi.org/project/scriv/$$VERSION)."

.PHONY: release check_release _check_credentials _check_manifest _check_version _check_scriv

release: _check_credentials clean check_release dist pypi tag gh_release comment_text ## do all the steps for a release

check_release: _check_manifest _check_tree _check_version _check_scriv _check_links ## check that we are ready for a release
	@echo "Release checks passed"

_check_credentials:
	@if [[ -z "$$TWINE_PASSWORD" ]]; then \
		echo 'Missing TWINE_PASSWORD: opvars'; \
		exit 1; \
	fi

_check_manifest:
	python -m check_manifest

_check_tree:
	@if [[ -n $$(git status --porcelain) ]]; then \
		echo 'There are modified files! Did you forget to check them in?'; \
		exit 1; \
	fi

_check_version:
	@if [[ $$(git tags | grep -q -w $$VERSION && echo "x") == "x" ]]; then \
		echo 'A git tag for this version exists! Did you forget to bump the version in src/scriv/__init__.py?'; \
		exit 1; \
	fi

_check_scriv:
	@if [[ $$(find -E changelog.d -regex '.*\.(md|rst)$$') ]]; then \
		echo 'There are scriv fragments! Did you forget `scriv collect`?'; \
		exit 1; \
	fi

_check_links:
	python -m scriv github-release --dry-run --fail-if-warn --check-links
