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

import net.http as h
import os

// test_prepare_request - test on creation of http request plus validation checks on header(s).
fn test_prepare_request() {
	println("## connect_test.test_prepare_request ##\n")

	// set env
	os.setenv(env_password, "p@ssw0rd", true)
	defer {
		os.unsetenv(env_password)
	}

	// load a config
	c := parse_config("./testdata/test_config_01.json") or {
		panic("a. failed to parse a config [test_config_01.json], reason: $err")
	}
	r := prepare_request(c, h.Method.get, "/")
	assert r.url == "http://localhost:9200/"
	assert r.header.contains(h.CommonHeader.content_type) == true
	assert r.header.contains(h.CommonHeader.authorization) == true
	assert r.header.contains(h.CommonHeader.accept_post) == false
	assert r.header.contains(h.CommonHeader.cross_origin_opener_policy) == false
	assert r.method == h.Method.get
}

// test_export_00_settings_mappings_no_meta_included - test on export operations; included exporting settings+mappings.
fn test_export_00_settings_mappings_no_meta_included() {
	println("## connect_test.test_export_00_settings_mappings_no_meta_included ##\n")

	// house keep
	//delete_file("./testdata/data/aflo_flow_config_*,apache_demo_backup.data")
	delete_file("./testdata/data/aflo_flow_config_*,kibana_sample_data_flights.data")

	// load config
	c := parse_config("./testdata/test_config_cloud_00.json") or {
		i := err.msg.index("failed to open file") or {
			panic("1a. unexpected error in reading config, $err")
		}
		if i == -1 {
			panic("1b. unexpected error in reading config, $err")
		}
		// stop as the config file is not available
		println("[test_export_00_only_settings_mappings] please provide a valid test file named test_config_cloud_00.json for testing")
		return
	}
	// run export
	export_operation(c) or {
		panic("2a. failed on export, $err")
	}
}

fn delete_file(path string) {
	os.rm(path) or {
		panic("[delete_file] failed to remove file, reason: $err")
	}
}