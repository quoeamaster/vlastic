// GNU Affero General Public License V.3.0 or AGPL-3.0
//
// vlastic - an Elasticsearch data importer and exporter written in V.
// Copyright (C) 2021 - quoeamaster@gmail.com
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

module main

import os

// test_parse_config - test on load and parse of config file(s)
fn test_parse_config() {
	println("## config_test.test_parse_config ##\n")

	// set env var
	os.setenv(env_username, "root", true)
	os.setenv(env_password, "password", true)
	defer {
		// unset env var
		os.unsetenv(env_username)
		os.unsetenv(env_password)
	}
	
	cfg := parse_config("./testdata/test_config_01.json") or {
		panic("1. error in parsing the config, $err")
	}
	println(cfg)

	// assertions
	assert cfg.es_username == "RooT"
	assert cfg.es_password == "password"
	assert cfg.imports.source_folder == "/user/exporter/data/"
}

// test_parse_config_on_missing_config_file - should throw error containing a message "failed to open file".
fn test_parse_config_on_missing_config_file() {
	println("## config_test.test_parse_config_on_missing_config_file ##\n")

	cfg := parse_config("./unavailable_file.json") or {
		i := err.msg.index("failed to open file") or {
			panic("1. error in loading a missing config file, $err")
		}
		if i == -1 {
			panic("1. error in loading a missing config file, $err")
		}
		Config{}
	}
}