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

import json
import x.json2

type Json_types = i8|int|string|bool|f32

// test_read_data_file - test on parsing an exported data file.
fn test_read_data_file() {
	println("## file_ops_test.test_read_data_file ##\n")

	batch := read_data_file("./testdata/data_file_01.data") or {
		panic("error in reading the data file, $err")
	}
	assert batch.lines.len == 30
	println("* 1st line of data read => ${batch.lines[0]}")

	// is it possible to parse the json into... a map[string]int???
	m := json.decode(map[string]int, batch.lines[0]) or {
		panic("failed to convert string data into map[string]int")
	}
	assert m['io_loadings'] == 19000

	// what about Sum-Typed or voidptr? Not work...
	// in general, would suggest to map with a struct which matches the json's fields.
	decode_data_line_01(batch.lines[0])
}

// decode_data_line_01 - testing on x.json2 parsing on non-predefined-json data structures.
fn decode_data_line_01(line string) {
	raw := json2.raw_decode(line) or {
		panic("[decode_data_line_01] raw_decode error, $err")
	}
	m := raw.as_map()
	
	mut v := m['id'] or { json2.Any(0) }
	assert v.int() == 1
	
	v = m["cpu_cores"] or { json2.Any(0) }
	assert v.int() == 1

	v = m["io_loadings"] or { json2.Any(0) }
	assert v.int() == 19000
	assert v.str() == "19000"
}