#!/usr/bin/env bats

# shellcheck disable=SC2230

load ../node_modules/bats-support/load.bash
load ../node_modules/bats-assert/load.bash
load ./lib/test_utils

# TODO: check tests below you really adopt

setup_file() {
	PROJECT_DIR="$(realpath "$(dirname "$BATS_TEST_DIRNAME")")"
	export PROJECT_DIR
	cd "$PROJECT_DIR"
	clear_lock git

	ASDF_DIR="$(mktemp -t asdf-openssl2-integration-tests.XXXX -d)"
	export ASDF_DIR

	get_lock git
	git clone \
		--branch=v0.10.2 \
		--depth=1 \
		https://github.com/asdf-vm/asdf.git \
		"$ASDF_DIR"
	clear_lock git
}

teardown_file() {
	clear_lock git
	rm -rf "$ASDF_DIR"
}

setup() {
	ASDF_OPENSSL2_TEST_TEMP="$(mktemp -t asdf-openssl2-integration-tests.XXXX -d)"
	export ASDF_OPENSSL2_TEST_TEMP
	ASDF_DATA_DIR="${ASDF_OPENSSL2_TEST_TEMP}/asdf"
	export ASDF_DATA_DIR
	mkdir -p "$ASDF_DATA_DIR/plugins"

	# `asdf plugin add asdf-openssl2 .` would only install from git HEAD.
	# So, we install by copying the plugin to the plugins directory.
	cp -R "$PROJECT_DIR" "${ASDF_DATA_DIR}/plugins/asdf-openssl2"
	cd "${ASDF_DATA_DIR}/plugins/asdf-openssl2"

	# shellcheck disable=SC1090,SC1091
	source "${ASDF_DIR}/asdf.sh"

	ASDF_OPENSSL2_VERSION_INSTALL_PATH="${ASDF_DATA_DIR}/installs/asdf-openssl2/ref-version-1-6"
	export ASDF_OPENSSL2_VERSION_INSTALL_PATH

	# optimization if already installed
	info "asdf install asdf-openssl2 ref:version-1-6"
	if [ -d "${HOME}/.asdf/installs/asdf-openssl2/ref-version-1-6" ]; then
		mkdir -p "${ASDF_DATA_DIR}/installs/asdf-openssl2"
		cp -R "${HOME}/.asdf/installs/asdf-openssl2/ref-version-1-6" "${ASDF_OPENSSL2_VERSION_INSTALL_PATH}"
		rm -rf "${ASDF_OPENSSL2_VERSION_INSTALL_PATH}/asdf-openssl2"
		asdf reshim
	else
		get_lock git
		asdf install asdf-openssl2 ref:version-1-6
		clear_lock git
	fi
	asdf local asdf-openssl2 ref:version-1-6
}

teardown() {
	asdf plugin remove asdf-openssl2 || true
	rm -rf "${ASDF_OPENSSL2_TEST_TEMP}"
}

info() {
	echo "# ${*} …" >&3
}

@test "asdf-openssl2_configuration__without_asdf-openssl2deps" {
	# Assert package index is placed in the correct location
	info "asdf-openssl2 refresh -y"
	get_lock git
	asdf-openssl2 refresh -y
	clear_lock git
	assert [ -f "${ASDF_OPENSSL2_VERSION_INSTALL_PATH}/asdf-openssl2/packages_official.json" ]

	# Assert package installs to correct location
	info "asdf-openssl2 install -y asdf-openssl2json@1.2.8"
	get_lock git
	asdf-openssl2 install -y asdf-openssl2json@1.2.8
	clear_lock git
	assert [ -x "${ASDF_OPENSSL2_VERSION_INSTALL_PATH}/asdf-openssl2/bin/asdf-openssl2json" ]
	assert [ -f "${ASDF_OPENSSL2_VERSION_INSTALL_PATH}/asdf-openssl2/pkgs/asdf-openssl2json-1.2.8/asdf-openssl2json.asdf-openssl2" ]
	assert [ ! -x "./asdf-openssl2deps/bin/asdf-openssl2json" ]
	assert [ ! -f "./asdf-openssl2deps/pkgs/asdf-openssl2json-1.2.8/asdf-openssl2json.asdf-openssl2" ]

	# Assert that shim was created for package binary
	assert [ -f "${ASDF_DATA_DIR}/shims/asdf-openssl2json" ]

	# Assert that correct asdf-openssl2json is used
	assert [ -n "$(asdf-openssl2json -v | grep ' version 1\.2\.8')" ]

	# Assert that asdf-openssl2 finds asdf-openssl2 packages
	echo "import asdf-openssl2json" >"${ASDF_OPENSSL2_TEST_TEMP}/testasdf-openssl2.asdf-openssl2"
	info "asdf-openssl2 c -r \"${ASDF_OPENSSL2_TEST_TEMP}/testasdf-openssl2.asdf-openssl2\""
	asdf-openssl2 c -r "${ASDF_OPENSSL2_TEST_TEMP}/testasdf-openssl2.asdf-openssl2"
}

@test "asdf-openssl2_configuration__with_asdf-openssl2deps" {
	rm -rf asdf-openssl2deps
	mkdir "./asdf-openssl2deps"

	# Assert package index is placed in the correct location
	info "asdf-openssl2 refresh"
	get_lock git
	asdf-openssl2 refresh -y
	clear_lock git
	assert [ -f "./asdf-openssl2deps/packages_official.json" ]

	# Assert package installs to correct location
	info "asdf-openssl2 install -y asdf-openssl2json@1.2.8"
	get_lock git
	asdf-openssl2 install -y asdf-openssl2json@1.2.8
	clear_lock git
	assert [ -x "./asdf-openssl2deps/bin/asdf-openssl2json" ]
	assert [ -f "./asdf-openssl2deps/pkgs/asdf-openssl2json-1.2.8/asdf-openssl2json.asdf-openssl2" ]
	assert [ ! -x "${ASDF_OPENSSL2_VERSION_INSTALL_PATH}/asdf-openssl2/bin/asdf-openssl2json" ]
	assert [ ! -f "${ASDF_OPENSSL2_VERSION_INSTALL_PATH}/asdf-openssl2/pkgs/asdf-openssl2json-1.2.8/asdf-openssl2json.asdf-openssl2" ]

	# Assert that asdf-openssl2 finds asdf-openssl2 packages
	echo "import asdf-openssl2json" >"${ASDF_OPENSSL2_TEST_TEMP}/testasdf-openssl2.asdf-openssl2"
	info "asdf-openssl2 c --asdf-openssl2Path:./asdf-openssl2deps/pkgs -r \"${ASDF_OPENSSL2_TEST_TEMP}/testasdf-openssl2.asdf-openssl2\""
	asdf-openssl2 c --asdf-openssl2Path:./asdf-openssl2deps/pkgs -r "${ASDF_OPENSSL2_TEST_TEMP}/testasdf-openssl2.asdf-openssl2"

	rm -rf asdf-openssl2deps
}
