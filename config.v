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
import os

const (
	// version - a hard-coded version to describe which version of configuration is supported.
	version = "1.0"
	env_username = "vlastic_user"
	env_password = "vlastic_pwd"
)

// Config - encapsulation of the json config file.
struct Config {
	// [json: es_hosts] -> attributes for the field es_hosts; similar to golang `json:es_hosts
	// ref: https://modules.vlang.io/x.json2.html`
	es_host string [json: es_host]
	exports Exports
	imports Imports
	
mut:	
	es_username string
	es_password string
}
// Exports - encapsulate the exports config.
struct Exports {
	// export_indices_meta - whether per doc's _index, _id and _type should be exported too
	export_indices_meta bool
	// export_indices_settings_mappings - should export indices' settings and mappings config?
	export_indices_settings_mappings bool
	// indices - target indices for export (e.g. "class_b,high_school_classes")
	indices []string
	// filter_query - query as string format to apply during the export operation
	filter_query string
	// target_folder - where to save the exported file(s)
	target_folder string
}
// Imports - encapsulate the imports config.
struct Imports {
	// create_target_indices - should create the target indices based on the exported indices file?
	create_target_indices []string
	// target_indices - might seem duplicated, however, some indices might not need to be created and re-used, 
	// hence this config is still required.
	target_indices []string
	// source_folder - where the data files are located.
	source_folder string
	// use_indices_meta - whether meta _index, _id, _type should be used; if not used, 
	// might created duplicated data as documents would imported using a generated ID.
	use_indices_meta bool
}

// parse_config - load and parse the [file].
fn parse_config(file string) ?Config {
	c := os.read_file(file) or {
		return error("[parse_config] failed to load the config file [$file], reason: ${err}")
	}
	mut cfg := json.decode(Config, c) or {
		return error("[parse_config] failed to parse the config, reason: ${err}")
	}
	// if config file doesn't contain such info... will check if environment variable contains the vlastic_user or vlastic_pwd
	env_map := os.environ()
	if cfg.es_username == "" {
		if env_username in env_map {
			cfg.es_username = env_map[env_username]
		}
	}
	if cfg.es_password == "" {
		if env_password in env_map {
			cfg.es_password = env_map[env_password]
		}
	}
	return cfg
}


/* // sample config file.
{
	"es_hosts": [ "http://localhost:9200", "https://some_host:9205" ],
	"es_username": "elastic",  <- can be retrieved through environment variable (vlastic_user)
	"es_password": "password", <- can be retrieved through environment variable (vlastic_pwd)
   
	"exports": {
		"export_indices_meta": false, <- whether per doc's _index, _id and _type should be exported too
		"export_indices_settings_mappings": true, <- should export indices' settings and mappings config?
		"indices": [ "class_b", "high_school_classes" ], <- target indices for export (e.g. "class_b,high_school_classes")
		"filter_query": "{ \"match\": { \"category\": \"Education\" }}", <- query as json format to apply during the export operation,
		"target_folder": "/user/exporter/data/" <- where to save the exported file(s)
	},

	"imports": {
		"create_target_indices": [ "class_b" ], <- should create the target indices based on the exported indices file?
		"target_indices": [ "class_b", "high_school_classes" ], <- might seem duplicated, however, some indices might not need to be created and re-used, hence this config is still required.
		"source_folder": "/user/exporter/data/", 
		"use_indices_meta": true <- whether meta _index, _id, _type should be used; if not used, might created duplicated data as documents would imported using a generated ID.
	}
}
*/