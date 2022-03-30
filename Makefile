.PHONY: help clean requirements

.DEFAULT_GOAL := help

help: ## display this help message
	@echo "Please use \`make <target>' where <target> is one of"
	@awk -F ':.*?## ' '/^[a-zA-Z]/ && NF==2 {printf "\033[36m  %-25s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

clean: ## remove stuff we don't need
	find . -name '__pycache__' -exec rm -rf {} +
	find . -name '*.pyc' -exec rm -f {} +
	find . -name '*.pyo' -exec rm -f {} +
	find . -name '*~' -exec rm -f {} +
	rm -fr build/ dist/ src/*.egg-info
	rm -fr .*_cache/
	rm -f out_*.json save_*.json

requirements: ## install development environment requirements
	pip install -r dev-requirements.txt


.PHONY: test quality black lint check_manifest

test: ## run tests in the current virtualenv
	pytest tests

quality: black lint check_manifest ## run code-checking tools

black:
	black -q src tests

lint:
	pylint src tests

check_manifest:
	python -m check_manifest

.PHONY: dist testpypi pypi tag sample

release: clean check_release dist pypi tag ## do all the steps for a release

check_release: check_manifest
	@if [[ $$(git tags | grep -q -w $$(python setup.py --version) && echo "x") == "x" ]]; then \
		echo 'A git tag for this version exists! Did you forget to bump the version?'; \
		exit 1; \
	fi
	@if (( $$(ls -1 scriv.d | wc -l) != 1 )); then \
		echo 'There are scriv fragments! Did you forget to `scriv collect`?'; \
		exit 1; \
	fi
	@if [[ $$(python setup.py --version) != $$(grep dinghy_version docs/black_digest.html | grep -E -o '[0-9.]+') ]]; then \
		echo 'The sample digest has the wrong version! Did you forget `make sample`?'; \
		exit 1; \
	fi
	@echo "Release checks passed"

dist: ## build the distributions
	python -m build --sdist --wheel
	python -m twine check dist/*

testpypi: ## upload the distributions to PyPI's testing server.
	python -m twine upload --verbose --repository testpypi dist/*

pypi: ## upload the built distributions to PyPI.
	python -m twine upload --verbose dist/*

tag: ## make a git tag with the version number
	git tag -a -m "Version $$(python setup.py --version)" $$(python setup.py --version)

sample: ## make the sample digest
	DINGHY_SAVE_ENTRIES=0 DINGHY_SAVE_RESPONSES=0 DINGHY_SAVE_RESULT=0 python -m dinghy docs/black_dinghy.yaml
	sed -i "" -e '/>Activity/s/ since.*</</' docs/black_digest.html
