#!/usr/bin/env bash

## typecho模组 typecho moudle

set +e

install_typecho() {
	cd /usr/share/nginx/
	curl --retry 5 -LO https://github.com/typecho/typecho/releases/latest/download/typecho.zip
	unzip typecho.zip
	rm *.zip
	mv build typecho
}
