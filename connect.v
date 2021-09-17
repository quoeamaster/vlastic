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
import strconv
import strings
import x.json2

const (
	header_auth_basic_scheme = "Basic"
)

// Parse_es_response - a struct to encapsulate the last_sort_meta if any + is_hits_empty (if the hits.hits is an empty array).
struct Parse_es_response {
mut:	
	last_sort_meta string
	is_hits_empty bool
}

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

// export_operation - export the indices' data.
fn export_operation(cfg Config) ?bool {
	// need to export settings an mappings?
	if cfg.exports.export_indices_settings_mappings == true {
		export_indices_settings_mappings(cfg)?
	}
	// export data
	export_indices_data(cfg)?

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
	// if the response is empty... then no files written and no error should occur
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
fn export_indices_data(cfg Config) ?bool {
	mut indices := ""
	for x in cfg.exports.indices {
		if indices.len > 0 {
			indices+=","
		}
		indices+=x
	}
	// open the data file
	file_name := "${append_slash_to_url(cfg.exports.target_folder)}${indices}.data"
	mut f := os.open_append(file_name) or {
		return error("[export_indices_data] failed to open the file for append, reason: $err")
	}
	defer {
		f.flush()
		f.close()
	}
	// [bug??] due to the parsing... of some problematic data; whenever error occurs, that 100 batch is ignored.
	batch_size := 100
	api := "$indices/_search?size=${batch_size}"
	query_body := '"query": $cfg.exports.filter_query'
	sort_body := '"sort": [{"_doc":"asc"}]'

	mut req := prepare_request(cfg, http.Method.get, api)
	req.data = '{ $query_body, $sort_body }'

	mut res := req.do() or {
		return error("[export_indices_data] failed to run the http request [$req.url], reason: $err")
	}
	if !is_valid_operation(&res) {
		return error("[export_indices_data] not a valid response, reason: ${res.bytestr()}")
	}
	// parsing response
	mut p_res := Parse_es_response{}
	p_res = parse_es_hits_response(mut &f, &res, cfg.exports.export_indices_meta) or {
		println("** 1st . some documents have parsing issues, idx[ $p_res.last_sort_meta ]")
		force_continue_parsing(p_res, batch_size)?
	}
	// loop until no more docs left for iteration
	for p_res.is_hits_empty == false {
		req.data = '{ $query_body, $sort_body, "search_after": ${p_res.last_sort_meta} }'
		//println("[debug] ${req.data}")

		res = req.do() or {
			return error("[export_indices_data] non-first-round > failed to run the http request [$req.url], reason: $err")
		}
		if !is_valid_operation(&res) {
			return error("[export_indices_data] non-first-round > not a valid response, reason: ${res.bytestr()}")
		}
		p_res = parse_es_hits_response(mut &f, &res, cfg.exports.export_indices_meta) or {
			// force continue
			println("** 2nd . some documents have parsing issues, idx[ $p_res.last_sort_meta ]")
			force_continue_parsing(p_res, batch_size)?
		}
		// [debug]
		//println(p_res)
	}
	return true
}
// parse_es_hits_response - parse the hits response provided and write the content to the file.
// If this response is not a hit response, would result an error.
//
// return 
// => string = last_sort_meta 
// => bool = true if hits.hits == empty
fn parse_es_hits_response(mut f &os.File, res &http.Response, include_meta bool) ?Parse_es_response {
	mut p_res := Parse_es_response{}

	raw := json2.raw_decode(res.text) or {
		return error("[parse_es_hits_response] failed to parse the response body, reason: $err")
	}
	mut m := raw.as_map()
	mut hits := m["hits"] or { return error("[parse_es_hits_response] failed to get 'hits' - 1st level") }
	m = hits.as_map()
	hits = m["hits"] or { return error("[parse_es_hits_response] failed to get 'hits.hits' - 2nd level") }
	hits_arr := hits.arr()

	// is it empty hits?
	if hits_arr.len == 0 {
		p_res.last_sort_meta = ""
		p_res.is_hits_empty = true
		return p_res
	}
	mut sb := strings.new_builder(10240)
	last_idx := hits_arr.len-1
	
	for idx, x in hits_arr {
		item_map := x.as_map()
		mut final_item := map[string]json2.Any

		if include_meta {
			mut v := item_map['_index'] or { json2.Any("__error__") }
			final_item['_index'] = v.str()

			v = item_map['_type'] or { json2.Any("__error__") }
			final_item['_type'] = v.str()

			v = item_map['_id'] or { json2.Any("__error__") }
			final_item['_id'] = v.str()
		}
		v := item_map['_source'] or { 
			return error("[parse_es_hits_response] failed to get the _source on hits.hits array, item[$idx]") 
		}
		final_item['_source'] = v
		// append the object to sb
		sb.write_string("${final_item.str()}\n")

		// update the last_sort_meta
		if idx == last_idx {
			v1 := item_map['sort'] or { return error("[parse_es_hits_response] failed to get 'sort' clause, item[$idx]") }
			p_res.last_sort_meta = v1.arr().str()
		}
	}
	f.write_string(sb.str()) or {
		return error("[parse_es_hits_response] failed to write to file, reason: $err")
	}

	p_res.is_hits_empty = false
	return p_res
}
// force_continue_parsing - create the [Parse_es_response] with the next _doc (natural order) 
// based on the interval declared by [batch_size].
fn force_continue_parsing(p_res Parse_es_response, batch_size int) ?Parse_es_response {
	// extract the id value...
	i_2 := p_res.last_sort_meta.index("]") or { 2 }
	i_after := strconv.atoi(p_res.last_sort_meta[1..i_2]) or {
		return error("[force_continue_parsing] 0. last_sort_meta is invalid... terminate now. ${p_res.last_sort_meta}")	
	}
	//println("after strconv ${i_after} and ${i_after+10000}")
	return Parse_es_response{
		last_sort_meta: "[${i_after+batch_size}]"
		is_hits_empty: false
	}
}



/* TODO: extract this logic to another fn ...
// check whether the response is a valid ES response (invalid == contain a root field "error")
v := json2.raw_decode(r.text) or {
	println("[is_valid_operator] failed to decode the contents of the http response [${r.text}], reason: $err")
	return false
}
m := v.as_map()
v_err := m["error"] or {
	// valid response~
	return true
}
println("[is_valid_operator] 'error' occured, ${v_err}")
return false
*/