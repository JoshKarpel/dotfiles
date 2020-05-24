#!/usr/bin/env bash

function background_get_ubuntu() {
  gsettings get org.gnome.desktop.background picture-uri
}

function background_set_ubuntu() {
  gsettings set org.gnome.desktop.background picture-uri file://"$1"
}
