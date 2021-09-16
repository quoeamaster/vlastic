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

import encoding.base64
import net.http
import os
import strings
import x.json2

const (
	header_auth_basic_scheme = "Basic"
)

// prepare_request - prepare a http request based on values coming from the [Config] as well as the http [method] and targeted [path].
fn prepare_request(cfg Config, method http.Method, path string) http.Request {
	mut r := http.Request{
		method: method
	}
	// create the final path 
	r.url = "${append_slash_to_url(cfg.es_host)}${remove_heading_slash(path)}"

	// prepare the header for auth
	if cfg.es_username != "" && cfg.es_password != "" {
		// ref: https://en.wikipedia.org/wiki/Basic_access_authentication
		// convert the user:pwd into base64 format
		mut secret := "${cfg.es_username}:${cfg.es_password}"
		secret = base64.encode_str(secret)
		// set the header
		r.add_header(http.CommonHeader.authorization, "${header_auth_basic_scheme} $secret")
	}
	r.add_header(http.CommonHeader.content_type, "application/json")

	return r
}
// append_slash_to_url - helper method to return a "/" ended path.
fn append_slash_to_url(path string) string {
	if !path.ends_with("/") {
		return path+"/"
	}
	return path
}
// remove_heading_slash - helper method to remove a heading "/" from the given path.
fn remove_heading_slash(path string) string {
	if path.starts_with("/") {
		return path[1..]
	}
	return path
}

// is_valid_operation - returns true if the response's status_code is a valid one + success (informational, success, or redirection).
fn is_valid_operation(r &http.Response) bool {
	s := r.status()
	return s.is_valid() && s.is_success()
}

fn export_operation(cfg Config) ?bool {
	mut queries := strings.new_builder(1024)
	// need to export settings an mappings?
	if cfg.exports.export_indices_settings_mappings == true {
		export_indices_settings_mappings(cfg) or {
			return err
		}
	}

	return true
}
// export_indices_settings_mappings - export the corresponding indices' settings+mappings to a data file.
fn export_indices_settings_mappings(cfg Config) ?bool {
	mut indices := ""
	for x in cfg.exports.indices {
		if indices.len > 0 {
			indices+=","
		}
		indices+=x
	} // end -- for (exports.indices)
	// GET http://xxx.com:9200/{index_name},{index_name_2}
	req := prepare_request(cfg, http.Method.get, indices)
	res := req.do() or {
		return error("[export_operation] failed to run the request - ${req.url}, ${err}")
	}
	if !is_valid_operation(&res) {
		return error("[export_operation] not a valid response, ${res.bytestr()}")
	}
	// parse the results
	raw := json2.raw_decode(res.text) or {
		return error("[export_operation] failed to decode the response, reason: $err")
	}
	m := raw.as_map()

	// create the settings_mappings file
	for k, value in m {
		file_name := "${append_slash_to_url(cfg.exports.target_folder)}${k}-settings-mappings.data"
		//v := m[k] or { json2.Any(0) }
		content := value.as_map().str()
		os.write_file(file_name, content) or {
			return error("[export_operation] failed to write to file [$file_name], reason: $err")
		}
	}
	return true
}