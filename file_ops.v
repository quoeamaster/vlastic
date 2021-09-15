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

struct File_batch_data {
mut:
	// lines - actual data read from the target file. Each line should correspond to separate valid document.
	lines []string
}

// read_data_file - read a data file at [file] location.
fn read_data_file(file string) ?File_batch_data {
	mut data := File_batch_data{
		lines: []string{}
	}
	mut f := os.open(file) or {
		return error("[read_data_file] failed to open file [$file], reason: $err")
	}
	defer {
		f.close()
	}
	// the buffer for reading data from the [file].
	mut b_content := []byte{len: 2048, cap:2048}
	for {
		i_val := f.read_bytes_into_newline(mut b_content) or {
			println("[b_content] while reading... $err")
			(-1)
		}
		if i_val <= 0 {
			// 0 means no bytes read probably eof
			break
		} 
		data.lines << string(b_content)
	}
	return data
}
